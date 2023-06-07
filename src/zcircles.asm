		incdir	src
		include	_main.i
		include	zcircles.i

MAX_CLEAR = 100*2+2
DIW_BW = CIRCLES_DIW_W/8
SCREEN_BW = CIRCLES_SCREEN_W/8

********************************************************************************
; a0 = clear list
ClearCircles:
	move.l	#$01000000,d0
	move.w	#DMAF_SETCLR!DMAF_BLITHOG,dmacon(a6)	; hog the blitter
.l:
	move.l	(a0)+,d1
	beq	.done					; address: end of array on zero
	move.w	(a0)+,d2				; mod/bit
	move.w	(a0)+,d3				; bltsize or zero for plot
	beq	.plot
; Clear blitted circle
	WAIT_BLIT
	move.l	d0,bltcon0(a6)
	move.l	d1,bltdpt(a6)
	move.w	d2,bltdmod(a6)
	move.w	d3,bltsize(a6)
	bra	.l
.plot:
; Clear plotted point
	move.l	d1,a2
	bclr	d2,(a2)
	bra	.l
.done:
	move.w	#DMAF_BLITHOG,dmacon(a6)
	rts

********************************************************************************
; Blit or plot circle with oob checks
;-------------------------------------------------------------------------------
DrawCircle:
; max x
		move.w	#CIRCLES_DIW_W/2,d4
		add.w	d2,d4
		cmp.w	d4,d0
		bge	.skip
; min x
		neg.w	d4
		cmp.w	d4,d0
		ble	.skip
; max y
		move.w	#CIRCLES_DIW_H/2,d4
		add.w	d2,d4
		cmp.w	d4,d1
		bge	.skip
; min y
		neg.w	d4
		cmp.w	d4,d1
		ble	.skip
; blit or plot
		tst.w	d2
		bne	BlitCircle
		bra	Plot
.skip:		rts

SKIPCLIP=1

********************************************************************************
; Draw a circle using blitter
;-------------------------------------------------------------------------------
; d0.w - x
; d1.w - y
; d2.w - r
; d3.l - colour (bpl offset)
; a1 - dest bpl (centered)
; a2 - clear list
;-------------------------------------------------------------------------------
BlitCircle:
		cmp.w	#CIRCLES_MAX_R,d2
		bgt	.skip
; Subract radius from coords to center
		sub.w	d2,d1
		sub.w	d2,d0
; Get blit params for radius:
		move.w	d2,d4
		subq	#1,d4
; mulu	#Blit_SIZEOF,d4
		lsl.w	#3,d4					; optimise
		lea	BltCircSizes,a0
		lea	(a0,d4.w),a0
		movem.w	Blit_Mod(a0),d6/a4
		move.l	Blit_Adr(a0),a0

		cmp.w	#CIRCLES_PAD/2,d2
		ble	.noClip

; Clipping checks:
; Min Y:
		move.w	#-CIRCLES_SCREEN_H/2,d4
		sub.w	d1,d4
		blt	.minYOk
		; bra .skip
		add.w	d4,d1					; offset y position
		move.w	#SCREEN_BW,d5				; get byte width from modulo
		sub.w	d6,d5
		muls	d4,d5
		add.l	d5,a0					; adjust src start
		lsl.w	#6,d4
		sub.w	d4,a4					; adjust bltsize
		bra	.checkX
.minYOk:
; Max Y:
		move.w	#CIRCLES_SCREEN_H/2,d4
		sub.w	d2,d4
		sub.w	d2,d4
		sub.w	d1,d4
		bge	.maxYOk
		; bra .skip
		neg.w	d4
		move.w	#SCREEN_BW,d5				; get byte width from modulo
		sub.w	d6,d5
		muls	d4,d5
		lsl.w	#6,d4
		sub.w	d4,a4					; adjust bltsize
.maxYOk:
.checkX:
; Min X:
		move.w	#-CIRCLES_DIW_W/2,d4
		sub.w	d0,d4
		move.w	d0,d4					; x/16 - DIW_BW/4
		asr.w	#4,d4
		sub.w	#-DIW_BW/4,d4
		bge	.minXOk
		bra .skip
		neg.w	d4
		subq	#1,d4
		sub.w	d4,a4					; adjust bltsize
		add.w	d4,d4
		lea	(a0,d4.w),a0				; offset source x
		add.w	d4,d6					; adjust modulo
		swap	d6
		add.w	d4,d6
		swap	d6
		asl.w	#3,d4					; offset x position
		add.w	d4,d0
