		include	src/_main.i
		include	dude.i

DUDE_END_FRAME = $600

TOP_PAD = 13
L_PAD = 32
R_PAD = 48
H_PAD = L_PAD+R_PAD
FILL_HEIGHT = 52
TEXT_Y = 26+TOP_PAD

CLEAR_LIST_ITEM_SZ = 5*2+4+2

SPACE_WIDTH = 10
GREET_SPACE = 30

DUDE_W = 96
DUDE_BW = DUDE_W/8
DUDE_H = 150/2
DUDE_Y = 60
DUDE_X = 6

DIW_W = 320
DIW_H = 256

PF1_BPLS = 3
PF1_W = DIW_W
PF1_H = DIW_H

PF2_BPLS = 3
PF2_W = DIW_W+H_PAD
PF2_H = DIW_H

BPLS = PF1_BPLS+PF2_BPLS

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

; Sprite
		lea	Sprite,a3
		lea	Sprite2+2,a4
		lea	XGrid,a1
		move.l	CurrFrame,d0
		subq	#1,d0
		neg.w	d0
		divu	#$180,d0
		swap	d0
		add.w	#XGRID_MIN_VIS,d0
		cmp.w	#XGRID_SIZE,d0
		bge	.skip
		add.w	d0,d0
		move.w	(a1,d0.w),d0
		sub.w	#L_PAD,d0

		add.w	d0,d0
		move.l	LineFloorY,a2
		move.w	(a2,d0.w),d1
		move.l	LineFloorX,a1
		move.w	(a1,d0.w),d0

		add.w	#DIW_XSTRT-H_PAD,d0
		add.w	#DIW_YSTRT-TOP_PAD,d1
		; hstart lower
		move.w	d0,d3
		and.b	#1,d3
		lsr.w	d0
		; vstop upper
		move.w	d1,d4
		lsr	#7,d4
		and.b	#2,d4
		or.b	d4,d3

		move.b	#DIW_YSTRT,(a3)+ ; vstart
		move.b	d0,(a3)+	; hstart upper
		move.b	d1,(a3)+	; vstop
		move.b	d3,(a3)+	; hstart lower  / vstop upper

		; vstart upper

		move.w	d1,d2
		sub.w	#49,d2
		move.w	d2,d4
		lsr	#6,d4
		and.b	#4,d4
		or.b	d4,d3

		move.b	d2,(a4)+	; vstart
		move.b	d0,(a4)+	; hstart upper
		move.b	d1,(a4)+	; vstop
		move.b	d3,(a4)+	; hstart lower  / vstop upper

.skip		rts

PokeBpls:
		lea	CopBpls+2,a1
; pf1
		move.l	ViewBuffer(pc),a0
		moveq	#3-1,d7
.l0:
		move.l	a0,d2
		swap	d2
		move.w	d2,(a1)		;high word of address
		move.w	a0,4(a1)	;low word of address
		addq.w	#8,a1		;skip two copper instructions
		add.l	#PF1_BPL,a0	;next ptr
		dbf	d7,.l0

; pf2
		move.l	ViewBufferB(pc),a0
		add.l	#TOP_PAD*PF2_BW+L_PAD/8,a0 ; padding
		move.l	a0,d2
		swap	d2
		move.w	d2,(a1)		;high word of address
		move.w	a0,4(a1)	;low word of address
		rts

********************************************************************************
Dude_Effect:
********************************************************************************


		moveq	#0,d0
		jsr	BlankScreen

		jsr	ResetFrameCounter
		jsr	Free

; Allocate mem
		move.l	#PF1_SIZE,d0
		jsr	AllocChip
		move.l	a0,DrawBuffer
		bsr	ClearScreen

		jsr	AllocChip
		move.l	a0,ViewBuffer
		bsr	ClearScreen

		move.l	#PF2_SIZE+PF2_BW*TOP_PAD,d0
		jsr	AllocChip
		move.l	a0,DrawBufferB
		bsr	ClearScreen
		jsr	AllocChip
		move.l	a0,ViewBufferB
		bsr	ClearScreen

		move.l	#CLEAR_LIST_ITEM_SZ*20,d0
		jsr	AllocPublic
		move.l	a0,DrawClearList
		clr.l	(a0)

		jsr	AllocPublic
		move.l	a0,ViewClearList
		clr.l	(a0)

