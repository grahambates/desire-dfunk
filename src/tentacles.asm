		incdir	src
		include	_main.i
		include	zcircles.i
		include	tentacles.i

TENTACLES_END_FRAME = 32*32

OUTER_COUNT = 7
INNER_COUNT = 7
INNER_SHIFT = 4

; Display window:
DIW_W = 320
DIW_H = 256
BPLS = 4
SCROLL = 1							; enable playfield scroll?
INTERLEAVED = 0
DPF = 0								; enable dual playfield?

; Screen buffer:
SCREEN_W = DIW_W+32
SCREEN_H = DIW_H

;-------------------------------------------------------------------------------
; Derived

COLORS = 1<<BPLS
SCREEN_BW = SCREEN_W/16*2					; byte-width of 1 bitplane line
		ifne	INTERLEAVED
SCREEN_MOD = SCREEN_BW*(BPLS-1)					; modulo (interleaved)
SCREEN_BPL = SCREEN_BW						; bitplane offset (interleaved)
		else
SCREEN_MOD = 0							; modulo (non-interleaved)
SCREEN_BPL = SCREEN_BW*SCREEN_H					; bitplane offset (non-interleaved)
		endc
SCREEN_SIZE = SCREEN_BW*SCREEN_H*BPLS				; byte size of screen buffer
DIW_BW = DIW_W/16*2
DIW_MOD = SCREEN_BW-DIW_BW+SCREEN_MOD-SCROLL*2
DIW_SIZE = DIW_BW*DIW_H*BPLS
DIW_XSTRT = ($242-DIW_W)/2
DIW_YSTRT = ($158-DIW_H)/2
DIW_XSTOP = DIW_XSTRT+DIW_W
DIW_YSTOP = DIW_YSTRT+DIW_H
DIW_STRT = (DIW_YSTRT<<8)!DIW_XSTRT
DIW_STOP = ((DIW_YSTOP-256)<<8)!(DIW_XSTOP-256)
DDF_STRT = ((DIW_XSTRT-17)>>1)&$00fc-SCROLL*8
DDF_STOP = ((DIW_XSTRT-17+(((DIW_W>>4)-1)<<4))>>1)&$00fc

Fade		dc.w	0

Tentacles_Effect:
		lea	Cop,a0
		jsr	InstallCopper

		; Allocate screen memory
		move.l	4.w,a6
		move.l	#SCREEN_BW*BPLS*SCREEN_H*2,d0
		moveq	#MEMF_CHIP,d1
		jsr	_LVOAllocMem(a6)
		move.l	d0,Screen

		; Sprites

		lea	CopSprPt+2,a0
		lea	Sprite,a1
		move.l	a1,a2

		moveq #4-1,d7
.sprSlice:
		move.w	(a1)+,d0
		lea	(a2,d0.w),a3
		move.w	a3,4(a0)
		move.l	a3,d1
		swap	d1
		move.w	d1,(a0)
		lea	8(a0),a0
		dbf	d7,.sprSlice

		move.l	#NullSprite,d1
		move.w	d0,d1
		swap	d0
		moveq	#8-4-1,d7
.spr
		move.w	d0,(a0)
		move.w	d1,4(a0)
		lea	8(a0),a0
		dbf	d7,.spr

		lea	custom,a6

		move.w	#$357,color17(a6)
		move.w	#$fff,color18(a6)
		move.w	#$00f,color19(a6)
		move.w	#$357,color21(a6)
		move.w	#$fff,color22(a6)
		move.w	#$00f,color23(a6)

Frame:
		; Horizontal scroll position frame frame count
		move.l	VBlank,d0

; Fade in
		cmp.w	#64,d0
		bgt	.noFadeIn
		lea	PalStart,a0
		lea	Pal,a1
		lea	PalOut,a2
		lsl	#8,d0
		add.w	d0,d0
		moveq	#COLORS-1,d1
		jsr	LerpPal
		bra	.loadPal
.noFadeIn

; Fade out
		cmp.w	#TENTACLES_END_FRAME-64,d0
		blt	.endFade
		lea	Pal,a0
		lea	PalStart,a1
		lea	PalOut,a2
		sub.w	#TENTACLES_END_FRAME-64,d0
		lsl	#8,d0
		add.w	d0,d0
		moveq	#COLORS-1,d1
		jsr	LerpPal

.loadPal
		lea	PalOut,a0
		lea	color00(a6),a1
		moveq	#16-1,d7
.col		move.w	(a0)+,(a1)+
		dbf	d7,.col
