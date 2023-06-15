const { pathDataToPolys } = require("svg-path-to-polygons");
const { XMLParser } = require("fast-xml-parser");
const fs = require("fs");
const xmlDataStr = fs.readFileSync(__dirname + "/../assets/KARNIVOR.svg");

const scale = 0.036;
const baseline = 750;
const xScale = 0.7;

const parser = new XMLParser({ ignoreAttributes: false });
let jsonObj = parser.parse(xmlDataStr);
const glyphs = jsonObj.svg.defs.font.glyph;

const out = [];

for (let i = 65; i < 91; i++) {
	const char = String.fromCharCode(i);
	const glyph = glyphs.find((g) => g["@_glyph-name"] === char);
	const pathData = glyph["@_d"];
	const width = Number(glyph["@_horiz-adv-x"]);

	const path = pathDataToPolys(pathData, { tolerance: 1, decimals: 1 });

	out.push({ path, width, char });
}

const fmt = (num) => {
	const val = Math.round(num * scale);
	return val; // >= 0 ? "$" + val : "-$" + val * -1;
};

console.log("FontTable:");
out.forEach((g) => {
	console.log(" dc.l glyph" + g.char);
});

console.log("\nFontGlyphs:");
out.forEach((g) => {
	console.log("glyph" + g.char + ":");
	console.log(" dc.b " + fmt(g.width * xScale + 2 / scale));
	console.log(" dc.b " + (g.path.length - 1));
	g.path.forEach((p) => {
		console.log(" dc.b " + (p.length - 2));
		for (let i = 0; i < p.length - 1; i++) {
			let pt =
				fmt(p[i][0] * xScale) +
				"," +
				fmt(baseline - p[i][1]);
			console.log(" dc.b " + pt);
		}
	});
});
// TODO: limit to used chars
