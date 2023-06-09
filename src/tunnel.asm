		include	"src/_main.i"
		include	"tunnel.i"

TUNNEL_END_FRAME = $3ff

SRC_W = 64
SRC_H = 64
DEST_W = 82
DEST_H = 122
ROW_BW = 492
CHUNKY_H = 90
CHUNKY_W = 50

PAN_X = (DEST_W-CHUNKY_W)/2
PAN_Y = (DEST_H-CHUNKY_H)/2

SRC_SIZE = SRC_W*SRC_H*2
SHADES = 14

; Display window:
DIW_W = 112
DIW_H = 272
DIW_XSTRT = $71

BPLS = 4

DMA_SET = DMAF_SETCLR!DMAF_MASTER!DMAF_RASTER!DMAF_COPPER

;-------------------------------------------------------------------------------
; Derived

COLORS = 1<<BPLS

DIW_BW = DIW_W/16*2
DIW_YSTRT = ($158-DIW_H)/2
DIW_YSTOP = DIW_YSTRT+DIW_H
DIW_XSTOP = DIW_XSTRT+DIW_W
DIW_STRT = ((DIW_YSTRT+1)<<8)!DIW_XSTRT
DIW_STOP = (DIW_YSTRT+1+DIW_H-256)<<8+DIW_XSTOP
DDF_STRT = ((DIW_XSTRT-17)>>1)+$20&$00fc
DDF_STOP = ((DIW_XSTRT-17+(((DIW_W>>4)-1)<<4))>>1)+$20&$00fc

		rsreset
CopC_OddCols	rs.l	CHUNKY_W/2
CopC_Wait	rs.l	1
CopC_EvenCols	rs.l	CHUNKY_W/2
CopC_Bg		rs.l	1
CopC_Loc	rs.l	1
CopC_Skip	rs.l	1
CopC_Jmp	rs.l	1
CopC_SIZEOF	rs.b	0

Script:
		; dc.l	$80,CmdMoveIW,1,XSpeed
		; dc.l	$140,CmdMoveIW,-1,XSpeed
		; dc.l	$180,CmdLerpWord,2,4,XSpeed
		; dc.l	$1c0,CmdLerpWord,-2,4,XSpeed
		; dc.l	$200,CmdLerpWord,1,4,XSpeed
		dc.l	0,0


********************************************************************************
Tunnel_Effect:
		jsr	ResetFrameCounter
		jsr	Free
		lea	BlankCop,a0
		sub.l	a1,a1
		jsr	StartEffect

		move.l	#SRC_SIZE*2*SHADES,d0
		jsr	AllocPublic
		move.l	a0,Shades

		move.l	#CopTemplateE-CopTemplate+CopC_SIZEOF*CHUNKY_H+4,d0
		jsr	AllocChipAligned
		move.l	a0,Cop

		bsr	InitChunky
		bsr	InitShades

		lea	ChunkyImage,a0
		move.l	Shades(pc),a1
		moveq	#1,d0

		moveq	#14-1,d7
.f		bsr.w	FadeRGB
		lea	SRC_SIZE*2(a1),a1
		addq	#1,d0
		dbf	d7,.f

		move.l	Cop,a0
		sub.l	a1,a1
		jsr	StartEffect

		lea	Script,a0
		jsr	Commander_Init
Frame:
		bsr	Update
		bsr	Draw

		lea	custom,a6
		jsr	WaitEOF

		cmp.l	#TUNNEL_END_FRAME,CurrFrame
		blt	Frame

		clr.l	spr0data(a6)
		clr.l	spr1data(a6)
		clr.l	spr2data(a6)
		clr.l	spr3data(a6)
		clr.l	spr4data(a6)
		clr.l	spr5data(a6)
		clr.l	spr6data(a6)
		clr.l	spr7data(a6)

		rts

NullSprite:	dc.l	0

********************************************************************************
* Routines:
********************************************************************************

********************************************************************************
InitChunky:
; Copy copper template
		lea	CopTemplate,a1
		move.w	#(CopTemplateE-CopTemplate)/4-1,d7
