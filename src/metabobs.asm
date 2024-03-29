		include	src/_main.i
		include	src/metabobs.i

METABOBS_END_FRAME = $200
; METABOBS_END_FRAME = $400

;********************************************************************************
; Faux metaballs effect
;-------------------------------------------------------------------------------
; - Use blitter operation with concentric circles to smooth intersections
;   between bobs
; - Highlights are added with sprites
; - Copper driven blitter to maximize DMA and reduce blitter setup overhead
;
; Blitter operations:
;-------------------------------------------------------------------------------
; 1. Clear dirty regions on both screen and tmp buffer
;
; 2. Main circle COPY to screen bpl 0
;  _
; /0\
; \_/
;
; 3. Ascending groups of 4 bpls COPY to tmp buffer
;    _______
;   / __2__ \
;  / / _1_ \ \
; / / / 0 \ \ \
; \ \ \___/ / /
;  \ \_____/ /
;   \_______/
;
; 3. AND descending group with tmp buffer to get intersections with other outer circles
;    OR to dest (screen) to combine with main / other circles
;    _______  _______
;   / __0__ \/ __2__ \
;  / / _1_ \/\/ _1_ \ \
; / / / 2 \/\/\/ 0 \ \ \
; \ \ \___/\/\/\___/ / /
;  \ \_____/\/\_____/ /
;   \_______/\_______/
;        _      _
;       / \/\/\/ \
;       \_/\/\/\_/

********************************************************************************
* Constants:
********************************************************************************

; Display window:
DIW_W = 256
DIW_H = 190
BPLS = 4
SCROLL = 0				; enable playfield scroll
INTERLEAVED = 1
DPF = 0					; enable dual playfield

; Screen buffer:
SCREEN_W = DIW_W
SCREEN_H = DIW_H

BALL_COUNT = 4
BALL_R = 30				; Max radius for ball
BOB_W = 64+16
GROUP_COUNT = 8				; Number of size groups
MAX_R = BALL_R-BPLS


;-------------------------------------------------------------------------------
; Derived
BOB_H = BALL_R*2
BOB_BW = BOB_W/16*2
BOB_MOD = SCREEN_BW-BOB_BW
BOB_BLTSIZE = (BOB_H*BPLS)<<6!BOB_BW>>1
BOB_MOD_SINGLE = SCREEN_BW*BPLS-BOB_BW
BOB_BLTSIZE_SINGLE = (BOB_H-3)<<6!BOB_BW>>1
BOB_BPL = BOB_BW*BOB_H
BOB_SIZE = BOB_BPL*BPLS

SIZE_COUNT = GROUP_COUNT+BPLS		; Need to generate this many circle sizes
GROUP_SIZE = BOB_SIZE*2			; Consists of two interleaved images - bpls in asc and desc order

COLORS = 1<<BPLS

SCREEN_BW = SCREEN_W/16*2		; byte-width of 1 bitplane line
		ifne	INTERLEAVED
SCREEN_MOD = SCREEN_BW*(BPLS-1)		; modulo (interleaved)
SCREEN_BPL = SCREEN_BW			; bitplane offset (interleaved)
		else
SCREEN_MOD = 0				; modulo (non-interleaved)
SCREEN_BPL = SCREEN_BW*SCREEN_H		; bitplane offset (non-interleaved)
		endc
SCREEN_SIZE = SCREEN_BW*SCREEN_H*BPLS	; byte size of screen buffer

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
BPLCON0V = BPLS<<(12+DPF)!DPF<<10!$200


********************************************************************************
* Entry points:
********************************************************************************

Script:
		dc.l	0,CmdLerpPal,6-1,4,PalStart,Pal,PalOut
		dc.l	$40,CmdLerpPal,6-1,6,Pal,Pal2,PalOut
		dc.l	$80,CmdLerpPal,6-1,6,Pal2,Pal3,PalOut
		dc.l	$180,CmdLerpPal,6-1,6,Pal3,Pal,PalOut
		dc.l	METABOBS_END_FRAME-(1<<4),CmdLerpPal,6-1,4,Pal,PalEnd,PalOut
		dc.l	0,0


********************************************************************************
Metabobs_Vbi:
;-------------------------------------------------------------------------------
		rts

