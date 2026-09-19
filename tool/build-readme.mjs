#!/usr/bin/env node
// Builds the retro README (black, paper and orange only) for NO SUS Canary: README.md + animated SVGs.
//
//   node tool/build-readme.mjs [config=readme.config.json] [outDir=.]
//
// Edit readme.config.json (live URL, repo URL, contract address, links) and re-run.
// Everything is drawn with shapes (a built-in 5x7 pixel font), because GitHub
// shows SVGs as images: no JavaScript and no external fonts, but CSS animation
// works. Every animation stops under prefers-reduced-motion, and the static
// frame always shows the finished state, so no text is ever hidden.

import fs from 'node:fs';
import path from 'node:path';

const cfgPath = process.argv[2] ?? 'readme.config.json';
const outDir = process.argv[3] ?? '.';
const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
const assetDir = path.join(outDir, 'assets', 'readme');
fs.mkdirSync(assetDir, { recursive: true });

// ---------------------------------------------------------------- palette
// Three colours, nothing else: black ink, paper and NO SUS orange.
const INK = '#141414';
const PAPER = '#FAF6EC';
const ORANGE = '#F28C28';

// ---------------------------------------------------------------- pixel font (5x7, uppercase)
const FONT = {
  'A': ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
  'B': ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'],
  'C': ['.###.', '#...#', '#....', '#....', '#....', '#...#', '.###.'],
  'D': ['####.', '#...#', '#...#', '#...#', '#...#', '#...#', '####.'],
  'E': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
  'F': ['#####', '#....', '#....', '####.', '#....', '#....', '#....'],
  'G': ['.###.', '#...#', '#....', '#.###', '#...#', '#...#', '.####'],
  'H': ['#...#', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
  'I': ['.###.', '..#..', '..#..', '..#..', '..#..', '..#..', '.###.'],
  'J': ['..###', '...#.', '...#.', '...#.', '...#.', '#..#.', '.##..'],
  'K': ['#...#', '#..#.', '#.#..', '##...', '#.#..', '#..#.', '#...#'],
  'L': ['#....', '#....', '#....', '#....', '#....', '#....', '#####'],
  'M': ['#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'],
  'N': ['#...#', '#...#', '##..#', '#.#.#', '#..##', '#...#', '#...#'],
  'O': ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
  'P': ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....'],
  'Q': ['.###.', '#...#', '#...#', '#...#', '#.#.#', '#..#.', '.##.#'],
  'R': ['####.', '#...#', '#...#', '####.', '#.#..', '#..#.', '#...#'],
  'S': ['.####', '#....', '#....', '.###.', '....#', '....#', '####.'],
  'T': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
  'U': ['#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
  'V': ['#...#', '#...#', '#...#', '#...#', '#...#', '.#.#.', '..#..'],
  'W': ['#...#', '#...#', '#...#', '#.#.#', '#.#.#', '#.#.#', '.#.#.'],
  'X': ['#...#', '#...#', '.#.#.', '..#..', '.#.#.', '#...#', '#...#'],
  'Y': ['#...#', '#...#', '.#.#.', '..#..', '..#..', '..#..', '..#..'],
  'Z': ['#####', '....#', '...#.', '..#..', '.#...', '#....', '#####'],
  '0': ['.###.', '#...#', '#..##', '#.#.#', '##..#', '#...#', '.###.'],
  '1': ['..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.'],
  '2': ['.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'],
  '3': ['####.', '....#', '....#', '.###.', '....#', '....#', '####.'],
  '4': ['...#.', '..##.', '.#.#.', '#..#.', '#####', '...#.', '...#.'],
  '5': ['#####', '#....', '####.', '....#', '....#', '#...#', '.###.'],
  '6': ['.###.', '#....', '#....', '####.', '#...#', '#...#', '.###.'],
  '7': ['#####', '....#', '...#.', '..#..', '.#...', '.#...', '.#...'],
  '8': ['.###.', '#...#', '#...#', '.###.', '#...#', '#...#', '.###.'],
  '9': ['.###.', '#...#', '#...#', '.####', '....#', '....#', '.###.'],
  ' ': ['.....', '.....', '.....', '.....', '.....', '.....', '.....'],
  '.': ['.....', '.....', '.....', '.....', '.....', '.##..', '.##..'],
  ',': ['.....', '.....', '.....', '.....', '.##..', '..#..', '.#...'],
  ':': ['.....', '.##..', '.##..', '.....', '.##..', '.##..', '.....'],
  '-': ['.....', '.....', '.....', '.###.', '.....', '.....', '.....'],
  '!': ['..#..', '..#..', '..#..', '..#..', '..#..', '.....', '..#..'],
  '?': ['.###.', '#...#', '....#', '...#.', '..#..', '.....', '..#..'],
  '/': ['....#', '....#', '...#.', '..#..', '.#...', '#....', '#....'],
  '#': ['.#.#.', '.#.#.', '#####', '.#.#.', '#####', '.#.#.', '.#.#.'],
  '>': ['.#...', '..#..', '...#.', '....#', '...#.', '..#..', '.#...'],
  '<': ['...#.', '..#..', '.#...', '#....', '.#...', '..#..', '...#.'],
  '(': ['...#.', '..#..', '.#...', '.#...', '.#...', '..#..', '...#.'],
  ')': ['.#...', '..#..', '...#.', '...#.', '...#.', '..#..', '.#...'],
  '+': ['.....', '..#..', '..#..', '#####', '..#..', '..#..', '.....'],
  '=': ['.....', '.....', '#####', '.....', '#####', '.....', '.....'],
  '~': ['.....', '.....', '.#...', '#.#.#', '...#.', '.....', '.....'],
  '*': ['.....', '#.#.#', '.###.', '#####', '.###.', '#.#.#', '.....'],
  "'": ['..#..', '..#..', '.#...', '.....', '.....', '.....', '.....'],
  '|': ['..#..', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
  '^': ['#....', '##...', '###..', '####.', '###..', '##...', '#....'], // play triangle
  '`': ['.....', '#####', '#####', '.###.', '.###.', '..#..', '.....'], // "next" triangle
};

const textW = (s, px) => s.length * 6 * px - px;

function pixelText(str, x, y, px, fill, attrs = '') {
  let rects = '';
  [...String(str).toUpperCase()].forEach((ch, i) => {
    const glyph = FONT[ch] ?? FONT['?'];
    const ox = x + i * 6 * px;
    glyph.forEach((row, ry) => {
      let start = -1;
      for (let cx = 0; cx <= 5; cx++) {
        const on = cx < 5 && row[cx] === '#';
        if (on && start < 0) start = cx;
        if (!on && start >= 0) {
          rects += `<rect x="${ox + start * px}" y="${y + ry * px}" width="${(cx - start) * px}" height="${px}"/>`;
          start = -1;
        }
      }
    });
  });
  return `<g fill="${fill}" ${attrs}>${rects}</g>`;
}

function sprite(rows, pal, x, y, px, attrs = '') {
  let out = '';
  rows.forEach((row, ry) => {
    let cx = 0;
    while (cx < row.length) {
      const c = row[cx];
      if (c === '.') { cx++; continue; }
      let end = cx;
      while (end < row.length && row[end] === c) end++;
      out += `<rect x="${x + cx * px}" y="${y + ry * px}" width="${(end - cx) * px}" height="${px}" fill="${pal[c]}"/>`;
      cx = end;
    }
  });
  return `<g ${attrs}>${out}</g>`;
}

function wrap(text, max) {
  const lines = [];
  let cur = '';
  for (const word of text.split(' ')) {
    const next = cur ? `${cur} ${word}` : word;
    if (next.length > max && cur) {
      lines.push(cur);
      cur = word;
    } else {
      cur = next;
    }
  }
  if (cur) lines.push(cur);
  return lines;
}

// ---------------------------------------------------------------- sprites
// Three colours only: INK, PAPER and ORANGE.
const CANARY_PAL = { K: INK, Y: ORANGE, y: PAPER, W: PAPER, O: INK };
const CANARY_A = [
  '.....KKKKK......',
  '...KKYYYYYKK....',
  '..KYYYYYYYWWK...',
  '..KYYYYYYYWKK...',
  '.KYYYYYYYYYYKOO.',
  '.KYYYYYYYYYYKOOO',
  '.KYyyyyYYYYYK...',
  'KYYyyyyyYYYYK...',
  'KYYYyyyyYYYK....',
  '.KYYYyyYYYYK....',
  '..KYYYYYYYK.....',
  '...KKKKKKK......',
  '....K...K.......',
  '...KK..KK.......',
];
const CANARY_B = [
  '.....KKKKK......',
  '...KKYYYYYKK....',
  '..KYYYYYYYWWK...',
  '..KYYYYYYYWKK...',
  '.KYYyyYYYYYYKOO.',
  '.KYyyyyYYYYYKOOO',
  '.KYYyyyYYYYYK...',
  'KYYYYYYYYYYYK...',
  'KYYYYYYYYYYK....',
  '.KYYYYYYYYYK....',
  '..KYYYYYYYK.....',
  '...KKKKKKK......',
  '....K...K.......',
  '...KK..KK.......',
];
const PHONE_PAL = { K: INK, P: INK, W: PAPER, Y: ORANGE };
const PHONE = [
  '.KKKKKKKK.',
  'KPPPPPPPPK',
  'KPWWWWWWPK',
  'KPWYYYYWPK',
  'KPWWWWWWPK',
  'KPWYYYWWPK',
  'KPWWWWWWPK',
  'KPWYYYYWPK',
  'KPWWWWWWPK',
  'KPWWWWWWPK',
  'KPPPPPPPPK',
  'KPPPWWPPPK',
  '.KKKKKKKK.',
];
const ENV_PAL = { K: INK, W: PAPER, Y: ORANGE };
const ENVELOPE = [
  'KKKKKKKKKKKKKK',
  'KYYWWWWWWWWYYK',
  'KWYYWWWWWWYYWK',
  'KWWYYWWWWYYWWK',
  'KWWWYYWWYYWWWK',
  'KWWWWYYYYWWWWK',
  'KWWWWWYYWWWWWK',
  'KWWWWWWWWWWWWK',
  'KWWWWWWWWWWWWK',
  'KKKKKKKKKKKKKK',
];
const LENS_PAL = { K: INK, L: PAPER, H: ORANGE };
const MAGNIFIER = [
  '..KKKK......',
  '.KLLLLK.....',
  'KLLKLLLK....',
  'KLKLLLLK....',
  'KLLLLLLK....',
  'KLLLLLLK....',
  '.KLLLLK.....',
  '..KKKKHH....',
  '......HHH...',
  '.......HHH..',
  '........HHH.',
  '.........HH.',
];
// A sneaky leaked page with eyes: the "wild LEAK".
const LEAK_PAL = { K: INK, W: PAPER, R: ORANGE, L: INK };
const LEAK = [
  '..KKKKKKKKKK....',
  '..KWWWWWWWWKK...',
  '..KWWWWWWWWWKK..',
  '..KWRRWWWRRWWK..',
  '..KWRKWWWRKWWK..',
  '..KWWWWWWWWWWK..',
  '..KWLLLLLLLWWK..',
  '..KWWWWWWWWWWK..',
  '..KWLLLLLLWWWK..',
  '..KWWWWKKWWWWK..',
  '..KWWWKRRKWWWK..',
  '..KWWWWWWWWWWK..',
  '..KWLLLLLWWWWK..',
  '..KWWWWWWWWWWK..',
  '..KKWKKWKKWKKK..',
  '...K..K..K..K...',
];

// ---------------------------------------------------------------- svg helpers
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');

function svgDoc(w, h, title, css, body, defs = '') {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" role="img" aria-label="${esc(title)}" shape-rendering="crispEdges">
<title>${esc(title)}</title>
<style>
${css}
@media (prefers-reduced-motion: reduce) { * { animation: none !important; } }
</style>
<defs>${defs}</defs>
${body}
</svg>
`;
}

// A paper card with a thick ink border and a hard orange shadow (bottom-right).
const SH = 8;
const card = (w, h, r = 16) =>
  `<rect x="${SH}" y="${SH}" width="${w - SH}" height="${h - SH}" rx="${r}" fill="${ORANGE}"/>
<rect x="3" y="3" width="${w - SH - 6}" height="${h - SH - 6}" rx="${r}" fill="${PAPER}" stroke="${INK}" stroke-width="6"/>`;

const written = new Set();
function write(name, content) {
  fs.writeFileSync(path.join(assetDir, name), content);
  written.add(name);
  console.log(`  wrote assets/readme/${name} (${(content.length / 1024).toFixed(1)} KB)`);
}

const blinkCss = `.blink { animation: blink 1.1s linear infinite; }
@keyframes blink { 0%,55% { opacity: 1; } 56%,100% { opacity: 0; } }`;
const flapCss = (s) => `.fa { animation: flapA ${s}s linear infinite; }
.fb { opacity: 0; animation: flapB ${s}s linear infinite; }
@keyframes flapA { 0%,49.9% { opacity: 1; } 50%,100% { opacity: 0; } }
@keyframes flapB { 0%,49.9% { opacity: 0; } 50%,100% { opacity: 1; } }`;
const bird = (x, y, px) =>
  sprite(CANARY_A, CANARY_PAL, x, y, px, 'class="fa"') + sprite(CANARY_B, CANARY_PAL, x, y, px, 'class="fb"');

// One-shot typewriter: each line is revealed by a paper-coloured cover that
// steps to the right, one character per step. Static frame = fully revealed.
function typewriter(lines, x, y0, px, lineGap, colors, cover, clipId, startDelay, cps) {
  let body = '';
  let css = '';
  let t = startDelay;
  lines.forEach((line, i) => {
    const y = y0 + i * lineGap;
    const w = textW(line, px) + px * 2;
    const n = Math.max(1, line.length);
    const dur = n / cps;
    body += pixelText(line, x, y, px, colors[Math.min(i, colors.length - 1)]);
    body += `<g clip-path="url(#${clipId})"><rect class="cv${i}" x="${x - px}" y="${y - px}" width="${w}" height="${px * 9}" fill="${cover}"/></g>`;
    css += `
.cv${i} { transform: translateX(${w}px); animation: cv${i} ${dur.toFixed(2)}s steps(${n}, end) ${t.toFixed(2)}s backwards; }
@keyframes cv${i} { from { transform: translateX(0px); } to { transform: translateX(${w}px); } }`;
    t += dur + 0.15;
  });
  return { body, css, end: t };
}

// ---------------------------------------------------------------- banner
function banner() {
  const W = 840, H = 250;
  const sparks = [[574, 50, 0], [792, 70, 0.6], [586, 176, 1.2], [800, 168, 1.8]];
  let body = card(W, H);
  body += `<rect x="610" y="206" width="150" height="6" fill="${INK}"/>`;
  sparks.forEach(([x, y, d]) => {
    body += `<g class="spark" style="animation-delay:${d}s" fill="${ORANGE}"><rect x="${x + 4}" y="${y}" width="4" height="12"/><rect x="${x}" y="${y + 4}" width="12" height="4"/></g>`;
  });
  body += pixelText('NO SUS', 52, 44, 9, ORANGE);
  body += pixelText('NO SUS', 46, 38, 9, INK);
  body += pixelText('CANARY', 50, 116, 5, ORANGE);
  body += pixelText('EVERY READER GETS THEIR OWN COPY.', 50, 164, 2, INK);
  body += `<g class="blink">${pixelText('^ PRESS START', 50, 196, 2, ORANGE)}</g>`;
  body += pixelText(cfg.event, W - SH - 30 - textW(cfg.event, 2), 196, 2, INK);
  body += `<g class="bob">${bird(612, 40, 10)}</g>`;
  const css = `${blinkCss}
${flapCss(0.5)}
.bob { animation: bob 1.2s ease-in-out infinite alternate; }
@keyframes bob { from { transform: translateY(0); } to { transform: translateY(-8px); } }
.spark { animation: spark 2.4s steps(2, end) infinite; }
@keyframes spark { 0%,100% { opacity: 1; } 50% { opacity: 0; } }`;
  write('banner.svg', svgDoc(W, H, 'NO SUS Canary: every reader gets their own copy.', css, body));
}

// ---------------------------------------------------------------- buttons
function button(file, label, alt, primary) {
  const W = 260, H = 64;
  const tw = textW(label, 2);
  const body = [
    `<rect x="6" y="6" width="${W - 6}" height="${H - 6}" rx="12" fill="${INK}"/>`,
    `<rect x="2" y="2" width="${W - 10}" height="${H - 10}" rx="12" fill="${primary ? ORANGE : PAPER}" stroke="${INK}" stroke-width="4"/>`,
    pixelText(label, Math.round((W - 6 - tw) / 2), Math.round((H - 6 - 14) / 2), 2, INK, primary ? 'class="nudge"' : ''),
  ].join('\n');
  const css = primary
    ? `.nudge { animation: nudge 1.4s ease-in-out infinite; }
@keyframes nudge { 0%,100% { transform: translateX(0); } 50% { transform: translateX(4px); } }`
    : '';
  write(file, svgDoc(W, H, alt, css, body));
}

// ---------------------------------------------------------------- dialogue box (handheld RPG style)
function dialogue(file, speaker, text, alt) {
  const W = 840, px = 3, gap = 34, x0 = 120;
  const max = Math.floor((W - x0 - 60) / (6 * px));
  const lines = [speaker, ...wrap(text.toUpperCase(), max)];
  const H = 44 + lines.length * gap + 26;
  const inner = { x: 18, y: 18, w: W - SH - 36, h: H - SH - 36 };
  const tw = typewriter(lines, x0, 42, px, gap, [ORANGE, INK], PAPER, 'box', 0.3, 42);
  const body = [
    card(W, H),
    `<rect x="${inner.x}" y="${inner.y}" width="${inner.w}" height="${inner.h}" rx="8" fill="none" stroke="${ORANGE}" stroke-width="2"/>`,
    `<g class="bob">${bird(34, Math.round((H - SH) / 2 - 30), 4)}</g>`,
    tw.body,
    `<g class="next">${pixelText('`', W - SH - 60, H - SH - 46, 3, INK)}</g>`,
  ].join('\n');
  const css = `${flapCss(0.6)}
.bob { animation: bob 1.4s ease-in-out infinite alternate; }
@keyframes bob { from { transform: translateY(0); } to { transform: translateY(-4px); } }
.next { animation: next 0.9s linear ${tw.end.toFixed(2)}s infinite; }
@keyframes next { 0%,55% { opacity: 1; transform: translateY(0); } 56%,100% { opacity: 0.2; transform: translateY(3px); } }
${tw.css}`;
  const defs = `<clipPath id="box"><rect x="${inner.x + 2}" y="${inner.y + 2}" width="${inner.w - 4}" height="${inner.h - 4}"/></clipPath>`;
  write(file, svgDoc(W, H, alt, css, body, defs));
}

// ---------------------------------------------------------------- the story (how it works)
function story() {
  const W = 840, H = 330, T = 10;
  const readers = ['ASHA', 'BEN', 'PRIYA', 'RAJ', 'ZOE'];
  const leaker = 2;
  const rx = [496, 562, 628, 694, 760];
  const phoneY = 196, envStart = { x: 118, y: 166 };
  let css = `
.bob { animation: bob 1s ease-in-out infinite alternate; }
@keyframes bob { from { transform: translateY(0); } to { transform: translateY(-5px); } }
${flapCss(0.5)}
.seal { animation: seal ${T}s linear infinite; }
@keyframes seal { 0% { opacity: 0; } 4%,92% { opacity: 1; } 96%,100% { opacity: 0; } }
.pulse { animation: pulse 1s steps(2, end) infinite; }
@keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: 0; } }
.bubble { animation: bubble ${T}s linear infinite; }
@keyframes bubble { 0%,49% { opacity: 0; } 53%,92% { opacity: 1; } 96%,100% { opacity: 0; } }
.leak { opacity: 0; animation: leak ${T}s linear infinite; }
@keyframes leak { 0%,43% { opacity: 0; transform: translate(${rx[leaker] + 1 - 446}px, ${phoneY + 16 - 118}px); }
  44% { opacity: 1; transform: translate(${rx[leaker] + 1 - 446}px, ${phoneY + 16 - 118}px); }
  52% { opacity: 1; transform: translate(0px, 0px); } 55%,100% { opacity: 0; transform: translate(0px, 0px); } }
.mag { animation: mag ${T}s linear infinite; }
@keyframes mag { 0%,54% { opacity: 0; transform: translate(-150px, 0px); } 56% { opacity: 1; transform: translate(-150px, 0px); }
  68% { opacity: 1; transform: translate(0px, 0px); } 72%,100% { opacity: 0; transform: translate(0px, 0px); } }
.win { animation: win ${T}s linear infinite; }
@keyframes win { 0%,69% { opacity: 0; } 70%,73%,77%,81%,92% { opacity: 1; } 71.5%,75%,79% { opacity: 0.2; } 96%,100% { opacity: 0; } }
.who { animation: who ${T}s linear infinite; }
@keyframes who { 0%,73% { opacity: 0; } 76%,92% { opacity: 1; } 96%,100% { opacity: 0; } }
.hl { animation: hl ${T}s linear infinite; }
@keyframes hl { 0%,69% { opacity: 0; } 70%,74%,78%,82%,86%,92% { opacity: 1; } 72%,76%,80%,84% { opacity: 0; } 96%,100% { opacity: 0; } }`;

  let body = card(W, H);
  body += `<rect x="24" y="272" width="${W - SH - 48}" height="3" fill="${INK}"/>`;
  body += `<g class="seal"><rect x="170" y="40" width="260" height="36" rx="8" fill="${PAPER}" stroke="${INK}" stroke-width="3"/>
<rect class="pulse" x="184" y="51" width="14" height="14" fill="${ORANGE}"/>
${pixelText('SEALED ON MONAD', 208, 51, 2, INK)}</g>`;
  body += `<g class="bob">${bird(40, 188, 5)}</g>`;
  body += pixelText('SENDER', 44, 286, 2, ORANGE);
  readers.forEach((name, j) => {
    body += pixelText(`0${j + 1}`, rx[j] + 4, phoneY - 22, 2, INK);
    body += sprite(PHONE, PHONE_PAL, rx[j], phoneY, 3);
    const nw = textW(name, 2);
    body += pixelText(name, rx[j] + 15 - Math.round(nw / 2), 286, 2, j === leaker ? ORANGE : INK);
  });
  readers.forEach((_, j) => {
    const fx = rx[j] + 1, fy = phoneY + 16;
    const a = 10 + j * 4, b = 22 + j * 4;
    css += `
.env${j} { animation: env${j} ${T}s ease-out infinite; }
@keyframes env${j} { 0%,${a - 0.1}% { opacity: 0; transform: translate(${envStart.x - fx}px, ${envStart.y - fy}px); }
  ${a}% { opacity: 1; transform: translate(${envStart.x - fx}px, ${envStart.y - fy}px); }
  ${b}% { opacity: 1; transform: translate(0px, 0px); } 92% { opacity: 1; transform: translate(0px, 0px); } 96%,100% { opacity: 0; transform: translate(0px, 0px); } }`;
    body += sprite(ENVELOPE, ENV_PAL, fx, fy, 2, `class="env${j}"`);
  });
  body += `<g class="bubble"><rect x="326" y="94" width="210" height="74" rx="10" fill="${PAPER}" stroke="${ORANGE}" stroke-width="3"/>
${pixelText('LEAKED!', 342, 106, 3, ORANGE)}
<rect x="342" y="138" width="150" height="4" fill="${INK}"/>
<rect x="342" y="150" width="110" height="4" fill="${INK}"/></g>`;
  body += sprite(ENVELOPE, ENV_PAL, 446, 118, 2, 'class="leak"');
  body += sprite(MAGNIFIER, LENS_PAL, 470, 110, 3, 'class="mag"');
  body += `<rect class="hl" x="${rx[leaker] - 8}" y="${phoneY - 30}" width="46" height="110" rx="6" fill="none" stroke="${ORANGE}" stroke-width="4"/>`;
  body += `<g class="win">${pixelText('THE CANARY SANG!', 150, 212, 3, ORANGE)}</g>`;
  body += `<g class="who">${pixelText(`COPY 0${leaker + 1} = ${readers[leaker]}`, 150, 242, 2, INK)}</g>`;
  write('story.svg', svgDoc(W, H,
    "Animation: the sender seals a note on Monad, five readers each receive a different copy, Priya's copy leaks, NO SUS scans it and the canary sings: copy 03 is Priya's.",
    css, body));
}

// ---------------------------------------------------------------- the catch (battle text scene)
function battle() {
  const W = 840, H = 390, T = 12, cps = 24, px = 3;
  const lines = ['A WILD LEAK APPEARED!', 'CANARY USED FINGERPRINT!', "IT'S SUPER EFFECTIVE!", "IT WAS PRIYA'S COPY! #03"];
  const windows = [[0, 22], [25, 47], [50, 72], [75, 95]];
  const box = { x: 20, y: 290, w: W - SH - 40, h: 76 };
  let css = `
${flapCss(0.6)}
.foe { animation: foe ${T}s linear infinite; }
@keyframes foe {
  0%,29% { transform: translate(0px, 0px); opacity: 1; }
  30%,32%,34%,36% { opacity: .15; }
  31%,33%,35%,37% { opacity: 1; }
  50% { transform: translate(0px, 0px); }
  51% { transform: translate(-8px, 0px); }
  52% { transform: translate(8px, 0px); }
  53% { transform: translate(-8px, 0px); }
  54%,76% { transform: translate(0px, 0px); opacity: 1; }
  82%,95% { transform: translate(0px, 40px); opacity: 0; }
  96%,100% { transform: translate(0px, 0px); opacity: 1; } }
.hp { transform-box: fill-box; transform-origin: 0% 50%; transform: scaleX(0.06); animation: hp ${T}s linear infinite; }
@keyframes hp { 0%,50% { transform: scaleX(1); } 58%,95% { transform: scaleX(0.06); } 100% { transform: scaleX(1); } }
.xpup { opacity: 0; animation: xpup ${T}s linear infinite; }
@keyframes xpup { 0%,78% { opacity: 0; transform: translate(0px, 0px); } 81% { opacity: 1; } 93% { opacity: 1; transform: translate(0px, -18px); } 96%,100% { opacity: 0; } }
.next { animation: next 0.9s linear infinite; }
@keyframes next { 0%,55% { opacity: 1; } 56%,100% { opacity: 0.2; } }`;

  const infoBox = (x, y, w, name, lv, bar) => `<rect x="${x}" y="${y}" width="${w}" height="76" rx="8" fill="${PAPER}" stroke="${INK}" stroke-width="3"/>
${pixelText(name, x + 18, y + 14, 3, INK)}
${pixelText(lv, x + w - 18 - textW(lv, 2), y + 18, 2, INK)}
${pixelText('HP', x + 18, y + 50, 2, ORANGE)}
<rect x="${x + 50}" y="${y + 48}" width="${w - 70}" height="14" rx="3" fill="${PAPER}" stroke="${INK}" stroke-width="2"/>
<rect ${bar ? `class="${bar}"` : ''} x="${x + 53}" y="${y + 51}" width="${w - 76}" height="8" fill="${ORANGE}"/>`;

  let body = card(W, H, 18);
  body += `<rect x="500" y="186" width="240" height="4" fill="${INK}"/>`;
  body += `<rect x="96" y="268" width="260" height="4" fill="${INK}"/>`;
  body += infoBox(36, 30, 330, 'LEAK', 'LV3', 'hp');
  body += `<g class="foe">${sprite(LEAK, LEAK_PAL, 560, 50, 8)}</g>`;
  body += bird(160, 156, 8);
  body += infoBox(466, 200, 340, 'CANARY', 'LV99', '');
  body += `<g class="xpup">${pixelText('+500 XP', 560, 166, 3, ORANGE)}</g>`;
  body += `<rect x="${box.x}" y="${box.y}" width="${box.w}" height="${box.h}" rx="12" fill="${PAPER}" stroke="${INK}" stroke-width="6"/>`;
  body += `<rect x="${box.x + 10}" y="${box.y + 10}" width="${box.w - 20}" height="${box.h - 20}" rx="6" fill="none" stroke="${ORANGE}" stroke-width="2"/>`;
  lines.forEach((line, i) => {
    const [a, b] = windows[i];
    const n = line.length;
    const w = textW(line, px) + px * 2;
    const d = ((n / cps) / T) * 100;
    const last = i === lines.length - 1;
    css += `
.bl${i} { opacity: ${last ? 1 : 0}; animation: bl${i} ${T}s linear infinite; }
@keyframes bl${i} { 0%,${(a - 0.01).toFixed(2)}% { opacity: 0; } ${a}%,${b}% { opacity: 1; } ${(b + 0.01).toFixed(2)}%,100% { opacity: 0; } }
.bc${i} { transform: translateX(${w}px); animation: bc${i} ${T}s linear infinite; }
@keyframes bc${i} { 0%,${a}% { transform: translateX(0px); animation-timing-function: steps(${n}, end); } ${(a + d).toFixed(2)}%,100% { transform: translateX(${w}px); } }`;
    body += `<g class="bl${i}">${pixelText(line, 50, 318, px, INK)}<g clip-path="url(#bbox)"><rect class="bc${i}" x="${50 - px}" y="${318 - px}" width="${w}" height="${px * 9}" fill="${PAPER}"/></g></g>`;
  });
  body += `<g class="next">${pixelText('`', box.x + box.w - 50, 334, 3, INK)}</g>`;
  const defs = `<clipPath id="bbox"><rect x="${box.x + 12}" y="${box.y + 12}" width="${box.w - 24}" height="${box.h - 24}"/></clipPath>`;
  write('battle.svg', svgDoc(W, H,
    "Battle text: A wild LEAK appeared! Canary used FINGERPRINT! It's super effective! It was Priya's copy, number 03.",
    css, body, defs));
}

// ---------------------------------------------------------------- footer
function gameOver() {
  const W = 840, H = 100;
  const a = 'GAME OVER?', b = '^ PLAY AGAIN AT THE LIVE APP';
  let body = card(W, H);
  body += pixelText(a, Math.round((W - SH - textW(a, 3)) / 2), 22, 3, ORANGE);
  body += `<g class="blink">${pixelText(b, Math.round((W - SH - textW(b, 2)) / 2), 58, 2, INK)}</g>`;
  write('game-over.svg', svgDoc(W, H, 'Game over? Play again at the live app.', blinkCss, body));
}

// ---------------------------------------------------------------- README
const zeroAddr = /^0x0{40}$/i;
const has = (v) => typeof v === 'string' && v.trim() !== '' && !zeroAddr.test(v);

function readme() {
  const live = cfg.liveUrl;
  const liveText = live.replace(/^https?:\/\//, '').replace(/#.*$/, '');
  const repo = cfg.repoUrl;
  const repoName = repo.split('/').pop();
  const testnet = has(cfg.contractTestnet) ? cfg.contractTestnet : null;
  const mainnet = has(cfg.contractMainnet) ? cfg.contractMainnet : null;
  const testnetUrl = testnet ? `${cfg.explorerTestnet}/address/${testnet}` : null;
  const mainnetUrl = mainnet ? `${cfg.explorerMainnet}/address/${mainnet}` : null;
  const link = (url, text) => (url ? `[${text}](${url})` : '_soon_');
  const ok = (b) => (b ? '**Done**' : 'Soon');
  const team = (cfg.team ?? []).join(' · ');
  const testnetMd = testnet ? `[\`${testnet}\`](${testnetUrl})` : '_deploying_';
  const buildInPublic = [cfg.xPostUrl, cfg.demoVideoUrl, cfg.adVideoUrl].some(Boolean);

  const checklist = [
    `| ${ok(!!live)} | Live app | [${liveText}](${live}) |`,
    `| ${ok(!!testnet)} | Contract on Monad testnet | ${testnetMd} |`,
    `| ${ok(!!cfg.verified && !!testnet)} | Verified source code | ${cfg.verified && testnetUrl ? `[View verified source](${cfg.verifiedUrl || testnetUrl})` : '_soon_'} |`,
    `| ${ok(!!testnet)} | Live transaction in the demo | Every **Open my copy** tap |`,
    `| **Done** | Public repo you can run | [Run it yourself](#more) |`,
    `| ${ok(buildInPublic)} | Build in public | ${link(cfg.xPostUrl, 'X post')} · ${link(cfg.demoVideoUrl, 'demo')} · ${link(cfg.adVideoUrl, 'ad')} |`,
    `| ${ok(!!mainnet)} | Bonus: Monad mainnet | ${mainnet ? `[\`${mainnet}\`](${mainnetUrl})` : '_soon_'} |`,
    `| ${ok(!!cfg.customDomain)} | Bonus: custom domain | ${cfg.customDomain ? `[${liveText.split('/')[0]}](${live})` : '_soon_'} |`,
  ].join('\n');

  return `<!-- Generated by tool/build-readme.mjs: edit readme.config.json and re-run instead of editing this file. -->

<p align="center">
  <a href="${live}"><img src="assets/readme/banner.svg" width="100%" alt="NO SUS Canary: every reader gets their own copy."></a>
</p>

<p align="center">
  <a href="${live}"><img src="assets/readme/btn-play.svg" height="56" alt="Play live"></a>
  &nbsp;
  <a href="#judge-checklist"><img src="assets/readme/btn-judge.svg" height="56" alt="Judge checklist"></a>
</p>

<p align="center"><img src="assets/readme/say-hello.svg" width="100%" alt="Prof. Canary: Share one link. Every reader gets a secretly different copy. If it leaks, I tell you whose copy it was."></p>

## Step 1: Watch

<p align="center"><img src="assets/readme/story.svg" width="100%" alt="Animation: the sender seals a note on Monad, five readers each receive a different copy, Priya's copy leaks, NO SUS scans it and the canary sings: copy 03 is Priya's."></p>

## Step 2: Try it

**60 seconds. No wallet. No install.**

1. **Make a note.** Open the [live app](${live}) → **PLAY CANARY** → **Create a Canary link** → **Use the demo note** → **Create Canary link**.
2. **Be a reader.** Open that link in a private window, type any name, tap **Open my copy**.
3. **Catch the leak.** Copy the reader's text → **Check a leak** → paste. It names the reader.

<p align="center"><img src="assets/readme/battle.svg" width="100%" alt="Battle text: A wild LEAK appeared! Canary used FINGERPRINT! It's super effective! It was Priya's copy, number 03."></p>

## Step 3: Why Monad

- **One transaction per reader.** Every **Open my copy** is recorded on-chain.
- **Final in under a second.** About **0.015 MON** each.
- **Parallel execution.** A whole room can open the link at once.

## Judge checklist

| | What | Where |
|---|---|---|
${checklist}

> **Honest limits:** it names *whose copy* leaked, not *who shared it*. It doesn't stop screenshots. It makes them traceable.

## More

<details>
<summary><b>How the fingerprint works</b></summary>

- **Write once.** NO SUS swaps safe word twins (\`don't\` / \`do not\`, \`five\` / \`5\`) to make up to **100 copies**. Each looks normal, each is unique.
- **Seal it.** Copies are encrypted in your browser. The key lives only in the link's \`#fragment\`. \`sealNote\` puts one hash of all copies on Monad before anyone reads.
- **Share it.** Each reader gets the next unused copy. \`openCopy\` records it on Monad with an anonymous tag, never the name.
- **Catch it.** Paste a leak into **Check a leak**. Matching runs on your device. If too little text survived, it names nobody.
</details>

<details>
<summary><b>Run it yourself</b></summary>

You need Flutter 3.44+ and Node 22+.

\`\`\`bash
git clone ${repo}.git
cd ${repoName}

# App (web)
cd app
flutter pub get
flutter run -d chrome

# Contract
cd ../contracts
npm ci
npx hardhat test
\`\`\`

Own backend and contract: see [\`docs/canary/NOSUS_CANARY_BUILD_PLAN.md\`](docs/canary/NOSUS_CANARY_BUILD_PLAN.md).
</details>

<details>
<summary><b>Architecture</b></summary>

\`\`\`mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'${PAPER}','primaryTextColor':'${INK}','primaryBorderColor':'${INK}','lineColor':'${ORANGE}','fontFamily':'monospace'}}}%%
flowchart LR
  S["Sender app"] -- "encrypted copies" --> F["canary function"]
  F -- "sealNote" --> M[("NoSusCanary on Monad")]
  R["Reader"] -- "open + name" --> F
  F -- "openCopy" --> M
  F -- "their copy" --> R
\`\`\`

- **Chain:** hashes and anonymous tags only.
- **Server:** encrypted copies it can't read.
- **Sender's device:** the key and every copy's fingerprint.
</details>

<details>
<summary><b>Test results</b></summary>

Fingerprint test harness, 15-slot demo note:

| Leak type | Right copy | Wrong copy |
|---|---|---|
| Full copy, marker removed | 300 / 300 | 0 |
| OCR-style (caps, no punctuation) | 300 / 300 | 0 |
| 2% random typos | 300 / 300 | 0 |
| Partial excerpts (30–70%) | named only when sure | 0 / 600 |
</details>

Full technical write-up (setup, deployment, contract and relayers): [\`docs/TECHNICAL_README.md\`](docs/TECHNICAL_README.md)

---

${team ? `**Team:** ${team} · ` : ''}Built at **${cfg.eventName}** · part of **NO SUS**

<p align="center"><a href="${live}"><img src="assets/readme/game-over.svg" width="100%" alt="Game over? Play again at the live app."></a></p>
`;
}

// ---------------------------------------------------------------- run
console.log('Building NO SUS Canary README…');
banner();
button('btn-play.svg', '^ PLAY LIVE', 'Play live', true);
button('btn-judge.svg', 'JUDGE CHECKLIST', 'Judge checklist', false);
dialogue('say-hello.svg', 'PROF. CANARY:', 'Share one link. Every reader gets a secretly different copy. If it leaks, I tell you whose copy it was.',
  'Prof. Canary: Share one link. Every reader gets a secretly different copy. If it leaks, I tell you whose copy it was.');
story();
battle();
gameOver();
// Remove assets from older versions of this README.
for (const f of fs.readdirSync(assetDir)) {
  if (f.endsWith('.svg') && !written.has(f)) {
    fs.rmSync(path.join(assetDir, f));
    console.log(`  removed stale assets/readme/${f}`);
  }
}
fs.writeFileSync(path.join(outDir, 'README.md'), readme());
console.log('  wrote README.md');
console.log('Done.');
