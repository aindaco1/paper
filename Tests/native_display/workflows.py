#!/usr/bin/env python3
"""Actual app workflows using the shared metadata-only WindowServer fixture."""
import argparse
import hashlib
import json
import os
import pathlib
import plistlib
import subprocess
import tempfile
import time
from regression import NativeTools, PaperCase, ROOT, serial_desktop, settings, terminate, wait_for


def run(app, evidence):
    report = dict(status='failed', executableSHA256=hashlib.sha256((app/'Contents/MacOS/Paper').read_bytes()).hexdigest(), cases=[])
    try:
        with serial_desktop(), tempfile.TemporaryDirectory(prefix='paper-workflows-') as directory:
            root = pathlib.Path(directory)
            tools = NativeTools(root, window=True)
            screens = tools.screens()
            front = tools.window('snapshot', os.getpid())['frontPID']
            front_id = tools.window('snapshot', os.getpid())['frontBundleIdentifier']
            for label, updates, visible in [
                ('active with lamp and strip', dict(deskLamp=dict(enabled=True,warmth=0.7,strength=0.4),
                    readingStrip=dict(enabled=True,center=0.5,height=0.15)), True),
                ('manual off', dict(enabled=False), False),
                ('presentation', dict(presentationPaused=True), False),
                ('snoozed', dict(snoozeUntil=time.time()-978307200+600), False),
                ('excluded app', dict(excludedApps=[dict(bundleID=front_id,name='Foreground test')]), False),
                ('excluded display', dict(disabledDisplays=[s['id'] for s in screens]), False),
            ]:
                preferences = settings(); preferences.update(updates)
                case = PaperCase(app, tools, root/label, preferences)
                try:
                    result = case.check(screens if visible else [], front, label)
                    # A transparent window still fails: the pause must remove it from WindowServer.
                    if not visible and any(w['layer'] > 0 for w in result['windowState']['windows']):
                        raise AssertionError(label + ': paused overlay still exists')
                    report['cases'].append(result)
                finally: case.close()
            # Copy the same signed bundle without altering the signature or bundle identity.
            copied = root/'Downloaded Paper.app'
            subprocess.run(['ditto', str(app), str(copied)], check=True)
            first = PaperCase(app, tools, root/'instance', settings())
            extras = []
            try:
                first.check(screens, front, 'first instance ready')
                environment = dict(os.environ, PAPER_TEST_SUITE=first.suite.removeprefix('xyz.dustwave.paper.test.'))
                for bundle in (app, copied, copied):
                    extras.append(subprocess.Popen([str(bundle/'Contents/MacOS/Paper'), '--background'], env=environment,
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
                for process in extras:
                    if process.wait(timeout=15) != 0: raise AssertionError('Duplicate did not exit cleanly')
                snap = first.snapshot()
                if len([w for w in snap['windows'] if w['layer'] > 0]) != len(screens):
                    raise AssertionError('Duplicate overlays exist')
                if snap['frontPID'] != first.process.pid: raise AssertionError('Existing app was not brought forward')
                report['cases'].append(dict(name='simultaneous copied-app launches activate existing owner',status='passed',windowState=snap))
                # The kernel must release the lease after an unclean exit too.
                first.process.kill(); first.process.wait(timeout=5)
                replacement = subprocess.Popen([str(copied/'Contents/MacOS/Paper'), '--background'], env=environment,
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                extras.append(replacement)
                wait_for(lambda: len([w for w in tools.window('snapshot', replacement.pid)['windows'] if w['layer'] > 0]) == len(screens), 'lease recovery after crash')
                report['cases'].append(dict(name='copy acquires lease after owner is killed',status='passed'))
                terminate(replacement)
                contenders = [subprocess.Popen([str(bundle/'Contents/MacOS/Paper'), '--background'], env=environment,
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) for bundle in (app, copied, app)]
                extras.extend(contenders)
                wait_for(lambda: sum(p.poll() is None for p in contenders) == 1, 'single winner of cold launch race')
                winner = next(p for p in contenders if p.poll() is None)
                wait_for(lambda: len([w for w in tools.window('snapshot', winner.pid)['windows'] if w['layer'] > 0]) == len(screens), 'cold race winner overlays')
                if any(p.returncode != 0 for p in contenders if p is not winner):
                    raise AssertionError('Cold launch contender failed')
                report['cases'].append(dict(name='three simultaneous cold launches have one owner',status='passed'))
            finally:
                for process in extras: terminate(process)
                first.close()
            report['status'] = 'passed'
    except Exception as error:
        report['error'] = str(error)
        raise
    finally:
        PaperCase.cleanup_suites()
        evidence.parent.mkdir(parents=True, exist_ok=True)
        evidence.write_text(json.dumps(report, indent=2)+'\n')
    print(f"PASS {len(report['cases'])} workflow cases")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--app', type=pathlib.Path, required=True)
    parser.add_argument('--evidence', type=pathlib.Path, required=True)
    args = parser.parse_args()
    run(args.app.resolve(), args.evidence.resolve())