********************************************************************************
Metabobs_Effect:
;-------------------------------------------------------------------------------
		jsr	ResetFrameCounter
		jsr	Free

		move.w	#$012,d0
		jsr	BlankScreen

		move.l	#$100*$100,d0
		jsr	AllocPublic
		move.l	a0,SqrtTab
		bsr	InitSqrt

		move.l	#BOB_BPL*SIZE_COUNT,d0
		jsr	AllocChip
		move.l	a0,Circles

		move.l	#GROUP_SIZE*GROUP_COUNT,d0
		jsr	AllocChip
		move.l	a0,Groups

		move.l	#SCREEN_SIZE,d0
		jsr	AllocChip
		move.l	a0,DrawBuffer
		bsr	ClearScreen
		jsr	AllocChip
		move.l	a0,ViewBuffer
		bsr	ClearScreen
		jsr	AllocChip
		move.l	a0,DrawTmp
		bsr	ClearScreen
		jsr	AllocChip
		move.l	a0,ViewTmp
		bsr	ClearScreen

		move.l	#Q_SIZE,d0
		jsr	AllocChip
		move.l	a0,DrawCopQueue
		jsr	AllocChip
		move.l	a0,ViewCopQueue

		move.l	#(SprDatE-SprDat+6)*BALL_COUNT*2,d0
		jsr	AllocChip
		move.l	a0,Sprites

		bsr	InitSprites
		bsr	InitCircles
		bsr	InitCircleGroups
		bsr	InitBlitter
		bsr	InitCopQueues
		bsr	GenerateBalls

		lea	Cop2Lc+2,a0
		move.l	#CopEnd,d0
		move.w	d0,4(a0)
		swap	d0
		move.w	d0,(a0)

		lea	Cop,a0
		lea	Metabobs_Vbi,a1
		jsr	StartEffect

		lea	Script,a0
		jsr	Commander_Init

		move.w	#DMAF_SETCLR!DMAF_BLITHOG,dmacon(a6) ; Hog the blitter

Frame:
; Flip double buffers
		movem.l	DblBuffers(pc),d0-d7
		exg	d0,d1		; screen
		exg	d2,d3		; tmp
		exg	d4,d5		; offsets
		exg	d6,d7		; cop queue
		movem.l	d0-d7,DblBuffers

		bsr	Clear
		bsr	UpdateBalls
		bsr	DrawBobs

		bsr	LoadPal

		jsr	WaitEOF
		bsr	PokeCop

		bsr	DrawSprites
		cmp.l	#METABOBS_END_FRAME,CurrFrame
		blt	Frame

		move.w	#DMAF_BLITHOG!DMAF_SPRITE,dmacon(a6)
		move.w	#0,copcon(a6)

		rts


PokeCop:
		lea	CopBpls+2,a1
		move.l	DrawBuffer(pc),a0
		moveq	#BPLS-1,d7
.l0:
		move.l	a0,d2
		swap	d2
		move.w	d2,(a1)
		move.w	a0,4(a1)
		addq.w	#8,a1
		add.l	#SCREEN_BPL,a0
		dbf	d7,.l0

		; Don't load the copper queue until it's populated
		move.l	ViewOffsets(pc),a0
		tst.l	(a0)
		beq	.skip
		lea	Cop2Lc+2,a0
		move.l	ViewCopQueue(pc),d0
		move.w	d0,4(a0)
		swap	d0
		move.w	d0,(a0)
.skip		rts

ClearScreen:
		WAIT_BLIT
		move.l	a0,bltdpt(a6)
		move.l	#$01000000,bltcon0(a6)
		clr.l	bltdmod(a6)
		move.w	#(SCREEN_H*BPLS)<<6!(SCREEN_BW/2),bltsize(a6)
		rts

********************************************************************************
* Routines:
********************************************************************************

********************************************************************************
; Initialise sprite data
;-------------------------------------------------------------------------------
InitSprites:
		lea	SprPtrs,a0	; Pointers to sprite structs
		move.l	Sprites,a1	; Sprite structs data
		moveq	#0,d2

		; Create sprite 1 for each ball:
		moveq	#BALL_COUNT-1,d0
.sprite:
		move.l	a1,(a0)+	; Store pointer to sprite struct
		move.l	d2,(a1)+	; Placeholder for control words
		; Copy sprite image data in longwords
		lea	SprDat+6(pc),a2	; Image data
		move.w	#(SprDatE-SprDat)/4-1,d1
.cp		move.l	(a2)+,(a1)+
		dbf	d1,.cp
		move.w	d2,(a1)+	; End of sprite struct
		dbf	d0,.sprite

		; Create sprite 2 for each ball:
		moveq	#BALL_COUNT-1,d0
.sprite2:
		move.l	a1,(a0)+	; Store pointer to sprite struct
		move.l	d2,(a1)+	; Placeholder for control words
		; Copy sprite image data in longwords
		lea	SprDat2+6(pc),a2 ; Image data
		move.w	#(SprDatE-SprDat)/4-1,d1
.cp2		move.l	(a2)+,(a1)+
		dbf	d1,.cp2
		move.w	d2,(a1)+	; End of sprite struct
		dbf	d0,.sprite2

		rts


