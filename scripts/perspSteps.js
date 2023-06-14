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

// console.log(out.length);
console.log("XGrid:");
console.log(" dc.w " + out.join(","));

function lerp320(from, to) {
	const out = [];
	const inc = (to - from) / 320;
	for (let i = 0; i < 320; i++) {
		out.push(Math.round(from + inc * i));
	}
	return out;
}
console.log("LineTop:");
console.log(" dc.w " + lerp320(60, 47).join(","));
console.log("LineBottom:");
console.log(" dc.w " + lerp320(180, 220).join(","));
