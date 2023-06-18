const TOP_PAD = 13;
const L_PAD = 32;
const R_PAD = 48;
const DIW_W = 320;

const leftDist = 728; // distance from vanishing point at left of screen

const PF2_W = DIW_W + L_PAD + R_PAD;

const referenceSize = 1.27; // gives 255 values
const referenceDist = leftDist + 160;
const ratio = referenceSize / referenceDist;

let p = 0;
const xGrid = [];
while (p < PF2_W) {
	xGrid.push(Math.round(p));
	p += ratio * (p + leftDist + 1);
}

console.log("XGRID_SIZE=" + xGrid.length);
console.log("XGRID_MAX_VIS=" + xGrid.findIndex((v) => v >= DIW_W + L_PAD));
console.log("XGRID_MIN_VIS=" + xGrid.findIndex((v) => v > L_PAD));

console.log("XGrid:");
console.log(" dc.w " + xGrid.join(","));

// Moved to asm...

// const TEXT_Y = 26 + TOP_PAD;
// console.log("TextMul2:");
// let start = TEXT_Y;
// let inc = -(TEXT_Y / PF2_W) * 8;
// for (let x = 0; x < 29; x++) {
// 	let v = start;
// 	console.log(".r" + x);
// 	const vals = [];
// 	for (let y = 0; y < 64; y++) {
// 		vals.push(Math.round(v));
// 		v += inc;
// 	}
// 	inc += (0.65 / PF2_W) * 8;
// 	start += 1;
// 	console.log(" dc.b " + vals.join(","));
// }