********************************************************************************
; Draw and fill individual circles at each size
;-------------------------------------------------------------------------------
; This populates the `Circles` data.
; It draws a range of `SIZE_COUNT` filled circles in ascending sizes up to max radius.
; This means that the smallest (first) circle is BALL_R-SIZE_COUNT+1
;-------------------------------------------------------------------------------
InitCircles:
		move.l	Circles(pc),a0
		; Initial radius for smallest circle
		moveq	#BALL_R-SIZE_COUNT+1,d0
		moveq	#BALL_R,d1	; x
		moveq	#BALL_R,d2	; y
		; Init common blitter regs
		move.l	#-1,bltafwm(a6)
		move.l	#0,bltamod(a6)
		moveq	#SIZE_COUNT-1,d7
.l:
		; Draw the circle outline
		move.w	#BOB_BW,d1
		jsr	DrawCircleFill
		; Blitter fill
		lea	BOB_BPL-1(a0),a1 ; offset for descending blit
		WAIT_BLIT
		move.l	#$09f00012,bltcon0(a6)
		move.l	a1,bltapth(a6)
		move.l	a1,bltdpth(a6)
		move.w	#BOB_H<<6!BOB_BW>>1,bltsize(a6)
		lea	BOB_BPL(a0),a0	; next bpl
		addq	#1,d0
		dbf	d7,.l
		rts


********************************************************************************
InitBlitter:
;-------------------------------------------------------------------------------
		move.l	#-1,bltafwm(a6)
		move.w	#0,bltcon1(a6)
		rts


********************************************************************************
InitCopQueues:
;-------------------------------------------------------------------------------
		move.w	#2,copcon(a6)	; copper danger mode to allow blit queue
		move.l	ViewCopQueue,a0
		bsr	InitCopQueue
		move.l	DrawCopQueue,a0


********************************************************************************
; Initialise copper queue list
;-------------------------------------------------------------------------------
; a0 - Queue list ptr
;-------------------------------------------------------------------------------
InitCopQueue:

; Offsets for placeholder values
Q_BLTCON0 = 1*4+2
Q_BLTDPTH = 2*4+2
Q_BLTDPTL = 3*4+2
Q_BLTAPTH = 4*4+2
Q_BLTAPTL = 5*4+2
Q_BLTCPTH = 6*4+2
Q_BLTCPTL = 7*4+2
Q_BLTBPTH = 8*4+2
Q_BLTBPTL = 9*4+2

;-------------------------------------------------------------------------------
; Sprite pointers
;-------------------------------------------------------------------------------

Q_SPR_ITEM = 4*2
Q_SPR_SIZE = 8*Q_SPR_ITEM
; Set all sprites to null
		move.l	0,d0
		rept	8
		swap	d0
		COPQ_MOVEW d0,(spr0pth+REPTN*4)
		swap	d0
		COPQ_MOVEW d0,(spr0ptl+REPTN*4)
		endr

;-------------------------------------------------------------------------------
; Clear bobs from previous draw:
;-------------------------------------------------------------------------------

Q_CLEAR_STRT = Q_SPR_SIZE+3*4
Q_CLEAR_ITEM = 4*4
Q_CLEAR_SIZE = Q_CLEAR_ITEM*BALL_COUNT*2

		COPQ_WAITBLIT
		COPQ_MOVEI BOB_MOD,bltdmod
		COPQ_MOVEI $100,bltcon0
		; * 2 because we clear from both view buffer and tmp
		moveq	#BALL_COUNT*2-1,d0
.clr:
		COPQ_WAITBLIT
		COPQ_MOVEI 0,bltdpth
		COPQ_MOVEI 0,bltdptl
		COPQ_MOVEI BOB_BLTSIZE,bltsize
		dbf	d0,.clr

;-------------------------------------------------------------------------------
; Main circles:
;-------------------------------------------------------------------------------

Q_MAIN_STRT = Q_CLEAR_STRT+Q_CLEAR_SIZE+4*4
Q_MAIN_ITEM = 9*4
Q_MAIN_SIZE = Q_MAIN_ITEM*BALL_COUNT

		COPQ_WAITBLIT
		COPQ_MOVEI 0,bltamod
		COPQ_MOVEI BOB_MOD_SINGLE,bltcmod
		COPQ_MOVEI BOB_MOD_SINGLE,bltdmod

		moveq	#BALL_COUNT-1,d0
.copyMain:
		COPQ_WAITBLIT
		COPQ_MOVEI $0bfa,bltcon0
		COPQ_MOVEI 0,bltdpth	; D - screen
		COPQ_MOVEI 0,bltdptl
		COPQ_MOVEI 0,bltapth	; A - circle
		COPQ_MOVEI 0,bltaptl
		COPQ_MOVEI 0,bltcpth	; C - screen
		COPQ_MOVEI 0,bltcptl
		COPQ_MOVEI BOB_BLTSIZE_SINGLE,bltsize
		dbf	d0,.copyMain

;-------------------------------------------------------------------------------
; Outer circles:
;-------------------------------------------------------------------------------

