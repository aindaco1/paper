#!/usr/bin/env python3
"""Real Paper overlay checks using Platform's test-only virtual monitors."""
import argparse
import hashlib
import json
import os
import pathlib
import platform
import plistlib
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'shared/dust-wave-platform/tools/macos-display'))
from support import NativeTools, serial_desktop, terminate, wait_for


def overlay_failures(snapshot, screens, front, intensity=0.19, level=1000):
    windows = [w for w in snapshot['windows'] if w['layer'] >= 1 and w['alpha'] > 0]
    failures = []
    if len(windows) != len(screens):
        failures.append(f'Expected {len(screens)} overlays, got {len(windows)}')
    for screen in screens:
        matches = [w for w in windows if all(abs(w['frame'][a] - screen[b]) <= 1 for a, b in
                    [('X', 'x'), ('Y', 'y'), ('Width', 'width'), ('Height', 'height')])]
        if len(matches) != 1:
            failures.append('Overlay does not exactly cover display ' + screen['name'])
        elif abs(matches[0]['alpha'] - (intensity.get(screen['id'], 0.19) if isinstance(intensity, dict) else intensity)) > 0.01:
            failures.append('Isolated test intensity was not applied')
        elif matches[0]['layer'] != level:
            failures.append('Overlay has the wrong window level')
    if snapshot['frontPID'] != front:
        failures.append('Overlay stole foreground focus')
    return failures


def settings(enabled=True, excluded=()):
    return dict(enabled=enabled, textureID='classic-matte', intensity=0.19, grainScale=1,
                grainStrength=1, pauseOnBattery=False, pauseOnLowPower=False,
                shortcutEnabled=False, disabledDisplays=list(excluded), excludedApps=[],
                schedule=dict(enabled=False, startMinute=1080, endMinute=420))


