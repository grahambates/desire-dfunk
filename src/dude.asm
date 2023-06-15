		include	src/_main.i
		include	dude.i

DUDE_END_FRAME = $1000

DUDE_W = 96
DUDE_BW = DUDE_W/8
DUDE_H = 150/2
DUDE_Y = 60

DIW_W = 320
DIW_H = 256

PF1_BPLS = 3
PF1_W = DIW_W
PF1_H = DIW_H

PF2_BPLS = 3
PF2_W = DIW_W+H_PAD
PF2_H = DIW_H

BPLS = PF1_BPLS+PF2_BPLS

TOP_PAD = 9
L_PAD = 32
R_PAD = 48
H_PAD = L_PAD+R_PAD
FILL_HEIGHT = 51

;-------------------------------------------------------------------------------
; Derived

PF1_BW = PF1_W/8
PF1_SIZE = PF1_BW*PF1_H*PF1_BPLS
PF1_BPL = PF1_BW
PF1_MOD = PF1_BW*(PF1_BPLS-1)

PF2_BW = PF2_W/8
PF2_SIZE = PF2_BW*PF2_H*PF2_BPLS
PF2_BPL = PF2_BW*PF2_H
PF2_MOD = PF2_BW-DIW_BW

DIW_BW = DIW_W/8
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
		lea	PF1_BPL(a0),a0
		move.l	a0,bpl2pt(a6)
		lea	PF1_BPL(a0),a0
		move.l	a0,bpl4pt(a6)

		; pf2
		lea	Bg+L_PAD/8,a2
		move.l	a2,bpl1pt(a6)
		lea	PF2_BPL(a2),a2
		move.l	a2,bpl3pt(a6)

		move.l	ViewBufferB(pc),a0
		add.l	#PF2_BW*TOP_PAD+L_PAD/8,a0
		move.l	a0,bpl5pt(a6)

		rts

********************************************************************************
Dude_Effect:
********************************************************************************
		jsr	ResetFrameCounter
		jsr	Free
		lea	BlankCop,a0
		sub.l	a1,a1
		jsr	StartEffect

		move.l	#PF1_SIZE,d0
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
		movem.l	DrawBuffer(pc),a0-a3
		exg	a0,a1
		exg	a2,a3
		movem.l	a0-a3,DrawBuffer

		bsr	DrawDude

; Clear
		move.l	DrawBufferB(pc),a0
		WAIT_BLIT
		move.l	a0,bltdpt(a6)
		move.l	#$01000000,bltcon0(a6)
		clr.w	bltdmod(a6)
		move.w	#255<<6!(PF2_BW/2),bltsize(a6)

		bsr	InitDrawLine

		move.l	CurrFrame,d0
		neg.w	d0
		move.w	d0,a2
		add.w	#50,a2
		lea	Text,a3
		lea	XGrid,a4
		lea	FontTable-65*4,a5
		bsr	DrawWord

; Fill top
		move.l	DrawBufferB(pc),a0
		add.l	#PF2_BW*(FILL_HEIGHT+TOP_PAD)-1,a0
		WAIT_BLIT
		move.l	a0,bltapt(a6)
		move.l	a0,bltdpt(a6)
		move.l	#$09f0001a,bltcon0(a6)
		move.w	#0,bltamod(a6)
		move.w	#0,bltdmod(a6)
		move.w	#FILL_HEIGHT<<6!(PF2_BW/2),bltsize(a6)

; Lines
		bsr	InitDrawLine
		move.l	DrawBufferB(pc),a0
		move.l	CurrFrame,d0
		neg.w	d0
		and.w	#$ff,d0
		add.w	d0,d0
		lea	XGrid,a1
		move.w	(a1,d0.w),d0

		move.w	d0,d3
		add.w	d3,d3
		lea	LineTop,a1
		move.w	(a1,d3.w),d1
		move.l	d0,d2
		lea	LineBottom,a1
		move.w	(a1,d3.w),d3
		bsr	DrawLineBlit

		jsr	WaitEOF
		cmp.l	#DUDE_END_FRAME,CurrFrame
		blt	Frame

		rts