Q_OUTER_STRT = Q_MAIN_STRT+Q_MAIN_SIZE+4*4
Q_OUTER_AND = 11*4
Q_OUTER_OR = 9*4
Q_OUTER_ITEM = Q_OUTER_AND+Q_OUTER_OR
Q_OUTER_SIZE = Q_OUTER_ITEM*BALL_COUNT

		COPQ_WAITBLIT
		COPQ_MOVEI BOB_MOD,bltbmod
		COPQ_MOVEI BOB_MOD,bltcmod
		COPQ_MOVEI BOB_MOD,bltdmod

		moveq	#BALL_COUNT-1,d0
.outer:
; AND with tmp to screen
		COPQ_WAITBLIT
		COPQ_MOVEI $fea,bltcon0
		COPQ_MOVEI 0,bltdpth	; D - screen
		COPQ_MOVEI 0,bltdptl
		COPQ_MOVEI 0,bltapth	; A - group ASC
		COPQ_MOVEI 0,bltaptl
		COPQ_MOVEI 0,bltcpth	; C - screen
		COPQ_MOVEI 0,bltcptl
		COPQ_MOVEI 0,bltbpth	; B - tmp
		COPQ_MOVEI 0,bltbptl
		cmp.w	#BALL_COUNT-1,d0
		; Skip this blit on first circle
		; Quickest way without changing offsets is to NOP instead of setting bltsize
		; Potential optimisation to do this properly
		beq	.first
		COPQ_MOVEI BOB_BLTSIZE,bltsize
		bra	.endTmp
.first
		COPQ_NOP
.endTmp
; OR to tmp
		COPQ_WAITBLIT
		COPQ_MOVEI $bfa,bltcon0
		COPQ_MOVEI 0,bltdpth	; D - tmp
		COPQ_MOVEI 0,bltdptl
		COPQ_MOVEI 0,bltapth	; A - group DESC
		COPQ_MOVEI 0,bltaptl
		COPQ_MOVEI 0,bltcpth	; C - tmp
		COPQ_MOVEI 0,bltcptl
		COPQ_MOVEI BOB_BLTSIZE,bltsize
		dbf	d0,.outer

; End copper list
		COPQ_WAITBLIT
		;COPQ_MOVEI $ff0,color00				; Profile remaining raster time
		COPQ_END

Q_SIZE = Q_OUTER_STRT+Q_OUTER_SIZE+4*4
		rts


********************************************************************************
; Create interleaved bitplanes for size groups
;-------------------------------------------------------------------------------
InitCircleGroups:
		moveq	#GROUP_COUNT-1,d7
		move.l	Groups(pc),a0
		move.l	Circles(pc),a1
		lea	GroupPtrs,a2
		lea	CirclePtrs,a3
.l:
		move.l	a0,(a2)+	; Store ptrs
		move.l	a1,(a3)+
		bsr	InitCircleGroup
		lea	GROUP_SIZE(a0),a0 ; next group
		lea	BOB_BPL(a1),a1	; next circle size
		dbf	d7,.l
		rts

InitCircleGroup:
		movem.l	d0-a6,-(sp)
		move.l	a0,a5
		lea	BOB_BPL(a1),a1
		move.l	a1,d1
; Source per bitplane in ascending size
		lea	BOB_BPL(a1),a2
		lea	BOB_BPL(a2),a3
		lea	BOB_BPL(a3),a4
		bsr	.writeInterleaved

; In descending size
		lea	BOB_SIZE(a5),a0
		move.l	d1,a4
		lea	BOB_BPL(a4),a3
		lea	BOB_BPL(a3),a2
		lea	BOB_BPL(a2),a1
		bsr	.writeInterleaved
		movem.l	(sp)+,d0-a6
		rts

.writeInterleaved:
		moveq	#BOB_H-1,d0
.l0:
		rept	BOB_BW/2
		move.w	(a1)+,(a0)+
		endr
		rept	BOB_BW/2
		move.w	(a2)+,(a0)+
		endr
		rept	BOB_BW/2
		move.w	(a3)+,(a0)+
		endr
		rept	BOB_BW/2
		move.w	(a4)+,(a0)+
		endr
		dbf	d0,.l0
		rts


********************************************************************************
; Clear existing bobs by writing stored offsets to copper blit queue
;-------------------------------------------------------------------------------
Clear:
		move.l	DrawOffsets(pc),a0
		move.l	DrawCopQueue,a1
		lea	Q_CLEAR_STRT-4(a1),a1
		moveq	#BALL_COUNT*2-1,d0
.l0:
		move.l	(a0)+,d1
		move.w	d1,Q_BLTDPTL(a1)
		swap	d1
		move.w	d1,Q_BLTDPTH(a1)
		lea	Q_CLEAR_ITEM(a1),a1
		dbf	d0,.l0
		rts


********************************************************************************
; Update sprite positions and pointers in copper list
;-------------------------------------------------------------------------------
DrawSprites:
		move.l	ViewCopQueue(pc),a0
		lea	SprPtrs,a1
		lea	SprPtrs+4*4,a4
		lea	Balls,a2
		moveq	#BALL_COUNT-1,d7