; lerp tables
LERP_TBL	macro
		move.l	#\3*2,d0
		jsr	AllocPublic
		move.l	a0,\4
		move.l	#\1,d0
		move.l	#\2,d1
		move.w	#\3-1,d2
		bsr	MakeLerpTbl
		endm

		LERP_TBL 62+TOP_PAD,46+TOP_PAD,PF2_W,WallTop
		LERP_TBL 177+TOP_PAD,227+TOP_PAD,PF2_W,WallBottom
		LERP_TBL 194+TOP_PAD,273+TOP_PAD,(DIW_W+R_PAD),LineFloorY
		LERP_TBL 0,PF2_W,(DIW_W+R_PAD),LineFloorX

		move.l	#29*64,d0
		jsr	AllocPublic
		move.l	a0,TextY
		bsr	InitTextY

		bsr	InitScreenMuls

; set pointers in copper loops
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

		lea	Cop2LcC+2,a0
		move.l	#CopLoopC,d0
		move.w	d0,4(a0)
		swap	d0
		move.w	d0,(a0)
; fixed bpls
		lea	CopBplsFixed+2,a1
		lea	Bg+L_PAD/8,a0
		moveq	#2-1,d7
.l1:
		move.l	a0,d2
		swap	d2
		move.w	d2,(a1)		;high word of address
		move.w	a0,4(a1)	;low word of address
		addq.w	#8,a1		;skip two copper instructions
		add.l	#PF2_BPL,a0	;next ptr
		dbf	d7,.l1

; Sprites

		lea	CopSprPt+2,a0

		lea	Sprite2+2,a1
		move.l	a1,d0
		swap	d0
		move.w	d0,(a0)
		move.w	a1,4(a0)
		lea	8(a0),a0

		lea	Sprite,a1
		move.l	a1,d0
		swap	d0
		move.w	d0,(a0)
		move.w	a1,4(a0)
		lea	8(a0),a0

		move.l	#NullSprite,d0
		move.w	d0,d1
		swap	d0
		moveq	#6-1,d7
.spr
		move.w	d0,(a0)
		move.w	d1,4(a0)
		lea	8(a0),a0
		dbf	d7,.spr

		move.w	#DMAF_SETCLR!DMAF_BLITHOG!DMAF_SPRITE,dmacon(a6)

		lea	Cop,a0
		lea	Vbi,a1
		jsr	StartEffect

Frame:
		movem.l	DrawBuffer(pc),a0-a5
		exg	a0,a1
		exg	a2,a3
		exg	a4,a5
		movem.l	a0-a5,DrawBuffer

		bsr	PokeBpls

		bsr	DrawDude

		bsr	ClearLines

;--------------------------------------------------------------------------------
; Clear filled text area
		move.l	DrawBufferB(pc),a0
		add.l	#TOP_PAD*PF2_BW,a0
		WAIT_BLIT
		move.l	a0,bltdpt(a6)
		move.l	#$01000000,bltcon0(a6)
		clr.w	bltdmod(a6)
		move.w	#FILL_HEIGHT<<6!(PF2_BW/2),bltsize(a6)

		; rest position data:
		lea	WordPositions,a4
		move.w	#$ffff,(a4)+
		move.w	#0,(a4)+
		move.w	#$ffff,(a4)+
		move.w	#0,(a4)+
		move.w	#$ffff,(a4)+
		move.w	#0,(a4)+

;--------------------------------------------------------------------------------
; Draw text:
		move.l	CurrFrame,d0
		neg.w	d0		; d0 = x pos
		add.w	#20,d0
		move.l	DrawBufferB(pc),a0
		lea	Greets,a1
		lea	WordPositions,a4
.gr
		move.w	(a1)+,d1	; d1 = x pos of text
		blt	.grDone		; EOF
		move.w	(a1)+,d2	; d2 = color
		move.l	(a1)+,a5	; a5 = font table
		move.l	(a1)+,a3	; a3 = glyph

		add.w	#GREET_SPACE,d0

		; Done if text is off-right
		cmp.w	#XGRID_MAX_VIS+GREET_SPACE/2,d0 ; include if line needed
		bge	.grDone
		move.w	d0,a2		; x used for draw
		add.w	d1,d0		; add width for next
		; Don't draw if off-left
		cmp.w	#XGRID_MIN_VIS,d0
		blt	.gr
		; Draw
		move.w	a2,(a4)+
		move.w	d2,(a4)+
		bsr	DrawWord

		bra	.gr
