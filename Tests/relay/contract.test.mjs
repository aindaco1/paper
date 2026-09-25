import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { validatePaperReport, paperFingerprint, paperRelayReport } from '../../integrations/crash-relay/paper-contract.mjs';
const sample = () => JSON.parse(readFileSync(new URL('../Fixtures/paper-diagnostic.json', import.meta.url)));
test('Swift golden report validates and remains bounded', () => {
    const r = sample(); assert.equal(validatePaperReport(r), r);
    assert.equal(paperRelayReport(r).app.identifier, 'xyz.dustwave.paper');
    assert.equal(paperRelayReport(r).report.stack, '');
});
test('unknown fields and free text fail closed at every level', () => {
    for (const mutate of [r => r.path = '/Users/private', r => r.application.name = 'Private',
            r => r.state.events.push('raw private error'), r => r.state.pause = 'Private App',
            r => r.state.displays = -1, r => r.state.intensityBucket = true,
            r => r.state.events = Array(21).fill('launch'), r => r.kind = 'unknown',
            r => r.application.version = 'private', r => r.state.excludedDisplays = 2]) {
        const r = sample(); mutate(r); assert.throws(() => validatePaperReport(r));
    }
});
test('state grouping ignores report IDs and routine log noise', async () => {
    const a = sample(), b = sample(); b.id = crypto.randomUUID(); b.state.events.push('toggled'); b.application.version = '0.4.1';
    assert.equal(await paperFingerprint(a), await paperFingerprint(b));
    b.state.events.push('importFailed'); assert.notEqual(await paperFingerprint(a), await paperFingerprint(b));
});
test('native grouping uses incident build and excludes present state', async () => {
    const a = sample(); a.kind = 'native_crash'; a.crash = {exception:'EXC_BAD_ACCESS',signal:'SIGSEGV',image:'Paper',imageOffset:123,version:'0.4.0',build:'7',operatingSystem:'27.0.0'};
    const b = structuredClone(a); b.state.pause = 'disabled'; b.state.events.push('importFailed');
    b.crash = Object.fromEntries(Object.entries(b.crash).reverse());
    assert.equal(await paperFingerprint(a), await paperFingerprint(b));
    b.crash.imageOffset = 124; assert.notEqual(await paperFingerprint(a), await paperFingerprint(b));
    b.crash.rawStack = 'private'; assert.throws(() => validatePaperReport(b));
});