.cp		move.l	(a1)+,(a0)+
		dbf	d7,.cp

		move.w	#DIW_YSTRT+1,d0
		move.w	#CHUNKY_H-1,d7
.row
		move.l	a0,a1					; Store address for jump
		addq	#8,a1

		addq	#3,d0
		cmp.w	#$fd,d0
		bne	.ok
		subq	#1,d0
.ok
		move.l	#color02<<16!$123,(a0)+			;CopC_OddCols
		; skip 3
		move.l	#color04<<16!$123,(a0)+
		move.l	#color05<<16!$123,(a0)+
		move.l	#color06<<16!$123,(a0)+
		move.l	#color07<<16!$123,(a0)+
		move.l	#color08<<16!$123,(a0)+
		move.l	#color09<<16!$123,(a0)+
		move.l	#color10<<16!$123,(a0)+
		move.l	#color11<<16!$123,(a0)+
		move.l	#color12<<16!$123,(a0)+
		move.l	#color13<<16!$123,(a0)+
		move.l	#color14<<16!$123,(a0)+
		move.l	#color15<<16!$123,(a0)+
		; skip 16
		move.l	#color17<<16!$123,(a0)+
		move.l	#color18<<16!$123,(a0)+
		move.l	#color19<<16!$123,(a0)+
		; skip 20
		move.l	#color21<<16!$123,(a0)+
		move.l	#color22<<16!$123,(a0)+
		move.l	#color23<<16!$123,(a0)+
		; skip 24
		move.l	#color25<<16!$123,(a0)+
		move.l	#color26<<16!$123,(a0)+
		move.l	#color27<<16!$123,(a0)+
		; skip 28
		move.l	#color29<<16!$123,(a0)+
		move.l	#color30<<16!$123,(a0)+
		move.l	#color31<<16!$123,(a0)+

		move.w	#$80,d1					;CopC_Wait
		and.w	d0,d1
		move.b	d1,(a0)+
		move.b	#$5d,(a0)+
		move.w	#$805c,(a0)+

		move.w	#CHUNKY_W/2-1,d6
.evenCol	move.l	#color00<<16!$123,(a0)+
		dbf	d6,.evenCol

		move.l	#color00<<16!$123,(a0)+			;CopC_Bg
		move.w	#(cop2lc+2),(a0)+			;CopC_Loc
		move.w	a1,(a0)+
		move.b	d0,(a0)+				;CopC_Skip
		move.b	#31,(a0)+
		move.w	#$ffff,(a0)+
		move.l	#copjmp2<<16,(a0)+			;CopC_Jmp
		dbf	d7,.row

		; end copper
		move.l	#-2,(a0)+

		move.l	Cop,a2
;-------------------------------------------------------------------------------
; Sprites
		lea	Sprites,a0
		lea	CopSprPt+2-CopTemplate(a2),a1
		moveq	#8-1,d0
.spr:
		move.l	a0,d1
		swap	d1
		move.w	d1,(a1)
		move.w	a0,4(a1)
		lea	8(a0),a0
		lea	8(a1),a1
		dbf	d0,.spr
;-------------------------------------------------------------------------------
; Bpls:
		lea	Bpls,a0
		lea	CopBplPt+2-CopTemplate(a2),a1
		moveq	#BPLS-1,d0
.bpls:
		move.l	a0,d1
		swap	d1
		move.w	d1,(a1)
		move.w	a0,4(a1)
		lea	14(a0),a0
		lea	8(a1),a1
		dbf	d0,.bpls

		rts


********************************************************************************
InitShades:
; Populate multiplication LUTs for RGB fade
;-------------------------------------------------------------------------------
		lea	RGBTbl,a0
		lea	RGBTbl4,a1
		moveq	#0,d2
		moveq	#16-1,d0
.y		moveq	#0,d3
		moveq	#16-1,d1
.x		move.w	d3,d4
		add.w	#$88,d4
		lsr.w	#8,d4
		move.b	d4,(a0)+
		lsl.w	#4,d4
		move.b	d4,(a1)+
		add.w	d2,d3
		dbf	d1,.x
		add.w	#$11,d2
		dbf	d0,.y
		rts

