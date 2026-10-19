// Draws branding/icon.png (512x512): a white shopping bag on a teal tile. No dependencies.
import { deflateSync } from 'node:zlib';
import { writeFileSync } from 'node:fs';

const S = 512;
const px = Buffer.alloc(S * S * 4);
const teal = [15, 118, 110], white = [255, 255, 255];

function inRoundRect(x, y, x0, y0, x1, y1, r) {
  if (x < x0 || x > x1 || y < y0 || y > y1) return false;
  const cx = Math.min(Math.max(x, x0 + r), x1 - r), cy = Math.min(Math.max(y, y0 + r), y1 - r);
  return (x - cx) ** 2 + (y - cy) ** 2 <= r * r;
}
function shade(x, y) {
  if (!inRoundRect(x, y, 0, 0, S - 1, S - 1, 112)) return null;
  const bag = inRoundRect(x, y, 136, 196, 376, 420, 28);
  const d = Math.hypot(x - 256, y - 196);
  const handle = y <= 196 && d >= 58 && d <= 82;
  const dot = Math.hypot(x - 200, y - 250) <= 14 || Math.hypot(x - 312, y - 250) <= 14;
  if (dot) return teal;
  return bag || handle ? white : teal;
}
// 4x supersampling for smooth edges
for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
  let r = 0, g = 0, b = 0, a = 0;
  for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) {
    const c = shade(x + (sx + 0.5) / 4 - 0.5, y + (sy + 0.5) / 4 - 0.5);
    if (c) { r += c[0]; g += c[1]; b += c[2]; a++; }
  }
  const i = (y * S + x) * 4;
  if (a) { px[i] = r / a; px[i + 1] = g / a; px[i + 2] = b / a; px[i + 3] = (a / 16) * 255; }
}

const raw = Buffer.alloc((S * 4 + 1) * S);
for (let y = 0; y < S; y++) px.copy(raw, y * (S * 4 + 1) + 1, y * S * 4, (y + 1) * S * 4);

const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0;
});
const crc = buf => { let c = 0xffffffff; for (const b of buf) c = crcTable[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const chunk = (type, data) => {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const c = Buffer.alloc(4); c.writeUInt32BE(crc(td));
  return Buffer.concat([len, td, c]);
};
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(S, 0); ihdr.writeUInt32BE(S, 4); ihdr[8] = 8; ihdr[9] = 6;

writeFileSync(new URL('../branding/icon.png', import.meta.url), Buffer.concat([
  Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
  chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0)),
]));
console.log('branding/icon.png written');
