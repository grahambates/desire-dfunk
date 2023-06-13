		include	src/_main.i
		include	dude.i

DUDE_END_FRAME = $800

DUDE_W = 96
DUDE_BW = DUDE_W/8
DUDE_H = 150/2
DUDE_Y = 60

DIW_W = 320
DIW_H = 256
SCREEN_W = DIW_W
SCREEN_H = DIW_H
BPLS = 6

;-------------------------------------------------------------------------------
; Derived
SCREEN_BW = SCREEN_W/8
SCREEN_SIZE = SCREEN_BW*SCREEN_H*BPLS/2
SCREEN_BPL = SCREEN_BW
DIW_BW = DIW_W/8
DIW_MOD = SCREEN_BW*(BPLS/2-1)
DIW_XSTRT = ($242-DIW_W)/2
DIW_YSTRT = ($158-DIW_H)/2
DIW_XSTOP = DIW_XSTRT+DIW_W
DIW_YSTOP = DIW_YSTRT+DIW_H
DIW_STRT = (DIW_YSTRT<<8)!DIW_XSTRT
DIW_STOP = ((DIW_YSTOP-256)<<8)!(DIW_XSTOP-256)
DDF_STRT = ((DIW_XSTRT-17)>>1)&$00fc
DDF_STOP = ((DIW_XSTRT-17+(((DIW_W>>4)-1)<<4))>>1)&$00fc


********************************************************************************
Vbi:
********************************************************************************
		; pf1
		move.l	ViewBuffer(pc),a0
		move.l	a0,bpl0pt(a6)
		lea	SCREEN_BPL(a0),a0
		move.l	a0,bpl2pt(a6)
		lea	SCREEN_BPL(a0),a0
		move.l	a0,bpl4pt(a6)
		; pf2
		lea	BlankBpl,a1
		lea	Bg,a2
		move.l	a2,bpl1pt(a6)
		lea	SCREEN_BW*SCREEN_H(a2),a2
		move.l	a2,bpl3pt(a6)
		move.l	a1,bpl5pt(a6)

		rts

********************************************************************************
Dude_Effect:
********************************************************************************
		jsr	ResetFrameCounter
		jsr	Free
		lea	BlankCop,a0
		sub.l	a1,a1
		jsr	StartEffect

		move.l	#SCREEN_SIZE,d0
		jsr	AllocChip
		move.l	a0,DrawBuffer
		bsr	ClearScreen

		jsr	AllocChip
		move.l	a0,ViewBuffer
		bsr	ClearScreen

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

		lea	Cop,a0
		lea	Vbi,a1
		jsr	StartEffect

Frame:
		movem.l	DrawBuffer(pc),a0-a1
		exg	a0,a1
		movem.l	a0-a1,DrawBuffer

		bsr	ClearScreen

		move.l	CurrFrame,d0
		lsr	#2,d0
		and.w	#$f,d0
		move.w	d0,d1
		mulu	#DUDE_BW*DUDE_H*3,d0

		add.w	d1,d1
		lea	Offsets,a1
		move.b	1(a1,d1),d2				; y
		move.b	(a1,d1),d1				; x
		ext.w	d2
		add.w	#DUDE_Y,d2
		mulu	#SCREEN_BW*3,d2
		add.l	#4,d2
		ror.w	#4,d1

		WAIT_BLIT
		move.l	DrawBuffer(pc),a1
		add.l	d2,a1
		lea	Anim,a0
		add.l	d0,a0
		or.w	#$09f0,d1
		move.w	d1,bltcon0(a6)
		move.l	#-1,bltafwm(a6)
		clr.w	bltamod(a6)
		move.w	#SCREEN_BW-DUDE_BW,bltdmod(a6)
		move.l	a0,bltapt(a6)
		move.l	a1,bltdpt(a6)
		move.w	#(DUDE_H*3<<6)!(DUDE_BW/2),bltsize(a6)

		bsr	InitDrawLine
		lea	BlankBpl,a0

		move.l	#119,d0
		move.l	#56,d1
		move.l	#119,d2
		move.l	#195,d3
		bsr	DrawLine

		move.l	#174,d0
		move.l	#54,d1
		move.l	#174,d2
		move.l	#202,d3
		bsr	DrawLine

		move.l	#4,d0
		move.l	#209,d1
		move.l	#90,d2
		move.l	#193,d3
		bsr	DrawLine

		move.l	#126,d0
		move.l	#233,d1
		move.l	#237,d2
		move.l	#211,d3
		bsr	DrawLine

		move.l	#266,d0
		move.l	#255,d1
		move.l	#319,d2
		move.l	#245,d3
		bsr	DrawLine