class PaperCase:
    suites = set()
    def __init__(self, app, tools, root, preferences):
        self.tools = tools
        root.mkdir()
        identifier = str(uuid.uuid4())
        self.suite = 'xyz.dustwave.paper.test.' + identifier
        self.suites.add(self.suite)
        preferences_file = root / 'preferences.plist'
        with preferences_file.open('wb') as handle:
            plistlib.dump({'settings.v1': json.dumps(preferences).encode()}, handle)
        subprocess.run(['defaults', 'import', self.suite, str(preferences_file)], check=True)
        environment = dict(os.environ, PAPER_TEST_SUITE=identifier)
        self.process = subprocess.Popen([str(app / 'Contents/MacOS/Paper'), '--background'], env=environment,
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def snapshot(self):
        if self.process.poll() is not None:
            raise RuntimeError('Paper exited during native display test')
        return self.tools.window('snapshot', self.process.pid)

    def check(self, screens, front, label, level=1000, intensity=0.19):
        # Wait only for creation/readiness, not for geometry/focus assertions to pass.
        if screens:
            wait_for(lambda: any(w['layer'] >= 1 and w['alpha'] > 0 for w in self.snapshot()['windows']),
                     'first overlay window')
        else:
            time.sleep(0.5)
        time.sleep(0.3)
        snapshot = self.snapshot()
        failures = overlay_failures(snapshot, screens, front, level=level, intensity=intensity)
        if failures:
            raise AssertionError(label + ': ' + '; '.join(failures) + '; observed ' + json.dumps(snapshot))
        return {'name': label, 'status': 'passed', 'displays': screens, 'windowState': snapshot}

    def close(self):
        terminate(self.process)
        subprocess.run(['defaults', 'delete', self.suite], check=True, stdout=subprocess.DEVNULL)

    @classmethod
    def cleanup_suites(cls):
        # CFPreferences can finish an in-flight write after a process exits.
        # Do a final, verified cleanup after all owned processes have stopped.
        for _ in range(3):
            for suite in cls.suites:
                subprocess.run(['defaults', 'delete', suite], capture_output=True)
            time.sleep(0.2)
            remaining = set()
            for suite in cls.suites:
                result = subprocess.run(['defaults', 'export', suite, '-'], capture_output=True)
                if result.returncode == 0 and plistlib.loads(result.stdout):
                    remaining.add(suite)
            cls.suites = remaining
            if not cls.suites:
                return
        raise RuntimeError('Temporary preferences cleanup failed')


def run(app, evidence):
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    binary = app / 'Contents/MacOS/Paper'
    report = dict(status='failed', version=info['CFBundleShortVersionString'],
                  executableSHA256=hashlib.sha256(binary.read_bytes()).hexdigest(), os=platform.platform(), cases=[])
    try:
        with serial_desktop(), tempfile.TemporaryDirectory(prefix='paper-native-display-') as directory:
            root = pathlib.Path(directory)
            tools = NativeTools(root, window=True)
            report['permissions'] = tools.window('permissions')
            baseline = tools.screens()
            report['baseline'] = baseline
            front = tools.window('snapshot', os.getpid())['frontPID']
            counter = 0
            for width, height, scale, origin in [(1920,1080,1,None), (1280,720,2,None),
                                                (1280,1024,1,(-1280,0)), (1280,720,2,(0,-720))]:
                with tools.display(width,height,scale,origin) as display:
                    for enabled, excluded, label in [(True, (), 'all displays'),
                            (True, (display['screen']['id'],), 'virtual display excluded'), (False, (), 'manual off')]:
                        counter += 1
                        case = PaperCase(app, tools, root / str(counter), settings(enabled, excluded))
                        try:
                            expected = [s for s in display['screens'] if enabled and s['id'] not in excluded]
                            report['cases'].append(case.check(expected, front, f'{width}x{height}@{scale} {origin}: {label}'))
                        finally:
                            case.close()
                print('PASS topology', width,height,scale,origin, flush=True)
            # Per-display override must affect only its own screen.
            with tools.display(1440,900,1) as display:
                preferences = settings()
                overrides = {display['screen']['id']: 0.37}
                preferences['displayIntensities'] = overrides
                case = PaperCase(app, tools, root/'intensities', preferences)
                try:
                    report['cases'].append(case.check(display['screens'],front,'per-display intensity',intensity=overrides))
                finally: case.close()
            # Selected-app mode is fail-closed; exclusion and manual off still win.
            front_id = tools.window('snapshot',os.getpid())['frontBundleIdentifier']
            if not front_id: raise RuntimeError('A foreground app with a bundle ID is required')
            for selected, excluded, enabled, label in [(False,False,True,'not selected'),
                    (True,False,True,'selected'),(True,True,True,'selected and excluded'),(True,False,False,'selected but off')]:
                preferences = settings(enabled)
                preferences.update(appRuleMode='only', includedApps=[dict(bundleID=front_id,name='Foreground fixture')] if selected else [])
                if excluded: preferences['excludedApps'] = preferences['includedApps']
                case = PaperCase(app,tools,root/label,preferences)
                try:
                    report['cases'].append(case.check(baseline if selected and not excluded and enabled else [],front,'only-app mode: '+label))
                finally: case.close()
            # Keep the actual app running while a display attaches and disconnects.
            case = PaperCase(app, tools, root/'hotplug', settings())
            try:
                report['cases'].append(case.check(baseline, front, 'before hot-plug'))
                with tools.display(1440,900,1) as display:
                    wait_for(lambda: len([w for w in case.snapshot()['windows'] if w['layer'] >= 1000 and w['alpha'] > 0]) == len(display['screens']), 'new display overlay')
                    report['cases'].append(case.check(display['screens'],front,'display attached while running'))
                wait_for(lambda: len([w for w in case.snapshot()['windows'] if w['layer'] >= 1000 and w['alpha'] > 0]) == len(baseline), 'disconnected display removed')
                report['cases'].append(case.check(baseline,front,'display removed while running'))
            finally:
                case.close()
            # A real accessory panel that does not activate its owning application.
            fixture = root/'FloatingFixture.app/Contents'
            (fixture/'MacOS').mkdir(parents=True)
            identifier = 'xyz.dustwave.paper.fixture.floating'
            (fixture/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier=identifier,
                CFBundleExecutable='FloatingFixture', CFBundlePackageType='APPL', LSUIElement=True)))
            subprocess.run(['swiftc', str(ROOT/'Tests/native_display/FloatingPanel.swift'),
                            '-o', str(fixture/'MacOS/FloatingFixture')], check=True)
            subprocess.run(['codesign', '--sign', '-', str(fixture.parent)], check=True)
            floating = subprocess.Popen([str(fixture/'MacOS/FloatingFixture')],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                wait_for(lambda: any(w['layer'] == 27 for w in tools.window('snapshot', floating.pid)['windows']),
                         'nonactivating floating panel')
                if tools.window('snapshot', floating.pid)['frontPID'] != front:
                    raise RuntimeError('Floating fixture activated itself; no overlay focus assertion is valid')
                for excluded in (False, True):
                    preferences = settings()
                    if excluded:
                        preferences['excludedApps'] = [dict(bundleID=identifier, name='Floating fixture')]
                    case = PaperCase(app, tools, root/f'floating-{excluded}', preferences)
                    try:
                        time.sleep(0.7)
                        report['cases'].append(case.check(baseline, front,
                            f'nonactivating panel excluded={excluded}', level=26 if excluded else 1000))
                        if excluded:
                            terminate(floating)
                            time.sleep(0.7)
                            report['cases'].append(case.check(baseline, front, 'excluded floating app closed'))
                    finally:
                        case.close()
            finally:
                terminate(floating)
            report['restoredDisplays'] = tools.screens()
            report['status'] = 'passed'
    except Exception as error:
        report['error'] = str(error)
        raise
    finally:
        try:
            PaperCase.cleanup_suites()
        except Exception as error:
            report['status'] = 'failed'
            report['cleanupError'] = str(error)
            raise
        finally:
            evidence.parent.mkdir(parents=True,exist_ok=True)
            evidence.write_text(json.dumps(report,indent=2)+'\n')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app',type=pathlib.Path,required=True)
    parser.add_argument('--evidence',type=pathlib.Path,required=True)
    args=parser.parse_args()
    run(args.app.resolve(),args.evidence.resolve())