.endFade

		move.l	VBlank,d6

		moveq	#15,d0					; last 4 bits go in bplcon1 and save later for adjustment
		and.w	d6,d0
		not.w	d0
		move.w	d0,Scroll
		; lower/upper bits for pf1/pf2 bplcon1
		and.w	#15,d0
		move.w	d0,d1
		lsl.w	#4,d0
		add.w	d1,d0
		move.w	d0,CopScroll+2				; write to copper
		; word value added to bpl address
		lsr.w	#4,d6
		add.w	d6,d6
		move.l	Screen,a1
		lea	(a1,d6.w),a1

		lea	CopBplPt+2,a0
		move.l	a1,a2
		moveq	#BPLS-1,d7
.l
		move.w	a2,4(a0)
		move.l	a2,d0
		swap	d0
		move.w	d0,(a0)
		lea	8(a0),a0
		lea	SCREEN_BPL(a2),a2
		dbf	d7,.l

; Wait for VBL before updating bpl pointers in copper
		DebugStartIdle
		jsr	WaitEOF
		DebugStopIdle

; Clear word on right of buffer to stop data looping back round:
		lea	SCREEN_BW-2(a1),a2
		WAIT_BLIT
		move.l	#-1,bltafwm(a6)
		move.w	#SCREEN_BW-2,bltdmod(a6)
		move.l	a2,bltdpt(a6)
		move.l	#$1000000,bltcon0(a6)
		move.w	#(SCREEN_H*(BPLS-1))<<6!1,bltsize(a6)
		WAIT_BLIT
		move.w	#(SCREEN_H)<<6!1,bltsize(a6)

		; Offset a1 to center/right of screen:
		add.w	#28+SCREEN_BW*128,a1

; Scale value from sum of sines:
		move.w	VBlank+2,d6
		add.w	#$130,d6

		lsl.w	#2,d6
		lea	Sin,a3

		move.w	d6,d4
		and.w	#$7fe,d4
		move.w	(a3,d4.w),d0

		move.w	d6,d4
		add.w	d6,d4
		add.w	d6,d4
		and.w	#$7fe,d4
		add.w	(a3,d4.w),d0

		ext.l	d0
		divs	#150,d0
		add.w	#$f0,d0					; min scale
		move.w	d0,Scale

; d6 = outer start angle
		and.w	#$7fe,d6
		move.w	(a3,d6.w),d6
		asr.w	#5,d6

; Outer rotation:
		; move.w	VBlank+2,d7
		; lsr.w	#7,d7
		; cmp.w #OUTER_COUNT-1,d7
		; ble .l0

		moveq	#OUTER_COUNT-1,d7
.l0
		; x = sin(a)
		move.w	d6,d4
		and.w	#$7fe,d4
		move.w	(a3,d4.w),d0
		asr	d0					; / 2 for pERsPECtIve

		; y = cos(a)
		add.w	#$1fe,d4
		and.w	#$7fe,d4
		move.w	(a3,d4.w),d1

; d4 = inner start angle
		move.w	VBlank+2,d4
		lsl.w	#4,d4

; Inner rotation:
		moveq	#INNER_COUNT-1,d5
.l1
		movem.w	d0-d7,-(sp)

		; x += sin(a1)
		and.w	#$7fe,d4
		move.w	(a3,d4.w),d2
		asr.w	#INNER_SHIFT,d2
		add.w	d2,d0					; d0 = x
		muls	Scale,d0
		swap	d0
		sub.w	Scroll,d0				; adjust for hscroll in bplcon1

		; y += cos(a1)
		add.w	#$1fe,d4
		and.w	#$7fe,d4
		move.w	(a3,d4.w),d2
		asr.w	#INNER_SHIFT,d2
		add.w	d2,d1					; d1 = y
		muls	Scale,d1
		swap	d1

		move.w	Scale,d2				; d2 = radius
		lsr.w	#6,d2
		move.w	d5,d3					; d3 = color
		; add.w d7,d3
		addq	#1,d3
		jsr	BlitCircleUnsafe
		movem.w	(sp)+,d0-d7

		; Increment angles 360 deg / count

		add.w	#($400/INNER_COUNT)*2,d4
		dbf	d5,.l1

		add.w	#($400/OUTER_COUNT)*2,d6
		dbf	d7,.l0

		cmp.l	#TENTACLES_END_FRAME,VBlank
		blt	Frame

		move.w #DMAF_SPRITE,dmacon(a6)

		; Free screen memory
		move.l	4.w,a6
		move.l	#SCREEN_BW*BPLS*SCREEN_H*2,d0
		move.l	Screen(pc),a1
		jsr	_LVOFreeMem(a6)

		lea	custom,a6

		rts


********************************************************************************
; Draw a circle using blitter
;-------------------------------------------------------------------------------
; d0.w - x
; d1.w - y
; d2.w - r
; d3.l - colour (bpl offset)
; a1 - dest bpl (centered)
;-------------------------------------------------------------------------------
BlitCircleUnsafe:
; Subract radius from coords to center
		sub.w	d2,d1
		sub.w	d2,d0
; Get blit params for radius:
		move.w	d2,d4
		subq	#1,d4
