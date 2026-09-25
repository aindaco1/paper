import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { checkDocumentation } from '../shared/dust-wave-platform/packages/test-core/src/documentation.js';
import { sha256File } from '../shared/dust-wave-platform/packages/release-core/src/file-integrity.js';

const root = fileURLToPath(new URL('../', import.meta.url));
execFileSync(process.execPath, ['shared/dust-wave-platform/scripts/check-desktop-consumer.mjs'], { cwd: root, stdio: 'inherit' });
assert.equal(readFileSync(resolve(root, 'shared/dust-wave-platform/tools/macos-display/VERSION'), 'utf8').trim(), '0.1.0');
for (const entry of JSON.parse(readFileSync(resolve(root, 'docs/vendor-sources.json')))) {
  assert.equal(sha256File(resolve(root, entry.path)), entry.sha256, `Vendored source changed: ${entry.path}`);
}
const files = ['README.md', 'CONTRIBUTING.md', 'SECURITY.md', 'THIRD_PARTY_NOTICES.md', 'docs/upstream-review.md', 'docs/testing.md', 'docs/privacy.md', 'docs/support.md', 'docs/releasing.md', 'docs/roadmap.md', 'docs/paperman-review.md'];
const result = checkDocumentation({ root, files: files.map(file => resolve(root, file)),
  requiredFiles: files, restrictToRoot: true });
assert.deepEqual(result.errors, []);
console.log(`Platform pin, vendored sources and ${result.markdownFileCount} documents verified.`);
