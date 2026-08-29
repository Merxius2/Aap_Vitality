/**
 * Default Aap Vitality app icon: heart + activity pulse on brand gradient.
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
  'ios/AapVitality/Resources/Assets.xcassets/AppIcon.appiconset'
);

const VITALITY_ICON_SVG = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#34D399"/>
      <stop offset="45%" stop-color="#0066CC"/>
      <stop offset="100%" stop-color="#38BDF8"/>
    </linearGradient>
    <linearGradient id="ring" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.95"/>
      <stop offset="100%" stop-color="#E0F2FE" stop-opacity="0.85"/>
    </linearGradient>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="10" stdDeviation="18" flood-color="#003366" flood-opacity="0.28"/>
    </filter>
  </defs>
  <rect width="1024" height="1024" rx="224" fill="url(#bg)"/>
  <circle cx="512" cy="512" r="360" fill="#FFFFFF" opacity="0.08"/>
  <circle cx="512" cy="512" r="290" fill="none" stroke="#FFFFFF" stroke-width="16" opacity="0.18"/>
  <g filter="url(#shadow)">
    <circle cx="512" cy="512" r="250" fill="url(#ring)"/>
  </g>
  <path d="M512 690 C360 560 300 500 300 430 C300 360 352 310 420 310 C468 310 500 338 512 368 C524 338 556 310 604 310 C672 310 724 360 724 430 C724 500 664 560 512 690 Z"
        fill="#EF4444"/>
  <path d="M180 620 C260 560 340 540 420 560 C500 580 560 630 620 690"
        stroke="#FFFFFF" stroke-width="22" stroke-linecap="round" fill="none" opacity="0.55"/>
  <path d="M220 700 C320 640 410 630 512 660 C614 690 700 720 804 680"
        stroke="#FFFFFF" stroke-width="18" stroke-linecap="round" fill="none" opacity="0.4"/>
  <circle cx="760" cy="300" r="56" fill="#FFFFFF" opacity="0.92"/>
  <path d="M736 300 H784 M760 276 V324" stroke="#0066CC" stroke-width="14" stroke-linecap="round"/>
  <text x="512" y="860" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-size="92" font-weight="700" fill="#FFFFFF" opacity="0.92">VITALITY</text>
</svg>`;

async function buildIcon(size) {
  return sharp(Buffer.from(VITALITY_ICON_SVG))
    .resize(size, size)
    .png()
    .toBuffer();
}

async function writeIcon(size, relativePath) {
  const png = await buildIcon(size);
  const outPath = path.join(PUBLIC, relativePath);
  await fs.mkdir(path.dirname(outPath), { recursive: true });
  await fs.writeFile(outPath, png);
  console.log(`Wrote ${relativePath} (${size}×${size})`);
  return png;
}

async function main() {
  await writeIcon(192, 'icon-vitality-192.png');
  await writeIcon(512, 'icon-vitality-512.png');
  const icon1024 = await buildIcon(1024);
  await fs.writeFile(path.join(PUBLIC, 'icon-vitality-1024.png'), icon1024);
  console.log('Wrote icon-vitality-1024.png (1024×1024)');

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
