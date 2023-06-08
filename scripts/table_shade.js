const { sin, cos, abs, PI, round, sqrt, atan2, min, max } = Math;
const argv = require("yargs/yargs")(process.argv.slice(2)).options({
  u: {
    alias: "dstWidth",
    default: 50,
    type: "number",
  },
  v: {
    alias: "dstHeight",
    default: 70,
    type: "number",
  },
  w: {
    alias: "srcWidth",
    default: 64,
    type: "number",
  },
  h: {
    alias: "srcHeight",
    default: 64,
    type: "number",
  },
  r: {
    alias: "routine",
    default: true,
    type: "boolean",
  },
  a: {
    alias: "aspect",
    default: 1,
    type: "number",
  },
}).argv;

const { dstWidth, dstHeight, srcWidth, srcHeight, routine, aspect } = argv;

const shades = 16;
const shadeDist = 1.5;
const shadeOffset = .4;
const uRept = 4;
const vScale = 2;

// https://devlog-martinsh.blogspot.com/2011/03/glsl-8x8-bayer-matrix-dithering.html
const bayer8 = [
  [0, 32, 8, 40, 2, 34, 10, 42] /* 8x8 Bayer ordered dithering  */,
  [48, 16, 56, 24, 50, 18, 58, 26] /* pattern.  Each input pixel   */,
  [12, 44, 4, 36, 14, 46, 6, 38] /* is scaled to the 0..63 range */,
  [60, 28, 52, 20, 62, 30, 54, 22] /* before looking in this table */,
  [3, 35, 11, 43, 1, 33, 9, 41] /* to determine the action.     */,
  [51, 19, 59, 27, 49, 17, 57, 25],
  [15, 47, 7, 39, 13, 45, 5, 37],
  [63, 31, 55, 23, 61, 29, 53, 21],
].map((r) => r.map((v) => (v - 32) / 32));

// http://en.wikipedia.org/wiki/Ordered_dithering
const bayer4 = [
  [1, 9, 3, 11],
  [13, 5, 15, 7],
  [4, 12, 2, 10],
  [16, 8, 14, 6],
].map((r) => r.map((v) => (v - 8) / 8));

// Output ASM:

console.log(`SRC_W = ${srcWidth}`);
console.log(`SRC_H = ${srcHeight}\n`);
console.log(`DEST_W = ${dstWidth}`);
console.log(`DEST_H = ${dstHeight}\n`);
console.log(`ROW_BW = ${dstWidth * 6}\n`);

console.log(" xdef DrawTbl");
console.log("DrawTbl:");

for (let j = 0; j < dstHeight; j++) {
  for (let i = 0; i < dstWidth; i++) {
    const x = -1 + (2 * i) / dstWidth;
    const y = -1 + (2 * j) / dstHeight;
    const r = sqrt(x * x + y * y);
    const a = atan2(y, x);

    let x1 = x * (dstWidth / dstHeight);
    let y1 = y * aspect;
    const r1 = sqrt(x1 * x1 + y1 * y1); // Aspect corrected radius

    let v = 1 / (r1 * vScale);
    let u = (a * uRept) / (2 * PI);
    // let b = 1 - max(min(v / shadeDist - shadeOffset, 1), 0);
    let b = max(min(r1*1.5 -.1, 1), 0);

    // // Flat plane
    // u = x/(Math.sqrt((y*y))+.1)
    // v = 1/(Math.sqrt((y*y))+.1)
    // b = Math.abs(y)

    // Star
    // v = 1 / (r + 0.5 + 0.5 * sin(3 * a));
    // u = (a * 3) / PI;
    // const v1 = 2 / (6 * r + 3 * x);
    // b = 1 - max(min((v * 4 + v1 * 2 - 4) / 10, 1), 0);

    if (v > 0x8000) {
      v = 0;
    }

    const yOffs = round(srcHeight * v) % srcHeight;
    const xOffs = round(srcWidth * u) % srcWidth;
    let offs = (yOffs * srcWidth + xOffs) * 2;
    if (offs < 0) {
      offs += srcHeight * srcWidth * 2;
    }

    const srcs = [
      "#0",

      `${offs}-32768(a3)`,
      `${offs}-16384(a3)`,
      `${offs}(a3)`,
      `${offs}+16384(a3)`,

      `${offs}-32768(a4)`,
      `${offs}-16384(a4)`,
      `${offs}(a4)`,
      `${offs}+16384(a4)`,

      `${offs}-32768(a5)`,
      `${offs}-16384(a5)`,
      `${offs}(a5)`,
      `${offs}+16384(a5)`,

      `${offs}(a6)`,
      `${offs}+16384(a6)`,

      `${offs}(a7)`,
    ];

    const adjust = bayer8[i % 8][j % 8] / shades / 2;
    //const adjust = bayer4[i % 4][j % 4] / shades / 2;
    const src = srcs[round((b + adjust) * (shades - 1))];

    const o = (i >> 1) * 4;
    if (i % 2) {
      console.log(` move.w ${src},${o}(a0)`);
    } else {
      console.log(` move.w ${src},${o}(a1)`);
    }
  }
  if (routine) {
    console.log(` lea CopC_SIZEOF(a0),a0`);
    console.log(` lea CopC_SIZEOF(a1),a1`);
  }
}
if (routine) {
  console.log(` rts`);
}
