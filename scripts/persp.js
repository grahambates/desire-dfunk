const leftDist = 728; // distance from vanishing point at left of screen

// const referenceSize = 147;
const referenceSize = 1.27; // gives 255 values
const referenceDist = leftDist + 160;

const size = (D) => (referenceSize / referenceDist) * (D + 1);

let p = 0;

const out = [];
while (p < 320) {
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

console.log("XGrid:");
console.log(" dc.w " + out.join(","));

console.log("LineTop:");
console.log(" dc.w " + lerp(60, 47, 320).join(","));
console.log("LineBottom:");
console.log(" dc.w " + lerp(180, 220, 320).join(","));
console.log("TextTop:");
console.log(" dc.w " + lerp(23 + 9, 0, 320).join(","));

console.log("TextMul:");
console.log(" dc.w " + lerp(0x8000, 0xf000, 320).join(","));