********************************************************************************
InitDrawLine:
; Prepare common blit regs for line draw
;-------------------------------------------------------------------------------
		WAIT_BLIT
		move.w	#PF2_BW,bltcmod(a6)
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
		sub.w	d0,d2		; d2 = dx = x1 - x2
		bmi.b	.oct2345	; nagative? octant could be 2,3,4,5
		sub.w	d1,d3		; d3 = dy = y1 - y2
		bmi.b	.oct01		; negative? octant is 0 or 1
		cmp.w	d3,d2		; compare dy with dx
		bmi.b	.oct6		; dy > dx? octant 6!
		moveq	#$0011,d4	; select line + octant 7!
		bra.b	.doneOct

.oct6		exg	d2,d3		; ensure d2=dmax and d3=dmin
		moveq	#$0001,d4	; select line + octant 6
		bra.b	.doneOct

.oct2345
		neg.w	d2		; make dx positive
		sub.w	d1,d3		; d3 = dy = y1 - y2
		bmi.b	.oct23		; negative? octant is 2 or 3
		cmp.w	d3,d2		; compare dy with dx
		bmi.b	.oct5		; dy > dx? octant 5!
		moveq	#$0015,d4	; select line + octant 4
		bra.b	.doneOct

.oct5		exg	d2,d3		; ensure d2=dmax and d3=dmin
		moveq	#$0009,d4	; select line + octant 5
		bra.b	.doneOct

.oct23
		neg.w	d3		; make dy positive
		cmp.w	d3,d2		; compare dy with dx
		bmi.b	.oct2		; dy > dx? octant 2!
		moveq	#$001d,d4	; select line + octant 3
		bra.b	.doneOct

.oct2		exg	d2,d3		; ensure d2=dmax and d3=dmin
		moveq	#$000d,d4	; select line + octant 2
		bra.b	.doneOct

.oct01
		neg.w	d3		; make dy positive
		cmp.w	d3,d2		; compare dy with dx
		bmi.b	.oct1		; dy > dx? octant 1!
		moveq	#$0019,d4	; select line + octant 0
		bra.b	.doneOct

.oct1		exg	d2,d3		; ensure d2=dmax and d3=dmin
		moveq	#$0005,d4	; select line + octant 1

.doneOct
		add.w	d2,d2		; d2 = 2 * dmax
		asl.w	#2,d3		; d3 = 4 * dmin

		move.l	a0,a5		; aptr bitplane to draw on

		add.w	d1,d1		; convert y1 pos into offset
		ext.l	d1
		move.w	.screenMuls(pc,d1.w),d1

		add.l	d1,a5		; add ofset to bitplane pointer
		ext.l	d0		; clear top bits of d0
		ror.l	#4,d0		; roll shift bits to top word
		add.w	d0,d0		; bottom word: convert to byte offset
		adda.w	d0,a5		; add byte offset to bitplane pointer
		swap	d0		; move shift value to bottom word
		or.w	#$0bca,d0	; usea, c and d. minterm $ca, d=a/c+/ac

		move.w	d2,d1		; d1 = 2 * dmax
		lsl.w	#5,d1		; shift dmax to hx pos for bltsize
		add.w	#$0042,d1	; add 1 to hx and set wx to 2

		WAIT_BLIT

		move.l	a5,bltcpt(a6)	; source c = bitplane to draw on
		move.l	a5,bltdpt(a6)	; destination = bitplane to draw on
		move.w	d0,bltcon0(a6)	; source a shift and logic function
		move.w	d3,bltbmod(a6)	; set 4 * dmin

		sub.w	d2,d3		; d3 = (2 * dmax)-(4 * dmin)
		ext.l	d3		; make full long sized
		move.l	d3,bltapt(a6)	; store in a pointer
		bpl.b	.notneg		; skip if positive
		or.w	#$0040,d4	; set sign bit if negative
