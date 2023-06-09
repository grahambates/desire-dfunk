		incdir	"include"

		include	"hw.i"
		include	"debug.i"
		include	"macros.i"

		xdef	_start

		xref	LerpPal
		xref	LerpCol
		xref	LerpWord
		xref	Random32
		xref	WaitEOF

		xref	VBlank
		xref	CurrFrame

		xref	StartEffect
		xref	InstallCopper
		xref	ResetFrameCounter
		xref	BlankCop

		; Tables
		xref	Sin
		xref	Cos
		xref	SqrtTab
		xref	DivTab

		; Memory
		xref	AllocChip
		xref	AllocChipAligned
		xref	AllocPublic
		xref	Free

		; Commander
		xdef	Commander_Init
		xdef	CmdMoveIL
		xdef	CmdMoveIW
		xdef	CmdMoveIB
		xdef	CmdAddIL
		xdef	CmdAddIW
		xdef	CmdAddIB
		xdef	CmdSubIL
		xdef	CmdSubIW
		xdef	CmdSubIB
		xdef	CmdLerpWord

		rsreset
Lerp_Count	rs.w	1
Lerp_Shift	rs.w	1
Lerp_Inc	rs.l	1
Lerp_Tmp	rs.l	1
Lerp_Ptr	rs.l	1					; Target address pointer
Lerp_SIZEOF	rs.w	0
