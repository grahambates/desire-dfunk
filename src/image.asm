		include	src/_main.i
		include	image.i

IMAGE_END_FRAME = $1000

D_GRAD_START = 21
D_GRAD_SIZE = 58
LETTERS_GRAD_START = 77
LETTERS_GRAD_SIZE = 52

DIW_W = 320
DIW_H = 180
SCREEN_W = DIW_W
SCREEN_H = DIW_H
BPLS = 4

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

DGradientData:
; https://gradient-blaster.grahambates.com/?points=123@0,a08@16,123@31&steps=32&blendMode=lab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=63
DGradientData1:
		dc.w	$123,$223,$223,$324,$324,$424,$424,$525
		dc.w	$625,$625,$626,$726,$816,$817,$917,$a18
		dc.w	$a08,$a18,$917,$817,$826,$726,$726,$526
		dc.w	$525,$525,$425,$324,$324,$223,$123,$123
; https://gradient-blaster.grahambates.com/?points=123@0,10a@16,123@31&steps=32&blendMode=lab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=63
DGradientData2:
		dc.w	$123,$123,$114,$124,$125,$115,$125,$216
		dc.w	$116,$217,$117,$218,$108,$119,$009,$10a
		dc.w	$10a,$10a,$109,$109,$118,$118,$117,$117
		dc.w	$116,$216,$115,$124,$114,$123,$123,$123
; https://gradient-blaster.grahambates.com/?points=123@0,0a3@16,123@31&steps=32&blendMode=lab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=63
DGradientData3:
		dc.w	$123,$123,$123,$133,$243,$143,$153,$253
		dc.w	$263,$273,$273,$273,$183,$193,$093,$1a3
		dc.w	$0a3,$1a3,$193,$183,$183,$173,$263,$163
		dc.w	$253,$253,$143,$143,$133,$133,$123,$123
; https://gradient-blaster.grahambates.com/?points=123@0,0aa@16,123@31&steps=32&blendMode=lab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=63
DGradientData4:
		dc.w	$123,$123,$124,$134,$145,$145,$155,$156
		dc.w	$166,$167,$077,$178,$188,$199,$099,$0aa
		dc.w	$0aa,$0aa,$099,$089,$188,$178,$167,$167
		dc.w	$156,$156,$145,$144,$134,$133,$123,$123

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
Image_Vbi:
********************************************************************************
; Set bpl ptrs
		lea	Image,a0
		lea	bpl0pt+custom,a1
		rept	BPLS
		move.l	a0,(a1)+
		lea	SCREEN_BPL(a0),a0
		endr

		move.l	CurrFrame,d0

		; bars
		lea	Bars,a0
		move.w	d0,d1
		lsr	#2,d1
		and.w	#$1e,d1
		move.w	(a0,d1),d1
		move.w	d1,TopBorder
		move.w	d1,BottomBorder

		; dots
		move.w	d0,d1
		lsr	#2,d1
		and.w	#$3e,d1
		lea	DGradientData1,a0
		add.w	#$30,d1
		and.w	#$3e,d1
		move.w	(a0,d1.w),Dot1
		lea	DGradientData2,a0
		add.w	#$30,d1
		and.w	#$3e,d1
		move.w	(a0,d1.w),Dot2
		lea	DGradientData3,a0
		add.w	#$30,d1
		and.w	#$3e,d1
		move.w	(a0,d1.w),Dot3
		lea	DGradientData1,a0
		add.w	#$30,d1
		and.w	#$3e,d1
		move.w	(a0,d1.w),Dot4
		lea	DGradientData4,a0
		add.w	#$30,d1
		and.w	#$3e,d1
		move.w	(a0,d1.w),Dot5

		; cycle letters
		move.w	d0,d1
		neg.w	d1
		lsr.l	#4,d1
		and.w	#3<<1,d1
		lea	Cols,a0
		lea	(a0,d1.w),a0
		lea	$198(a6),a1
		move.l	(a0)+,(a1)+
		move.l	(a0)+,(a1)+

		; highlight
		move.w	#$777,$196(a6)
		btst	#6,d0
		beq	.odd
		move.w	#$fff,$196(a6)
