		include	src/transitions.i

LERPS_WORDS_LEN = 4

rsreset
Lerp_Count	rs.w	1
Lerp_Shift	rs.w	1
Lerp_Inc	rs.l	1
Lerp_Tmp	rs.l	1
Lerp_Ptr	rs.l	1					; Target address pointer
Lerp_SIZEOF	rs.w	0


********************************************************************************
; Start a new lerp
;-------------------------------------------------------------------------------
; d0.w - target value
; d1.w - duration (pow 2)
; a1 - ptr
;-------------------------------------------------------------------------------
LerpWord:
		lea	LerpWordsState,a2
		moveq	#LERPS_WORDS_LEN-1,d2
.l		tst.w	Lerp_Count(a2)
		beq	.free
		lea	Lerp_SIZEOF(a2),a2
		dbf	d2,.l
		rts						; no free slots
.free
		moveq	#1,d2
		lsl.w	d1,d2
		move.w	d2,(a2)+				; count
		move.w	d1,(a2)+				; shift
		move.w	(a1),d3					; current value
		sub.w	d3,d0
		ext.l	d0
		move.l	d0,(a2)+				; inc
		lsl.l	d1,d3
		move.l	d3,(a2)+				; tmp
		move.l	a1,(a2)+				; ptr
		rts

********************************************************************************
; Continue any active lerps
;-------------------------------------------------------------------------------
LerpWordsStep:
		lea	LerpWordsState,a0
		moveq	#LERPS_WORDS_LEN-1,d0
.l		tst.w	Lerp_Count(a0)				; Skip if not enabled / finished
		beq	.next
		sub.w	#1,Lerp_Count(a0)
		movem.l	Lerp_Inc(a0),d1-d2/a1
		add.l	d1,d2
		move.l	d2,Lerp_Tmp(a0)
		move.w	Lerp_Shift(a0),d1
		asr.l	d1,d2
		move.w	d2,(a1)
.next		lea	Lerp_SIZEOF(a0),a0
		dbf	d0,.l
		rts


********************************************************************************
; Fade between two RGB palettes
;-------------------------------------------------------------------------------
; a0 - src1
; a1 - src2
; a2 - dest
; d0.w - step 0-$8000
; d1.w - colors-1
;-------------------------------------------------------------------------------
LerpPal:
		move.w	#$f0,d2
		cmp.w	#$8000,d0
		blo.s	.l
.cp:		move.w	(a1)+,(a2)+
		dbf	d1,.cp
		bra.s	.end
.l:		move.w	(a0)+,d3
		move.w	(a1)+,d4
		bsr	DoLerpCol
		move.w	d7,(a2)+
		dbf	d1,.l
.end:
		rts


********************************************************************************
; Lerp single colour
;-------------------------------------------------------------------------------
; d0.w - step 0-$8000
; d3.w - src1
; d4.w - src2
; returns:
; d7 - dest
;-------------------------------------------------------------------------------
LerpCol:
		move.w	#$f0,d2

DoLerpCol:
		move.w	d3,d5					; R
		clr.b	d5
		move.w	d4,d7
		clr.b	d7
		sub.w	d5,d7
		add.w	d7,d7
		muls	d0,d7
		swap	d7
		add.w	d5,d7
		move.w	d3,d5					; G
		and.w	d2,d5
		move.w	d4,d6
		and.w	d2,d6
		sub.w	d5,d6
		add.w	d6,d6
		muls	d0,d6
		swap	d6
		add.w	d5,d6
		and.w	d2,d6
		move.b	d6,d7
		moveq	#$f,d6
		and.w	d6,d3
		and.w	d6,d4
		sub.w	d3,d4					; B
		add.w	d4,d4
		muls	d0,d4
		swap	d4
		add.w	d3,d4
		or.w	d4,d7
		rts


*******************************************************************************
		bss
*******************************************************************************

LerpWordsState:	ds.b	Lerp_SIZEOF*LERPS_WORDS_LEN
