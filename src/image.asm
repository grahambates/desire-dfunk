		include	src/_main.i
		include	image.i
		include	tunnel.i

IMAGE_END_FRAME = $200
; IMAGE_END_FRAME = $20

; Color indexes
GRAD_COL = color05
HIGHLIGHT_COL = color24
LETTERS_COL = $198

; Copper positions
D_GRAD_Y = 11
D_GRAD_H = 58
LETTERS_GRAD_Y = 70
LETTERS_GRAD_H = 52

; Screen
DIW_W = 320
DIW_H = 150
SCREEN_W = DIW_W
SCREEN_H = DIW_H
BPLS = 5

;-------------------------------------------------------------------------------
; Derived
COLORS = 1<<BPLS
SCREEN_BW = SCREEN_W/8
SCREEN_SIZE = SCREEN_BW*SCREEN_H*BPLS
SCREEN_BPL = SCREEN_BW*SCREEN_H
DIW_BW = DIW_W/8
DIW_MOD = 0
DIW_XSTRT = ($242-DIW_W)/2
DIW_YSTRT = ($158-DIW_H)/2
DIW_XSTOP = DIW_XSTRT+DIW_W
DIW_YSTOP = DIW_YSTRT+DIW_H
DIW_STRT = (DIW_YSTRT<<8)!DIW_XSTRT
DIW_STOP = ((DIW_YSTOP-256)<<8)!(DIW_XSTOP-256)
DDF_STRT = ((DIW_XSTRT-17)>>1)&$00fc
DDF_STOP = ((DIW_XSTRT-17+(((DIW_W>>4)-1)<<4))>>1)&$00fc


********************************************************************************
Image_Vbi:
********************************************************************************
; Set bpl ptrs
		lea	Image,a0
		lea	bpl0pt+custom,a1
		rept	BPLS
		move.l	a0,(a1)+
		lea	SCREEN_BPL(a0),a0
		endr

		lea	Cop,a5
		move.l	CurrFrame,d0

		; bars
		lea	Bars(pc),a0
		move.w	d0,d1
		lsr	#2,d1
		and.w	#$1e,d1
		move.w	(a0,d1),d1
		move.w	d1,TopBorder-Cop(a5)
		move.w	d1,BottomBorder-Cop(a5)

		lea	FastCycleGoldCols(pc),a0
		lea	FastCycleGold+2,a1
		moveq	#6,d2
		moveq	#2,d3
		bsr	DoCycle

		lea	MediumCycleBlueCols(pc),a0
		lea	MediumCycleBlue+2,a1
		moveq	#7,d2
		moveq	#3,d3
		bsr	DoCycle

		lea	MediumCyclePurpleCols(pc),a0
		lea	MediumCyclePurple+2,a1
		moveq	#3,d2
		moveq	#3,d3
		bsr	DoCycle

		lea	SlowCycleFunkCols(pc),a0
		lea	SlowCycleFunk+2,a1
		moveq	#4,d2
		moveq	#4,d3
		bsr	DoCycle

		; highlight
		move.w	#$777,ColHighlight
		btst	#6,d0
		beq	.odd
		move.w	#$fff,ColHighlight
.odd

		; d gradient
		lea	DGradientData(pc),a0
		lea	DGradient+2-Cop(a5),a1
		move.w	#D_GRAD_H-1,d7
		lsr.w	#1,d0
.dgrad
		move.w	d0,d1
		lsr	#1,d1
		and.w	#$3e,d1
		move.w	(a0,d1),(a1)
		lea	8(a1),a1
		addq	#1,d0
		dbf	d7,.dgrad

		; letters gradient
		lsl	#3,d0
		and.w	#$7fe,d0
		lea	Sin,a0
		move.w	(a0,d0),d0
		lsr.w	#8,d0
		lsr.w	#1,d0
		lea	LGradientData,a0
		lea	LettersGradient+2,a1
		lea	Sin,a2
		move.w	#LETTERS_GRAD_H-1,d7
.lgrad
		move.w	d0,d1
		lsl	#1,d1
		and.w	#$7e,d1
		move.w	(a0,d1),(a1)
		lea	8(a1),a1
		addq	#1,d0
		dbf	d7,.lgrad

		rts