.odd

		lea	Cols,a0
		move.l	CurrFrame,d0
		neg.w	d0
		lsr.w	#4,d0
		and.w	#3<<1,d0
		lea	(a0,d0.w),a0

		lea	DGradientData,a0

		; d gradient
		lea	DGradient+2,a1
		move.w	#D_GRAD_SIZE-1,d7
		move.l	CurrFrame,d0
		lsr.w	#1,d0
.dgrad
		move.w	d0,d1
		lsr	#1,d1
		and.w	#$7e,d1
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
		move.w	#LETTERS_GRAD_SIZE-1,d7
.lgrad
		move.w	d0,d1
		lsl	#1,d1
		and.w	#$7e,d1
		move.w	(a0,d1),(a1)
		lea	8(a1),a1
		addq	#1,d0
		dbf	d7,.lgrad

		rts

Cols:
		dc.w	$6cf,$d6f,$e71,$ed1
		dc.w	$6cf,$d6f,$e71,$ed1

********************************************************************************
Image_Effect:
********************************************************************************
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

Frame:
		jsr	WaitEOF
		cmp.l	#IMAGE_END_FRAME,CurrFrame
		blt	Frame
		rts


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
		; incbin	data/dfunk320.COP
		dc.w	$180,$000
		dc.w	$182,$111
		dc.w	$184,$213
		dc.w	$188,$325
		dc.w	$18a,$547
		dc.w	$18c,$879
		dc.w	$18e,$98c
		dc.w	$190,$a9c
		dc.w	$192,$bbc
		dc.w	$194,$668

Cop2LcA		dc.w	cop2lch,0
		dc.w	cop2lcl,0
CopLoopA
		; top loop
		dc.w	$180,$000
		dc.w	$180,$111
		COP_WAITH 0,$e0
		dc.w	$180,$111
		dc.w	$180,$000
		COP_WAITH 0,$e0
		COP_SKIPV DIW_YSTRT-1
		dc.w	copjmp2,0
		; top border
		dc.w	$180
TopBorder:	dc.w	$fff
		COP_WAITV DIW_YSTRT
		dc.w	$180,$000

		dc.w	$186
Dot1:		dc.w	$fff
		COP_WAITV DIW_YSTRT+12
		dc.w	$186
Dot2:		dc.w	$f0f

		COP_WAITV DIW_YSTRT+D_GRAD_START
DGradient:
.y		set	DIW_YSTRT+D_GRAD_START
		rept	D_GRAD_SIZE
		dc.w	$186,0
		COP_WAITH .y,$e0
.y		set	.y+1
		endr

		COP_WAITV DIW_YSTRT+LETTERS_GRAD_START
LettersGradient:
		rept	LETTERS_GRAD_SIZE
		dc.w	$186,0
		COP_WAITH $80,$e0
		endr

		COP_WAITV DIW_YSTRT+147
		dc.w	$186
Dot3:		dc.w	$ff0
		COP_WAITV DIW_YSTRT+155
		dc.w	$186
Dot4:		dc.w	$f0f
		COP_WAITV DIW_YSTRT+169
		dc.w	$186
Dot5:		dc.w	$0ff

		; pal fix
		COP_WAIT $ff,$de



		; bottom border
		COP_WAITV DIW_YSTOP+1
		dc.w	$180
BottomBorder:	dc.w	$fff
		COP_WAITV DIW_YSTOP+2
		dc.w	$180,$000
		; bottom loop
Cop2LcB		dc.w	cop2lch,0
		dc.w	cop2lcl,0
CopLoopB
		dc.w	$180,$000
		dc.w	$180,$111
		COP_WAITH $0,$e0
		dc.w	$180,$111
		dc.w	$180,$000
		COP_WAITH $0,$e0
		COP_SKIPV DIW_YSTOP+50
		dc.w	copjmp2,0


		dc.l	-2

Image:
		incbin	data/dfunk320.BPL
