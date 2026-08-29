/**
 * Generate iOS page-icon imagesets and store icon PNGs from web SVG sources.
 * Run: node scripts/sync-ios-store-assets.mjs
 */
import { promises as fs } from 'node:fs';
import path from 'node:path';
import sharp from 'sharp';

const ROOT = path.resolve(import.meta.dirname, '..');
const PUBLIC = path.join(ROOT, 'public');
const ASSETS = path.join(ROOT, 'ios/AapSC/Resources/Assets.xcassets');

const ICON_SETS = ['gold-medal', 'neon-lane', 'trophy-splash', 'platinum-star'];
const PAGES = ['progress', 'upload', 'history', 'benchmark', 'medals', 'coins', 'settings'];

async function ensureDir(dir) {
  await fs.mkdir(dir, { recursive: true });
}

async function writeImageset(imagesetDir, filename, pngBuffer) {
  await ensureDir(imagesetDir);
  await fs.writeFile(path.join(imagesetDir, filename), pngBuffer);
  await fs.writeFile(
    path.join(imagesetDir, 'Contents.json'),
    JSON.stringify({
      images: [{ filename, idiom: 'universal', scale: '2x' }],
      info: { author: 'xcode', version: 1 },
    }, null, 2)
  );
}

async function renderSvgToPng(svgPath, size) {
  return sharp(svgPath).resize(size, size).png().toBuffer();
}

async function syncStoreIcons() {
  for (const slug of ICON_SETS) {
    const svgPath = path.join(PUBLIC, 'icons/store', `${slug}.svg`);
    const png = await renderSvgToPng(svgPath, 72);
    const imagesetDir = path.join(ASSETS, `StoreIcon-${slug}.imageset`);
    await writeImageset(imagesetDir, `${slug}.png`, png);
    console.log(`StoreIcon-${slug}`);
  }
}

async function syncPageIcons() {
  for (const slug of ICON_SETS) {
    for (const page of PAGES) {
      const svgPath = path.join(PUBLIC, 'icons/store/page-icons', slug, `${page}.svg`);
      const png = await renderSvgToPng(svgPath, 72);
      const imagesetDir = path.join(ASSETS, `PageIcon-${slug}-${page}.imageset`);
      await writeImageset(imagesetDir, `${page}.png`, png);
      console.log(`PageIcon-${slug}-${page}`);
    }
  }
}

async function main() {
  await syncStoreIcons();
  await syncPageIcons();
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
