#!/usr/bin/env python3
"""Sustained per-process kernel counters for an isolated, signed Paper executable."""
import argparse, hashlib, json, pathlib, platform, plistlib, subprocess, sys, tempfile, time
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'Tests/native_display'))
from regression import PaperCase, settings, serial_desktop

parser = argparse.ArgumentParser()
parser.add_argument('--app', type=pathlib.Path, required=True)
parser.add_argument('--scenario', choices=['active','paused','off'], required=True)
parser.add_argument('--seconds', type=int, default=600)
parser.add_argument('--excluded-app')
parser.add_argument('--effects', action='store_true', help='Enable static lamp and reading strip for the active scenario.')
parser.add_argument('--evidence', type=pathlib.Path, required=True)
a = parser.parse_args()
app = a.app.resolve()
report = dict(status='failed', scenario=a.scenario, os=platform.platform(),
    version=plistlib.loads((app/'Contents/Info.plist').read_bytes())['CFBundleShortVersionString'],
    executableSHA256=hashlib.sha256((app/'Contents/MacOS/Paper').read_bytes()).hexdigest(),
    energyScope='Kernel-attributed process energy; excludes WindowServer, display and other apps. Not battery drain or wall power.')
try:
    with serial_desktop(), tempfile.TemporaryDirectory(prefix='paper-energy-') as directory:
        root = pathlib.Path(directory)
        observer = root/'ProcessUsage'
        subprocess.run(['clang','-Wall','-Wextra',str(ROOT/'Tests/performance/ProcessUsage.c'),'-o',str(observer)],check=True)
        preferences = settings(enabled=a.scenario != 'off')
        if a.scenario == 'paused': preferences['snoozeUntil'] = time.time()-978307200+7200
        if a.excluded_app: preferences['excludedApps'] = [dict(bundleID=a.excluded_app,name='Measurement exclusion')]
        if a.effects:
            preferences.update(deskLamp=dict(enabled=True,warmth=0.5,strength=0.3),readingStrip=dict(enabled=True,center=0.5,height=0.15))
        report['preferences'] = preferences
        case = PaperCase(app,None,root/'case',preferences)
        try:
            time.sleep(10)
            result = subprocess.run([str(observer),str(case.process.pid),str(a.seconds)],text=True,capture_output=True,check=True)
            samples = [json.loads(row) for row in result.stdout.splitlines()]
            first,last = samples[0],samples[-1]
            elapsed = last['elapsed']-first['elapsed']
            delta = lambda key: last[key]-first[key]
            energy = delta('energyNanojoules')
            report.update(status='passed',seconds=elapsed,samples=samples,
                cpuPercent=100*(delta('userNs')+delta('systemNs'))/1e9/elapsed,
                interruptWakeupsPerSecond=delta('interruptWakeups')/elapsed,
                idleWakeupsPerSecond=delta('idleWakeups')/elapsed,
                physicalMemoryGrowthBytes=delta('physicalBytes'),
                peakPhysicalBytes=max(row['physicalBytes'] for row in samples),
                readBytes=delta('readBytes'),writeBytes=delta('writeBytes'),
                energyJoules=energy/1e9 if energy > 0 else None,
                averageProcessMilliwatts=energy/1e6/elapsed if energy > 0 else None)
        finally: case.close()
except Exception as error:
    report['error'] = str(error)
    raise
finally:
    PaperCase.cleanup_suites()
    a.evidence.parent.mkdir(parents=True,exist_ok=True)
    a.evidence.write_text(json.dumps(report,indent=2)+'\n')
