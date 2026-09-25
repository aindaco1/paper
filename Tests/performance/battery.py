#!/usr/bin/env python3
"""Opt-in whole-device discharge observation; never changes system power settings."""
import argparse
import json
import pathlib
import plistlib
import subprocess
import tempfile
import time
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'Tests/native_display'))
from regression import PaperCase, settings, serial_desktop


def battery():
    devices = plistlib.loads(subprocess.check_output(['ioreg', '-r', '-c', 'AppleSmartBattery', '-a']))
    if not devices: raise RuntimeError('No internal battery found')
    device = devices[0]
    if device.get('ExternalConnected') or device.get('IsCharging'):
        raise RuntimeError('Unplug power before measuring; AC-connected results are invalid')
    current, maximum = device.get('AppleRawCurrentCapacity'), device.get('AppleRawMaxCapacity')
    if not isinstance(current, int) or not isinstance(maximum, int) or maximum <= 0:
        raise RuntimeError('Raw battery capacity is unavailable on this Mac')
    return dict(monotonic=time.monotonic(), wallTime=time.time(), currentCapacity=current, maxCapacity=maximum,
                voltageMillivolts=device.get('Voltage'), temperature=device.get('Temperature'))


def run(app, seconds, evidence):
    import hashlib
    report = dict(status='incomplete', executableSHA256=hashlib.sha256((app/'Contents/MacOS/Paper').read_bytes()).hexdigest(),
        scope='Whole-device discharge, not causal app energy. Keep brightness, workload and power mode fixed. Repeat with reversed order.', phases=[])
    try:
        battery()  # Fail before launching any app if prerequisites are missing.
        with serial_desktop(), tempfile.TemporaryDirectory(prefix='paper-battery-') as directory:
            for index, active in enumerate((False, True, True, False)):
                case = PaperCase(app, None, pathlib.Path(directory)/str(index), settings(enabled=active))
                phase = dict(active=active,samples=[]); report['phases'].append(phase)
                try:
                    time.sleep(30)
                    deadline = time.monotonic()+seconds
                    while True:
                        phase['samples'].append(battery())
                        evidence.write_text(json.dumps(report,indent=2)+'\n')
                        if time.monotonic() >= deadline: break
                        time.sleep(min(30,deadline-time.monotonic()))
                    first,last = phase['samples'][0],phase['samples'][-1]
                    if last['wallTime']-first['wallTime'] > seconds+60:
                        raise RuntimeError('A sleep or long interruption invalidated the phase')
                    phase['capacityDrop'] = first['currentCapacity']-last['currentCapacity']
                    phase['seconds'] = last['monotonic']-first['monotonic']
                finally: case.close()
        report['status'] = 'observed'
        report['interpretation'] = 'Compare repeated phases; small or inconsistent capacity changes are inconclusive. This does not isolate panel/GPU/WindowServer energy.'
    except Exception as error:
        report['error'] = str(error)
        raise
    finally:
        PaperCase.cleanup_suites()
        evidence.write_text(json.dumps(report,indent=2)+'\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app',type=pathlib.Path,required=True)
    parser.add_argument('--phase-seconds',type=int,default=600)
    parser.add_argument('--evidence',type=pathlib.Path,required=True)
    parser.add_argument('--preflight', action='store_true', help='Check battery prerequisites only; do not launch Paper or measure.')
    args = parser.parse_args()
    if args.preflight:
        battery(); print('Battery prerequisites available; no measurement was started.'); sys.exit(0)
    if args.phase_seconds < 450: parser.error('Use at least 450 seconds per phase (30 minutes total plus settling).')
    args.evidence.parent.mkdir(parents=True,exist_ok=True)
    run(args.app.resolve(),args.phase_seconds,args.evidence.resolve())
