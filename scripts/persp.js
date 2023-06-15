const leftDist = 728; // distance from vanishing point at left of screen
const W = 320 + 32 + 48;
const TOP_PAD = 9;

// const referenceSize = 147;
const referenceSize = 1.27; // gives 255 values
const referenceDist = leftDist + 160;

const size = (D) => (referenceSize / referenceDist) * (D + 1);

let p = 0;

const out = [];
while (p < W) {
	out.push(Math.round(p));
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

console.log("XGRID_SIZE=" + out.length);
console.log("XGrid:");
console.log(" dc.w " + out.join(","));

console.log("TextTop:");
console.log(" dc.w " + lerp(26 + TOP_PAD, 0, W).join(","));
console.log("LineTop:");
console.log(" dc.w " + lerp(62 + TOP_PAD, 48 + TOP_PAD, W).join(","));
console.log("LineBottom:");
console.log(" dc.w " + lerp(176 + TOP_PAD, 226 + TOP_PAD, W).join(","));
console.log("LineFloorEdge:");
console.log(" dc.w " + lerp(192 + TOP_PAD, 294 + TOP_PAD, W).join(","));
console.log("LineFloorX:");
console.log(" dc.w " + lerp(-80, W - 48, out[out.length - 1]).join(","));

console.log("TextMul:");
console.log(" dc.w " + lerp(0x8000, 0xd000, W).join(","));
