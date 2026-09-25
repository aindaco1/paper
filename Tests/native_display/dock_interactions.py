#!/usr/bin/env python3
"""Keep Paper visible while the real Dock and Command-Tab switcher are open."""
import argparse
import hashlib
import json
import pathlib
import platform
import subprocess
import tempfile
import time

from regression import ROOT, NativeTools, PaperCase, overlay_failures, settings, serial_desktop
from mission_control import foreground_fixture
from support import ready


def observe(case, screens, front, label, duration=0.8):
    # Check every sample, including the first. Waiting for visibility here would
    # hide the very disappearance/restoration regression this suite targets.
    deadline = time.monotonic() + duration
    samples = 0
    failure = None
    while time.monotonic() < deadline:
        snapshot = case.snapshot()
        errors = overlay_failures(snapshot, screens, front)
        if errors and failure is None:
            failure = dict(errors=errors, windowState=snapshot)
        samples += 1
        time.sleep(0.025)
    result = dict(name=label, status='failed' if failure else 'passed', samples=samples)
    if failure:
        result.update(failure)
    return result


def run(app, evidence):
    report = dict(status='failed', os=platform.platform(), cases=[],
                  executableSHA256=hashlib.sha256((app/'Contents/MacOS/Paper').read_bytes()).hexdigest())
    try:
        (ROOT/'dist').mkdir(exist_ok=True)
        with serial_desktop(), tempfile.TemporaryDirectory(prefix='dock-interactions-', dir=ROOT/'dist') as folder:
            root = pathlib.Path(folder)
            tools = NativeTools(root, window=True)
            probe = root/'DockInteractionProbe'
            subprocess.run(['swiftc', str(ROOT/'Tests/native_display/DockInteractionProbe.swift'),
                            '-o', str(probe)], check=True, timeout=60)
            screens = tools.screens()
            with foreground_fixture(tools, root) as front:
                for label, preferences, expected in [
                    ('enabled', settings(), screens),
                    ('manual off', settings(False), []),
                    ('excluded displays', settings(True, [s['id'] for s in screens]), []),
                ]:
                    case = PaperCase(app, tools, root/label, preferences)
                    try:
                        report['cases'].append(case.check(expected, front, label + ': baseline'))
                        for cycle in range(2):
                            for mode in ['dock', 'switcher']:
                                process = subprocess.Popen([str(probe), mode], stdin=subprocess.PIPE,
                                                           stdout=subprocess.PIPE, text=True)
                                try:
                                    if ready(process) != dict(interaction=mode, active=True):
                                        raise AssertionError('Interaction was not independently confirmed')
                                    result = observe(case, expected, front, f'{label}: {mode} {cycle + 1}')
                                    process.stdin.close()
                                    after = json.loads(process.stdout.readline())
                                    if not after['active']:
                                        raise AssertionError('Interaction closed before overlay assertions finished')
                                    process.wait(timeout=5)
                                    if process.returncode:
                                        raise RuntimeError('Input helper failed')
                                    report['cases'].append(result)
                                finally:
                                    if not process.stdin.closed:
                                        process.stdin.close()
                                    # EOF makes the helper release held keys in its defer.
                                    process.wait(timeout=15)
                                    process.stdout.close()
                                time.sleep(0.7)
                                report['cases'].append(observe(case, expected, front,
                                    f'{label}: after {mode} {cycle + 1}', duration=0.2))
                    finally:
                        case.close()
                    print('Checked Dock and Command-Tab:', label, flush=True)
            failed = [c['name'] for c in report['cases'] if c['status'] == 'failed']
            if failed:
                raise AssertionError('Failed interaction checks: ' + ', '.join(failed))
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