.notneg
		move.w	d4,bltcon1(a6)	; octant selection, sign and line
		sub.w	d2,d3		; d2 = (2*dmax), d3 = (2*dmax)-(4*dmin)
		move.w	d3,bltamod(a6)	; d3 = 4 * (dmax - dmin)
		move.w	d1,bltsize(a6)	; set length and start the blitter
		rts

; TODO: precalc
; Multiplication LUT for screen byte width
.screenMuls:
		rept	PF2_H
		dc.w	PF2_BW*REPTN
		endr


********************************************************************************
DrawLineBlit:
; Draw a line for filling using the blitter
; Based on TEC, but with muls LUT
;-------------------------------------------------------------------------------
; d0.w - x1
; d1.w - y1
; d2.w - x2
; d3.w - y2
; a0 - Draw buffer
; a6 - Custom
;-------------------------------------------------------------------------------
		cmp.w	d1,d3
		bgt.s	.l0
		beq.s	.done
		exg	d0,d2
		exg	d1,d3
.l0		moveq	#0,d4
		move.w	d1,d4
		add.w	d4,d4
		move.w	ScreenMuls(pc,d4.w),d4
		move.w	d0,d5
		add.l	a0,d4
		asr.w	#3,d5
		ext.l	d5
		add.l	d5,d4		; fix - was word but needs to be long for high screen addresses
		moveq	#0,d5
		sub.w	d1,d3
		sub.w	d0,d2
		bpl.s	.l1
		moveq	#1,d5
		neg.w	d2
.l1		move.w	d3,d1
		add.w	d1,d1
		cmp.w	d2,d1
		dbhi	d3,.l2
.l2		move.w	d3,d1
		sub.w	d2,d1
		bpl.s	.l3
		exg	d2,d3
.l3		addx.w	d5,d5
		add.w	d2,d2
		move.w	d2,d1
		sub.w	d3,d2
		addx.w	d5,d5
		and.w	#15,d0
		ror.w	#4,d0
		or.w	#$a4a,d0
		WAIT_BLIT
		move.w	d2,bltaptl(a6)
		sub.w	d3,d2
		lsl.w	#6,d3
		addq.w	#2,d3
		move.w	d0,bltcon0(a6)
		move.b	.oct(pc,d5.w),bltcon1+1(a6)
		move.l	d4,bltcpt(a6)
		move.l	d4,bltdpt(a6)
		movem.w	d1/d2,bltbmod(a6)
		move.w	d3,bltsize(a6)
.done		rts
.oct		dc.b	3,3+64,19,19+64,11,11+64,23,23+64

; TODO: combine
; Multiplication LUT for screen byte width
ScreenMuls:
		rept	PF2_H
		dc.w	PF2_BW*REPTN
		endr


********************************************************************************
ClearScreen:
		WAIT_BLIT
		move.l	a0,bltdpt(a6)
		move.l	#$01000000,bltcon0(a6)
		clr.l	bltdmod(a6)
		move.w	#(PF1_H*3)<<6!(PF1_BW/2),bltsize(a6)
		rts

********************************************************************************
DrawDude:
		move.l	CurrFrame,d0
		lsr	#2,d0
		and.w	#$f,d0
		move.w	d0,d1
		mulu	#DUDE_BW*DUDE_H*3,d0

		add.w	d1,d1
		lea	Offsets,a1
		move.b	1(a1,d1),d2	; y
		move.b	(a1,d1),d1	; x
		ext.w	d2
		add.w	#DUDE_Y,d2
		mulu	#PF1_BW*PF1_BPLS,d2
		add.l	#4,d2
		ror.w	#4,d1

		WAIT_BLIT
		move.l	DrawBuffer(pc),a1
		add.l	d2,a1
		lea	Anim,a0
		add.l	d0,a0
		or.w	#$09f0,d1
		move.w	d1,bltcon0(a6)
		move.w	#0,bltcon1(a6)
		move.l	#-1,bltafwm(a6)
		clr.w	bltamod(a6)
		move.w	#PF1_BW-DUDE_BW,bltdmod(a6)
		move.l	a0,bltapt(a6)
		move.l	a1,bltdpt(a6)
		move.w	#((DUDE_H+1)*PF1_BPLS<<6)!(DUDE_BW/2),bltsize(a6)