; 		moveq	#0,d0
; 		moveq	#0,d1
; 		moveq	#0,d2
; 		moveq	#0,d3
; 		moveq	#0,d5
; 		moveq	#0,d6
; 		moveq	#0,d7
; 		lea	BlankBpl,a0
; 		lea	glyphA,a1
; 		move.b	(a1)+,d5				; width
; 		move.b	(a1)+,d7				; path count
; .path

; 		move.b	(a1)+,d6				; point count
; 		and.w	#$ff,d6
; 		; first point
; 		move.b	(a1)+,d0
; 		and.w	#$ff,d0
; 		move.b	(a1)+,d1
; 		and.w	#$ff,d1
; .pt
; 		move.b	(a1),d2
; 		and.w	#$ff,d2
; 		move.b	1(a1),d3
; 		and.w	#$ff,d3
; 		bsr	DrawLine
; 		move.b	(a1)+,d0
; 		and.w	#$ff,d0
; 		move.b	(a1)+,d1
; 		and.w	#$ff,d1
; 		dbf	d6,.pt
; 		dbf	d7,.path

		jsr	WaitEOF
		cmp.l	#DUDE_END_FRAME,CurrFrame
		blt	Frame

		rts


********************************************************************************
InitDrawLine:
; Prepare common blit regs for line draw
;-------------------------------------------------------------------------------
		WAIT_BLIT
		move.w	#SCREEN_BW,bltcmod(a6)
		move.l	#-$8000,bltbdat(a6)
		move.l	#-1,bltafwm(a6)
		rts

********************************************************************************
DrawLine:
; d0.w - x1
; d1.w - y1
; d2.w - x2
; d3.w - y2
; a0 - Draw buffer
; a6 - Custom
;-------------------------------------------------------------------------------
		sub.w	d0,d2					; d2 = dx = x1 - x2
		bmi.b	.oct2345				; nagative? octant could be 2,3,4,5
		sub.w	d1,d3					; d3 = dy = y1 - y2
		bmi.b	.oct01					; negative? octant is 0 or 1
		cmp.w	d3,d2					; compare dy with dx
		bmi.b	.oct6					; dy > dx? octant 6!
		moveq	#$0011,d4				; select line + octant 7!
		bra.b	.doneOct

.oct6		exg	d2,d3					; ensure d2=dmax and d3=dmin
		moveq	#$0001,d4				; select line + octant 6
		bra.b	.doneOct

.oct2345
		neg.w	d2					; make dx positive
		sub.w	d1,d3					; d3 = dy = y1 - y2
		bmi.b	.oct23					; negative? octant is 2 or 3
		cmp.w	d3,d2					; compare dy with dx
		bmi.b	.oct5					; dy > dx? octant 5!
		moveq	#$0015,d4				; select line + octant 4
		bra.b	.doneOct

.oct5		exg	d2,d3					; ensure d2=dmax and d3=dmin
		moveq	#$0009,d4				; select line + octant 5
		bra.b	.doneOct

.oct23
		neg.w	d3					; make dy positive
		cmp.w	d3,d2					; compare dy with dx
		bmi.b	.oct2					; dy > dx? octant 2!
		moveq	#$001d,d4				; select line + octant 3
		bra.b	.doneOct

.oct2		exg	d2,d3					; ensure d2=dmax and d3=dmin
		moveq	#$000d,d4				; select line + octant 2
		bra.b	.doneOct

.oct01
		neg.w	d3					; make dy positive
		cmp.w	d3,d2					; compare dy with dx
		bmi.b	.oct1					; dy > dx? octant 1!
		moveq	#$0019,d4				; select line + octant 0
		bra.b	.doneOct

.oct1		exg	d2,d3					; ensure d2=dmax and d3=dmin
		moveq	#$0005,d4				; select line + octant 1

