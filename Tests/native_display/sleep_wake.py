#!/usr/bin/env python3
"""Observe a real user-authorized Mac sleep/wake cycle. User must wake and unlock."""
import argparse, hashlib, json, os, pathlib, platform, subprocess, tempfile, time
from regression import ROOT, NativeTools, PaperCase, settings, serial_desktop, terminate, wait_for

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--app',type=pathlib.Path,required=True);p.add_argument('--evidence',type=pathlib.Path,required=True)
p.add_argument('--trigger',type=pathlib.Path,required=True)
p.add_argument('--manual',action='store_true',help='Use the Apple Sleep menu after READY instead of pmset')
a=p.parse_args();app=a.app.resolve()
report=dict(status='failed',os=platform.platform(),cases=[],
    executableSHA256=hashlib.sha256((app/'Contents/MacOS/Paper').read_bytes()).hexdigest())
try:
    with serial_desktop(),tempfile.TemporaryDirectory(prefix='paper-sleep-') as folder:
        root=pathlib.Path(folder);tools=NativeTools(root,window=True)
        probe=root/'LifecycleFixture';events=root/'events.jsonl'
        subprocess.run(['swiftc',str(ROOT/'Tests/native_display/LifecycleFixture.swift'),'-o',str(probe)],check=True)
        process=subprocess.Popen([str(probe),str(events)])
        read=lambda:[json.loads(row) for row in events.read_text().splitlines()] if events.exists() else []
        cases=[]
        try:
            wait_for(lambda:any(x['event']=='ready' for x in read()),'system observer ready')
            screens=tools.screens();front=tools.window('snapshot',os.getpid())['frontPID']
            for label,prefs,expected in [('active',settings(),screens),('manual-off',settings(False),[]),
                    ('display-excluded',settings(True,[s['id'] for s in screens]),[])]:
                case=PaperCase(app,tools,root/label,prefs);cases.append((label,case,expected))
                report['cases'].append(case.check(expected,front,'before sleep: '+label))
            print('READY: waiting for trigger; wake and unlock about 20 seconds after sleeping.',flush=True)
            wait_for(lambda:a.trigger.exists(),'authorized sleep trigger',timeout=300)
            a.trigger.unlink()
            if not a.manual:
                result=subprocess.run(['pmset','sleepnow'],text=True,capture_output=True)
                report['sleepCommand']=dict(returncode=result.returncode,output=result.stdout+result.stderr)
                if result.returncode: raise RuntimeError('pmset could not put the Mac to sleep')
            else: report['sleepCommand']={'method':'Apple menu Sleep'}
            wait_for(lambda:any(x['event']=='NSWorkspaceWillSleepNotification' for x in read()),'real system willSleep',timeout=300)
            wait_for(lambda:any(x['event']=='NSWorkspaceDidWakeNotification' for x in read()),'real system didWake',timeout=300)
            wait_for(lambda:tools.window('snapshot',os.getpid())['frontBundleIdentifier'] not in ('','com.apple.loginwindow'),
                'user unlocked desktop',timeout=300)
            time.sleep(3)
            front=tools.window('snapshot',os.getpid())['frontPID']
            if tools.screens()!=screens: raise AssertionError('Display topology changed across sleep/wake')
            for label,case,expected in cases:
                report['cases'].append(case.check(expected,front,'after real wake: '+label))
            report['events']=read()
            sleep=next(x['time'] for x in report['events'] if x['event']=='NSWorkspaceWillSleepNotification')
            wake=next(x['time'] for x in report['events'] if x['event']=='NSWorkspaceDidWakeNotification')
            if wake<=sleep: raise AssertionError('Wake did not follow sleep')
            report.update(status='passed',sleepToWakeSeconds=wake-sleep)
        finally:
            report['events']=read()
            for _,case,_ in cases: case.close()
            terminate(process)
except Exception as error:
    report['error']=str(error);raise
finally:
    PaperCase.cleanup_suites()
    a.evidence.parent.mkdir(parents=True,exist_ok=True)
    a.evidence.write_text(json.dumps(report,indent=2)+'\n')
