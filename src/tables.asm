		include	src/tables.i

DIVS_RANGE = $7ff
MULSCALE = 160

********************************************************************************
Tables_Precalc:
;-------------------------------------------------------------------------------
; Populate square root lookup table
;-------------------------------------------------------------------------------
; 		lea	SqrtTab,a0
; 		moveq	#0,d0
; .loop0:		move.w	d0,d1
; 		add.w	d1,d1
; .loop1:		move.b	d0,(a0)+
; 		dbf	d1,.loop1
; 		addq.b	#1,d0
; 		bcc.s	.loop0

;-------------------------------------------------------------------------------
; Populate sin table
;-------------------------------------------------------------------------------
; https://eab.abime.net/showpost.php?p=1471651&postcount=24
; maxError = 26.86567%
; averageError = 8.483626%
;-------------------------------------------------------------------------------
		lea	Sin,a0
		moveq	#0,d0
		move.w	#$4000,d1
		moveq	#32,d2
.loop:
		move.w	d0,d3
		muls	d1,d3
		asr.l	#8,d3
		asr.l	#4,d3
		move.w	d3,(a0)+
		neg.w	d3
		move.w	d3,1022(a0)
		add.w	d2,d0
		sub.w	d2,d1
		bgt.s	.loop
; Copy extra 90 deg for cosine
		lea	Sin,a0
		lea	Sin+1024*2,a1
		move.w	#256/2,d0
.copy
		move.l	(a0)+,(a1)+
		dbf	d0,.copy

;-------------------------------------------------------------------------------
; Populate reciprocal division lookup table
;-------------------------------------------------------------------------------
		lea	DivTab+2,a0
		moveq	#1,d7
.l:
		move.l	#$10000,d0
		divu	d7,d0
		move.w	d0,(a0)+
		addq	#1,d7
		cmp.w	#DIVS_RANGE,d7
		ble	.l

********************************************************************************
; Populate multiplication lookup table
; [-127 to 127] * [-127 to 127] / 128
;-------------------------------------------------------------------------------
InitMulsTbl:
		lea	MulsTable,a0
		move.w	#-127,d0				; d0 = x = -127-127
		move.w	#256-1,d7
.loop1		moveq	#-127,d1				; d1 = y = -127-127
		move.w	#256-1,d6
.loop2		move.w	d0,d2					; d2 = x
		muls.w	d1,d2					; d2 = x*y
; asr.w	#7,d2					; d2 = (x*y)/128
		divs	#MULSCALE,d2
		move.b	d2,(a0)+				; write to table
		addq	#1,d1
		dbf	d6,.loop2
		addq	#1,d0
		dbf	d7,.loop1

		rts

*******************************************************************************
		bss
*******************************************************************************

; Precalced sqrt LUT data
; SqrtTab:	ds.b	$100*$100

; FP 2/14
; +-16384
; ($c000-$4000) over 1024 ($400) steps
Sin:		ds.w	256
Cos:		ds.w	1024

DivTab:		ds.w	DIVS_RANGE
MulsTable:	ds.b	256*256