.minXOk:
; Max X:
		move.w	d0,d4
		asr.w	#3,d4
		add.w	#SCREEN_BW,d4				; get byte width from modulo
		sub.w	d6,d4
		sub.w	#DIW_BW/2,d4
		ble	.maxXOk
		; Skip right clipping for perf boost
		bra .skip
		lsr.w	#1,d4
		sub.w	d4,a4					; adjust bltsize
		add.w	d4,d4					; byte offset
		add.w	d4,d6					; adjust modulo
		swap	d6
		add.w	d4,d6
		swap	d6

.maxXOk:
.noClip

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
; Save to clear list
		move.l	d5,(a2)+
		move.w	d6,(a2)+
		move.w	a4,(a2)+

; Do blit:
		WAIT_BLIT
		move.l	d6,bltamod(a6)
		move.w	d6,bltcmod(a6)
		; moveq	#-1,d6
		; lsl.l	d4,d6
		; move.l	d6,bltafwm(a6)
		lsl.w	#2,d4					; d4 = offset into bltcon table
		move.l	.bltcon(pc,d4),bltcon0(a6)
		move.l	d5,bltcpt(a6)
		move.l	a0,bltapt(a6)
		move.l	d5,bltdpt(a6)
		move.w	a4,bltsize(a6)
.skip:		rts

		lsl.w	#2,d4
		move.l	.bltcon(pc,d4),bltcon0(a6)
; snip...

; Table for combined minterm and shifts for bltcon0/bltcon1
.bltcon:	dc.l	$0fea0000,$1fea1000,$2fea2000,$3fea3000
		dc.l	$4fea4000,$5fea5000,$6fea6000,$7fea7000
		dc.l	$8fea8000,$9fea9000,$afeaa000,$bfeab000
		dc.l	$cfeac000,$dfead000,$efeae000,$ffeaf000


********************************************************************************
; Plot point
;-------------------------------------------------------------------------------
; d0 - x
; d1 - y
; d3 - colour (bpl offset)
; a1 - dest (centered)
; a2 - clear list
;-------------------------------------------------------------------------------
Plot:
		moveq	#$f,d2
		and.w	d0,d2
		not.w	d2
		asr.w	#3,d0
		muls	#SCREEN_BW,d1
		add.w	d0,d1
		lea	(a1,d1.w),a4
		add.l	d3,a4					; colour bpl offset
		bset	d2,(a4)
		move.l	a4,(a2)+
		move.w	d2,(a2)+
		move.w	#0,(a2)+
		rts


********************************************************************************
; Precalc routines:
********************************************************************************

********************************************************************************
; Initialise blitter circle data
;-------------------------------------------------------------------------------
; `BltCircBpl` is populated with a range of filled circles with radius from 1-MAX_R.
; `BltCircSizes` is populated with pointers to the bitplane data and blit
; parameters for each size.
;-------------------------------------------------------------------------------
Circles_Precalc:
		move.w	#DMAF_SETCLR!DMAF_MASTER!DMAF_BLITTER,dmacon(a6)

		lea	BltCircBpl,a0
		lea	BltCircSizes,a1
		move.w	#CIRCLES_MAX_R,d7
		move.b	#%10100000,(a0)				; fix up smallest circle
; Initial radius for smallest circle
		moveq	#1,d0					; d0 = radius
.l:
		move.w	d0,d2					; d2 = diameter
		add.w	d2,d2
; Calc byte width
		move.w	d2,d1					; d1 = byte width
		add.w	#31,d1					; round up + 1 word
		lsr.w	#4,d1					; /16
		add.w	d1,d1					; *2
; Store address
		move.l	a0,(a1)+
; Modulo
		move.w	#SCREEN_BW,d4				; d4 = blit modulo
		sub.w	d1,d4
		move.w	d4,(a1)+
; Blit size
		move.w	d2,d3					; d3 = blit size
		lsl.w	#6,d3
		move.w	d1,d4
		lsr.w	d4
		add.w	d4,d3
		move.w	d3,(a1)+
