const { pathDataToPolys } = require("svg-path-to-polygons");
const { XMLParser } = require("fast-xml-parser");
const fs = require("fs");

const xScale = 0.7;
const SPACE_WIDTH = 15;

const colors = ["$6cf", "$d6f", "$e71", "$ed1"];

const greets = [
	["SLIPSTREAM", "zosilla"],
	["RIFT", "NameSmile"],
	["LOGICOMA", "zosilla"],
	["INSANE", "RabbitFire"],
	["FATZONE", "NameSmile"],
	["TUHB", "RabbitFire"],
	["BITSHIFTERS", "zosilla"],
	["MELON", "NameSmile"],
	["FOCUS DESIGN", "zosilla"],
	["PROXIMA", "NameSmile"],
	["FIVE FINGER PUNCH", "zosilla"],
	["ABYSS", "RabbitFire"],
	["RESISTANCE", "NameSmile"],
	["MOODS PLATEAU", "zosilla"],
];

const fonts = {};

buildFont("zosilla", 0.018, 1400);
buildFont("NameSmile", 0.017, 1600);
buildFont("RabbitFire", 0.019, 1400);
// buildFont("KARNIVOR", 0.036, 750);
// buildFont("yukari", 0.014, 1600);

function buildFont(name, scale, baseline) {
	const xmlDataStr = fs.readFileSync(
		__dirname + `/../assets/${name}.svg`
	);
	const parser = new XMLParser({ ignoreAttributes: false });
	let jsonObj = parser.parse(xmlDataStr);
	const glyphsDat = jsonObj.svg.defs.font.glyph;

	const fmt = (num) => Math.round(num * scale);

	glyphs = [];

	const text = greets
		.filter((g) => g[1] === name)
		.map((g) => g[0])
		.join("");

	for (let i = 65; i < 91; i++) {
		const char = String.fromCharCode(i);
		if (!text.includes(char)) {
			glyphs.push(null);
			continue;
		}
		const glyph = glyphsDat.find((g) => g["@_glyph-name"] === char);
		const pathData = glyph["@_d"];
		const width = Number(glyph["@_horiz-adv-x"]);

		const path = pathDataToPolys(pathData, {
			tolerance: 1,
			decimals: 1,
		});

		glyphs.push({ path, width, char });
	}

	console.log(name + "FontTable:");
	glyphs.forEach((g) => {
		console.log(` dc.l ${g ? name + g.char : 0}`);
	});

	console.log("\n" + name + "FontGlyphs:");
	glyphs.filter(Boolean).forEach((g) => {
		console.log(name + g.char + ":");
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
		console.log(" even");
	});
	// TODO: limit to used chars

	fonts[name] = { scale, glyphs };
}

greets.forEach((g) => {
	console.log(`${makeLabel(g)}: dc.b "${g[0]}",0`);
});

console.log(" even");

console.log(`Greets:`);

greets.forEach((g, i) => {
	console.log(` dc.w ${getWidth(g)}`); // Width
	console.log(` dc.w ${colors[i % 4]}`); // Color
	console.log(` dc.l ${g[1]}FontTable-65*4`); // Font
	console.log(` dc.l ${makeLabel(g)}`); // Text data
});
console.log(" dc.w -1");

function makeLabel(g) {
	return "t" + g[0].replace(/ /g, "");
}

function getWidth([str, name]) {
	let w = 0;
	for (i = 0; i < str.length; i++) {
		const char = str.charCodeAt(i);
		const width =
			char === 32
				? SPACE_WIDTH
				: fonts[name].glyphs[char - 65].width;
		w += Math.round(width * xScale * fonts[name].scale + 2);
	}
	return w;
}
