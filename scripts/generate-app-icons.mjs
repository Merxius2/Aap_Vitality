/**
 * Generate PNG app icon sizes from SVG sources.
 * Run: node scripts/generate-app-icons.mjs
 */
import { promises as fs } from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';

const ROOT = path.resolve(import.meta.dirname, '..');
const PUBLIC = path.join(ROOT, 'public');
const IOS_ASSETS = path.join(ROOT, 'ios/AapSC/Resources/Assets.xcassets');

const ICON_SETS = [
  { svg: 'icons/store/gold-medal.svg', outputs: ['icons/store/gold-medal-192.png', 'icons/store/gold-medal-512.png'], iosAppIcon: 'GoldMedal' },
  { svg: 'icons/store/neon-lane.svg', outputs: ['icons/store/neon-lane-192.png', 'icons/store/neon-lane-512.png'], iosAppIcon: 'NeonLane' },
  { svg: 'icons/store/trophy-splash.svg', outputs: ['icons/store/trophy-splash-192.png', 'icons/store/trophy-splash-512.png'], iosAppIcon: 'TrophySplash' },
  { svg: 'icons/store/platinum-star.svg', outputs: ['icons/store/platinum-star-192.png', 'icons/store/platinum-star-512.png'], iosAppIcon: 'PlatinumStar' },
];

async function renderPng(svgPath, size, outputPath) {
  await sharp(svgPath)
    .resize(size, size)
    .flatten({ background: '#38BDF8' })
    .png()
    .toFile(outputPath);
}

async function main() {
  for (const set of ICON_SETS) {
    const svgPath = path.join(PUBLIC, set.svg);
    const [out192, out512] = set.outputs;
    await renderPng(svgPath, 192, path.join(PUBLIC, out192));
    await renderPng(svgPath, 512, path.join(PUBLIC, out512));
    console.log(`Generated ${out192}, ${out512}`);

    const iosName = set.iosAppIcon;
    if (iosName) {
      const iosDir = path.join(IOS_ASSETS, `${iosName}.appiconset`);
      await fs.mkdir(iosDir, { recursive: true });
      await renderPng(svgPath, 1024, path.join(iosDir, `${iosName}-1024.png`));
      await fs.writeFile(
        path.join(iosDir, 'Contents.json'),
        `${JSON.stringify({
          images: [{
            filename: `${iosName}-1024.png`,
            idiom: 'universal',
            platform: 'ios',
            size: '1024x1024',
          }],
          info: { author: 'xcode', version: 1 },
        }, null, 2)}\n`
      );
      console.log(`Updated ios ${iosName}.appiconset`);
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