.l:
		move.l	(a1)+,a3	; next sprite
		move.l	(a4)+,a5
; Set pointers:
		move.l	a3,d3
		move.w	d3,6(a0)
		swap	d3
		move.w	d3,2(a0)

		move.l	a5,d3
		move.w	d3,6+Q_SPR_ITEM*4(a0)
		swap	d3
		move.w	d3,2+Q_SPR_ITEM*4(a0)

		lea	Q_SPR_ITEM(a0),a0 ; next reg pair in copper list
; control words:
		move.w	Ball_X(a2),d0
		move.w	Ball_Y(a2),d1
		; center
		add.w	#SCREEN_W/2-BALL_R,d0
		add.w	#SCREEN_H/2-BALL_R,d1

		move.w	d0,d3
		sub.w	#DIW_W/2,d3
		asr	#4,d3
		neg.w	d3
		subq	#6,d3

		; muls #BALL_R,d3
		; move.w #BALL_R-GROUP_COUNT,d4
		; add.w Ball_R(a2),d4
		; divs d4,d3

		add.w	d3,d0

		move.w	d1,d3
		sub.w	#DIW_H/2,d3
		asr	#5,d3
		neg.w	d3
		subq	#7,d3

		; muls #BALL_R,d3
		; move.w #BALL_R-GROUP_COUNT,d4
		; add.w Ball_R(a2),d4
		; divs d4,d3

		add.w	d3,d1

		add.w	#DIW_XSTRT+BALL_R-8,d0 ; center
		add.w	#DIW_YSTRT+BALL_R-10,d1


		move.w	d0,d3
		and.b	#1,d3
		lsr.w	d0
		move.b	d1,(a3)+	; vstart
		move.b	d1,(a5)+
		move.b	d0,(a3)+	; hstart upper
		move.b	d0,(a5)+
		add.b	#20,d1
		move.b	d1,(a3)+	; vstop
		move.b	d1,(a5)+
		move.b	d3,(a3)+	; hstart lower
		move.b	d3,(a5)+
		lea	Ball_SIZEOF(a2),a2

		dbf	d7,.l
		rts


********************************************************************************
; Populate values for new bobs in copper list
;-------------------------------------------------------------------------------
DrawBobs:
		movem.l	d0-a6,-(sp)
		move.l	DrawBuffer(pc),d6
		lea	CirclePtrs,a0	; Individual circles
		move.l	DrawTmp(pc),a1	; Temp buffer
		move.l	DrawOffsets(pc),a2 ; Offsets for clear
		move.l	DrawCopQueue(pc),a3
		lea	Q_OUTER_STRT(a3),a4 ; a4 = Outer ptr
		lea	Q_MAIN_STRT(a3),a3 ; a3 = Main ptr
		lea	Balls,a5	; Ball structs for position/scale data
		lea	GroupPtrs,a6

		moveq	#BALL_COUNT-1,d7
.l:
		move.w	Ball_X(a5),d0
		move.w	Ball_Y(a5),d1
		move.w	Ball_R(a5),d2
		lea	Ball_SIZEOF(a5),a5
		; center
		add.w	#SCREEN_W/2-BALL_R,d0
		add.w	#SCREEN_H/2-BALL_R,d1

		; convert radius to offset
		sub.w	#MAX_R,d2
		add.w	#GROUP_COUNT-1,d2

		; 0 = smallest
		; max - group count?


		; GROUP_COUNT-1 = largest
		; should be BALL_R, but isn't?
		; this is because of the outer bpls
		; need to use this radius for bounds check, but not collisions

; Set src ptrs using scale as offset to select correct size
		lsl.w	#2,d2		; *4 for longword offset
		move.l	(a0,d2.w),d3	; d3 = single circle
		move.l	(a6,d2.w),d4	; d4 = circle group ASC
		move.l	d4,d5		; d5 = circle group DESC
		add.l	#BOB_SIZE,d5

		mulu	#SCREEN_BW*BPLS,d1 ; d1 = yOffset (bytes)
; x shift:
		moveq	#15,d2
		and.w	d0,d2		; d2 = hshift
		ror.w	#4,d2		; move to upper nibble
; clear and update upper nibbles in bltcon0 insts
		and.w	#$fff,Q_BLTCON0(a3)
		and.w	#$fff,Q_BLTCON0(a4)
		and.w	#$fff,Q_BLTCON0+Q_OUTER_AND(a4)
		or.w	d2,Q_BLTCON0(a3)
		or.w	d2,Q_BLTCON0(a4)
		or.w	d2,Q_BLTCON0+Q_OUTER_AND(a4)
; offset:
		asr.w	#3,d0		; d0 = xOffset (bytes)
		add.l	d0,d1		; d1 = totalOffset = yOffset + xOffset
		move.l	d1,d2
		add.l	d6,d1		; d1 = screen with offset
		add.l	a1,d2		; d2 = tmp with offset
		move.l	d1,(a2)+	; store offset for clearing
		move.l	d2,(a2)+