********************************************************************************
FadeRGB:
; Fade texture from black to original
; Writes repeated result *2 to destination to allow offset scrolling
;-------------------------------------------------------------------------------
; a0 - Source
; a1 - Dest
; d0.w - shade 0-15
;-------------------------------------------------------------------------------
		movem.l	d0-d1/a0-a2,-(sp)
		lea	RGBTbl,a2
		lea	RGBTbl4,a3
		move.l	a1,a4
		add.l	#SRC_SIZE,a4
		lsl.w	#4,d0
		add.l	d0,a2					; Move to row in LUTs for fade value
		add.l	d0,a3
		moveq	#0,d1
		moveq	#0,d2
		moveq	#0,d3
		moveq	#$f,d4
.unroll		equ	16
		move.w	#SRC_W*SRC_H/.unroll-1,d0
.l		rept	.unroll
		move.b	(a0)+,d1				; r
		move.b	(a2,d1),d1
		move.b	d1,(a1)+
		move.b	d1,(a4)+
		move.b	(a0)+,d1				; g
		move.b	d1,d2
		lsr	#4,d2
		move.b	(a3,d2),d2
		and.w	d4,d1					; b
		or.b	(a2,d1),d2
		move.b	d2,(a1)+
		move.b	d2,(a4)+
		endr
		dbf	d0,.l
		movem.l	(sp)+,d0-d1/a0-a2
		rts


********************************************************************************
Update:
;-------------------------------------------------------------------------------
		lea	Vars(pc),a5

		lea	Sin,a0
		lea	Cos,a1

; set Y speed
		move.l	VBlank,d0
		lsl	#1,d0
		and.w	#$7fe,d0
		move.w	(a1,d0),d1
		ext.l d1
		lsl.l #4,d1
		swap  d1
		addq #1,d1
		move.w d1,YSpeed

ADJ=$800-$40

; set X speed
		move.l	VBlank,d1
		add.l #ADJ,d1
		lsl	#3,d1
		and.w	#$7fe,d1
		move.w	(a1,d1),d1

		move.l	VBlank,d0
		add.l #ADJ,d0
		lsl	#2,d0
		and.w	#$7fe,d0
		move.w	(a0,d0),d0
		add.l d0,d1

		ext.l d1
		lsl.l #2,d1
		add.l #$8000,d1
		swap  d1

		move.w d1,XSpeed

; Texture offset:
; Offset X
		move.w	X-Vars(a5),d0
		add.w	XSpeed-Vars(a5),d0
		bge.b	.notNegX
		add.w	#SRC_W,d0
		bra.b	.noWrapX
.notNegX	cmp.w	#SRC_W,d0
		blt.b	.noWrapX
		sub.w	#SRC_W,d0
.noWrapX	move.w	d0,X-Vars(a5)
; Offset Y
		move.w	Y-Vars(a5),d0
		add.w	YSpeed-Vars(a5),d0
		bge.b	.notNegY
		add.w	#SRC_H,d0
		bra.b	.noWrapY
.notNegY	cmp.w	#SRC_H,d0
		blt.b	.noWrapY
		sub.w	#SRC_H,d0
.noWrapY	move.w	d0,Y-Vars(a5)

; Panning:
		move.l	VBlank,d0
		lsl	#3,d0
		and.w	#$7fe,d0
		move.w	(a0,d0),d1
		asr.w	d1

		move.l	VBlank,d0
		lsl	#2,d0
		muls	#5,d0
		and.w	#$7fe,d0
		move.w	(a1,d0),d0
		asr.w	d0
		add.w	d0,d1

		move.l	VBlank,d0
		lsl	#3,d0
		and.w	#$7fe,d0
		move.w	(a0,d0),d0

; Pan X
		muls	#PAN_X*2,d0
		FP2I	d0
		add.w	#PAN_X,d0
		move.w	d0,PanX-Vars(a5)
; Pan Y
		muls	#PAN_Y*2,d1
		FP2I	d1
		add.w	#PAN_Y,d1
		move.w	d1,PanY-Vars(a5)

		rts

