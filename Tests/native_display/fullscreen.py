#!/usr/bin/env python3
"""Enter a real macOS fullscreen Space; inspect the signed Paper app there and back."""
import argparse, hashlib, json, os, pathlib, platform, plistlib, subprocess, tempfile, time
from regression import ROOT, NativeTools, PaperCase, settings, serial_desktop, terminate, wait_for


def run(app, evidence):
    report = dict(status='failed', os=platform.platform(), cases=[],
        executableSHA256=hashlib.sha256((app/'Contents/MacOS/Paper').read_bytes()).hexdigest())
    try:
        with serial_desktop(), tempfile.TemporaryDirectory(prefix='paper-fullscreen-') as folder:
            root=pathlib.Path(folder); tools=NativeTools(root,window=True)
            original_front=tools.window('snapshot',os.getpid())['frontPID']
            fixture=root/'LifecycleFixture.app/Contents'; (fixture/'MacOS').mkdir(parents=True)
            identifier='xyz.dustwave.paper.fixture.lifecycle'
            (fixture/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier=identifier,
                CFBundleExecutable='LifecycleFixture', CFBundlePackageType='APPL')))
            subprocess.run(['swiftc',str(ROOT/'Tests/native_display/LifecycleFixture.swift'),'-o',str(fixture/'MacOS/LifecycleFixture')],check=True)
            subprocess.run(['codesign','--sign','-',str(fixture.parent)],check=True)
            events=root/'events.jsonl'; command=root/'command'
            process=subprocess.Popen([str(fixture/'MacOS/LifecycleFixture'),str(events),str(command)])
            read=lambda: [json.loads(row) for row in events.read_text().splitlines()] if events.exists() else []
            def event(name): return next((row for row in read() if row['event']==name),None)
            try:
                wait_for(lambda:event('ready'),'fixture ready')
                tools.window('activate',process.pid)
                wait_for(lambda:tools.window('snapshot',process.pid)['frontPID']==process.pid,'fixture foreground')
                screens=tools.screens()
                case=PaperCase(app,tools,root/'active',settings())
                try:
                    report['cases'].append(case.check(screens,process.pid,'before fullscreen'))
                    command.write_text('enter')
                    entered=wait_for(lambda:event('entered-fullscreen'),'actual fullscreen Space entered',timeout=25)
                    if not entered['fullscreen']: raise AssertionError('Fixture did not enter native fullscreen')
                    time.sleep(1)
                    report['cases'].append(case.check(screens,process.pid,'in native fullscreen Space'))
                    command.write_text('exit')
                    exited=wait_for(lambda:event('exited-fullscreen'),'fullscreen Space exited',timeout=25)
                    if exited['fullscreen']: raise AssertionError('Fixture did not exit native fullscreen')
                    time.sleep(1)
                    report['cases'].append(case.check(screens,process.pid,'after fullscreen'))
                finally: case.close()
                previous=sum(row['event']=='entered-fullscreen' for row in read())
                command.write_text('enter')
                wait_for(lambda:sum(row['event']=='entered-fullscreen' for row in read())>previous,'second fullscreen entry',timeout=25)
                time.sleep(1)
                for label,preferences in [('manual off',settings(False)),('excluded app',settings()),('excluded displays',settings(True,[s['id'] for s in screens]))]:
                    if label=='excluded app': preferences['excludedApps']=[dict(bundleID=identifier,name='Fullscreen fixture')]
                    case=PaperCase(app,tools,root/label,preferences)
                    try: report['cases'].append(case.check([],process.pid,'fullscreen '+label))
                    finally: case.close()
                command.write_text('exit')
                wait_for(lambda:sum(row['event']=='exited-fullscreen' for row in read())==2,'second fullscreen exit',timeout=25)
                report['events']=read(); report['status']='passed'
            finally:
                terminate(process)
                if original_front: tools.window('activate',original_front)
    except Exception as error:
        report['error']=str(error); raise
    finally:
        PaperCase.cleanup_suites()
        evidence.parent.mkdir(parents=True,exist_ok=True)
        evidence.write_text(json.dumps(report,indent=2)+'\n')
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app',type=pathlib.Path,required=True); parser.add_argument('--evidence',type=pathlib.Path,required=True)
    a=parser.parse_args(); run(a.app.resolve(),a.evidence.resolve())
