		include	_main.i
		include	tentacles.i

TENTACLES_END_FRAME = $fff

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

Tentacles_Effect:
		move.l	#Cop,cop1lc(a6)

; Load palette
		lea	Pal(pc),a0
		lea	color00(a6),a1
		moveq	#16-1,d7
.col		move.w	(a0)+,(a1)+
		dbf	d7,.col

Frame:
; Horizontal scroll position frame frame count
		move.l	VBlank,d6
		; add.w	d6,d6
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
		lea	Screen,a1
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

		add.w	#($400/OUTER_COUNT)*2*3,d6
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

		dc.w 0,$f06,$f58,$f79,$f9a,$fbc,$ecd,$ded
		dc.w 0,$f5b,$f7c,$f9d,$fbd,$fde,$fef,$fff

		; dc.w	$000,$aa0,$895,$676,$466,$357,$037,$007
		; dc.w	$000,$ff0,$de8,$9cb,$7ac,$49d,$06e,$00f

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

; https://gradient-blaster.grahambates.com/?points=000@0,324@127,000@255&steps=256&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=100
Gradient:
		dc.w	$2b07,$fffe
		dc.w	$180,$000
		dc.w	$4207,$fffe
		dc.w	$180,$001
		dc.w	$4307,$fffe
		dc.w	$180,$000
		dc.w	$4407,$fffe
		dc.w	$180,$100
		dc.w	$4507,$fffe
		dc.w	$180,$000
		dc.w	$4707,$fffe
		dc.w	$180,$001
		dc.w	$4807,$fffe
		dc.w	$180,$000
		dc.w	$4a07,$fffe
		dc.w	$180,$100
		dc.w	$4b07,$fffe
		dc.w	$180,$000
		dc.w	$4c07,$fffe
		dc.w	$180,$001
		dc.w	$4d07,$fffe
		dc.w	$180,$000
		dc.w	$4f07,$fffe
		dc.w	$180,$101
		dc.w	$5007,$fffe
		dc.w	$180,$000
		dc.w	$5207,$fffe
		dc.w	$180,$101
		dc.w	$5307,$fffe
		dc.w	$180,$000
		dc.w	$5407,$fffe
		dc.w	$180,$001
		dc.w	$5507,$fffe
		dc.w	$180,$000
		dc.w	$5607,$fffe
		dc.w	$180,$101
		dc.w	$5707,$fffe
		dc.w	$180,$001
		dc.w	$5807,$fffe
		dc.w	$180,$101
		dc.w	$5907,$fffe
		dc.w	$180,$000
		dc.w	$5a07,$fffe
		dc.w	$180,$101
		dc.w	$5b07,$fffe
		dc.w	$180,$001
		dc.w	$5c07,$fffe
		dc.w	$180,$111
		dc.w	$5d07,$fffe
		dc.w	$180,$001
		dc.w	$5e07,$fffe
		dc.w	$180,$101
		dc.w	$5f07,$fffe
		dc.w	$180,$011
		dc.w	$6007,$fffe
		dc.w	$180,$101
		dc.w	$6107,$fffe
		dc.w	$180,$001
		dc.w	$6207,$fffe
		dc.w	$180,$111
		dc.w	$6307,$fffe
		dc.w	$180,$001
		dc.w	$6407,$fffe
		dc.w	$180,$112
		dc.w	$6507,$fffe
		dc.w	$180,$101
		dc.w	$6607,$fffe
		dc.w	$180,$011
		dc.w	$6707,$fffe
		dc.w	$180,$101
		dc.w	$6807,$fffe
		dc.w	$180,$001
		dc.w	$6907,$fffe
		dc.w	$180,$101
		dc.w	$6a07,$fffe
		dc.w	$180,$112
		dc.w	$6b07,$fffe
		dc.w	$180,$101
		dc.w	$6c07,$fffe
		dc.w	$180,$111
		dc.w	$6d07,$fffe
		dc.w	$180,$101
		dc.w	$6f07,$fffe
		dc.w	$180,$112
		dc.w	$7007,$fffe
		dc.w	$180,$101
		dc.w	$7107,$fffe
		dc.w	$180,$111
		dc.w	$7207,$fffe
		dc.w	$180,$102
		dc.w	$7407,$fffe
		dc.w	$180,$111
		dc.w	$7507,$fffe
		dc.w	$180,$102
		dc.w	$7607,$fffe
		dc.w	$180,$212
		dc.w	$7707,$fffe
		dc.w	$180,$101
		dc.w	$7807,$fffe
		dc.w	$180,$112
		dc.w	$7907,$fffe
		dc.w	$180,$102
		dc.w	$7a07,$fffe
		dc.w	$180,$212
		dc.w	$7b07,$fffe
		dc.w	$180,$102
		dc.w	$7c07,$fffe
		dc.w	$180,$212
		dc.w	$7d07,$fffe
		dc.w	$180,$112
		dc.w	$7f07,$fffe
		dc.w	$180,$212
		dc.w	$8007,$fffe
		dc.w	$180,$112
		dc.w	$8107,$fffe
		dc.w	$180,$202
		dc.w	$8207,$fffe
		dc.w	$180,$113
		dc.w	$8307,$fffe
		dc.w	$180,$212
		dc.w	$8507,$fffe
		dc.w	$180,$112
		dc.w	$8607,$fffe
		dc.w	$180,$212
		dc.w	$8707,$fffe
		dc.w	$180,$103
		dc.w	$8807,$fffe
		dc.w	$180,$212
		dc.w	$8a07,$fffe
		dc.w	$180,$223
		dc.w	$8b07,$fffe
		dc.w	$180,$112
		dc.w	$8c07,$fffe
		dc.w	$180,$213
		dc.w	$8d07,$fffe
		dc.w	$180,$212
		dc.w	$8e07,$fffe
		dc.w	$180,$113
		dc.w	$8f07,$fffe
		dc.w	$180,$213
		dc.w	$9107,$fffe
		dc.w	$180,$212
		dc.w	$9207,$fffe
		dc.w	$180,$223
		dc.w	$9307,$fffe
		dc.w	$180,$213
		dc.w	$9607,$fffe
		dc.w	$180,$314
		dc.w	$9707,$fffe
		dc.w	$180,$223
		dc.w	$9807,$fffe
		dc.w	$180,$213
		dc.w	$9a07,$fffe
		dc.w	$180,$313
		dc.w	$9b07,$fffe
		dc.w	$180,$213
		dc.w	$9c07,$fffe
		dc.w	$180,$224
		dc.w	$9d07,$fffe
		dc.w	$180,$213
		dc.w	$9e07,$fffe
		dc.w	$180,$313
		dc.w	$9f07,$fffe
		dc.w	$180,$223
		dc.w	$a007,$fffe
		dc.w	$180,$313
		dc.w	$a107,$fffe
		dc.w	$180,$214
		dc.w	$a207,$fffe
		dc.w	$180,$323
		dc.w	$a307,$fffe
		dc.w	$180,$223
		dc.w	$a407,$fffe
		dc.w	$180,$324
		dc.w	$a507,$fffe
		dc.w	$180,$313
		dc.w	$a607,$fffe
		dc.w	$180,$224
		dc.w	$a707,$fffe
		dc.w	$180,$313
		dc.w	$a807,$fffe
		dc.w	$180,$224
		dc.w	$a907,$fffe
		dc.w	$180,$314
		dc.w	$aa07,$fffe
		dc.w	$180,$324
		dc.w	$ab07,$fffe
		dc.w	$180,$323
		dc.w	$ad07,$fffe
		dc.w	$180,$214
		dc.w	$ae07,$fffe
		dc.w	$180,$323
		dc.w	$af07,$fffe
		dc.w	$180,$324
		dc.w	$b007,$fffe
		dc.w	$180,$213
		dc.w	$b107,$fffe
		dc.w	$180,$223
		dc.w	$b207,$fffe
		dc.w	$180,$314
		dc.w	$b307,$fffe
		dc.w	$180,$213
		dc.w	$b407,$fffe
		dc.w	$180,$323
		dc.w	$b507,$fffe
		dc.w	$180,$213
		dc.w	$b607,$fffe
		dc.w	$180,$324
		dc.w	$b707,$fffe
		dc.w	$180,$213
		dc.w	$b807,$fffe
		dc.w	$180,$323
		dc.w	$b907,$fffe
		dc.w	$180,$213
		dc.w	$ba07,$fffe
		dc.w	$180,$324
		dc.w	$bb07,$fffe
		dc.w	$180,$213
		dc.w	$bc07,$fffe
		dc.w	$180,$313
		dc.w	$bd07,$fffe
		dc.w	$180,$213
		dc.w	$bf07,$fffe
		dc.w	$180,$222
		dc.w	$c007,$fffe
		dc.w	$180,$213
		dc.w	$c407,$fffe
		dc.w	$180,$313
		dc.w	$c507,$fffe
		dc.w	$180,$213
		dc.w	$c607,$fffe
		dc.w	$180,$212
		dc.w	$c707,$fffe
		dc.w	$180,$113
		dc.w	$c807,$fffe
		dc.w	$180,$212
		dc.w	$ca07,$fffe
		dc.w	$180,$223
		dc.w	$cb07,$fffe
		dc.w	$180,$112
		dc.w	$cc07,$fffe
		dc.w	$180,$213
		dc.w	$cd07,$fffe
		dc.w	$180,$212
		dc.w	$ce07,$fffe
		dc.w	$180,$112
		dc.w	$cf07,$fffe
		dc.w	$180,$213
		dc.w	$d007,$fffe
		dc.w	$180,$212
		dc.w	$d107,$fffe
		dc.w	$180,$112
		dc.w	$d207,$fffe
		dc.w	$180,$213
		dc.w	$d307,$fffe
		dc.w	$180,$202
		dc.w	$d407,$fffe
		dc.w	$180,$112
		dc.w	$d607,$fffe
		dc.w	$180,$213
		dc.w	$d707,$fffe
		dc.w	$180,$112
		dc.w	$d807,$fffe
		dc.w	$180,$202
		dc.w	$d907,$fffe
		dc.w	$180,$111
		dc.w	$da07,$fffe
		dc.w	$180,$212
		dc.w	$db07,$fffe
		dc.w	$180,$102
		dc.w	$dc07,$fffe
		dc.w	$180,$112
		dc.w	$dd07,$fffe
		dc.w	$180,$102
		dc.w	$de07,$fffe
		dc.w	$180,$212
		dc.w	$df07,$fffe
		dc.w	$180,$112
		dc.w	$e007,$fffe
		dc.w	$180,$101
		dc.w	$e107,$fffe
		dc.w	$180,$102
		dc.w	$e207,$fffe
		dc.w	$180,$211
		dc.w	$e307,$fffe
		dc.w	$180,$102
		dc.w	$e407,$fffe
		dc.w	$180,$112
		dc.w	$e507,$fffe
		dc.w	$180,$101
		dc.w	$e607,$fffe
		dc.w	$180,$111
		dc.w	$e707,$fffe
		dc.w	$180,$101
		dc.w	$e807,$fffe
		dc.w	$180,$102
		dc.w	$e907,$fffe
		dc.w	$180,$101
		dc.w	$ea07,$fffe
		dc.w	$180,$112
		dc.w	$eb07,$fffe
		dc.w	$180,$101
		dc.w	$ec07,$fffe
		dc.w	$180,$111
		dc.w	$ed07,$fffe
		dc.w	$180,$001
		dc.w	$ee07,$fffe
		dc.w	$180,$101
		dc.w	$ef07,$fffe
		dc.w	$180,$112
		dc.w	$f007,$fffe
		dc.w	$180,$001
		dc.w	$f107,$fffe
		dc.w	$180,$011
		dc.w	$f207,$fffe
		dc.w	$180,$101
		dc.w	$f307,$fffe
		dc.w	$180,$001
		dc.w	$f407,$fffe
		dc.w	$180,$111
		dc.w	$f507,$fffe
		dc.w	$180,$001
		dc.w	$f607,$fffe
		dc.w	$180,$101
		dc.w	$f707,$fffe
		dc.w	$180,$000
		dc.w	$f807,$fffe
		dc.w	$180,$101
		dc.w	$f907,$fffe
		dc.w	$180,$001
		dc.w	$fa07,$fffe
		dc.w	$180,$111
		dc.w	$fb07,$fffe
		dc.w	$180,$000
		dc.w	$fc07,$fffe
		dc.w	$180,$101
		dc.w	$fd07,$fffe
		dc.w	$180,$001
		dc.w	$ff07,$fffe
		dc.w	$180,$110
		dc.w	$ffdf,$fffe				; PAL fix
		dc.w	$007,$fffe
		dc.w	$180,$001
		dc.w	$107,$fffe
		dc.w	$180,$100
		dc.w	$207,$fffe
		dc.w	$180,$001
		dc.w	$307,$fffe
		dc.w	$180,$000
		dc.w	$407,$fffe
		dc.w	$180,$100
		dc.w	$507,$fffe
		dc.w	$180,$001
		dc.w	$607,$fffe
		dc.w	$180,$000
		dc.w	$707,$fffe
		dc.w	$180,$001
		dc.w	$807,$fffe
		dc.w	$180,$000
		dc.w	$a07,$fffe
		dc.w	$180,$100
		dc.w	$b07,$fffe
		dc.w	$180,$000
		dc.w	$c07,$fffe
		dc.w	$180,$001
		dc.w	$d07,$fffe
		dc.w	$180,$000
		dc.w	$1607,$fffe
		dc.w	$180,$001
		dc.w	$1707,$fffe
		dc.w	$180,$000
		dc.w	$ffff,$fffe				; End copper list
		dc.l	-2

		bss_c
Screen:
		ds.b	SCREEN_BW*BPLS*SCREEN_H*2