PanOffs:	dc.l	0
********************************************************************************
Draw:
;-------------------------------------------------------------------------------
		move.l	Cop(pc),a1
		move.l	sp,.stack				; Free up a7 register for an extra shade - this means we can't use jsr
		lea	CopChunky+CopC_EvenCols+2(a1),a0
		lea	CopChunky+CopC_OddCols+2(a1),a1
		lea	DrawTbl,a2

		move.l	Shades(pc),a3
		move.l	a3,a4
		move.l	a3,a5
		move.l	a3,a6
		add.l	#SRC_SIZE*4,a3
		add.l	#SRC_SIZE*12,a4
		add.l	#SRC_SIZE*20,a5
		add.l	#SRC_SIZE*24,a6
		lea	ChunkyImage,a7
;-------------------------------------------------------------------------------
; Texture offset:
		move.w	X(pc),d0
		add.w	d0,d0
		ext.l	d0
		move.w	Y(pc),d1
		; mulu        #SRC_W*2,d1
		; lsl.w	#8,d1					; OPT
		lsl.w	#7,d1					; OPT
		ext.l	d1
		add.w	d0,d1
		add.l	d1,a3
		add.l	d1,a4
		add.l	d1,a5
		add.l	d1,a6
		add.l	d1,a7
;-------------------------------------------------------------------------------
; Panning:
		move.w	PanX(pc),d0
		btst	#0,d0
		beq	.isEven
		exg	a0,a1
		subq	#4,a1
.isEven
; Draw row start += PanX*6
		move.w	d0,d1
		add.w	d1,d1
		add.w	d0,d1
		add.w	d1,d1
		lea	(a2,d1),a2
; Copper ptr -= (PanX>>1)*4
		asr.w	d0
		add.w	d0,d0
		add.w	d0,d0
		sub.l	d0,a0
		sub.l	d0,a1
		move.l	d0,PanOffs				; store

		move.w	PanY(pc),d0
		mulu	#ROW_BW,d0
		add.l	d0,a2

;-------------------------------------------------------------------------------
		move.l	CurrFrame,d0
		lsr.w	#1,d0
		cmp.w	#CHUNKY_H-1,d0
		ble	.l
		moveq	#CHUNKY_H-1,d0
.l
		move.w	CHUNKY_W*6(a2),d1			; stash instructions before SMC
		move.l	CHUNKY_W*6+2(a2),d2
		move.w	#$4ef9,CHUNKY_W*6(a2)			; insert `jmp .ret`
		move.l	#.ret,CHUNKY_W*6+2(a2)
		jmp	(a2)
.ret
		move.w	d1,CHUNKY_W*6(a2)			; restore originl instructions
		move.l	d2,CHUNKY_W*6+2(a2)
		lea	CopC_SIZEOF(a0),a0
		lea	CopC_SIZEOF(a1),a1
		lea	ROW_BW(a2),a2
		dbf	d0,.l

		move.l	PanOffs,d0
		add.l	d0,a0
		add.l	d0,a1

; 		move.w #$123,d3
; 		moveq	#20-1,d0
; .l0		bsr	ClearRow
; 		lea	CopC_SIZEOF(a0),a0
; 		lea	CopC_SIZEOF(a1),a1
; 		dbf	d0,.l0

		move.l	.stack,sp
		rts

.stack		dc.l	1

