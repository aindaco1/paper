#!/usr/bin/env python3
"""Sign with an installed identity; notarize with local Apple Auth API credentials.

Credentials are read in place and never copied into artifacts or receipts.
The receipt retains the submission ID so a timed-out submission can be resumed.
"""
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import uuid


def identity():
    configured = os.environ.get('PAPER_SIGNING_IDENTITY')
    if configured:
        return configured
    output = subprocess.check_output(['security', 'find-identity', '-v', '-p', 'codesigning'], text=True)
    identities = re.findall(r'([A-F0-9]{40}) "Developer ID Application: [^\"]+"', output)
    if len(identities) != 1:
        raise RuntimeError('Set PAPER_SIGNING_IDENTITY to one installed Developer ID Application identity.')
    return identities[0]


def credentials():
    root = pathlib.Path(os.environ.get('DUSTWAVE_APPLE_AUTH_DIR',
        str(pathlib.Path.home() / 'Library/Mobile Documents/com~apple~CloudDocs/Apple Auth')))
    keys = [p for p in root.glob('AuthKey_*.p8') if re.fullmatch(r'AuthKey_[A-Z0-9]+\.p8', p.name)]
    if len(keys) != 1:
        raise RuntimeError('Apple Auth must contain exactly one AuthKey_*.p8 API key.')
    issuer_path = next((root / name for name in ('apple-api-issuer.txt', 'app-store-connect-issuer.txt', 'issuer.txt')
                        if (root / name).is_file()), None)
    if issuer_path is None:
        raise RuntimeError('Apple Auth is missing apple-api-issuer.txt.')
    issuer = str(uuid.UUID(issuer_path.read_text().strip()))
    return ['--key', str(keys[0]), '--key-id', keys[0].stem.removeprefix('AuthKey_'), '--issuer', issuer]


def apple(command, arguments, auth):
    # Keep subprocess arguments and raw auth errors out of public evidence.
    result = subprocess.run(['xcrun', 'notarytool', command, *arguments, *auth, '--output-format', 'json'],
                            text=True, capture_output=True)
    try:
        data = json.loads(result.stdout)
    except ValueError:
        raise RuntimeError(f'notarytool {command} failed (exit {result.returncode}). Check Apple Auth credentials and network access.') from None
    if result.returncode and data.get('status') != 'In Progress':
        raise RuntimeError(f'notarytool {command} failed (exit {result.returncode}, status {data.get("status", "unknown")}).')
    return data


def notarize(artifact):
    artifact = artifact.resolve()
    auth = credentials()
    submit = artifact
    if artifact.suffix == '.app':
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(artifact)], check=True)
        submit = artifact.parent / (artifact.stem + '-notarization.zip')
        subprocess.run(['ditto', '-c', '-k', '--keepParent', str(artifact), str(submit)], check=True)
    digest = hashlib.sha256(submit.read_bytes()).hexdigest()
    receipt_path = artifact.parent / (artifact.name + '.notary.json')
    receipt = json.loads(receipt_path.read_text()) if receipt_path.exists() else {}
    if receipt.get('submittedSHA256') != digest or not receipt.get('id'):
        result = apple('submit', [str(submit)], auth)
        receipt = {'id': result['id'], 'submittedSHA256': digest, 'status': result.get('status', 'In Progress')}
        receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    print('Notarization submission:', receipt['id'], flush=True)
    result = apple('wait', [receipt['id'], '--timeout', '15m'], auth)
    receipt['status'] = result.get('status', 'unknown')
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    if receipt['status'] != 'Accepted':
        raise RuntimeError(f'Notarization {receipt["status"]}; submission ID retained in {receipt_path.name}.')
    subprocess.run(['xcrun', 'stapler', 'staple', str(artifact)], check=True)
    subprocess.run(['xcrun', 'stapler', 'validate', str(artifact)], check=True)
    gate = ['spctl', '--assess', '--verbose=2']
    gate += ['--type', 'execute'] if artifact.suffix == '.app' else ['--type', 'open', '--context', 'context:primary-signature']
    subprocess.run([*gate, str(artifact)], check=True)
    receipt['stapled'] = True
    receipt['gatekeeper'] = 'accepted'
    receipt_path.write_text(json.dumps(receipt, indent=2) + '\n')
    print('Accepted, stapled and verified:', artifact.name, flush=True)


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['identity']:
            print(identity())
        elif len(sys.argv) == 2:
            notarize(pathlib.Path(sys.argv[1]))
        else:
            raise RuntimeError('Usage: notarize.py identity | path-to-app-or-dmg')
    except (RuntimeError, OSError, subprocess.SubprocessError, ValueError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