********************************************************************************
; a0 = colors
; a1 = copper
; d1 = pos
; d2 = colour count
; d3 = speed shift
DoCycle:
		move.l	d0,d1
		neg.w	d1
		lsr.l	d3,d1
		divu	d2,d1
		swap	d1
		add.w	d1,d1
		lea	(a0,d1.w),a0
		subq	#1,d2
.l		move.w	(a0)+,(a1)
		addq	#4,a1
		dbf	d2,.l
		rts

********************************************************************************
Image_Effect:
********************************************************************************
		jsr	Free
		jsr	ResetFrameCounter
		lea	Cop,a0
		lea	Image_Vbi,a1
		jsr	StartEffect

		lea	Cop2LcA+2,a0
		move.l	#CopLoopA,d0
		move.w	d0,4(a0)
		swap	d0
		move.w	d0,(a0)

		lea	Cop2LcB+2,a0
		move.l	#CopLoopB,d0
		move.w	d0,4(a0)
		swap	d0
		move.w	d0,(a0)

		lea	Cop2LcD+2,a0
		move.l	#CopLoopD,d0
		move.w	d0,4(a0)
		swap	d0
		move.w	d0,(a0)

		lea	BottomGradient+2,a0
		lea	BottomGradCols,a1
		moveq	#14-1,d0
.l		move.w	(a1)+,(a0)
		lea	16(a0),a0
		dbf	d0,.l

		jsr	Tunnel_Setup

Frame:
		jsr	WaitEOF
		cmp.l	#IMAGE_END_FRAME,CurrFrame
		blt	Frame
		rts


********************************************************************************
Data:
********************************************************************************

SlowCycleFunkCols:
		dc.w	$ed1,$e71,$d6f,$6cf
		dc.w	$ed1,$e71,$d6f,$6cf
FastCycleGoldCols:
		dc.w	$443,$664,$886,$a97,$775,$765
		dc.w	$443,$664,$886,$a97,$775,$765
MediumCyclePurpleCols:
		dc.w	$747,$434,$323
		dc.w	$747,$434,$323
MediumCycleBlueCols:
		dc.w	$112,$122,$122,$123,$233,$7ac,$567
		dc.w	$112,$122,$122,$123,$233,$7ac,$567

BottomGradCols:
; https://gradient-blaster.grahambates.com/?points=446@0,335@4,224@6,112@11,111@13&steps=14&blendMode=linear&ditherMode=off&target=amigaOcs
		dc.w	$446,$446,$335,$335,$335,$224,$224,$113
		dc.w	$113,$113,$112,$112,$111,$111


; https://gradient-blaster.grahambates.com/?points=123@0,a08@16,123@31&steps=32&blendMode=lab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=63
DGradientData:
		dc.w	$123,$223,$223,$324,$324,$424,$424,$525
		dc.w	$625,$625,$626,$726,$816,$817,$917,$a18
		dc.w	$a08,$a18,$917,$817,$826,$726,$726,$526
		dc.w	$525,$525,$425,$324,$324,$223,$123,$123

; https://gradient-blaster.grahambates.com/?points=bfc@0,f1c@57,bfd@63&steps=64&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=26
LGradientData:
		dc.w	$bfc,$bfc,$bfd,$cfd,$cfc,$cfc,$cfc,$ced
		dc.w	$ded,$cec,$dec,$dec,$ddc,$ddd,$ddd,$edc
		dc.w	$ddc,$ecd,$dcd,$ecd,$ecc,$ecc,$ecd,$ebd
		dc.w	$ebc,$ebc,$ebc,$ebd,$ead,$fac,$fad,$fac
		dc.w	$ead,$f9d,$f9c,$f9c,$f9c,$f8d,$f8d,$f8d
		dc.w	$f8c,$f7c,$f7d,$f7d,$f7c,$f6c,$f7c,$f6d
		dc.w	$f5d,$f5c,$f5c,$f5c,$f4d,$f4c,$f3d,$f3c
		dc.w	$f2c,$f1c,$f6d,$f8d,$fad,$ecd,$dee,$bfe