.grDone

;--------------------------------------------------------------------------------
; Set color positions:
		lea	WordPositions+2,a0
		lea	TextPos2,a1
		lea	TextPos2A,a2
		lea	XGrid,a3

		move.l	CurrFrame,d6
		move.w	d6,d5
		lsr	#5,d5
		and.w	#3<<1,d5
		lea	Cols,a4
		move.w	(a4,d5),d5	; highlight color

		; hightlight for first color?
		move.w	(a0)+,d0
		move.w	d0,TextCol1
		btst	#5,d6
		beq	.noHl
		move.w	d5,d0
.noHl
		move.w	d0,TextCol1A
		moveq	#2-1,d7
.col
		movem.w	(a0)+,d0/d3
		add.w	d0,d0
		move.w	(a3,d0),d0
		sub.w	#L_PAD,d0
		lsr	d0
		add.w	#$38,d0
		bset	#0,d0
		move.w	#color13,d1	; Color to set - maybe nop
; Skip if too far right(!)
		cmp.w	#$d0,d0
		ble	.noSkip
		move.w	#$1fe,d0	; noop the wait
		move.w	d0,d1		; and the color set
.noSkip
		move.w	d0,(a1)		; wait for color change or nop
		move.w	d0,(a2)
		move.w	d1,4(a1)	; color index or nop
		move.w	d1,4(a2)
		move.w	d3,6(a1)	; color value

		; hightlight for this color?
		add.w	#$20,d6		; increment frame values for offset 'randomness'
		btst	#6,d6
		beq	.noHl2
		move.w	d5,d3
.noHl2
		move.w	d3,6(a2)

		lea	TextPos3-TextPos2(a1),a1
		lea	TextPos3-TextPos2(a2),a2
.next		dbf	d7,.col

;--------------------------------------------------------------------------------
; Fill text:
		move.l	DrawBufferB(pc),a0
		add.l	#PF2_BW*(FILL_HEIGHT+TOP_PAD)-1,a0
		WAIT_BLIT
		move.l	a0,bltapt(a6)
		move.l	a0,bltdpt(a6)
		move.l	#$09f0001a,bltcon0(a6)
		clr.l	bltamod(a6)
		move.w	#FILL_HEIGHT<<6!(PF2_BW/2),bltsize(a6)

		bsr	InitDrawLine

;--------------------------------------------------------------------------------
DrawWall:
		move.l	DrawBufferB(pc),a0
		move.l	DrawClearList(pc),a1

		lea	WordPositions,a3
		moveq	#3-1,d7
.l
		move.w	(a3),d0
		lea	4(a3),a3
		sub.w	#GREET_SPACE/2,d0
		cmp.w	#XGRID_MAX_VIS,d0
		bge	.grDone
		cmp.w	#XGRID_MIN_VIS,d0
		blt	.l
		bsr	DrawWallLine
		bra	.l
.grDone
		lea	WordPositions,a3
		moveq	#3-1,d7
.l1
		move.w	(a3),d0
		lea	4(a3),a3
		add.w	#GREET_SPACE,d0
		cmp.w	#XGRID_MAX_VIS,d0
		bge	.grDone1
		cmp.w	#XGRID_MIN_VIS,d0
		blt	.l1
		bsr	DrawWallLine
		bra	.l1
.grDone1


;--------------------------------------------------------------------------------
; Floor lines:
		bsr	InitDrawLine
		move.l	DrawBufferB(pc),a0
; Offset screen buffer to move right padding to the left, giving us more space for bottom edge off-screen
; Will need to put this back later
; This means that bottom edge X can contain negative numbers up to -R_PAD
		sub.l	#R_PAD/8,a0

		move.l	CurrFrame,d0
		neg.w	d0
		and.w	#$3f,d0
		add.w	#XGRID_MIN_VIS,d0
