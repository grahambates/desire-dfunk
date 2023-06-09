		incdir	"src"
		incdir	"include"

		include	"hw.i"
		include	"debug.i"

		; common
		include	"macros.i"
		include	"tables.i"
		include	"circles.i"
		include	"commander.i"
		include	"memory.i"
		include	"transitions.i"

		xdef	_start

		xref	Random32
		xref	WaitEOF

		xref	VBlank
		xref	CurrFrame

		xref	StartEffect
		xref	InstallCopper
		xref	ResetFrameCounter
		xref	BlankCop