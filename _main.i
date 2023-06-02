		incdir	"include"
		include	"hw.i"
		include	"debug.i"
		include	"macros.i"

		xdef	_start

		xref	SwapBuffers
		xref	Clear
		xref	LerpPal
		xref	LerpCol
		xref	Random32
		xref	WaitEOF
		xref	BlitCircle
		xref	BltCircSizes
		xref	DrawCircle
		xref	CopCircle
		xref	Plot

		xref	VBlank
		xref	DrawBuffer
		xref	DrawClearList

		xref	PokeBpls
		xref	InstallInterrupt

		xref	Sin
		xref	Cos
		xref	SqrtTab
		xref	DivTab
		xref	ValueNoise
		xref	LogSteps
		xref	Pal0
		xref	Pal1
		xref	Pal2
		xref	Pal3

; Maximum radius for blitter circles
; Need to adjust BltCircBpl size when you change this
BLTCIRC_MAX_R = 48

		rsreset
Blit_Adr	rs.l	1
Blit_Mod	rs.w	1
Blit_Sz		rs.w	1
Blit_SIZEOF	rs.b	0
