		include	src/_main.i
		include	dude.i

DUDE_END_FRAME = $200

DUDE_W = 96
DUDE_BW = DUDE_W/8
DUDE_H = 150/2
DUDE_Y = 50

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
		lea	SCREEN_BPL(a2),a2
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
		add.l	#2,d2
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

		jsr	WaitEOF
		cmp.l	#DUDE_END_FRAME,CurrFrame
		blt	Frame

		rts


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
		dc.w	color08,$123
		dc.w	color09,$212
		dc.w	color11,$426
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
		COP_SKIPV DUDE_Y+DIW_YSTRT+DUDE_H*2
		dc.w	copjmp2,0

		dc.l	-2

Anim:
		incbin	data/dude_walking.BPL

Bg:
		incbin	data/dude-bg.BPL

		bss_c


BlankBpl:	ds.b	SCREEN_SIZE
