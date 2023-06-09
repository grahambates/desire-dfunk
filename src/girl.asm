		include	src/_main.i
		include	girl.i

GIRL_END_FRAME = $3ff

DIW_W = 320
DIW_H = 256
SCREEN_W = DIW_W
SCREEN_H = DIW_H+12
BPLS = 3

;-------------------------------------------------------------------------------
; Derived
COLORS = 1<<BPLS
SCREEN_BW = SCREEN_W/8
SCREEN_SIZE = SCREEN_BW*SCREEN_H*BPLS
SCREEN_BPL = SCREEN_BW
DIW_BW = DIW_W/8
DIW_MOD = SCREEN_BW*(BPLS-1)
DIW_XSTRT = ($242-DIW_W)/2
DIW_YSTRT = ($158-DIW_H)/2
DIW_XSTOP = DIW_XSTRT+DIW_W
DIW_YSTOP = DIW_YSTRT+DIW_H
DIW_STRT = (DIW_YSTRT<<8)!DIW_XSTRT
DIW_STOP = ((DIW_YSTOP-256)<<8)!(DIW_XSTOP-256)
DDF_STRT = ((DIW_XSTRT-17)>>1)&$00fc
DDF_STOP = ((DIW_XSTRT-17+(((DIW_W>>4)-1)<<4))>>1)&$00fc

********************************************************************************
Girl_Vbi:
********************************************************************************
		move.l	ViewBuffer(pc),a0
		lea	bpl0pt+custom,a1
		rept	BPLS
		move.l	a0,(a1)+
		lea	SCREEN_BPL(a0),a0
		endr
		rts


********************************************************************************
Girl_Effect:
********************************************************************************
		jsr ResetFrameCounter
		jsr Free

		move.l	#SCREEN_SIZE,d0
		jsr	AllocChip
		move.l	a0,DrawBuffer
		bsr	ClearScreen

		jsr	AllocChip
		move.l	a0,ViewBuffer
		bsr	ClearScreen

		lea	Cop,a0
		lea	Girl_Vbi,a1
		jsr	StartEffect

;-------------------------------------------------------------------------------
Frame:
		movem.l	DrawBuffer(pc),a0-a1
		exg	a0,a1
		movem.l	a0-a1,DrawBuffer

		; Just clear needed area
		WAIT_BLIT
		move.l a0,a1
		add.l 	#SCREEN_BW*BPLS*(70+HEAD_H-CC_H)+2,a1
		move.l	a1,bltdpt(a6)
		move.l	#$01000000,bltcon0(a6)
		move.w	#SCREEN_BW-HEAD_BW,bltdmod(a6)
		move.w	#(CC_H*BPLS)<<6!(HEAD_BW/2),bltsize(a6)

		; Shoulders pos
		lea	Cos,a4
		move.w	VBlank+2,d1
		lsl.w	#5,d1
		and.w	#$7fe,d1
		move.w	(a4,d1.w),d1
		ext.l	d1
		lsl.l	#5,d1
		swap	d1
		neg.w d1

		move.w	#0,d2					; y2

		tst.w d1
		bge .pos
		neg.w d1
		exg d1,d2
.pos

		bsr	BlitBody

		; Head x pos
		lea	Cos,a4
		move.w	VBlank+2,d0
		lsl.w	#5,d0
		and.w	#$7fe,d0
		move.w	(a4,d0.w),d0
		ext.l	d0
		lsl.l	#4,d0
		swap	d0
		add.w	#25,d0

		move.w	#70,d1
		move.l	DrawBuffer(pc),a0
		bsr	BlitHead

		jsr	WaitEOF
		move.w	#DMAF_BLITHOG,dmacon(a6) ; unhog the blitter
		cmp.l	#GIRL_END_FRAME,CurrFrame
		blt	Frame

		rts

HEAD_W = 160
HEAD_H = 159
HEAD_BW = HEAD_W/8

BODY_W = 192
BODY_H = 51
BODY_BW = BODY_W/8

********************************************************************************
ClearScreen:
		WAIT_BLIT
		move.l	a0,bltdpt(a6)
		move.l	#$01000000,bltcon0(a6)
		clr.l	bltdmod(a6)
		move.w	#(SCREEN_H*BPLS)<<6!(SCREEN_BW/2),bltsize(a6)
		rts

********************************************************************************
; Blit head to screen
;-------------------------------------------------------------------------------
; a0 = screen
; d0.w = x
; d1.w = y
BlitHead:
		lea	Head,a1
		lea	HEAD_BW(a1),a2				; mask
