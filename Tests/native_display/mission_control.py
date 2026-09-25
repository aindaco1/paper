#!/usr/bin/env python3
"""Exercise the real Mission Control overview without capturing screen contents."""
import argparse
import contextlib
import hashlib
import json
import os
import pathlib
import platform
import plistlib
import shutil
import subprocess
import tempfile
import time

from regression import ROOT, NativeTools, PaperCase, settings, serial_desktop, terminate, wait_for
from support import ready


@contextlib.contextmanager
def foreground_fixture(tools, root):
    original = tools.window('snapshot', os.getpid())['frontPID']
    bundle = root/'MissionControlFixture.app/Contents'
    (bundle/'MacOS').mkdir(parents=True)
    (bundle/'Info.plist').write_bytes(plistlib.dumps(dict(
        CFBundleIdentifier='xyz.dustwave.paper.fixture.mission-control',
        CFBundleExecutable='WindowProbe', CFBundlePackageType='APPL')))
    shutil.copyfile(root/'WindowProbe', bundle/'MacOS/WindowProbe')
    (bundle/'MacOS/WindowProbe').chmod(0o755)
    process = subprocess.Popen([str(bundle/'MacOS/WindowProbe'), 'sentinel'], stdout=subprocess.PIPE, text=True)
    try:
        ready(process)
        tools.window('activate', process.pid)
        wait_for(lambda: tools.window('snapshot', process.pid)['frontPID'] == process.pid,
                 'controlled fixture foreground')
        yield process.pid
    finally:
        terminate(process)
        if original:
            tools.window('activate', original)


def run(app, evidence):
    report = dict(status='failed', os=platform.platform(), cases=[],
                  executableSHA256=hashlib.sha256((app/'Contents/MacOS/Paper').read_bytes()).hexdigest())
    try:
        (ROOT/'dist').mkdir(exist_ok=True)
        with serial_desktop(), tempfile.TemporaryDirectory(prefix='mission-control-', dir=ROOT/'dist') as folder:
            root = pathlib.Path(folder)
            tools = NativeTools(root, window=True)
            probe = root/'MissionControlProbe'
            subprocess.run(['swiftc', str(ROOT/'Tests/native_display/MissionControlProbe.swift'),
                            '-o', str(probe)], check=True, timeout=60)

            def active():
                return json.loads(subprocess.check_output([str(probe)], text=True, timeout=5))

            def toggle():
                subprocess.run(['open', '/System/Applications/Mission Control.app'], check=True, timeout=5)

            @contextlib.contextmanager
            def overview():
                try:
                    toggle()
                    wait_for(active, 'Mission Control actually opened')
                    time.sleep(1)  # Let the system transition finish.
                    yield
                finally:
                    if active():
                        # Escape must go through the system event stream. Posting
                        # it directly to Dock's PID can leave the overview open.
                        subprocess.run(['osascript', '-e', 'tell application "System Events" to key code 53'],
                                       check=True, timeout=5)
                        wait_for(lambda: not active(), 'Mission Control closed')
                        time.sleep(1)

            if active():
                raise RuntimeError('Close Mission Control before running the suite')
            screens = tools.screens()
            with foreground_fixture(tools, root) as front:
                # Mission Control may restore the last user-activated app rather
                # than an AX-activated fixture. Measure that transition without
                # Paper, then require identical focus while Paper is present.
                with overview():
                    during_front = tools.window('snapshot', os.getpid())['frontPID']
                restored_front = tools.window('snapshot', os.getpid())['frontPID']
                report['focusBaseline'] = dict(before=front, during=during_front, restored=restored_front)
                for label, preferences, expected, cycles in [
                    ('enabled', settings(), screens, 2),
                    ('manual off', settings(False), [], 1),
                    ('excluded displays', settings(True, [s['id'] for s in screens]), [], 1),
                ]:
                    tools.window('activate', front)
                    wait_for(lambda: tools.window('snapshot', front)['frontPID'] == front, 'fixture foreground')
                    case = PaperCase(app, tools, root/label, preferences)
                    try:
                        report['cases'].append(case.check(expected, front, label + ': before overview'))
                        for cycle in range(cycles):
                            if cycle:
                                tools.window('activate', front)
                                wait_for(lambda: tools.window('snapshot', front)['frontPID'] == front, 'fixture foreground')
                            with overview():
                                result = case.check([], during_front, f'{label}: in overview {cycle + 1}')
                                if not active():
                                    raise AssertionError('Mission Control closed before the overlay assertion')
                                result['missionControlActive'] = True
                                report['cases'].append(result)
                            report['cases'].append(case.check(expected, restored_front, f'{label}: restored {cycle + 1}'))
                    finally:
                        case.close()
                    print('PASS Mission Control:', label, flush=True)
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
            evidence.parent.mkdir(parents=True, exist_ok=True)
            evidence.write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=pathlib.Path, required=True)
    parser.add_argument('--evidence', type=pathlib.Path, required=True)
    args = parser.parse_args()
    run(args.app.resolve(), args.evidence.resolve())