.floorL
		bsr	DrawFloorLine
		add.w	#$40,d0
		cmp.w	#XGRID_SIZE-1,d0
		bge	.floorDone
		bra	.floorL
.floorDone

		move.w	#0,(a1)+	; end clear list

		jsr	WaitEOF
		cmp.l	#DUDE_END_FRAME,CurrFrame
		blt	Frame

		move.w	#DMAF_BLITHOG,dmacon(a6)

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
; Draw a line *not* for filling using the blitter
; Based on TEC, but with muls LUT
;-------------------------------------------------------------------------------
; d0.w - x1
; d1.w - y1
; d2.w - x2
; d3.w - y2
; a0 - Draw buffer
; a1 - Draw clearlist
; a6 - Custom
;-------------------------------------------------------------------------------
		cmp.w	d1,d3
		bgt.s	.l0
		beq	.done
		exg	d0,d2
		exg	d1,d3
.l0		moveq	#0,d4
		move.w	d1,d4
		add.w	d4,d4
		lea	ScreenMuls,a2
		move.w	(a2,d4.w),d4
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
		; or.w	#$0bca,d0

		WAIT_BLIT
		move.w	d2,bltaptl(a6)
		move.w	d2,(a1)+	; Write to clear list
		sub.w	d3,d2
		lsl.w	#6,d3
		addq.w	#2,d3
		move.w	d0,bltcon0(a6)
		move.b	.oct(pc,d5.w),d6
		move.b	d6,bltcon1+1(a6)
		move.l	d4,bltcpt(a6)
		move.l	d4,bltdpt(a6)
		movem.w	d1/d2,bltbmod(a6)
		move.w	d3,bltsize(a6)
		; Write to clear list
		move.w	d0,(a1)+
		move.w	d1,(a1)+
		move.w	d2,(a1)+
		move.w	d3,(a1)+
		move.l	d4,(a1)+
		move.b	d6,(a1)+
		clr.b	(a1)+

.done		rts
.oct		dc.b	1,1+64,17,17+64,9,9+64,21,21+64


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
		; or.w	#$bca,d0

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
ScreenMuls:	ds.w	PF2_H

InitScreenMuls:
		lea	ScreenMuls(pc),a0
		moveq	#0,d0
		move.w	#PF2_H-1,d7
.l		move.w	d0,(a0)+
		add.w	#PF2_BW,d0
		dbf	d7,.l

********************************************************************************
ClearLines:
		bsr	InitDrawLine
		move.l	DrawClearList(pc),a1
.l
		WAIT_BLIT
		movem.w	(a1)+,d0-d4
		tst.w	d0
		beq	.clrLDone
		move.l	(a1)+,d5
		move.b	(a1)+,d6
		clr.b	(a1)+
		move.w	d0,bltaptl(a6)
		move.w	d1,bltcon0(a6)
		move.b	d6,bltcon1+1(a6)
		move.l	d5,bltcpt(a6)
		move.l	d5,bltdpt(a6)
		movem.w	d2/d3,bltbmod(a6)
		move.w	d4,bltsize(a6)
		bra	.l
.clrLDone	rts

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
		add.l	#DUDE_X,d2
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
; a5 = font table
********************************************************************************
DrawWord:
		movem.l	d0/a0/a1/a4,-(sp)
.char
		moveq	#0,d0
		moveq	#0,d5
		moveq	#0,d6
		moveq	#0,d7

		move.b	(a3)+,d0
		beq	.done		; EOL?
		cmp.w	#32,d0		; space?
		bne	.notSpace
		add.w	#SPACE_WIDTH,a2
		bra	.char
.notSpace
		lsl	#2,d0
		move.l	(a5,d0.w),a1

;-------------------------------------------------------------------------------
; DrawChar
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
		move.w	#$ff,d3
		move.b	(a1)+,d2	; next x
		and.w	d3,d2
		and.b	(a1)+,d3	; next y
		add.w	a2,d2

		; Perspective transform:
		lea	XGrid,a4
		add.w	d2,d2
		move.w	(a4,d2.w),d2	; Translate x to screen x in perspective grid LUT

		; Scale y for x position
		move.l	TextY,a4
		lsl.w	#6,d3
		move.w	d2,d5
		asr	#3,d5
		lea	(a4,d3),a4
		move.b	(a4,d5.w),d3
		and.w	#$ff,d3

		movem.w	d2-d3,-(sp)	; backup x/y before line draw, which trashes them
		cmp.w	#-1,d0
		beq	.skipBlit
		bsr	DrawLineBlit
