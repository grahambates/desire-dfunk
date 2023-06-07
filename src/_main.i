		incdir	"include"

		include	"hw.i"
		include	"funcdef.i"
		include	"exec/exec_lib.i"
		include	"exec/memory.i"

		include	"debug.i"
		include	"macros.i"

		xdef	_start

		xref	LerpPal
		xref	LerpCol
		xref	LerpWord
		xref	Random32
		xref	WaitEOF

		xref	VBlank

		xref	InstallInterrupt
		xref	InstallCopper

		xref	Sin
		xref	Cos
		xref	SqrtTab
		xref	DivTab


		rsreset
Lerp_Count	rs.w	1
Lerp_Shift	rs.w	1
Lerp_Inc	rs.l	1
Lerp_Tmp	rs.l	1
Lerp_Ptr	rs.l	1					; Target address pointer
Lerp_SIZEOF	rs.w	0