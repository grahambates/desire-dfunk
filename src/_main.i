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

		xdef	Random32
		xdef	WaitEOF

		xdef	VBlank
		xdef	CurrFrame

		xdef	StartEffect
		xdef	InstallCopper
		xdef	ResetFrameCounter
		xdef	BlankCop
		xdef	BlankScreen