; Low ptrs
		move.w	d1,Q_BLTDPTL(a3) ; Main: d = screen
		move.w	d3,Q_BLTAPTL(a3) ;       a = circle
		move.w	d1,Q_BLTCPTL(a3) ;       c = screen
		move.w	d1,Q_BLTDPTL(a4) ; AND:  d = screen
		move.w	d4,Q_BLTAPTL(a4) ;       a = group asc
		move.w	d1,Q_BLTCPTL(a4) ;       c = screen
		move.w	d2,Q_BLTBPTL(a4) ;       b = tmp
		move.w	d2,Q_BLTDPTL+Q_OUTER_AND(a4) ; OR:   d = tmp
		move.w	d5,Q_BLTAPTL+Q_OUTER_AND(a4) ;       a = group desc
		move.w	d2,Q_BLTCPTL+Q_OUTER_AND(a4) ;       c = tmp
; Hi ptrs
		swap	d1
		swap	d2
		swap	d3
		swap	d4
		swap	d5
		move.w	d1,Q_BLTDPTH(a3) ; Main: d = screen
		move.w	d3,Q_BLTAPTH(a3) ;       a = circle
		move.w	d1,Q_BLTCPTH(a3) ;       c = screen
		move.w	d1,Q_BLTDPTH(a4) ; AND:  d = screen
		move.w	d4,Q_BLTAPTH(a4) ;       a = group asc
		move.w	d1,Q_BLTCPTH(a4) ;       c = screen
		move.w	d2,Q_BLTBPTH(a4) ;       b = tmp
		move.w	d2,Q_BLTDPTH+Q_OUTER_AND(a4) ; OR:   d = tmp
		move.w	d5,Q_BLTAPTH+Q_OUTER_AND(a4) ;       a = group desc
		move.w	d2,Q_BLTCPTH+Q_OUTER_AND(a4) ;       c = tmp
		swap	d3
		swap	d4
		swap	d5
; next item...
		lea	Q_MAIN_ITEM(a3),a3
		lea	Q_OUTER_ITEM(a4),a4
		dbf	d7,.l
;-------------------------------------------------------------------------------
		movem.l	(sp)+,d0-a6
		rts

		rsreset
COL_BG		rs.w	1
COL_MID		rs.w	1
COL_FILL	rs.w	1
COL_HL1		rs.w	1
COL_HL2		rs.w	1
COL_HL3		rs.w	1

LoadPal:
		move.l	PalOut,a0
		lea	CopPal+2,a1
		move.w	COL_BG(a0),(a1)
		move.w	COL_FILL(a0),4(a1)
		move.w	COL_MID(a0),8(a1)
		move.w	COL_FILL(a0),12(a1)
		move.w	COL_MID(a0),16(a1)
		move.w	COL_FILL(a0),20(a1)
		move.w	COL_FILL(a0),24(a1)
		move.w	COL_FILL(a0),28(a1)
		move.w	COL_MID(a0),32(a1)
		move.w	COL_FILL(a0),36(a1)
		move.w	COL_FILL(a0),40(a1)
		move.w	COL_FILL(a0),44(a1)
		move.w	COL_FILL(a0),48(a1)
		move.w	COL_FILL(a0),52(a1)
		move.w	COL_FILL(a0),56(a1)
		move.w	COL_FILL(a0),60(a1)
		moveq	#4-1,d7
.l
		move.w	COL_HL1(a0),68(a1)
		move.w	COL_HL2(a0),72(a1)
		move.w	COL_HL3(a0),76(a1)
		lea	16(a1),a1
		dbf	d7,.l
		rts


********************************************************************************
InitSqrt:
		move.l	SqrtTab,a0
		moveq	#0,d0
.loop0:		move.w	d0,d1
		add.w	d1,d1
.loop1:		move.b	d0,(a0)+
		dbf	d1,.loop1
		addq.b	#1,d0
		bcc.s	.loop0
		rts


********************************************************************************
GenerateBalls:
		move.l	#(MAX_R)<<16,d2
		lea	Balls,a1
		move.l	#$162b28ba,RandomSeed
		moveq	#BALL_COUNT-1,d1
.l:
; x
		jsr	Random32
		asr.l	#8,d0
		move.l	d0,(a1)+
; y
		jsr	Random32
		asr.l	#8,d0
		asr.l	#1,d0
		move.l	d0,(a1)+
; r
		move.l	d2,(a1)+
		sub.l	#1<<16,d2
; vx
		jsr	Random32
		ext.l	d0
		lsl.l	#1,d0
		move.l	d0,(a1)+
; vy
		jsr	Random32
		ext.l	d0
		lsl.l	#1,d0
		move.l	d0,(a1)+
