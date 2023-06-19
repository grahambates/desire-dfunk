		include	src/_main.i
		include	girl.i

GIRL_END_FRAME = $200

HEAD_W = 160
HEAD_H = 159
HEAD_BW = HEAD_W/8

BODY_W = 192
BODY_H = 51
BODY_BW = BODY_W/8

CRED_H = 33
CRED_1_W = 160
CRED_2_W = 80
CRED_3_W = 144

DIW_W = 320
DIW_H = 256
SCREEN_W = DIW_W
SCREEN_H = DIW_H*2
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
Script:
		dc.l	0,CmdLerpWord,0,8,YPos
		dc.l	GIRL_END_FRAME-(1<<3),CmdLerpWord,100,3,YPos
		dc.l	0,0


********************************************************************************
Girl_Vbi:
********************************************************************************
		move.l	ViewBuffer(pc),a0

		; pf1
		move.l	a0,bpl0pt(a6)
		lea	SCREEN_BPL(a0),a0
		move.l	a0,bpl2pt(a6)
		lea	SCREEN_BPL(a0),a0
		move.l	a0,bpl4pt(a6)

		; pf1
		move.l	CredScreen,a1
		move.l	a1,bpl1pt(a6)
		add.l	#SCREEN_BW,a1
		move.l	a1,bpl3pt(a6)
		rts


********************************************************************************
Girl_Effect:
********************************************************************************
		jsr	ResetFrameCounter
		jsr	Free

		lea	Script,a0
		jsr	Commander_Init

		move.l	#SCREEN_SIZE,d0
		jsr	AllocChip
		move.l	a0,DrawBuffer
		bsr	ClearScreen

		jsr	AllocChip
		move.l	a0,ViewBuffer
		bsr	ClearScreen

		move.l	#SCREEN_BW*SCREEN_H,d0
		jsr	AllocChip
		move.l	a0,CredScreen

		lea	Cop,a0
		lea	Girl_Vbi,a1
		jsr	StartEffect

;-------------------------------------------------------------------------------
Frame:
		movem.l	DrawBuffer(pc),a0-a1
		exg	a0,a1
		movem.l	a0-a1,DrawBuffer

		; Just clear needed area
		; WAIT_BLIT
		; move.l a0,a1
		; add.l 	#SCREEN_BW*BPLS*(70+HEAD_H-CC_H)+2,a1
		; move.l	a1,bltdpt(a6)
		; move.l	#$01000000,bltcon0(a6)
		; move.w	#SCREEN_BW-HEAD_BW,bltdmod(a6)
		; move.w	#(CC_H*BPLS)<<6!(HEAD_BW/2),bltsize(a6)

		bsr	ClearScreen

		cmp.l	#$80,CurrFrame
		ble	.noCred3
		bsr	BlitCred3
.noCred3
		cmp.l	#$100,CurrFrame
		ble	.noCred2
		bsr	BlitCred2
.noCred2
		cmp.l	#$180,CurrFrame
		ble	.noCred1
		bsr	BlitCred1
.noCred1

		; Shoulders pos
		move.l	DrawBuffer,a0
		lea	Cos,a4
		move.w	VBlank+2,d1
		lsl.w	#5,d1
		and.w	#$7fe,d1
		move.w	(a4,d1.w),d1
		ext.l	d1
		lsl.l	#5,d1
		swap	d1
		neg.w	d1

		move.w	#0,d2		; y2

		tst.w	d1
		bge	.pos
		neg.w	d1
		exg	d1,d2
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

		move.w	YPos(pc),d1
		add.w	#70,d1
		move.l	DrawBuffer(pc),a0
		bsr	BlitHead

		jsr	WaitEOF
		move.w	#DMAF_BLITHOG,dmacon(a6) ; unhog the blitter
		cmp.l	#GIRL_END_FRAME,CurrFrame
		blt	Frame

		rts

********************************************************************************
ClearScreen:
		WAIT_BLIT
		move.l	a0,bltdpt(a6)
		move.l	#$01000000,bltcon0(a6)
		clr.l	bltdmod(a6)
		move.w	#(DIW_H*BPLS)<<6!(SCREEN_BW/2),bltsize(a6)
		rts

********************************************************************************
; Blit head to screen
;-------------------------------------------------------------------------------
; a0 = screen
; d0.w = x
; d1.w = y
BlitHead:
		lea	Head,a1
		lea	HEAD_BW(a1),a2	; mask
; y offset
		mulu	#SCREEN_BW*BPLS,d1
		add.w	d1,a0
; x offset
		moveq	#$f,d1		; 0-15 shift
		and.w	d0,d1
		lsl	#2,d1		; offset for bltcon table
		lsr.w	#3,d0		; byte offset
		add.w	d0,a0
		move.w	#DMAF_SETCLR!DMAF_BLITHOG,dmacon(a6) ; hog the blitter
		WAIT_BLIT
		move.l	.bltcon(pc,d1.w),bltcon0(a6)
		move.l	#(SCREEN_BW-HEAD_BW)<<16!HEAD_BW,bltcmod(a6)
		move.l	#HEAD_BW<<16!(SCREEN_BW-HEAD_BW),bltamod(a6)