.skip		rts

********************************************************************************
; a0 = draw buffer
; a1 = glyph
; a2.w = x offset
; a3 = text data
; a4 = x grid
; a5 = font table
********************************************************************************
DrawWord:
.char
		moveq	#0,d0
		move.b	(a3)+,d0
		beq	.done
		lsl	#2,d0
		move.l	(a5,d0.w),a1
		bsr	DrawChar
		bra	.char
.done		rts

Text:
		dc.b	"MELON",0
		even

********************************************************************************
; a0 = draw buffer
; a1 = glyph
; a2.w = x offset
; a4 = xgrid
********************************************************************************
DrawChar:
		moveq	#0,d5
		moveq	#0,d6
		moveq	#0,d7
		move.b	(a1)+,d5	; width
		move.w	d5,Width	; d5 gets trashed by line draw
		move.w	a2,d0
		ble	.skipChar
		cmp.w	#XGRID_SIZE-30,d0
		bge	.skipChar
		move.b	(a1)+,d7	; path count
.path
		moveq	#-1,d0
		move.b	(a1)+,d6	; point count
		and.w	#$ff,d6
.pt
		move.b	(a1)+,d2
		and.w	#$ff,d2
		move.b	(a1)+,d3
		and.w	#$ff,d3
		add.w	a2,d2

		; perspective transform:
		lea	XGrid,a4
		add.w	d2,d2
		move.w	(a4,d2.w),d2
		move.w	d2,d5
		add.w	d5,d5
		lea	TextMul,a4
		mulu	(a4,d5.w),d3	; TODO: make this a table
		add.l	d3,d3
		swap	d3
		lea	TextTop,a4
		add.w	(a4,d5.w),d3

		movem.w	d2-d3,-(sp)
		cmp.w	#-1,d0
		beq	.skipBlit
		bsr	DrawLineBlit
.skipBlit
		movem.w	(sp)+,d0-d1
		dbf	d6,.pt
		dbf	d7,.path
.skipChar	add.w	Width(pc),a2
		rts

Width:		dc.w	0


********************************************************************************
Vars:
********************************************************************************

DrawBuffer	dc.l	0
ViewBuffer	dc.l	0
DrawBufferB	dc.l	BlankBpl
ViewBufferB	dc.l	BlankBpl2

********************************************************************************
Data:
********************************************************************************

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

		include	data/persp.i
		include	data/font.i


********************************************************************************
		data_c
********************************************************************************

Cop:
		dc.w	diwstrt,DIW_STRT
		dc.w	diwstop,DIW_STOP
		dc.w	ddfstrt,DDF_STRT
		dc.w	ddfstop,DDF_STOP
		dc.w	bpl1mod,PF1_MOD
		dc.w	bpl2mod,PF2_MOD
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
		dc.w	bpl1mod,-PF1_BW
		incbin	data/dude_walking.COP
		COP_WAITH 0,$e0
		dc.w	bpl1mod,PF1_MOD
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
		dc.w	bpl1mod,-PF1_BW
		incbin	data/dude_walking.COP
		COP_WAITH $80,$e0
		dc.w	bpl1mod,PF1_MOD
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
		ds.b	DUDE_BW*PF1_BPLS

Bg:
		incbin	data/dude-bg.BPL


********************************************************************************
		bss_c
********************************************************************************

		ds.b	PF2_BW*TOP_PAD
BlankBpl:	ds.b	PF2_SIZE
		ds.b	PF2_BW*TOP_PAD
BlankBpl2:	ds.b	PF2_SIZE

