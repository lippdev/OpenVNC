import { build } from 'esbuild';
import { cp, mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const output = `${root}target/viewer`;
await mkdir(output, { recursive: true });
await build({
  absWorkingDir: root,
  entryPoints: ['apps/macos/Viewer/client.js'],
  bundle: true,
  // noVNC 1.7 performs an asynchronous codec capability probe. Bundle as ESM
  // (entry has no exports), then wrap in an async function for a local classic
  // script. This avoids file:// module CORS and preserves upstream source.
  format: 'esm',
  banner: { js: 'window.webkit.messageHandlers.session.postMessage({event: "rendererLoading"});\n(async () => {' },
  footer: { js: '})().catch(() => window.webkit.messageHandlers.session.postMessage({event: "rendererFailed"}));' },
  target: 'safari16',
  outfile: `${output}/client.js`,
  legalComments: 'linked',
});
for (const file of ['index.html', 'viewer.css']) {
  await cp(`${root}apps/macos/Viewer/${file}`, `${output}/${file}`);
}
// Ship exact unmodified upstream source and license notices with the bundle.
await cp(`${root}node_modules/@novnc/novnc`, `${output}/ThirdParty/noVNC`, { recursive: true });
await writeFile(`${output}/ThirdParty/NOTICE.txt`,
  'noVNC 1.7.0 — https://github.com/novnc/noVNC/tree/v1.7.0\n' +
  'Unmodified source, AUTHORS, MPL-2.0 and bundled dependency licenses are in noVNC/.\n' +
  'esbuild is a build tool only and is not part of the runtime.\n');
