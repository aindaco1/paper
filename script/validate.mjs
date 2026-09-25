import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { assertConsumerPin } from '../shared/dust-wave-platform/packages/test-core/src/consumer-pin.js';
import { checkDocumentation } from '../shared/dust-wave-platform/packages/test-core/src/documentation.js';
import { sha256File } from '../shared/dust-wave-platform/packages/release-core/src/file-integrity.js';

const root = fileURLToPath(new URL('../', import.meta.url));
assertConsumerPin({ root, expectedCommit: '6bb9854149203ee71445bf150c4ba86fac607d04',
  packages: { 'test-core': '0.3.0', 'release-core': '0.4.0' } });
assert.equal(readFileSync(resolve(root, 'shared/dust-wave-platform/tools/macos-display/VERSION'), 'utf8').trim(), '0.1.0');
for (const entry of JSON.parse(readFileSync(resolve(root, 'docs/vendor-sources.json')))) {
  assert.equal(sha256File(resolve(root, entry.path)), entry.sha256, `Vendored source changed: ${entry.path}`);
}
const files = ['README.md', 'THIRD_PARTY_NOTICES.md', 'docs/upstream-review.md', 'docs/testing.md'];
const result = checkDocumentation({ root, files: files.map(file => resolve(root, file)),
  requiredFiles: files, restrictToRoot: true });
assert.deepEqual(result.errors, []);
console.log(`Platform pin, vendored sources and ${result.markdownFileCount} documents verified.`);
