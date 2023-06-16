const TOP_PAD = 13;
const L_PAD = 32;
const R_PAD = 48;
const DIW_W = 320;

const leftDist = 728; // distance from vanishing point at left of screen

const W = DIW_W + L_PAD + R_PAD;

// const referenceSize = 147;
const referenceSize = 1.27; // gives 255 values
const referenceDist = leftDist + 160;

const size = (D) => (referenceSize / referenceDist) * (D + 1);

let p = 0;

const xGrid = [];
while (p < W) {
	xGrid.push(Math.round(p));
	const s = size(p + leftDist);
	p += s;
}

console.log("Persp:");

function lerp(from, to, steps) {
	const out = [];
	const inc = (to - from) / steps;
	for (let i = 0; i < steps; i++) {
		out.push(Math.round(from + inc * i));
	}
	return out;
}

console.log("XGRID_SIZE=" + xGrid.length);
console.log("XGRID_MAX_VIS=" + xGrid.findIndex((v) => v >= DIW_W + L_PAD));
console.log("XGRID_MIN_VIS=" + xGrid.findIndex((v) => v > L_PAD));

console.log("XGrid:");
console.log(" dc.w " + xGrid.join(","));

console.log("LineTop:");
console.log(" dc.w " + lerp(62 + TOP_PAD, 48 + TOP_PAD, W).join(","));
console.log("LineBottom:");
console.log(" dc.w " + lerp(176 + TOP_PAD, 226 + TOP_PAD, W).join(","));
console.log("LineFloorEdge:");
console.log(" dc.w " + lerp(192 + TOP_PAD, 294 + TOP_PAD, W).join(","));
console.log("LineFloorX:");
console.log(" dc.w " + lerp(-80, W - 48, xGrid[xGrid.length - 1]).join(","));

const textY = 26 + TOP_PAD;

console.log("TextMul2:");
for (let x = 0; x < 30; x++) {
	const inc = (x * 0.65) / W;
	const hInc = textY / W;
	let v = x + textY;
	console.log(".r" + x);
	const vals = [];
	26 + TOP_PAD, 0;
	for (let y = 0; y < 256; y++) {
		vals.push(Math.round(v));
		v += inc * 2;
		v -= hInc * 2;
	}
	console.log(" dc.b " + vals.join(","));
}
