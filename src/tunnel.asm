		incdir	src
		include	"_main.i"
		include	"tunnel.i"


********************************************************************************
Tunnel_Effect:
		move.l	0,a0
		jsr	InstallInterrupt

		move.l	#SRC_SIZE*2*SHADES,d0
		jsr	AllocPublic
		move.l	a0,Shades

		move.l	#CopTemplateE-CopTemplate,d0
		jsr	AllocChipAligned
		move.l	a0,Cop
		jsr	InstallCopper

		lea	CopTemplate,a1
		move.w	#(CopTemplateE-CopTemplate)/4-1,d7
.cp		move.l	(a1)+,(a0)+
		dbf	d7,.cp

		bsr	InitChunky
		bsr	InitShades

		lea	ChunkyImage,a0
		move.l	Shades(pc),a1
		moveq	#1,d0

		rept	14
		bsr.w	FadeRGB
		lea	SRC_SIZE*2(a1),a1
		addq	#1,d0
		endr
.mainLoop:
		bsr	Update
		bsr	Draw

		lea	custom,a6
		jsr	WaitEOF
		btst	#6,ciaa
		bne.b	.mainLoop
.exit		rts


********************************************************************************
* Routines:
********************************************************************************

********************************************************************************
InitChunky:
		move.l Cop,a2
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
;-------------------------------------------------------------------------------
; Jmp locs
		lea	CopChunky+CopC_Wait-CopTemplate(a2),a0
		move.l	a0,cop2lc+custom
		move.w	#CHUNKY_H-1,d0
.loc:
		move.w	a0,CopC_Loc-CopC_Wait+2(a0)
		lea	CopC_SIZEOF(a0),a0
		dbf	d0,.loc

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
		lea	Sin16(pc),a0
		lea	Cos16(pc),a1

		move.l	VBlank,d0
		add.w	d0,d0
		and.w	#$1fe,d0
		move.w	(a0,d0),d1
		asr.w	d1

		move.l	VBlank,d0
		muls	#5,d0
		and.w	#$1fe,d0
		move.w	(a1,d0),d0
		asr.w	d0
		add.w	d0,d1

		move.l	VBlank,d0
		add.w	d0,d0
		and.w	#$1fe,d0
		move.w	(a0,d0),d0

; Pan X
		muls	#PAN_X,d0
		FP2I	d0
		add.w	#PAN_X,d0
		move.w	d0,PanX-Vars(a5)
; Pan Y
		muls	#PAN_Y,d1
		FP2I	d1
		add.w	#PAN_Y,d1
		move.w	d1,PanY-Vars(a5)

		rts


********************************************************************************
Draw:
;-------------------------------------------------------------------------------
		move.l	Cop(pc),a1
		move.l	sp,.stack				; Free up a7 register for an extra shade - this means we can't use jsr
		lea	CopChunky+CopC_EvenCols+2-CopTemplate(a1),a0
		lea	CopChunky+CopC_OddCols+2-CopTemplate(a1),a1
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

		move.w	PanY(pc),d0
		mulu	#ROW_BW,d0
		add.l	d0,a2

;-------------------------------------------------------------------------------
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

		move.l	.stack,sp
		rts

.stack		dc.l	1


********************************************************************************
Vars:
********************************************************************************

XSpeed:		dc.w	1
YSpeed:		dc.w	3
X:		dc.w	0
Y:		dc.w	0
PanX:		dc.w	0
PanY:		dc.w	0

Shades:		dc.l	0
Cop:		dc.l	0

********************************************************************************
Data:
********************************************************************************

		include	"data/sincos16.i"

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

;--------------------------------------------------------------------------------
;Copper chunky display

		rsreset
CopC_OddCols	rs.l	CHUNKY_W/2
CopC_Wait	rs.l	1
CopC_EvenCols	rs.l	CHUNKY_W/2
CopC_Bg		rs.l	1
CopC_Loc	rs.l	1
CopC_Skip	rs.l	1
CopC_Jmp	rs.l	1
CopC_SIZEOF	rs.b	0

CopChunky:
.y		set	DIW_YSTRT+1
		rept	CHUNKY_H
		ifeq	.y-$fd
.y		set	.y+2
		else
.y		set	.y+3
		endc

		COP_MOVE 0,color02				;CopC_OddCols
		COP_MOVE 0,color04
		COP_MOVE 0,color05
		COP_MOVE 0,color06
		COP_MOVE 0,color07
		COP_MOVE 0,color08
		COP_MOVE 0,color09
		COP_MOVE 0,color10
		COP_MOVE 0,color11
		COP_MOVE 0,color12
		COP_MOVE 0,color13
		COP_MOVE 0,color14
		COP_MOVE 0,color15
		COP_MOVE 0,color17
		COP_MOVE 0,color18
		COP_MOVE 0,color19
		COP_MOVE 0,color21
		COP_MOVE 0,color22
		COP_MOVE 0,color23
		COP_MOVE 0,color25
		COP_MOVE 0,color26
		COP_MOVE 0,color27
		COP_MOVE 0,color29
		COP_MOVE 0,color30
		COP_MOVE 0,color31

		dc.w	(.y&$80)<<8!$5d,$805c			;CopC_Wait

		rept	CHUNKY_W/2
		COP_MOVE 0,color00				;CopC_EvenCols
		endr

		COP_MOVE $123,color00				;CopC_Bg

		COP_MOVE 0,cop2lc+2				;CopC_Loc
		COP_SKIP .y,$30					;CopC_Skip
		COP_MOVE 0,copjmp2				;CopC_Jmp

		endr						;/CHUNKY_H

		COP_END
CopTemplateE:


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