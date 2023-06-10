const fs = require("fs")

const data = fs.readFileSync(__dirname + "/../data/heart.obj").toString()

const lines = data.split('\n').map(l => l.substring(2).split(' ')).map(n => n.map(Number).map(n => Math.round(n*64)))
console.log(lines.map(l => ' dc.b ' + l.join(',')).join('\n'))