; y offset
		mulu	#SCREEN_BW*BPLS,d1
		add.w	d1,a0
; x offset
		moveq	#$f,d1					; 0-15 shift
		and.w	d0,d1
		lsl	#2,d1					; offset for bltcon table
		lsr.w	#3,d0					; byte offset
		add.w	d0,a0
		move.w #DMAF_SETCLR!DMAF_BLITHOG,dmacon(a6) ; hog the blitter
		WAIT_BLIT
		move.l	.bltcon(pc,d1.w),bltcon0(a6)
		move.l	#(SCREEN_BW-HEAD_BW)<<16!HEAD_BW,bltcmod(a6)
		move.l	#HEAD_BW<<16!(SCREEN_BW-HEAD_BW),bltamod(a6)
		; movem.l	a0-a2,bltcpth(a6)

CC_H = 40
		move.l	a1,bltapth(a6)
		move.l	a0,bltdpth(a6)
		move.w	#((HEAD_H-CC_H)*BPLS)<<6!(HEAD_BW/2),bltsize(a6)
		WAIT_BLIT
		add.l #(HEAD_H-CC_H)*BPLS*SCREEN_BW,a0
		add.l #(HEAD_H-CC_H)*BPLS*HEAD_BW*2,a1
		add.l #(HEAD_H-CC_H)*BPLS*HEAD_BW*2,a2
		move.l	.bltconb(pc,d1.w),bltcon0(a6)
		movem.l	a0-a2,bltcpth(a6)
		move.l	a0,bltdpth(a6)
		move.w	#(40*BPLS)<<6!(HEAD_BW/2),bltsize(a6)
		rts

; Table for combined minterm and shifts for bltcon0/bltcon1
.bltcon:	dc.l	$09f00000,$19f01000,$29f02000,$39f03000
		dc.l	$49f04000,$59f05000,$69f06000,$79f07000
		dc.l	$89f08000,$99f09000,$a9f0a000,$b9f0b000
		dc.l	$c9f0c000,$d9f0d000,$e9f0e000,$f9f0f000

		; Table for combined minterm and shifts for bltcon0/bltcon1
.bltconb:	dc.l	$0fca0000,$1fca1000,$2fca2000,$3fca3000
		dc.l	$4fca4000,$5fca5000,$6fca6000,$7fca7000
		dc.l	$8fca8000,$9fca9000,$afcaa000,$bfcab000
		dc.l	$cfcac000,$dfcad000,$efcae000,$ffcaf000


********************************************************************************
; Blit head to screen
;-------------------------------------------------------------------------------
; a0 = screen
; d1.w = y1
; d2.w = y2
BlitBody:
		add.w	#(DIW_H-BODY_H)*SCREEN_BW*BPLS,a0	; fixed position
		lea	Body,a1

		WAIT_BLIT
		move.l	#$09f00000,bltcon0(a6)
		move.w	#BODY_BW-2,bltamod(a6)
		move.w	#(SCREEN_BW-2),bltdmod(a6)

		move.w	#2,d5					; byte increment - controls direction
DX = BODY_W/16-1
		move.w	d2,d3					; dy
		sub.w	d1,d3
		bge	.pos
		lea	DX*2(a1),a1
		lea	DX*2(a0),a0
		neg.w	d3
		neg.w	d5
		exg	d1,d2
.pos
		; D = 2*dy - dx
		move.w	d3,d4
		add.w	d4,d4
		sub.w	#DX,d4

		muls	#SCREEN_BW*BPLS,d1
		moveq	#12-1,d7
.l
		WAIT_BLIT
		lea	(a0,d1),a2
		move.l	a1,bltapth(a6)
		move.l	a2,bltdpth(a6)
		move.w	#(BODY_H*BPLS)<<6!1,bltsize(a6)
		add.w	d5,a0
		add.w	d5,a1
		; if D > 0
		tst.w	d4
		ble	.noInc
		add.w	#SCREEN_BW*BPLS,d1			; y = y + 1 (pre multiplied)
		sub.w	#DX*2,d4				; D = D - 2*dx
.noInc
		; D = D + 2*dy
		add.w	d3,d4
		add.w	d3,d4
		dbf	d7,.l
		rts

********************************************************************************
Vars:
********************************************************************************

DrawBuffer:	dc.l	0
ViewBuffer:	dc.l	0


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
		dc.w	color00,$90c
		dc.w	color01,$323
		dc.w	color02,$666
		dc.w	color03,$eca
		dc.l	-2

; Image
Head:
		incbin	data/girl-head.BPL
Body:
		incbin	data/girl-body.BPL