CC_H = 40
		move.l	a1,bltapth(a6)
		move.l	a0,bltdpth(a6)
		move.w	#((HEAD_H-CC_H)*BPLS)<<6!(HEAD_BW/2),bltsize(a6)
		WAIT_BLIT
		add.l	#(HEAD_H-CC_H)*BPLS*SCREEN_BW,a0
		add.l	#(HEAD_H-CC_H)*BPLS*HEAD_BW*2,a1
		add.l	#(HEAD_H-CC_H)*BPLS*HEAD_BW*2,a2
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
.bltconb:	dc.l	$0fca0000,$1fca1000,$2fca2000,$3fca3000
		dc.l	$4fca4000,$5fca5000,$6fca6000,$7fca7000
		dc.l	$8fca8000,$9fca9000,$afcaa000,$bfcab000
		dc.l	$cfcac000,$dfcad000,$efcae000,$ffcaf000


BlitCred3:
		WAIT_BLIT
		move.l	CredScreen(pc),a1
		add.w	#SCREEN_BW*25+2,a1
		lea	Cred3,a0
		move.l	#$09f00000,bltcon0(a6)
		move.l	#-1,bltafwm(a6)
		clr.w	bltamod(a6)
		move.w	#SCREEN_BW-CRED_3_W/8,bltdmod(a6)
		move.l	a0,bltapt(a6)
		move.l	a1,bltdpt(a6)
		move.w	#(CRED_H<<6)!(CRED_3_W/16),bltsize(a6)
		rts

BlitCred1:
		WAIT_BLIT
		move.l	CredScreen(pc),a1
		add.w	#SCREEN_BW*90+20,a1
		lea	Cred1,a0
		move.l	#$09f00000,bltcon0(a6)
		move.l	#-1,bltafwm(a6)
		clr.w	bltamod(a6)
		move.w	#SCREEN_BW-CRED_1_W/8,bltdmod(a6)
		move.l	a0,bltapt(a6)
		move.l	a1,bltdpt(a6)
		move.w	#(CRED_H<<6)!(CRED_1_W/16),bltsize(a6)
		rts

BlitCred2:
		WAIT_BLIT
		move.l	CredScreen(pc),a1
		add.w	#SCREEN_BW*170+28,a1
		lea	Cred2,a0
		move.l	#$09f00000,bltcon0(a6)
		move.l	#-1,bltafwm(a6)
		clr.w	bltamod(a6)
		move.w	#SCREEN_BW-CRED_2_W/8,bltdmod(a6)
		move.l	a0,bltapt(a6)
		move.l	a1,bltdpt(a6)
		move.w	#(CRED_H<<6)!(CRED_2_W/16),bltsize(a6)
		rts


********************************************************************************
; Blit head to screen
;-------------------------------------------------------------------------------
; a0 = screen
; d1.w = y1
; d2.w = y2
BlitBody:
		move.w	#DIW_H-BODY_H,d3
		add.w	YPos(pc),d3
		muls	#SCREEN_BW*BPLS,d3
		add.l	d3,a0
		lea	Body,a1

		WAIT_BLIT
		move.l	#$09f00000,bltcon0(a6)
		move.w	#BODY_BW-2,bltamod(a6)
		move.w	#(SCREEN_BW-2),bltdmod(a6)

		move.w	#2,d5		; byte increment - controls direction
DX = BODY_W/16-1
		move.w	d2,d3		; dy
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
		add.w	#SCREEN_BW*BPLS,d1 ; y = y + 1 (pre multiplied)
		sub.w	#DX*2,d4	; D = D - 2*dx
.noInc
		; D = D + 2*dy
		add.w	d3,d4
		add.w	d3,d4
		dbf	d7,.l
		rts

********************************************************************************
Vars:
********************************************************************************

YPos:		dc.w	25
DrawBuffer:	dc.l	0
ViewBuffer:	dc.l	0
CredScreen:	dc.l	0


********************************************************************************
		data_c
********************************************************************************

ChipData:

Cop:
		dc.w	diwstrt,DIW_STRT
		dc.w	diwstop,DIW_STOP
		dc.w	ddfstrt,DDF_STRT
		dc.w	ddfstop,DDF_STOP
		dc.w	bpl1mod,DIW_MOD
		dc.w	bpl2mod,0
		dc.w	bplcon0,(BPLS+2)<<12!$200!(1<<10)
		dc.w	color00,$90c
		dc.w	color01,$323
		dc.w	color02,$eca
		dc.w	color03,$666
		dc.w	color09,$000
		dc.w	color10,$fff
		dc.w	color11,$fff
		dc.l	-2
; Images
Head:		incbin	data/girl-head.BPL
Body:		incbin	data/girl-body.BPL
Cred1:		incbin	data/credit-gigabates.BPL
Cred2:		incbin	data/credit-maze.BPL
Cred3:		incbin	data/credit-steffest.BPL

		printt	"Girl:ChipData"
		printv	*-ChipData