; Draw the circle outline
		bsr	DrawCircleFill
; Next bpl:
		mulu	d2,d1					; offset = byte width * diameter
		lea	(a0,d1.w),a0
; Blitter fill (descending)
		lea	-1(a0),a2
		WAIT_BLIT
		move.l	#-1,bltafwm(a6)
		clr.l	bltamod(a6)
		move.l	#$09f00012,bltcon0(a6)
		move.l	a2,bltapth(a6)
		move.l	a2,bltdpth(a6)
		move.w	d3,bltsize(a6)
; Next radius
		addq	#1,d0
		cmp.w	d7,d0
		ble	.l

; Calc length for BSS
	sub.l #BltCircBpl,a0
	nop
		rts

********************************************************************************
; Bresenham circle for blitter fill
;-------------------------------------------------------------------------------
; a0 - Dest ptr
; d0 - Radius
; d1 - byte width
;-------------------------------------------------------------------------------
DrawCircleFill:
		movem.l	d0-a7,-(sp)
		move.w	d0,d2
		move.w	d0,d4					; d4 = x = r
		moveq	#0,d5					; d5 = y = 0
		neg.w	d0					; d0 = P = 1 - r
		addq	#1,d0

; Plot first point:
		move.w	d4,d6					; X,Y
		moveq	#0,d7
		bsr	.plot
		move.w	d4,d6					; -X,Y
		neg.w	d6
		moveq	#0,d7
		bsr	.plot

.l:
		cmp.w	d5,d4					; x > y?
		ble	.done

		tst.w	d0					; P < 0?
		blt	.inside
		subq	#1,d4					; x--;
		sub.w	d4,d0					; P -= x
		sub.w	d4,d0					; P -= x

.inside:
		addq	#1,d5					; y++

		add.w	d5,d0					; P += y
		add.w	d5,d0					; P += y
		addq	#1,d0					; P += 1

		cmp.w	d5,d4					; x < y?
		blt	.done

; Plot:

; Only mirror y if x will  change on next loop
; Avoid multiple pixels on same row as the breaks blitter fill
		tst.w	d0					; if (P >= 0)
		blt	.noMirror
		cmp.w	d5,d4					; if (x != y):
		beq	.noMirror
		move.w	d5,d6					; Y,X
		move.w	d4,d7
		subq	#1,d7
		bsr	.plot
		move.w	d5,d6					; -Y,X
		neg.w	d6
		move.w	d4,d7
		subq	#1,d7
		bsr	.plot
		move.w	d5,d6					; Y,-X
		move.w	d4,d7
		neg.w	d7
		bsr	.plot
		move.w	d5,d6					; -Y,-X
		neg.w	d6
		move.w	d4,d7
		neg.w	d7
		bsr	.plot
.noMirror:
		move.w	d4,d6					; X,Y
		move.w	d5,d7
		subq	#1,d7
		bsr	.plot
		move.w	d4,d6					; -X,Y
		neg.w	d6
		move.w	d5,d7
		subq	#1,d7
		bsr	.plot
		move.w	d4,d6					; X,-Y
		move.w	d5,d7
		neg.w	d7
		bsr	.plot
		move.w	d4,d6					; -X,-Y
		neg.w	d6
		move.w	d5,d7
		neg.w	d7
		bsr	.plot

		bra	.l

.done:
		movem.l	(sp)+,d0-a7
		rts

.plot:
		add.w	d2,d6
		add.w	d2,d7
		muls	d1,d7
		move.w	d6,d3
		not.w	d3
		asr.w	#3,d6
		add.w	d7,d6
		bset	d3,(a0,d6.w)
		rts


*******************************************************************************
		bss
*******************************************************************************
; Ptrs to circle images / blit params for each radius
BltCircSizes:	ds.b	Blit_SIZEOF*CIRCLES_MAX_R

; Double buffered list of clear data to restore blits/plots
ClearList1:	ds.b	Blit_SIZEOF*MAX_CLEAR+4
ClearList2:	ds.b	Blit_SIZEOF*MAX_CLEAR+4

*******************************************************************************
		bss_c
*******************************************************************************

; Blitter circle bitplane data for all sizes. Generated by InitCircles
BltCircBpl:	ds.b	$21e0				; calculated in InitBlitCircles