.skipBlit
		movem.w	(sp)+,d0-d1	; restore x/y to different regs as 'current' for next loop
		dbf	d6,.pt
		dbf	d7,.path
.skipChar	add.w	Width(pc),a2

		bra	.char
.done
		movem.l	(sp)+,d0/a0/a1/a4
		rts

********************************************************************************
; d0 = x
; a0 = draw buffer with offset -R_PAD
DrawFloorLine:
		move.w	d0,-(sp)
		add.w	d0,d0
		lea	XGrid,a2
		move.w	(a2,d0.w),d0	; d0 = x in screen pixels

		move.w	d0,d3
		add.w	d3,d3
		move.l	WallBottom,a2
		move.w	(a2,d3.w),d1
		addq	#1,d1

		move.w	d0,d3
		sub.w	#L_PAD,d3
		add.w	d3,d3
		move.l	LineFloorX,a2
		move.w	(a2,d3.w),d2
		move.l	LineFloorY,a2
		move.w	(a2,d3.w),d3

		; Put back right padding to adjust for screen offset
		; This should mean that all x coordinates are now positive
		add.w	#R_PAD,d0
		bsr	DrawLine
.skipLine2
		move.w	(sp)+,d0
		rts


********************************************************************************
; d0 = x
; a0 = draw buffer
DrawWallLine:
		movem.l	d0-d1/a2,-(sp)
		add.w	d0,d0
		lea	XGrid,a2
		move.w	(a2,d0.w),d0

		move.w	d0,d3
		add.w	d3,d3
		move.l	WallTop(pc),a2
		move.w	(a2,d3.w),d1
		move.l	d0,d2
		move.l	WallBottom,a2
		move.w	(a2,d3.w),d3
		bsr	DrawLine
.skipLine
		movem.l	(sp)+,d0-d1/a2
		rts

********************************************************************************
; d0.l = from
; d1.l = to
; d2.w = steps-1
; a0 = dest
MakeLerpTbl:
		sub.l	d0,d1		; delta
		lsl.l	#8,d1		; increment (fp)
		divs	d2,d1
		ext.l	d1
		lsl.l	#8,d0		; current (fp)
.l
		add.l	d1,d0
		move.l	d0,d3
		asr.l	#8,d3
		move.w	d3,(a0)+
		dbf	d2,.l
		rts


********************************************************************************
; a0 = table
InitTextY:
		move.l	#TEXT_Y<<16,d3	; start value
		move.l	#-(TEXT_Y*(8<<16))/PF2_W,d0 ; increment
		moveq	#29-1,d7
.m0
		move.l	d3,d1		; reset to start value
		moveq	#64-1,d6
.m1
		move.l	d1,d2		; fp to int
		swap	d2
		move.b	d2,(a0)+	; write to tbl
		add.l	d0,d1		; add increment
		dbf	d6,.m1
		add.l	#$353,d0	; increase scale ((8<<16)*0.65)/PF2_W,d0
		add.l	#1<<16,d3	; increase start value
		dbf	d7,.m0
		rts


********************************************************************************
Vars:
********************************************************************************

DrawBuffer	dc.l	0
ViewBuffer	dc.l	0
DrawBufferB	dc.l	0
ViewBufferB	dc.l	0
DrawClearList	dc.l	0
ViewClearList	dc.l	0

WallTop:	dc.l	0
WallBottom:	dc.l	0
LineFloorY:	dc.l	0
LineFloorX:	dc.l	0
TextY:		dc.l	0

Width:		dc.w	0

********************************************************************************
Data:
********************************************************************************

WordPositions:	ds.w	4*2

Cols:		dc.w	$08fa,$05a5,$0fdd,$0a28

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

NullSprite:	dc.l	0