.no0

		dbf	d1,.l
		move.l	#BALLS_END,(a1)+
		rts

UpdateBalls:
		movem.l	d0-a6,-(sp)
		lea	Balls,a5
		moveq	#BALL_COUNT-1,d7
.l:
		movem.l	(a5),d0-d4
		bsr	UpdateBall
		lea	Ball_SIZEOF(a5),a5
		dbf	d7,.l
		movem.l	(sp)+,d0-a6
		rts

********************************************************************************
; Update position/velocity for a single ball
;-------------------------------------------------------------------------------
; d0 = x
; d1 = y
; d2 = r
; d3 = vx
; d4 = vy
;-------------------------------------------------------------------------------
UpdateBall:
		movem.l	d0-a6,-(sp)	; Only back up what we need

; Add velocity to position
		add.l	d3,d0
		add.l	d4,d1
		bsr	CheckBoundsRect
; Update props
		movem.l	d0-d4,(a5)

		bsr	CheckCollisions
		movem.l	(sp)+,d0-a6
		rts



********************************************************************************
; Check bounds: rectangle
;-------------------------------------------------------------------------------
CheckBoundsRect:
		move.l	#(DIW_W/2-10)<<16,d5 ; d5 = maxX = width/2-r
		sub.l	d2,d5

		cmp.l	d5,d0		; Check maxX
		ble	.xmaxOk
		move.l	d5,d0
		neg.l	d3
.xmaxOk
		neg.l	d5
		cmp.l	d5,d0		; Check minX (r)
		bge	.xminOk
		move.l	d5,d0
		neg.l	d3
.xminOk

		move.l	#(DIW_H/2-10)<<16,d5 ; d5 = maxX = width/2-r
		sub.l	d2,d5

		cmp.l	d5,d1		; Check max Y
		ble	.ymaxOk
		move.l	d5,d1
		neg.l	d4
.ymaxOk
		neg.l	d5
		cmp.l	d5,d1		; Check min Y (r)
		bge	.yminOk
		move.l	d5,d1
		neg.l	d4
.yminOk
		rts


; Floating point accuracy for various operations
; tweak these for balance between inaccuracy and overflow
TRANSFORM_ACC = 5
COL_OVERLAP_ACC = 5
COL_NORM_ACC = 5
BOUNDS_NORM_ACC = 2
BOUNDS_REFLECT_ACC = 4

; Radius for circluar bounds check
BOUNDS_R = DIW_H/2

; Rectangular bounds
BOUNDS_X = DIW_W/2
BOUNDS_Y = DIW_H/2

BALLS_END = $7fffffff			; Magic number for end of array


********************************************************************************
; Check collisons with other balls
;-------------------------------------------------------------------------------
; d0 = x
; d1 = y
; d2 = r
; d3 = vx
; d4 = vy
; a5 = ptr to current ball
;-------------------------------------------------------------------------------
CheckCollisions:
		move.l	a5,a4		; a4 = target (other ball to compare)
		swap	d2
		move.w	d2,d7
		subq	#1,d7		; d7 = r
		move.l	#BALLS_END,d6	; magic number for end of array
.next:
		lea	Ball_SIZEOF(a4),a4
		move.l	Ball_X(a4),d2
		cmp.l	d6,d2		; last item?
		bne	.notLast
		rts			; exit
.notLast

		move.w	Ball_R(a4),d4
		add.w	d7,d4		; d4 = maxDist = r1+r2

; Check rect bounds first:
		sub.l	d0,d2		; d2 = dx
		move.l	d2,a0		; a0 = dx (backup before swap)
		swap	d2
		cmp.w	d4,d2
		bgt.b	.next
		move.l	Ball_Y(a4),d5
		sub.l	d1,d5		; d5 = dy
		move.l	d5,a1		; a1 = dy
		swap	d5
		cmp.w	d4,d5
		bgt.b	.next
		neg.w	d4
		cmp.w	d4,d2
		blt.b	.next
		cmp.w	d4,d5
		blt.b	.next
		neg.w	d4

; Check distance^2:
		move.w	d4,a2		; a2 = maxDist
		mulu	d4,d4		; d4 = maxDist^2 = (r1+r2)^2
		muls	d2,d2
		muls	d5,d5
		add.l	d5,d2		; d2 = dist^2 = dx^2+dy^2
		bne.b	.notZero	; min value to protect against divide by zero
		moveq	#1,d2
.notZero
; Hit if dist^2 < maxDist^2:
		cmp.l	d4,d2
		bge.b	.next
; Hit!:
; Get actual dist using sqrt lookup
		move.l	SqrtTab,a3
		move.b	(a3,d2.w),d2	; d2 = dist
		and.w	#$ff,d2
; Get overlap:
		move.w	a2,d5
		sub.w	d2,d5		; d5 = (maxDist - dist) / 2 = overlap (FP)

; use maxDist as d
; stops velocities spiraling upwards
		move.l	a2,d2