; mulu	#Blit_SIZEOF,d4
		lsl.w	#3,d4					; optimise
		ext.l	d4
		lea	BltCircSizes,a0
		lea	(a0,d4.w),a0
		movem.w	Blit_Mod(a0),d6/a4
		move.l	Blit_Adr(a0),a0

; Lookup bltcon value for x shift
		moveq	#15,d4
		and.w	d0,d4
; Offset dest for x/y/color
		muls	#SCREEN_BW,d1				; d1 = yOffset (bytes)
		asr.w	#3,d0					; d0 = xOffset (bytes)
		add.w	d0,d1					; d1 = totalOffset = yOffset + xOffset
		move.l	a1,d5					; d5 = dest pointer with offset
		ext.l	d1
		add.l	d1,d5

		WAIT_BLIT
		move.l	d6,bltamod(a6)
		move.w	d6,bltcmod(a6)
		lsl.w	#2,d4					; d4 = offset into bltcon table
		move.l	.bltcon(pc,d4),d4			; d4 = BLTCON0/1

		bra	.s
		; Table for combined minterm and shifts for bltcon0/bltcon1
.bltcon:	dc.l	$0bfa0000,$1bfa1000,$2bfa2000,$3bfa3000
		dc.l	$4bfa4000,$5bfa5000,$6bfa6000,$7bfa7000
		dc.l	$8bfa8000,$9bfa9000,$abfaa000,$bbfab000
		dc.l	$cbfac000,$dbfad000,$ebfae000,$fbfaf000
.s

; Fill/clear each bpl to create color (not interleaved)
		moveq	#BPLS-2,d0
.bpl
		move.l	d4,d6					; d6 = BLTCON0/1
; change bltcon0 to clear inside shape if bit not set in colour value
		btst	d0,d3
		bne	.fill
		and.l	#$ff0fffff,d6
.fill		WAIT_BLIT
		move.l	d6,bltcon0(a6)
		move.l	d5,bltcpt(a6)
		move.l	a0,bltapt(a6)
		move.l	d5,bltdpt(a6)
		move.w	a4,bltsize(a6)
		add.l	#SCREEN_BPL,d5
		dbf	d0,.bpl

		WAIT_BLIT
		move.l	d4,d6
		and.l	#$ff0fffff,d6
		move.l	d6,bltcon0(a6)
		move.l	d5,bltcpt(a6)
		move.l	a0,bltapt(a6)
		move.l	d5,bltdpt(a6)
		move.w	a4,bltsize(a6)

; Get blit params for radius:
		subq	#2,d2
		ble	.nope
		subq	#1,d2
; mulu	#Blit_SIZEOF,d2
		lsl.w	#3,d2					; optimise
		ext.l	d2
		lea	BltCircSizes,a0
		lea	(a0,d2.w),a0
		movem.w	Blit_Mod(a0),d6/a4
		move.l	Blit_Adr(a0),a0

		WAIT_BLIT
		move.l	d4,bltcon0(a6)

		move.l	d6,bltamod(a6)
		move.w	d6,bltcmod(a6)
		move.l	d5,bltcpt(a6)
		move.l	a0,bltapt(a6)
		move.l	d5,bltdpt(a6)
		move.w	a4,bltsize(a6)

.nope		rts


Scale:		dc.w	$100
Scroll:		dc.w	0
Pal:
		dc.w	$123,$f06,$f58,$f79,$f9a,$fbc,$ecd,$ded
		dc.w	$744,$f5b,$f7c,$f9d,$fbd,$fde,$fef,$fff

PalStart:
		dc.w	$123,$123,$123,$123,$123,$123,$123,$123
		dc.w	$123,$123,$123,$123,$123,$123,$123,$123

Screen:		dc.l	0


*******************************************************************************
		data_c
*******************************************************************************

Cop:
		dc.w	diwstrt,DIW_STRT
		dc.w	diwstop,DIW_STOP
		dc.w	ddfstrt,DDF_STRT
		dc.w	ddfstop,DDF_STOP
		dc.w	bpl1mod,DIW_MOD
		dc.w	bpl2mod,DIW_MOD
		dc.w	bplcon0,BPLS<<(12+DPF)!DPF<<10!$200
		dc.w	dmacon,DMAF_SETCLR!DMAF_SPRITE
CopBplPt:
		rept	BPLS
		dc.w	bpl0pt+REPTN*4,0
		dc.w	bpl0pt+REPTN*4+2,0
		endr
CopSprPt:
		rept	8
		dc.w	spr0pth+REPTN*4,0
		dc.w	spr0ptl+REPTN*4,0
		endr
CopScroll:	dc.w	bplcon1,0
		dc.l	-2

Sprite:
		incbin	"assets/foo.spr"

NullSprite:
		dc.l	0

*******************************************************************************
		bss
*******************************************************************************

PalOut:		ds.w	COLORS