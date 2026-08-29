/**
 * Default Aap-SC app icon: three swim-coach mascots in a pool scene.
 * Brand gradient: #0066CC → #38BDF8 (matches trophy-splash / BrandBlue).
 *
 * Run: node scripts/generate-default-app-icon.mjs
 */
import { promises as fs } from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';

const ROOT = path.resolve(import.meta.dirname, '..');
const PUBLIC = path.join(ROOT, 'public');
const IOS_APP_ICON = path.join(
  ROOT,
  'ios/AapSC/Resources/Assets.xcassets/AppIcon.appiconset'
);

const POOL_BG_SVG = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="poolSky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#7DD3FC"/>
      <stop offset="38%" stop-color="#38BDF8"/>
      <stop offset="100%" stop-color="#0066CC"/>
    </linearGradient>
    <linearGradient id="water" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#0EA5E9" stop-opacity="0.55"/>
      <stop offset="100%" stop-color="#0369A1" stop-opacity="0.92"/>
    </linearGradient>
    <linearGradient id="deck" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#BAE6FD"/>
      <stop offset="100%" stop-color="#7DD3FC"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" rx="224" fill="url(#poolSky)"/>
  <rect x="0" y="700" width="1024" height="80" fill="url(#deck)"/>
  <path d="M0 780 Q170 748 342 768 T684 756 T1024 780 L1024 1024 L0 1024 Z" fill="url(#water)"/>
  <path d="M0 748 Q256 718 512 738 T1024 748" stroke="#FFFFFF" stroke-width="10" fill="none" opacity="0.45"/>
  <line x1="256" y1="790" x2="256" y2="990" stroke="#FFFFFF" stroke-width="7" opacity="0.22"/>
  <line x1="512" y1="790" x2="512" y2="990" stroke="#FFFFFF" stroke-width="7" opacity="0.22"/>
  <line x1="768" y1="790" x2="768" y2="990" stroke="#FFFFFF" stroke-width="7" opacity="0.22"/>
  <ellipse cx="512" cy="860" rx="420" ry="48" fill="#FFFFFF" opacity="0.08"/>
  <circle cx="512" cy="118" r="104" fill="#FFFFFF" opacity="0.96"/>
  <g transform="translate(512 118) scale(3.15)" fill="#57C4B7">
    <g transform="translate(-32 -34)">
      <circle cx="22" cy="17" r="9"/>
      <path d="M29 21C36 14 44 16 48 26" stroke="#57C4B7" stroke-width="7" stroke-linecap="round" fill="none"/>
      <path d="M10 46C16 42 22 42 28 46C34 50 40 50 46 46C52 42 58 42 64 46" stroke="#57C4B7" stroke-width="5" stroke-linecap="round" fill="none"/>
      <path d="M6 54C14 50 22 50 30 54C38 58 46 58 54 54" stroke="#57C4B7" stroke-width="5" stroke-linecap="round" fill="none" opacity="0.85"/>
      <path d="M10 62C18 58 26 58 34 62C42 66 50 66 58 62" stroke="#57C4B7" stroke-width="5" stroke-linecap="round" fill="none" opacity="0.7"/>
    </g>
  </g>
</svg>`;

const MASCOTS = [
  { file: 'flip-open.png', left: 36, top: 250, height: 750 },
  { file: 'flo-open.png', left: 318, top: 220, height: 780 },
  { file: 'fins-open.png', left: 598, top: 250, height: 750 },
];

async function loadMascot(name, height) {
  const filePath = path.join(PUBLIC, 'mascot', name);
  const meta = await sharp(filePath).metadata();
  const width = Math.round((meta.width / meta.height) * height);
  return sharp(filePath).resize(width, height, { fit: 'contain' }).png().toBuffer();
}

async function buildIcon(size) {
  const scale = size / 1024;
  const background = await sharp(Buffer.from(POOL_BG_SVG))
    .resize(size, size)
    .png()
    .toBuffer();

  const layers = await Promise.all(
    MASCOTS.map(async (mascot) => {
      const height = Math.round(mascot.height * scale);
      const input = await loadMascot(mascot.file, height);
      const meta = await sharp(input).metadata();
      return {
        input,
        left: Math.round(mascot.left * scale),
        top: Math.round(mascot.top * scale),
        width: meta.width,
        height: meta.height,
      };
    })
  );

  return sharp(await sharp(background).composite(layers).png().toBuffer())
    .flatten({ background: '#38BDF8' })
    .png()
    .toBuffer();
}

async function writeIcon(size, relativePath) {
  const png = await buildIcon(size);
  const outPath = path.join(PUBLIC, relativePath);
  await fs.writeFile(outPath, png);
  console.log(`Wrote ${relativePath} (${size}×${size})`);
  return png;
}

async function main() {
  await writeIcon(192, 'icon-sc-192.png');
  await writeIcon(512, 'icon-sc-512.png');
  const icon1024 = await buildIcon(1024);
  await fs.writeFile(path.join(PUBLIC, 'icon-sc-1024.png'), icon1024);
  console.log('Wrote icon-sc-1024.png (1024×1024)');

  await fs.mkdir(IOS_APP_ICON, { recursive: true });
  await fs.writeFile(path.join(IOS_APP_ICON, 'AppIcon-1024.png'), icon1024);
  const contents = {
    images: [
      {
        filename: 'AppIcon-1024.png',
        idiom: 'universal',
        platform: 'ios',
        size: '1024x1024',
      },
    ],
    info: { author: 'xcode', version: 1 },
  };
  await fs.writeFile(
    path.join(IOS_APP_ICON, 'Contents.json'),
    `${JSON.stringify(contents, null, 2)}\n`
  );
  console.log('Updated ios AppIcon.appiconset');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