; Update velocities:
; normal vector n
		move.l	a0,d3		; d3 = nx = dx/d
		asr.l	#8,d3
		divs	d2,d3
		ext.l	d3
		move.l	a1,d4		; d4 = ny = dy/d
		asr.l	#8,d4
		divs	d2,d4

		asr.l	#8,d3
		asr.l	#8,d4

		; muls	d5,d3
		; muls	d5,d4

		; asr.l	#4,d4
		; asr.l	#4,d3

		sub.l	d3,Ball_VX(a4)
		add.l	d3,Ball_VX(a5)
		sub.l	d4,Ball_VY(a4)
		add.l	d4,Ball_VY(a5)

		bra	.next


********************************************************************************
Vars:
********************************************************************************

DblBuffers:
;-------------------------------------------------------------------------------
DrawBuffer:	dc.l	0
ViewBuffer:	dc.l	0
DrawTmp:	dc.l	0
ViewTmp:	dc.l	0
DrawOffsets:	dc.l	Offsets2
ViewOffsets:	dc.l	Offsets
DrawCopQueue:	dc.l	0
ViewCopQueue:	dc.l	0

; Circle sizes as individual bitplanes
; Generated by InitCircles
Circles:	dc.l	0

; Interleaved image data pairs:
; Data for outer circles with bitplanes in ascending and descending size order
Groups:		dc.l	0

Sprites:	dc.l	0

Offsets:	ds.l	BALL_COUNT*2
Offsets2:	ds.l	BALL_COUNT*2

CirclePtrs:
		ds.l	GROUP_COUNT
GroupPtrs:
		ds.l	GROUP_COUNT

SprPtrs:	ds.l	BALL_COUNT*2	; Pointers to sprite structs

PalOut:		dc.l	PalStart

SqrtTab:	dc.l	0

********************************************************************************
Data:
********************************************************************************

		rsreset
Ball_X		rs.l	1
Ball_Y		rs.l	1
Ball_R		rs.l	1
Ball_VX		rs.l	1
Ball_VY		rs.l	1
; Ball_Col	rs.l	1
Ball_SIZEOF	rs.b	0

Balls:		ds.b	Ball_SIZEOF*BALL_COUNT+2 ; TODO: alloc

SprDat:
		incbin	"data/ball-highlight-b.SPR"
SprDatE:
SprDat2:
		incbin	"data/ball-highlight-a.SPR"
SprDat2E:

; Color palette:
; https://gradient-blaster.grahambates.com/?points=024@0,226@2,f4d@5&steps=6&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
Pal:
		dc.w	$012,$313,$515,$627,$a2b,$d2c
Pal2:
		dc.w	$012,$313,$515,$647,$57a,$2ad
Pal3:
		dc.w	$012,$313,$515,$836,$c57,$f88
PalStart
		rept	6
		dc.w	0
		endr
PalEnd
		rept	6
		dc.w	$024
		endr

*******************************************************************************
		data_c
*******************************************************************************

Cop:
		dc.w	diwstrt,DIW_STRT
		dc.w	diwstop,DIW_STOP
		dc.w	ddfstrt,DDF_STRT
		dc.w	ddfstop,DDF_STOP
		dc.w	bplcon0,BPLCON0V
		dc.w	bpl1mod,DIW_MOD
		dc.w	bpl2mod,DIW_MOD
		dc.w	dmacon,DMAF_SETCLR!DMAF_SPRITE

CopBpls:
		dc.w	bpl0pt,0
		dc.w	bpl0ptl,0
		dc.w	bpl1pt,0
		dc.w	bpl1ptl,0
		dc.w	bpl2pt,0
		dc.w	bpl2ptl,0
		dc.w	bpl3pt,0
		dc.w	bpl3ptl,0
		dc.w	bpl4pt,0
		dc.w	bpl4ptl,0

CopPal:
		dc.w	color00,0
		dc.w	color01,0
		dc.w	color02,0
		dc.w	color03,0
		dc.w	color04,0
		dc.w	color05,0
		dc.w	color06,0
		dc.w	color07,0
		dc.w	color08,0
		dc.w	color09,0
		dc.w	color10,0
		dc.w	color11,0
		dc.w	color12,0
		dc.w	color13,0
		dc.w	color14,0
		dc.w	color15,0
		dc.w	color16,0
		dc.w	color17,0
		dc.w	color18,0
		dc.w	color19,0
		dc.w	color20,0
		dc.w	color21,0
		dc.w	color22,0
		dc.w	color23,0
		dc.w	color24,0
		dc.w	color25,0
		dc.w	color26,0
		dc.w	color27,0
		dc.w	color28,0
		dc.w	color29,0
		dc.w	color30,0
		dc.w	color31,0

Cop2Lc		dc.w	cop2lch,0
		dc.w	cop2lcl,0
		dc.w	copjmp2,0
CopE:
CopEnd:		dc.l	-2
