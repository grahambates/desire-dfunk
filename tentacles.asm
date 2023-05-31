		include	_main.i
		include	tentacles.i

TENTACLES_END_FRAME = $fff

OUTER_COUNT = 11
INNER_COUNT = 7
INNER_SHIFT = 3

; Display window:
DIW_W = 320
DIW_H = 256
BPLS = 3
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
		add.w	d6,d6
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

; Wait for VBL before updating bpl pointers in copper
		DebugStartIdle
		jsr	WaitEOF
		DebugStopIdle

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

		ext.l d0
		divs #150,d0
		add.w	#$f0,d0					; min scale
		move.w	d0,Scale

; d6 = outer start angle
		and.w	#$7fe,d6
		move.w (a3,d6.w),d6
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
		asr d0 ; / 2 for pERsPECtIve

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

; Fill/clear each bpl to create color (not interleaved)
		moveq	#BPLS-1,d0
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
		rts

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

; https://gradient-blaster.grahambates.com/?points=103@0,256@132,515@255&steps=256&blendMode=oklab&ditherMode=errorDiffusion&target=amigaOcs&ditherAmount=59
Gradient:
	dc.w $180,$103
	dc.w $3107,$fffe
	dc.w $180,$113
	dc.w $3407,$fffe
	dc.w $180,$103
	dc.w $3507,$fffe
	dc.w $180,$113
	dc.w $3b07,$fffe
	dc.w $180,$013
	dc.w $3c07,$fffe
	dc.w $180,$113
	dc.w $3d07,$fffe
	dc.w $180,$114
	dc.w $3e07,$fffe
	dc.w $180,$113
	dc.w $4007,$fffe
	dc.w $180,$114
	dc.w $4107,$fffe
	dc.w $180,$113
	dc.w $4307,$fffe
	dc.w $180,$124
	dc.w $4407,$fffe
	dc.w $180,$113
	dc.w $4507,$fffe
	dc.w $180,$114
	dc.w $4607,$fffe
	dc.w $180,$123
	dc.w $4707,$fffe
	dc.w $180,$114
	dc.w $4807,$fffe
	dc.w $180,$113
	dc.w $4907,$fffe
	dc.w $180,$124
	dc.w $4a07,$fffe
	dc.w $180,$114
	dc.w $4b07,$fffe
	dc.w $180,$123
	dc.w $4c07,$fffe
	dc.w $180,$114
	dc.w $4d07,$fffe
	dc.w $180,$124
	dc.w $4e07,$fffe
	dc.w $180,$114
	dc.w $4f07,$fffe
	dc.w $180,$123
	dc.w $5007,$fffe
	dc.w $180,$124
	dc.w $5107,$fffe
	dc.w $180,$114
	dc.w $5207,$fffe
	dc.w $180,$124
	dc.w $5507,$fffe
	dc.w $180,$024
	dc.w $5607,$fffe
	dc.w $180,$124
	dc.w $5e07,$fffe
	dc.w $180,$134
	dc.w $5f07,$fffe
	dc.w $180,$124
	dc.w $6207,$fffe
	dc.w $180,$134
	dc.w $6307,$fffe
	dc.w $180,$124
	dc.w $6407,$fffe
	dc.w $180,$234
	dc.w $6507,$fffe
	dc.w $180,$124
	dc.w $6607,$fffe
	dc.w $180,$134
	dc.w $6707,$fffe
	dc.w $180,$124
	dc.w $6807,$fffe
	dc.w $180,$234
	dc.w $6907,$fffe
	dc.w $180,$125
	dc.w $6a07,$fffe
	dc.w $180,$134
	dc.w $6b07,$fffe
	dc.w $180,$234
	dc.w $6c07,$fffe
	dc.w $180,$125
	dc.w $6d07,$fffe
	dc.w $180,$134
	dc.w $6e07,$fffe
	dc.w $180,$235
	dc.w $6f07,$fffe
	dc.w $180,$125
	dc.w $7007,$fffe
	dc.w $180,$234
	dc.w $7107,$fffe
	dc.w $180,$035
	dc.w $7207,$fffe
	dc.w $180,$134
	dc.w $7307,$fffe
	dc.w $180,$135
	dc.w $7e07,$fffe
	dc.w $180,$145
	dc.w $7f07,$fffe
	dc.w $180,$135
	dc.w $8007,$fffe
	dc.w $180,$235
	dc.w $8107,$fffe
	dc.w $180,$135
	dc.w $8207,$fffe
	dc.w $180,$145
	dc.w $8307,$fffe
	dc.w $180,$235
	dc.w $8407,$fffe
	dc.w $180,$145
	dc.w $8507,$fffe
	dc.w $180,$235
	dc.w $8607,$fffe
	dc.w $180,$145
	dc.w $8707,$fffe
	dc.w $180,$235
	dc.w $8807,$fffe
	dc.w $180,$245
	dc.w $8a07,$fffe
	dc.w $180,$235
	dc.w $8b07,$fffe
	dc.w $180,$245
	dc.w $8e07,$fffe
	dc.w $180,$145
	dc.w $9207,$fffe
	dc.w $180,$146
	dc.w $9307,$fffe
	dc.w $180,$246
	dc.w $9407,$fffe
	dc.w $180,$145
	dc.w $9507,$fffe
	dc.w $180,$245
	dc.w $9607,$fffe
	dc.w $180,$246
	dc.w $9707,$fffe
	dc.w $180,$145
	dc.w $9807,$fffe
	dc.w $180,$246
	dc.w $9907,$fffe
	dc.w $180,$145
	dc.w $9a07,$fffe
	dc.w $180,$246
	dc.w $9b07,$fffe
	dc.w $180,$145
	dc.w $9c07,$fffe
	dc.w $180,$256
	dc.w $9d07,$fffe
	dc.w $180,$245
	dc.w $9e07,$fffe
	dc.w $180,$256
	dc.w $a007,$fffe
	dc.w $180,$245
	dc.w $a107,$fffe
	dc.w $180,$256
	dc.w $a207,$fffe
	dc.w $180,$156
	dc.w $a307,$fffe
	dc.w $180,$246
	dc.w $a407,$fffe
	dc.w $180,$256
	dc.w $a507,$fffe
	dc.w $180,$246
	dc.w $a607,$fffe
	dc.w $180,$256
	dc.w $a707,$fffe
	dc.w $180,$246
	dc.w $a807,$fffe
	dc.w $180,$256
	dc.w $ac07,$fffe
	dc.w $180,$156
	dc.w $af07,$fffe
	dc.w $180,$256
	dc.w $b007,$fffe
	dc.w $180,$156
	dc.w $b107,$fffe
	dc.w $180,$256
	dc.w $b307,$fffe
	dc.w $180,$246
	dc.w $b407,$fffe
	dc.w $180,$256
	dc.w $b807,$fffe
	dc.w $180,$246
	dc.w $b907,$fffe
	dc.w $180,$256
	dc.w $bb07,$fffe
	dc.w $180,$356
	dc.w $be07,$fffe
	dc.w $180,$346
	dc.w $bf07,$fffe
	dc.w $180,$356
	dc.w $c007,$fffe
	dc.w $180,$246
	dc.w $c107,$fffe
	dc.w $180,$356
	dc.w $c207,$fffe
	dc.w $180,$346
	dc.w $c307,$fffe
	dc.w $180,$256
	dc.w $c407,$fffe
	dc.w $180,$346
	dc.w $c607,$fffe
	dc.w $180,$356
	dc.w $c707,$fffe
	dc.w $180,$346
	dc.w $c907,$fffe
	dc.w $180,$456
	dc.w $ca07,$fffe
	dc.w $180,$346
	dc.w $cb07,$fffe
	dc.w $180,$446
	dc.w $cc07,$fffe
	dc.w $180,$456
	dc.w $cd07,$fffe
	dc.w $180,$346
	dc.w $ce07,$fffe
	dc.w $180,$446
	dc.w $d007,$fffe
	dc.w $180,$345
	dc.w $d107,$fffe
	dc.w $180,$446
	dc.w $d207,$fffe
	dc.w $180,$346
	dc.w $d307,$fffe
	dc.w $180,$446
	dc.w $d407,$fffe
	dc.w $180,$346
	dc.w $d507,$fffe
	dc.w $180,$446
	dc.w $d607,$fffe
	dc.w $180,$346
	dc.w $d707,$fffe
	dc.w $180,$446
	dc.w $da07,$fffe
	dc.w $180,$445
	dc.w $db07,$fffe
	dc.w $180,$446
	dc.w $dc07,$fffe
	dc.w $180,$445
	dc.w $dd07,$fffe
	dc.w $180,$446
	dc.w $de07,$fffe
	dc.w $180,$445
	dc.w $df07,$fffe
	dc.w $180,$446
	dc.w $e007,$fffe
	dc.w $180,$435
	dc.w $e107,$fffe
	dc.w $180,$446
	dc.w $e207,$fffe
	dc.w $180,$445
	dc.w $e307,$fffe
	dc.w $180,$435
	dc.w $e407,$fffe
	dc.w $180,$446
	dc.w $e507,$fffe
	dc.w $180,$435
	dc.w $e607,$fffe
	dc.w $180,$445
	dc.w $e707,$fffe
	dc.w $180,$436
	dc.w $e807,$fffe
	dc.w $180,$445
	dc.w $e907,$fffe
	dc.w $180,$435
	dc.w $ea07,$fffe
	dc.w $180,$446
	dc.w $eb07,$fffe
	dc.w $180,$435
	dc.w $ec07,$fffe
	dc.w $180,$445
	dc.w $ed07,$fffe
	dc.w $180,$536
	dc.w $ee07,$fffe
	dc.w $180,$436
	dc.w $ef07,$fffe
	dc.w $180,$445
	dc.w $f007,$fffe
	dc.w $180,$436
	dc.w $f107,$fffe
	dc.w $180,$435
	dc.w $f207,$fffe
	dc.w $180,$436
	dc.w $f307,$fffe
	dc.w $180,$435
	dc.w $f407,$fffe
	dc.w $180,$436
	dc.w $f507,$fffe
	dc.w $180,$435
	dc.w $f607,$fffe
	dc.w $180,$536
	dc.w $f707,$fffe
	dc.w $180,$435
	dc.w $f807,$fffe
	dc.w $180,$436
	dc.w $f907,$fffe
	dc.w $180,$535
	dc.w $fa07,$fffe
	dc.w $180,$436
	dc.w $fb07,$fffe
	dc.w $180,$435
	dc.w $fc07,$fffe
	dc.w $180,$536
	dc.w $fd07,$fffe
	dc.w $180,$435
	dc.w $fe07,$fffe
	dc.w $180,$536
	dc.w $ff07,$fffe
	dc.w $180,$535
	dc.w $ffdf,$fffe ; PAL fix
	dc.w $007,$fffe
	dc.w $180,$435
	dc.w $107,$fffe
	dc.w $180,$526
	dc.w $207,$fffe
	dc.w $180,$436
	dc.w $307,$fffe
	dc.w $180,$525
	dc.w $407,$fffe
	dc.w $180,$435
	dc.w $507,$fffe
	dc.w $180,$535
	dc.w $607,$fffe
	dc.w $180,$436
	dc.w $707,$fffe
	dc.w $180,$535
	dc.w $807,$fffe
	dc.w $180,$425
	dc.w $907,$fffe
	dc.w $180,$535
	dc.w $a07,$fffe
	dc.w $180,$525
	dc.w $b07,$fffe
	dc.w $180,$426
	dc.w $c07,$fffe
	dc.w $180,$535
	dc.w $d07,$fffe
	dc.w $180,$525
	dc.w $f07,$fffe
	dc.w $180,$435
	dc.w $1007,$fffe
	dc.w $180,$526
	dc.w $1107,$fffe
	dc.w $180,$525
	dc.w $1e07,$fffe
	dc.w $180,$515
	dc.w $1f07,$fffe
	dc.w $180,$525
	dc.w $2007,$fffe
	dc.w $180,$515
	dc.w $2107,$fffe
	dc.w $180,$525
	dc.w $2207,$fffe
	dc.w $180,$515
	dc.w $2407,$fffe
	dc.w $180,$525
	dc.w $2507,$fffe
	dc.w $180,$515
	dc.w $ffff,$fffe ; End copper list

		dc.l	-2

		bss_c
Screen:
		ds.b	SCREEN_BW*BPLS*SCREEN_H*2