Bars:
		dc.w	$b9c,$c9c,$c9b,$c99,$ca9,$cb9,$cc9,$bc9
		dc.w	$ac9,$9c9,$9cb,$9cc,$9bc,$9ac,$99c,$a9c


********************************************************************************
		data_c
********************************************************************************

Cop:
		dc.w	diwstrt,DIW_STRT
		dc.w	diwstop,DIW_STOP
		dc.w	ddfstrt,DDF_STRT
		dc.w	ddfstop,DDF_STOP
		dc.w	bpl1mod,DIW_MOD
		dc.w	bpl2mod,DIW_MOD
		dc.w	bplcon0,BPLS<<12!$200

		dc.w	$180,$111
		dc.w	$182,$213
		dc.w	$184,$325
		dc.w	$186,$000
		dc.w	$188,$547
		; dc.w	color05,$6b7
		dc.w	$18c,$879
		dc.w	$18e,$bbc
		dc.w	$190,$a9c
		dc.w	$192,$98c
		dc.w	$194,$668
FastCycleGold:
		dc.w	color15,0
		dc.w	color19,0
		dc.w	color11,0
		dc.w	color18,0
		dc.w	color13,0
		dc.w	color12,0
MediumCyclePurple:
		dc.w	color17,0
		dc.w	color14,0
		dc.w	color16,0
SlowCycleFunk:
		dc.w	color20,0
		dc.w	color23,0
		dc.w	color21,0
		dc.w	color22,0
ColHighlight:
		dc.w	color24,0
MediumCycleBlue:
		dc.w	color26,0
		dc.w	color30,0
		dc.w	color28,0
		dc.w	color25,0
		dc.w	color29,0
		dc.w	color27,0
		dc.w	color31,0

		COP_WAITV 20		; align borders

Cop2LcA		dc.w	cop2lch,0
		dc.w	cop2lcl,0
CopLoopA
		; top loop
		dc.w	color00,$000
		dc.w	color00,$111
		COP_WAITH 0,$e0
		dc.w	color00,$111
		dc.w	color00,$000
		COP_WAITH 0,$e0
		COP_SKIPV DIW_YSTRT-1
		dc.w	copjmp2,0
		; top border
		dc.w	color00
TopBorder:	dc.w	$fff
		COP_WAITV DIW_YSTRT
		dc.w	color00,$000

		COP_WAITV DIW_YSTRT+D_GRAD_Y
DGradient:
.y		set	DIW_YSTRT+D_GRAD_Y
		rept	D_GRAD_H
		dc.w	GRAD_COL,0
		COP_WAITH .y,$e0
.y		set	.y+1
		endr

		COP_WAITV DIW_YSTRT+LETTERS_GRAD_Y
LettersGradient:
		rept	LETTERS_GRAD_H
		dc.w	GRAD_COL,0
		COP_WAITH $80,$e0
		endr

BottomGradient:
		rept	14*2
		dc.w	GRAD_COL,$000
		COP_WAITH $80,$e0
		endr

		; bottom border
		COP_WAITV DIW_YSTOP
		dc.w	color00
BottomBorder:	dc.w	$fff
		COP_WAITV DIW_YSTOP+1
		dc.w	color00,$000

		; bottom loop 1
Cop2LcB		dc.w	cop2lch,0
		dc.w	cop2lcl,0
CopLoopB
		dc.w	color00,$000
		dc.w	color00,$111
		COP_WAITH $80,$e0
		dc.w	color00,$111
		dc.w	color00,$000
		COP_WAITH $80,$e0
		COP_SKIPV $fe
		dc.w	copjmp2,0

		dc.w	color00,$000
		dc.w	color00,$111
		COP_WAITH $80,$e0
		dc.w	color00,$111
		dc.w	color00,$000
		COP_WAITH $80,$e0

		; bottom loop 2
Cop2LcD		dc.w	cop2lch,0
		dc.w	cop2lcl,0
CopLoopD
		dc.w	color00,$000
		dc.w	color00,$111
		COP_WAITH $0,$e0
		dc.w	color00,$111
		dc.w	color00,$000
		COP_WAITH $0,$e0
		COP_SKIPV $40
		dc.w	copjmp2,0


		dc.l	-2

Image:
		incbin	data/dfunk_ordered.BPL