ClearRow:
		move.w	d3,0(a0)
		move.w	d3,4(a1)
		move.w	d3,4(a0)
		move.w	d3,8(a1)
		move.w	d3,8(a0)
		move.w	d3,12(a1)
		move.w	d3,12(a0)
		move.w	d3,16(a1)
		move.w	d3,16(a0)
		move.w	d3,20(a1)
		move.w	d3,20(a0)
		move.w	d3,24(a1)
		move.w	d3,24(a0)
		move.w	d3,28(a1)
		move.w	d3,28(a0)
		move.w	d3,32(a1)
		move.w	d3,32(a0)
		move.w	d3,36(a1)
		move.w	d3,36(a0)
		move.w	d3,40(a1)
		move.w	d3,40(a0)
		move.w	d3,44(a1)
		move.w	d3,44(a0)
		move.w	d3,48(a1)
		move.w	d3,48(a0)
		move.w	d3,52(a1)
		move.w	d3,52(a0)
		move.w	d3,56(a1)
		move.w	d3,56(a0)
		move.w	d3,60(a1)
		move.w	d3,60(a0)
		move.w	d3,64(a1)
		move.w	d3,64(a0)
		move.w	d3,68(a1)
		move.w	d3,68(a0)
		move.w	d3,72(a1)
		move.w	d3,72(a0)
		move.w	d3,76(a1)
		move.w	d3,76(a0)
		move.w	d3,80(a1)
		move.w	d3,80(a0)
		move.w	d3,84(a1)
		move.w	d3,84(a0)
		move.w	d3,88(a1)
		move.w	d3,88(a0)
		move.w	d3,92(a1)
		move.w	d3,92(a0)
		move.w	d3,96(a1)
		move.w	d3,96(a0)
		rts


********************************************************************************
Vars:
********************************************************************************

XSpeed:		dc.w	0
YSpeed:		dc.w	1
X:		dc.w	0
Y:		dc.w	0
PanX:		dc.w	0
PanY:		dc.w	0

Shades:		dc.l	0
Cop:		dc.l	0

********************************************************************************
Data:
********************************************************************************

DrawTbl:
		incbin	"obj/tables_shade1.o"

ChunkyImage:
		incbin	"data/tex.rgb"
		incbin	"data/tex.rgb"

;--------------------------------------------------------------------------------
; Main copper list:
CopTemplate:
		COP_MOVE 0,fmode
		COP_MOVE DIW_STRT,diwstrt
		COP_MOVE DIW_STOP,diwstop
		COP_MOVE DDF_STRT,ddfstrt
		COP_MOVE DDF_STOP,ddfstop
		COP_MOVE DMAF_SETCLR!DMAF_SPRITE,dmacon
		COP_MOVE -DIW_BW,bpl1mod
		COP_MOVE -DIW_BW,bpl2mod
		COP_MOVE BPLS<<12!$200,bplcon0
		COP_MOVE $33,bplcon1
		COP_MOVE 0,bplcon2
CopSprPt:
		rept	8*2
		COP_MOVE 0,sprpt+REPTN*2
		endr
CopBplPt:
		rept	BPLS*2
		COP_MOVE 0,bpl0pt+REPTN*2
		endr
		COP_WAIT DIW_YSTRT,$ae
		COP_MOVE DMAF_SPRITE,dmacon
CopTemplateE:

CopChunky = CopTemplateE-CopTemplate


*******************************************************************************
bss
*******************************************************************************

; Lookup tables for RGB fade
RGBTbl:		ds.b	16*16
RGBTbl4:	ds.b	16*16

*******************************************************************************
		data_c
*******************************************************************************

SPR_STRT = DIW_YSTRT<<8!DIW_XSTRT+$1e
SPR_END = (DIW_YSTRT+CHUNKY_H*4)&$ff<<8!$03

Sprites:
		rept	3
		dc.w	SPR_STRT+REPTN*12,SPR_END
		dc.w	$0f00
		dc.w	$000f
;                        0102
		dc.w	SPR_STRT+REPTN*12+8,SPR_END
		dc.w	$0f00
		dc.w	$0f00
;                        0300
		endr
		dc.w	SPR_STRT+3*12,SPR_END
		dc.w	$0f00
		dc.w	$000f
;                        0102
		dc.w	SPR_STRT+3*12+8,SPR_END
		dc.w	$0f0f
		dc.w	$0f00
;                        0301

Bpls:
		dc.w	$0000,$00f0,$00f0,$00f0,$00f0,$00f0,$00f0
		dc.w	$00f0,$0000,$f0f0,$0000,$f0f0,$0000,$f0f0
		dc.w	$0f00,$f0f0,$f0f0,$0000,$0000,$f0f0,$f0f0
		dc.w	$0000,$0000,$0000,$f0f0,$f0f0,$f0f0,$f0f0
;                        0420  4050  6070  8090  a0b0  c0d0  e0f0