Cop:
		dc.w	diwstrt,DIW_STRT
		dc.w	diwstop,DIW_STOP
		dc.w	ddfstrt,DDF_STRT
		dc.w	ddfstop,DDF_STOP
		dc.w	bpl1mod,PF1_MOD
		dc.w	bpl2mod,PF2_MOD
		dc.w	bplcon0,BPLS<<12!$200!(1<<10)
		dc.w	bplcon2,$24

		; COP_WAITV 11		; Needed when not using music wait. Not sure why.

CopBpls:
		; pf1
		dc.w	bpl0pt,0
		dc.w	bpl0ptl,0
		dc.w	bpl2pt,0
		dc.w	bpl2ptl,0
		dc.w	bpl4pt,0
		dc.w	bpl4ptl,0
		; pf2 buffer
		dc.w	bpl5pt,0
		dc.w	bpl5ptl,0
CopSprPt:
		dc.w	spr0pth,0
		dc.w	spr0ptl,0
		dc.w	spr1pth,0
		dc.w	spr1ptl,0
		dc.w	spr2pth,0
		dc.w	spr2ptl,0
		dc.w	spr3pth,0
		dc.w	spr3ptl,0
		dc.w	spr4pth,0
		dc.w	spr4ptl,0
		dc.w	spr5pth,0
		dc.w	spr5ptl,0
		dc.w	spr6pth,0
		dc.w	spr6ptl,0
		dc.w	spr7pth,0
		dc.w	spr7ptl,0
CopBplsFixed:
		; pf2 fixed
		dc.w	bpl1pt,0
		dc.w	bpl1ptl,0
		dc.w	bpl3pt,0
		dc.w	bpl3ptl,0

		; BG palette
		incbin	data/dude-bg.COP
		dc.w	color12,$414
		dc.w	color13,$000
		dc.w	color14,$101
		dc.w	color15,$000

		; Sprite palette
		dc.w	color17,$000
		dc.w	color18,$111
		dc.w	color19,$000

		; Loop for interlaced effect on text
Cop2LcC		dc.w	cop2lch,0
		dc.w	cop2lcl,0
CopLoopC
		dc.w	color13
TextCol1	dc.w	$ff0
TextPos2	dc.w	$3b,$80fe
		dc.w	color13
TextCol2	dc.w	$f0f
TextPos3	dc.w	$3b,$80fe
		dc.w	color13
TextCol3	dc.w	$0ff
TextEol		COP_WAITH 0,$e0

		dc.w	color13
TextCol1A	dc.w	$ff0
TextPos2A	dc.w	$3b,$80fe
		dc.w	color13
TextCol2A	dc.w	$f0f
TextPos3A	dc.w	$3b,$80fe
		dc.w	color13
TextCol3A	dc.w	$0ff
TextEolA	COP_WAITH 0,$e0

		COP_SKIPV DIW_YSTRT+FILL_HEIGHT
		dc.w	copjmp2,0

		dc.w	color13,0

; loop A
Cop2LcA		dc.w	cop2lch,0
		dc.w	cop2lcl,0
		COP_WAITV DUDE_Y+DIW_YSTRT-4
CopLoopA
		dc.w	bpl1mod,-PF1_BW
		incbin	data/dude_walking.COP
		COP_WAITH 0,$e0
		dc.w	bpl1mod,PF1_MOD
		dc.w	$182,$000
		dc.w	$186,$414
		dc.w	$184,$a28
		dc.w	$18c,$f8a
		dc.w	$188,$000
		dc.w	$18a,$556
		dc.w	$18e,$5a5
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
		dc.w	$182,$000
		dc.w	$186,$414
		dc.w	$184,$a28
		dc.w	$18c,$f8a
		dc.w	$188,$000
		dc.w	$18a,$556
		dc.w	$18e,$5a5
		COP_WAITH $80,$e0
		COP_SKIPV $ff
		dc.w	copjmp2,0

		dc.l	-2

Anim:
		incbin	data/dude_walking.BPL
		ds.b	DUDE_BW*PF1_BPLS

Bg:
		incbin	data/dude-bg.BPL

Sprite:
		dc.l	0
		rept	255
		dc.l	$07a00040
		endr
Sprite2:
		incbin	data/lamppost.SPR

; TODO:
; double line glitch

; blit padding on bg
; pre-render dude frames?
; try to save bytes on bss
