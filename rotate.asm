		include	_main.i
		include	rotate.i

DIW_BW = 320/8
SCREEN_BW = 336/8
SCREEN_H = 256

MAX_R = $7
MAX_PARTICLES = 80

EOF = $7fff

; perpective
DIST = 1000
SCALE_SHIFT = 8

; these need to make a total of 14 for FP?
MUL_SHIFTA = 7

FPMULS		macro
		muls	\1,\2
		lsl.l	#2,\2
		swap	\2
		endm

		rsreset
Particle_X	rs.w	1
Particle_Y	rs.w	1
Particle_Z	rs.w	1
Particle_R	rs.w	1
Particle_SIZEOF	rs.b	0

		rsreset
Transformed_X	rs.w	1
Transformed_Y	rs.w	1
Transformed_R	rs.w	1
Transformed_SIZEOF rs.b	0


Rotate_Effect:
		lea	PokeBpls,a0
		jsr	InstallInterrupt

		bsr	InitMulsTbl

; Generate random particles
		lea	Particles,a0
		moveq	#MAX_PARTICLES-1,d7
.l0		bsr	InitParticle
		dbf	d7,.l0

Frame:

		jsr	SwapBuffers
		; TODO: would full screen clear be better for parallelisation with transform?
		jsr	Clear

		movem.w Rot,d5-d7
		add.w #20,d6
		; add.w #4,d6
		; add.w #6,d7
		and.w #$7fe,d6
		; and.w #$7fe,d6
		; and.w #$7fe,d7
		movem.w d5-d7,Rot
		bsr	BuildMatrix

		; bsr	TransformOld
		bsr	Transform

Draw:
		move.l	DrawBuffer,a1
		lea	DIW_BW/2+SCREEN_H/2*SCREEN_BW(a1),a1	; centered with top/left padding
		move.l	DrawClearList,a2
		lea	Transformed,a5
		move.l	DrawBuffer,a1
		lea	DIW_BW/2+SCREEN_H/2*SCREEN_BW(a1),a1	; centered with top/left padding
		move.l	DrawClearList,a2

.l
		movem.w	(a5)+,d0-d2				; x/y/r
		cmp.w	#EOF,d0
		beq	.done
		moveq	#0,d3
		jsr	DrawCircle
		bra	.l
.done

		move.l	#0,(a2)+				; End clear list

		DebugStartIdle
		jsr	WaitEOF
		DebugStopIdle

		bra	Frame
		rts


********************************************************************************
; Calculate rotation matrix and apply values to self-modifying code loop
;
; A = cos(Y)*cos(Z)    B = sin(X)*sin(Y)*cos(Z)−cos(X)*sin(Z)     C = cos(X)*sin(Y)*cos(Z)+sin(X)*sin(Z)
; D = cos(Y)*sin(Z)    E = sin(X)*sin(Y)*sin(Z)+cos(X)*cos(Z)     F = cos(X)*sin(Y)*sin(Z)−sin(X)*cos(Z)
; G = −sin(Y)          H = sin(X)*cos(Y)                          I = cos(X)*cos(Y)
;-------------------------------------------------------------------------------
; d5-d7 - x/y/z rotation
;-------------------------------------------------------------------------------
BuildMatrix:
smc		equr	a0
sin		equr	a1
cos		equr	a2
x		equr	d5
y		equr	d6
z		equr	d7

		lea	SMCLoop+3(pc),smc
		lea	Sin,sin
		lea	Cos,cos

		move.w	(sin,x),d2
		FPMULS	(sin,y),d2				; d2 = sin(X)*sin(Y)
		move.w	(cos,x),d3
		FPMULS	(sin,z),d3				; d3 = sin(Z)*cos(X)
		move.w	(cos,x),d4
		FPMULS	(cos,z),d4				; d4 = cos(X)*cos(Z)

; A = cos(Y)*cos(Z)
		move.w	(cos,y),d0
		FPMULS	(cos,z),d0				; cos(Y)*cos(Z)
		lsr.w	#MUL_SHIFTA,d0
		move.b	d0,MatA-SMCLoop(smc)
