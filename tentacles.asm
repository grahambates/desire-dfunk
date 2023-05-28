		include	_main.i
		include	tentacles.i

TENTACLES_END_FRAME = $7ff

OUTER_COUNT = 8
INNER_COUNT = 5

; Display window:
DIW_W = 320
DIW_H = 256
BPLS = 3
SCROLL = 1							; enable playfield scroll?
INTERLEAVED = 0
DPF = 0								; enable dual playfield?

; Screen buffer:
SCREEN_W = DIW_W+16
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


Tentacles_Effect:
		move.l	#Cop,cop1lc(a6)

; Load palette
		lea	Pal(pc),a0
		lea	color00(a6),a1
		moveq	#16-1,d7
.col		move.w	(a0)+,(a1)+
		dbf	d7,.col

Frame:
		move.l	VBlank,d6
		add.w	d6,d6
		moveq	#15,d0
		and.w	d6,d0
		not.w	d0
		move.w	d0,Scroll
		move.w	d0,d1
		lsl.w 	#4,d0
		add.w	d1,d0
		lea	CopScroll+2,a0
		move.w	d0,(a0)

		lsr.w	#4,d6
		add.w	d6,d6
		lea	Screen,a1
		lea	(a1,d6.w),a1

		DebugStartIdle
		jsr	WaitEOF
		DebugStopIdle

		lea	CopBplPt+2,a0
		move.l	a1,a2
		moveq #BPLS-1,d7
.l
		move.w	a2,4(a0)
		move.l	a2,d0
		swap	d0
		move.w	d0,(a0)
		lea 	8(a0),a0
		lea 	SCREEN_BPL(a2),a2
		dbf	d7,.l

; Clear word on right of buffer to stop data looping back round:
		lea	SCREEN_BW-2(a1),a2
		WAIT_BLIT
		move.w	#SCREEN_BW-2,bltdmod(a6)
		move.l	a2,bltdpt(a6)
		move.l	#$1000000,bltcon0(a6)
		move.w	#(SCREEN_H*BPLS)<<6!1,bltsize(a6)

		; ; Offset a1 to center/right of screen:
		add.w	#24+SCREEN_BW*128,a1

		move.w	VBlank+2,d6
		lsl.w	#4,d6
		lea	Sin,a3

		move.w	d6,d4
		and.w	#$7fe,d4
		move.w	(a3,d4.w),d0

		move.w	d6,d4
		divs	#3,d4
		and.w	#$7fe,d4
		add.w	(a3,d4.w),d0

		asr.w	#8,d0
		add.w	#$b0,d0
		move.w	d0,Scale

		moveq	#OUTER_COUNT-1,d7
.l0
		move.w	d6,d4
		and.w	#$7fe,d4
		move.w	(a3,d4.w),d0
		muls	Scale,d0
		swap	d0
		sub.w	Scroll,d0

		add.w	#$1fe,d4
		and.w	#$7fe,d4
		move.w	(a3,d4.w),d1
		muls	Scale,d1
		swap	d1

		move.w	VBlank+2,d4
		lsl.w	#5,d4

		moveq	#INNER_COUNT-1,d5
.l1
		movem.w	d0-d6,-(sp)

		and.w	#$7fe,d4
		move.w	(a3,d4.w),d2
		muls	Scale,d2
		swap	d2
		asr.w	#2,d2
		add.w	d2,d0

		add.w	#$1fe,d4
		and.w	#$7fe,d4
		move.w	(a3,d4.w),d2
		muls	Scale,d2
		swap	d2
		asr.w	#2,d2
		add.w	d2,d1

		move.w	Scale,d2
		lsr.w	#5,d2
		move.w	d5,d3
		and.w #3,d3
		mulu #SCREEN_BPL,d3
		jsr	BlitCircleUnsafe
		movem.w	(sp)+,d0-d6

		add.w	#($400/INNER_COUNT)*2,d4
		dbf	d5,.l1

		add.w	#($400/OUTER_COUNT)*2,d6
		dbf	d7,.l0

		cmp.l	#TENTACLES_END_FRAME,VBlank
		blt	Frame
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

; Prepare and store blit params:
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
		add.l	d3,d5					; add colour bpl offset to dest

; Do blit:
		WAIT_BLIT
		move.l	d6,bltamod(a6)
		move.w	d6,bltcmod(a6)
		move.l	#-1,d6
		lsl.l	d4,d6
		move.l	d6,bltafwm(a6)
		lsl.w	#2,d4					; d4 = offset into bltcon table
		move.l	.bltcon(pc,d4),d4			; d4 = BLTCON0/1
		move.l	d4,bltcon0(a6)
		move.l	d5,bltcpt(a6)
		move.l	a0,bltapt(a6)
		move.l	d5,bltdpt(a6)
		move.w	a4,bltsize(a6)
.skip:		rts

; Table for combined minterm and shifts for bltcon0/bltcon1
.bltcon:	dc.l	$0bfa0000,$1bfa1000,$2bfa2000,$3bfa3000
		dc.l	$4bfa4000,$5bfa5000,$6bfa6000,$7bfa7000
		dc.l	$8bfa8000,$9bfa9000,$abfaa000,$bbfab000
		dc.l	$cbfac000,$dbfad000,$ebfae000,$fbfaf000


Scale:		dc.w	$100
Scroll:		dc.w	0
Pal:		dc.w	$222,$625,$a45,$e75,$fc7,$ae7,$3b6,$277,$236,$35c,$4ae,$7ef,$eee,$9ab,$578,$345

*******************************************************************************
		data_c
*******************************************************************************

Cop:
		dc.w	fmode,0
		dc.w	diwstrt,DIW_STRT
		dc.w	diwstop,DIW_STOP
		dc.w	ddfstrt,DDF_STRT
		dc.w	ddfstop,DDF_STOP
		dc.w	bpl1mod,DIW_MOD
		dc.w	bpl2mod,DIW_MOD
		dc.w	bplcon0,BPLS<<(12+DPF)!DPF<<10!$200
CopBplPt:
		rept	BPLS
		dc.w	bpl0pt+REPTN*4,0
		dc.w	bpl0pt+REPTN*4+2,0
		endr
CopScroll:	dc.w	bplcon1,0
		dc.l	-2

		bss_c
Screen:
		ds.b	SCREEN_BW*BPLS*SCREEN_H*2
