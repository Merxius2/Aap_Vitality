/**
 * Generate page-header icon SVGs styled to match each store app icon set.
 * Run: node scripts/generate-page-icons.mjs
 */
import { promises as fs } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(import.meta.dirname, '..');
const OUT = path.join(ROOT, 'public/icons/store/page-icons');

const PAGES = ['progress', 'upload', 'history', 'benchmark', 'medals', 'coins', 'settings'];

const GLYPHS = {
  progress: '<rect x="9" y="20" width="4" height="7" rx="1" fill="FG"/><rect x="16" y="14" width="4" height="13" rx="1" fill="FG"/><rect x="23" y="17" width="4" height="10" rx="1" fill="FG"/>',
  upload: '<path d="M18 8v14M13 13l5-5 5 5" stroke="FG" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M11 25h14" stroke="FG" stroke-width="2.2" stroke-linecap="round"/>',
  history: '<circle cx="18" cy="18" r="8" stroke="FG" stroke-width="2.2" fill="none"/><path d="M18 18V13.5" stroke="FG" stroke-width="2.2" stroke-linecap="round"/><path d="M18 18h4.2" stroke="FG" stroke-width="2.2" stroke-linecap="round"/>',
  benchmark: '<path d="M9 24l5-6 5 3 8-10" stroke="FG" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
  medals: '<circle cx="18" cy="13.5" r="5" stroke="FG" stroke-width="2" fill="none"/><path d="M12.5 19.5c2 4.5 4.5 6.5 5.5 6.5s3.5-2 5.5-6.5" stroke="FG" stroke-width="2" stroke-linecap="round" fill="none"/>',
  coins: '<circle cx="14" cy="20" r="5.5" stroke="FG" stroke-width="2" fill="none"/><circle cx="22" cy="17" r="5.5" stroke="FG" stroke-width="2" fill="none"/>',
  settings: '<circle cx="18" cy="18" r="3.2" fill="FG"/><path d="M18 10.5v2.2M18 23.3v2.2M10.5 18h2.2M23.3 18h2.2M12.8 12.8l1.6 1.6M21.6 21.6l1.6 1.6M12.8 23.2l1.6-1.6M21.6 14.4l1.6-1.6" stroke="FG" stroke-width="2" stroke-linecap="round"/>',
};

const SETS = {
  'gold-medal': {
    bg: `<defs><linearGradient id="bg" x1="4" y1="3" x2="32" y2="33" gradientUnits="userSpaceOnUse"><stop stop-color="#FDE68A"/><stop offset="0.5" stop-color="#F59E0B"/><stop offset="1" stop-color="#B45309"/></linearGradient></defs><circle cx="18" cy="18" r="16" fill="url(#bg)"/><circle cx="18" cy="18" r="12.5" fill="#78350F" fill-opacity="0.15"/>`,
    fg: '#FFFBEB',
  },
  'neon-lane': {
    bg: `<rect width="36" height="36" rx="18" fill="#020617"/><path d="M8 12h20M8 18h20M8 24h20" stroke="#22D3EE" stroke-width="1.5" stroke-linecap="round" opacity="0.55"/><path d="M12 12v12M18 12v12M24 12v12" stroke="#FF00AA" stroke-width="1" stroke-linecap="round" opacity="0.35"/>`,
    fg: '#5CE1E6',
  },
  'trophy-splash': {
    bg: `<defs><linearGradient id="bg" x1="6" y1="4" x2="30" y2="32" gradientUnits="userSpaceOnUse"><stop stop-color="#0066CC"/><stop offset="1" stop-color="#38BDF8"/></linearGradient></defs><circle cx="18" cy="18" r="16" fill="url(#bg)"/>`,
    fg: '#FFFBEB',
    accent: '<path d="M13 11h10l-1.5 4.5H14.5L13 11z" fill="#F5C518"/>',
  },
  'platinum-star': {
    bg: `<defs><linearGradient id="bg" x1="4" y1="4" x2="32" y2="32" gradientUnits="userSpaceOnUse"><stop stop-color="#F8FAFC"/><stop offset="0.45" stop-color="#CBD5E1"/><stop offset="1" stop-color="#64748B"/></linearGradient></defs><circle cx="18" cy="18" r="16" fill="url(#bg)"/><circle cx="18" cy="18" r="12.5" fill="#475569" fill-opacity="0.1"/>`,
    fg: '#F8FAFC',
    accent: '<path d="M18 9l2.2 5.2H26l-4.3 3.2 1.6 5.6L18 20.8l-5.3 3.2 1.6-5.6L10 14.2h5.8L18 9z" fill="#F8FAFC" fill-opacity="0.22" stroke="#94A3B8" stroke-width="0.8"/>',
  },
};

function renderSvg(setKey, page) {
  const set = SETS[setKey];
  const glyph = GLYPHS[page].replaceAll('FG', set.fg);
  const accent = set.accent || '';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 36 36" fill="none">${set.bg}${accent}${glyph}</svg>\n`;
}

async function main() {
  for (const setKey of Object.keys(SETS)) {
    const dir = path.join(OUT, setKey);
    await fs.mkdir(dir, { recursive: true });
    for (const page of PAGES) {
      const file = path.join(dir, `${page}.svg`);
      await fs.writeFile(file, renderSvg(setKey, page));
    }
    console.log(`Generated ${PAGES.length} page icons for ${setKey}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