; B = sin(X)*sin(Y)*cos(Z)−cos(X)*sin(Z)
		move.w	d2,d0					; sin(X)*sin(Y)
		FPMULS	(cos,z),d0				; sin(X)*sin(Y)*cos(Z)
		move.w	(cos,x),d1				; cos(X)
		FPMULS	(sin,z),d1				; cos(X)*sin(Z)
		sub.w	d1,d0					; sin(X)*sin(Y)*cos(Z)-cos(X)*sin(Z)
		lsr.w	#MUL_SHIFTA,d0
		move.b	d0,MatB-SMCLoop(smc)
; C = cos(X)*sin(Y)*cos(Z)+sin(X)*sin(Z)
		move.w	d4,d0					; cos(X)*cos(Z)
		FPMULS	(sin,y),d0				; cos(X)*cos(Z)*sin(Y)
		move.w	(sin,x),d1				; sin(X)
		FPMULS	(sin,z),d1				; sin(X)*sin(Z)
		add.w	d1,d0					; cos(X)*cos(Z)*sin(Y)+sin(X)*sin(Z)
		lsr.w	#MUL_SHIFTA,d0
		move.b	d0,MatC-SMCLoop(smc)
; D = cos(Y)*sin(Z)
		move.w	(cos,y),d0
		FPMULS	(sin,z),d0				; cos(Y)*sin(Z)
		lsr.w	#MUL_SHIFTA,d0
		move.b	d0,MatD-SMCLoop(smc)
; E = sin(X)*sin(Y)*sin(Z)+cos(X)*cos(Z)
		move.w	d2,d0					; sin(X)*sin(Y)
		FPMULS	(sin,z),d0				; sin(X)*sin(Y)*sin(Z)
		add.w	d4,d0					; sin(X)*sin(Y)*sin(Z)+cos(X)*cos(Z)
		lsr.w	#MUL_SHIFTA,d0
		move.b	d0,MatE-SMCLoop(smc)
; F = cos(X)*sin(Y)*sin(Z)−sin(X)*cos(Z)
		move.w	d3,d0					; sin(Z)*cos(X)
		FPMULS	(sin,y),d0				; cos(X)*sin(Y)*sin(Z)
		move.w	(sin,x),d1				; sin(X)
		FPMULS	(cos,z),d1				; sin(X)*cos(Z)
		sub.w	d1,d0
		lsr.w	#MUL_SHIFTA,d0
		move.b	d0,MatF-SMCLoop(smc)
; G = −sin(Y)
		move.w	(sin,y),d0				; sin(Y)
		neg.w	d0					; -sin(Y)
		lsr.w	#MUL_SHIFTA,d0
		move.b	d0,MatG-SMCLoop(smc)
; H = sin(X)*cos(Y)
		move.w	(sin,x),d0				; sin(X)
		FPMULS	(cos,y),d0				; sin(X)*cos(Y)
		lsr.w	#MUL_SHIFTA,d0
		move.b	d0,MatH-SMCLoop(smc)
; I = cos(X)*cos(Y)
		move.w	d4,d0					; cos(X)*cos(Z)
		lsr.w	#MUL_SHIFTA,d0
		move.b	d0,MatI-SMCLoop(smc)

		rts

********************************************************************************
Transform:
; Combined operation to rotate, translate and apply perspective to all the
; vertices in an object. The resulting 2d vertices are written back to the
; temporary 'Transformed' buffer.
;-------------------------------------------------------------------------------
transformed	equr	a1
multbl		equr	a2
divtbl		equr	a3
ox		equr	d0					; original
oy		equr	d1
oz		equr	d2
tx		equr	d3					; transformed
ty		equr	d4
tz		equr	d5
r		equr	d6

		lea	Particles,a0
		lea	Transformed,transformed			; Destination for transformed 2D vertices
		lea	MulsTable+(256*127),multbl		; start at middle of table (0x)
		lea	DivTab,divtbl

__SMC__ = $7f							; Values to be replaced in self-modifying code

		move.w	#MAX_PARTICLES-1,d7

SMCLoop:
		movem.w	(a0)+,ox-oz/r				; d0 = x, d1 = y, d2 = z, d6 = r