.doneOct
		add.w	d2,d2					; d2 = 2 * dmax
		asl.w	#2,d3					; d3 = 4 * dmin

		move.l	a0,a5					; aptr bitplane to draw on

		add.w	d1,d1					; convert y1 pos into offset
		ext.l	d1
		move.w	.screenMuls(pc,d1.w),d1

		add.l	d1,a5					; add ofset to bitplane pointer
		ext.l	d0					; clear top bits of d0
		ror.l	#4,d0					; roll shift bits to top word
		add.w	d0,d0					; bottom word: convert to byte offset
		adda.w	d0,a5					; add byte offset to bitplane pointer
		swap	d0					; move shift value to bottom word
		or.w	#$0bca,d0				; usea, c and d. minterm $ca, d=a/c+/ac

		move.w	d2,d1					; d1 = 2 * dmax
		lsl.w	#5,d1					; shift dmax to hx pos for bltsize
		add.w	#$0042,d1				; add 1 to hx and set wx to 2

		WAIT_BLIT

		move.l	a5,bltcpt(a6)				; source c = bitplane to draw on
		move.l	a5,bltdpt(a6)				; destination = bitplane to draw on
		move.w	d0,bltcon0(a6)				; source a shift and logic function
		move.w	d3,bltbmod(a6)				; set 4 * dmin

		sub.w	d2,d3					; d3 = (2 * dmax)-(4 * dmin)
		ext.l	d3					; make full long sized
		move.l	d3,bltapt(a6)				; store in a pointer
		bpl.b	.notneg					; skip if positive
		or.w	#$0040,d4				; set sign bit if negative
.notneg
		move.w	d4,bltcon1(a6)				; octant selection, sign and line
		sub.w	d2,d3					; d2 = (2*dmax), d3 = (2*dmax)-(4*dmin)
		move.w	d3,bltamod(a6)				; d3 = 4 * (dmax - dmin)
		move.w	d1,bltsize(a6)				; set length and start the blitter
		rts

; TODO: precalc
; Multiplication LUT for screen byte width
.screenMuls:
		rept	SCREEN_H
		dc.w	SCREEN_BW*REPTN
		endr


********************************************************************************
ClearScreen:
		WAIT_BLIT
		move.l	a0,bltdpt(a6)
		move.l	#$01000000,bltcon0(a6)
		clr.l	bltdmod(a6)
		move.w	#(DIW_H*BPLS/2)<<6!(SCREEN_BW/2),bltsize(a6)
		rts


********************************************************************************
Vars:
********************************************************************************

DrawBuffer	dc.l	0
ViewBuffer	dc.l	0

Offsets:
		dc.b	0,-1
		dc.b	0,-2
		dc.b	0,-1
		dc.b	1,-1
		dc.b	2,-2
		dc.b	2,-3
		dc.b	1,-3
		dc.b	1,-2
		dc.b	1,-1
		dc.b	1,-2
		dc.b	1,-2
		dc.b	1,-1
		dc.b	1,-2
		dc.b	1,-3
		dc.b	1,-2
		dc.b	1,-1

		include	data/font.i


********************************************************************************
		data_c
********************************************************************************

Cop:
		dc.w	diwstrt,DIW_STRT
		dc.w	diwstop,DIW_STOP
		dc.w	ddfstrt,DDF_STRT
		dc.w	ddfstop,DDF_STOP
		dc.w	bpl1mod,DIW_MOD
		dc.w	bpl2mod,0
		dc.w	bplcon0,BPLS<<12!$200!(1<<10)
		incbin	data/dude-bg.COP
		dc.w	color12,$414
		dc.w	color13,$fff
		dc.w	color14,$101
		dc.w	color15,$000
; loop A
Cop2LcA		dc.w	cop2lch,0
		dc.w	cop2lcl,0
		COP_WAITV DUDE_Y+DIW_YSTRT-4
CopLoopA
		dc.w	bpl1mod,-SCREEN_BW
		incbin	data/dude_walking.COP
		COP_WAITH 0,$e0
		dc.w	bpl1mod,DIW_MOD
		dc.w	color01,$000
		dc.w	color02,$414
		dc.w	color03,$a28
		dc.w	color04,$f8a
		dc.w	color05,$000
		dc.w	color06,$556
		dc.w	color07,$5a5
		COP_WAITH 0,$e0
		COP_SKIPV $80
		dc.w	copjmp2,0

; loop B
Cop2LcB		dc.w	cop2lch,0
		dc.w	cop2lcl,0
CopLoopB
		dc.w	bpl1mod,-SCREEN_BW
		incbin	data/dude_walking.COP
		COP_WAITH $80,$e0
		dc.w	bpl1mod,DIW_MOD
		dc.w	color01,$000
		dc.w	color02,$414
		dc.w	color03,$a28
		dc.w	color04,$f8a
		dc.w	color05,$000
		dc.w	color06,$556
		dc.w	color07,$5a5
		COP_WAITH $80,$e0
		; COP_SKIPV DUDE_Y+DIW_YSTRT+DUDE_H*2
		COP_SKIPV $ff
		dc.w	copjmp2,0

		dc.l	-2

Anim:
		incbin	data/dude_walking.BPL

Bg:
		incbin	data/dude-bg.BPL

		bss_c


BlankBpl:	ds.b	SCREEN_SIZE