; x'=A*x+B*y+C*z
MatA		move.b	__SMC__(multbl,ox.w),tx
MatB		add.b	__SMC__(multbl,oy.w),tx
MatC		add.b	__SMC__(multbl,oz.w),tx
		ext.w	tx
; y'=D*x+E*y+F*z
MatD		move.b	__SMC__(multbl,ox.w),ty
MatE		add.b	__SMC__(multbl,oy.w),ty
MatF		add.b	__SMC__(multbl,oz.w),ty
		ext.w	ty
; z'=G*x+H*y+I*z
MatG		move.b	__SMC__(multbl,ox.w),tz
MatH		add.b	__SMC__(multbl,oy.w),tz
MatI		add.b	__SMC__(multbl,oz.w),tz
		ext.w	tz

; Apply perspective:
		add.w	#DIST,tz
		asr.w	#SCALE_SHIFT,tz
		ble	.next

		; add.w	tz,tz
		; move.w	(divtbl,tz),d5				; d5 = 1/z

		; muls	d5,tx
		; swap	tx
		; muls	d5,ty
		; swap	ty
		; mulu	d5,r
		; swap	r

		ext.l r
		divu tz,r
		ext.l tx
		divu tz,tx
		ext.l ty
		divu tz,ty

		; TODO: maybe interleave draw?
		move.w	tx,(transformed)+			; write output
		move.w	ty,(transformed)+
		move.w	r,(transformed)+

.next		dbf	d7,SMCLoop
		move.w	#EOF,(transformed)+
		rts


********************************************************************************
; Populate multiplication lookup table
; [-127 to 127] * [0 to 255] / 128
;-------------------------------------------------------------------------------
InitMulsTbl:
		lea	MulsTable,a0
		move.w	#-127,d0				; d0 = x = -127-127
		move.w	#256-1,d7
.loop1		moveq	#0,d1					; d1 = y = 0-255
		move.w	#256-1,d6
.loop2		move.w	d0,d2					; d2 = x
		move.w	d1,d3					; d3 = y
		ext.w	d3
		muls.w	d3,d2					; d2 = x*y
		asr.l	#7,d2					; d2 = (x*y)/128
		move.b	d2,(a0)+				; write to table
		addq	#1,d1
		dbf	d6,.loop2
		addq	#1,d0
		dbf	d7,.loop1
		rts


TransformOld:
		lea	Particles,a0
		lea	Transformed,a1
		lea	DivTab,a2
		moveq	#MAX_PARTICLES-1,d7
.l
; Load the next particle:
; d0 = x
; d1 = y
; d2 = z
; d3 = r
		movem.w	(a0)+,d0-d3

; Apply perspective
		add.w	#DIST,d2
		asr.w	#SCALE_SHIFT,d2
		ble	.next

		; lookup reciprocal to convert div to mul
		add.w	d2,d2
		move.w	(a2,d2.w),d5

		muls	d5,d0
		swap	d0
		muls	d5,d1
		swap	d1
		mulu	d5,d3
		swap	d3

		move.w	d0,(a1)+
		move.w	d1,(a1)+
		move.w	d3,(a1)+

.next		dbf	d7,.l
		move.w	#EOF,(a1)+
		rts


********************************************************************************
InitParticle:
; x
		jsr	Random32
		; asr.b d0
		move.b	d0,(a0)+
		clr.b	(a0)+
; y
		jsr	Random32
		; asr.b d0
		move.b	d0,(a0)+
		clr.b	(a0)+
; z
		jsr	Random32
		; asr.b d0
		move.b	d0,(a0)+
		clr.b	(a0)+
; r
		jsr	Random32
		and.w	#MAX_R,d0
		addq	#7,d0
		move.w	d0,(a0)+

		rts


*******************************************************************************
		bss
*******************************************************************************

; Multiplication lookup-table
MulsTable:	ds.b	256*256

Particles:	ds.b	Particle_SIZEOF*MAX_PARTICLES

Transformed:	ds.w	Transformed_SIZEOF*MAX_PARTICLES+1

Rot:		ds.w 3
