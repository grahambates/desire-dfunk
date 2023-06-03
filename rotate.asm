		include	_main.i
		include	rotate.i

DIW_W = 320
DIW_H = 256
DIW_BW = DIW_W/8
SCREEN_W = DIW_W+32
SCREEN_H = DIW_H+32
SCREEN_BW = SCREEN_W/8
SCREEN_BPL = SCREEN_BW*SCREEN_H

SIN_MASK = $1fe
SIN_SHIFT = 8

DIST_SHIFT = 7
ZOOM_SHIFT = 9
; FIXED_ZOOM = 300

POINTS_COUNT = 64
LERP_POINTS_SHIFT = 7
LERP_POINTS_LENGTH = 1<<LERP_POINTS_SHIFT

LERPS_WORDS_LEN = 4

PROFILE = 0

		rsreset
Point_X		rs.w	1
Point_Y		rs.w	1
Point_Z		rs.w	1
Point_R		rs.w	1
Point_SIZEOF	rs.b	0

		rsreset
Lerp_Count	rs.w	1
Lerp_Shift	rs.w	1
Lerp_Inc	rs.l	1
Lerp_Tmp	rs.l	1
Lerp_Ptr	rs.l	1					; Target address pointer
Lerp_SIZEOF	rs.w	0

; Fixed point multiplication for 1/15 format
FPMULS		macro
		muls	\1,\2
		add.l	\2,\2
		swap	\2
		endm


********************************************************************************
Rotate_Vbl:
********************************************************************************
		jsr	PokeBpls

;-------------------------------------------------------------------------------
Script:
		move.w	VBlank+2,d7
; Start lerp1:
		cmp.w	#$40,d7
		bne	.endLerp0
		move.w	#150,d0
		move.w	#7,d1
		move.l	#ZoomBase,a1
		pea	.endScript
		bsr	LerpWord
.endLerp0

; Start lerp1:
		cmp.w	#$100,d7
		bne	.endLerp1
		lea	SpherePoints,a0
		lea	BoxPoints,a1
		pea	.endScript
		bsr	LerpPoints
.endLerp1
; Start lerp2:
		cmp.w	#$300,d7
		bne	.endLerp2
		lea	BoxPoints,a0
		lea	Particles,a1
		pea	.endScript
		bsr	LerpPoints
.endLerp2
; Zoom / scroll speed tween:
		cmp.w	#$300+LERP_POINTS_LENGTH+1,d7
		bne	.endZoom

		move.w	#120,d0
		move.w	#6,d1
		move.l	#ZoomBase,a1
		bsr	LerpWord

		move.w	#$200,d0
		move.w	#6,d1
		move.l	#ParticlesSpeedX,a1
		bsr	LerpWord

		move.w	#$400,d0
		move.w	#7,d1
		move.l	#ParticlesSpeedY,a1
		bsr	LerpWord

		move.w	#$400,d0
		move.w	#8,d1
		move.l	#ParticlesSpeedZ,a1
		bsr	LerpWord

		move.l	#Particles,DrawPoints
		bra	.endScript
.endZoom

;
		cmp.w	#$500,d7
		bne	.endStop
		move.w	#0,d0
		move.w	#7,d1
		move.l	#ParticlesSpeedX,a1
		bsr	LerpWord

		move.w	#0,d0
		move.w	#7,d1
		move.l	#ParticlesSpeedY,a1
		bsr	LerpWord

		move.w	#0,d0
		move.w	#7,d1
		move.l	#ParticlesSpeedZ,a1
		bsr	LerpWord
		bra	.endScript
.endStop
;
		cmp.w	#$580,d7
		bne	.endLerp3
		lea	Particles,a0
		lea	LogoPoints,a1
		pea	.endScript
		bsr	LerpPoints
.endLerp3

		cmp.w	#$680,d7
		bne	.endLerp4
		lea	LogoPoints,a0
		lea	SpherePoints,a1
		pea	.endScript
		bsr	LerpPoints
.endLerp4

.endScript

		rts


********************************************************************************
Rotate_Effect:
********************************************************************************
		lea	Rotate_Vbl(pc),a0
		jsr	InstallInterrupt

		bsr	InitMulsTbl
		bsr	InitParticles
		bsr	InitBox
		bsr	InitSphere
		bsr	InitLogo

		move.l	#SpherePoints,DrawPoints

;-------------------------------------------------------------------------------
SetPalette:
		lea	color16(a6),a1
		move.w	#15-1,d6
.col
		lea	Pal+10,a2
		moveq	#0,d0					; r
		moveq	#0,d1					; g
		moveq	#0,d2					; b
		moveq	#4-1,d5					; iterate channels
.chan1
		move.w	-(a2),d4				; Channel color
		move.w	d6,d3
		addq	#1,d3
		btst	d5,d3
		beq	.nextChan
; Add the colours:
; blue
		move.w	d4,d3
		and.w	#$f,d3
		add.w	d3,d2
		cmp.w	#$f,d2
		ble	.blueOk
		move.w	#$f,d2
.blueOk
; green
		lsr	#4,d4
		move.w	d4,d3
		and.w	#$f,d3
		add.w	d3,d1
		cmp.w	#$f,d1
		ble	.greenOk
		move.w	#$f,d1
.greenOk
; red
		lsr	#4,d4
		and.w	#$f,d4
		add.w	d4,d0
		cmp.w	#$f,d0
		ble	.redOk
		move.w	#$f,d0
.redOk
.nextChan	dbf	d5,.chan1
		lsl.w	#8,d0
		lsl.w	#4,d1
		add.w	d1,d0
		add.w	d2,d0
		move.w	d0,-(a1)
		dbf	d6,.col
; Set bg
		move.w	-(a2),color(a6)

********************************************************************************
Frame:
		jsr	SwapBuffers
		jsr	Clear

		bsr	LerpPointsStep
		bsr	LerpWordsStep

; Update particle positions:
		lea	Particles,a0
		movem.w	ParticlesSpeed(pc),d1-d3
		move.w	#$f00,d0
		and.w	d0,d1
		and.w	d0,d2
		and.w	d0,d3
UNROLL_PARTICLES = 8
		moveq	#POINTS_COUNT/UNROLL_PARTICLES-1,d6
.l0
		rept	UNROLL_PARTICLES
		add.w	d1,(a0)+
		add.w	d2,(a0)+
		add.w	d3,(a0)+
		addq	#2,a0
		endr
		dbf	d6,.l0

		move.w	Pal,color(a6)

;-------------------------------------------------------------------------------
SetZoom:
		lea	Sin,a0
		move.w	VBlank+2,d0
		lsl	#2,d0
		and.w	#$7fe,d0
		move.w	(a0,d0.w),d5
		move.w	#ZOOM_SHIFT,d0
		asr	d0,d5
		add.w	ZoomBase(pc),d5
		move.w	d5,Zoom
		ifd	FIXED_ZOOM
		move.w	#FIXED_ZOOM,Zoom
		endc

;-------------------------------------------------------------------------------
SetRotation:
		move.w	VBlank+2,d4
		; x
		move.w	d4,d5
		lsl	#1,d5
		add.w	#$200,d5
		and.w	#$7fe,d5
		move.w	(a0,d5.w),d5
		lsr	#5,d5
		and.w	#SIN_MASK,d5
		; y
		move.w	d4,d6
		lsl	#1,d6
		and.w	#$7fe,d6
		move.w	(a0,d6.w),d6
		lsr	#4,d6
		and.w	#SIN_MASK,d6
		; z
		move.w	d4,d7
		and.w	#SIN_MASK,d7

		; move.w	#0,d5
		; move.w	#0,d6
		; move.w	#0,d7

;-------------------------------------------------------------------------------
; Calculate rotation matrix and apply values to self-modifying code loop
;
; A = cos(Y)*cos(Z)    B = sin(X)*sin(Y)*cos(Z)−cos(X)*sin(Z)     C = cos(X)*sin(Y)*cos(Z)+sin(X)*sin(Z)
; D = cos(Y)*sin(Z)    E = sin(X)*sin(Y)*sin(Z)+cos(X)*cos(Z)     F = cos(X)*sin(Y)*sin(Z)−sin(X)*cos(Z)
; G = −sin(Y)          H = sin(X)*cos(Y)                          I = cos(X)*cos(Y)
;-------------------------------------------------------------------------------
BuildMatrix:
smc		equr	a0
sin		equr	a1
cos		equr	a2
x		equr	d5
y		equr	d6
z		equr	d7

		lea	SMCLoop+3(pc),smc
		lea	Sin1,sin
		lea	Cos1,cos

		move.w	(sin,x),d2
		FPMULS	(sin,y),d2				; d2 = sin(X)*sin(Y)
		move.w	(cos,x),d3
		FPMULS	(sin,z),d3				; d3 = sin(Z)*cos(X)
		move.w	(cos,x),d4
		FPMULS	(cos,z),d4				; d4 = cos(X)*cos(Z)

; A = cos(Y)*cos(Z)
		move.w	(cos,y),d0
		FPMULS	(cos,z),d0				; cos(Y)*cos(Z)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatA-SMCLoop(smc)
; B = sin(X)*sin(Y)*cos(Z)−cos(X)*sin(Z)
		move.w	d2,d0					; sin(X)*sin(Y)
		FPMULS	(cos,z),d0				; sin(X)*sin(Y)*cos(Z)
		move.w	(cos,x),d1				; cos(X)
		FPMULS	(sin,z),d1				; cos(X)*sin(Z)
		sub.w	d1,d0					; sin(X)*sin(Y)*cos(Z)-cos(X)*sin(Z)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatB-SMCLoop(smc)
; C = cos(X)*sin(Y)*cos(Z)+sin(X)*sin(Z)
		move.w	d4,d0					; cos(X)*cos(Z)
		FPMULS	(sin,y),d0				; cos(X)*cos(Z)*sin(Y)
		move.w	(sin,x),d1				; sin(X)
		FPMULS	(sin,z),d1				; sin(X)*sin(Z)
		add.w	d1,d0					; cos(X)*cos(Z)*sin(Y)+sin(X)*sin(Z)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatC-SMCLoop(smc)
; D = cos(Y)*sin(Z)
		move.w	(cos,y),d0
		FPMULS	(sin,z),d0				; cos(Y)*sin(Z)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatD-SMCLoop(smc)
; E = sin(X)*sin(Y)*sin(Z)+cos(X)*cos(Z)
		move.w	d2,d0					; sin(X)*sin(Y)
		FPMULS	(sin,z),d0				; sin(X)*sin(Y)*sin(Z)
		add.w	d4,d0					; sin(X)*sin(Y)*sin(Z)+cos(X)*cos(Z)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatE-SMCLoop(smc)
; F = cos(X)*sin(Y)*sin(Z)−sin(X)*cos(Z)
		move.w	d3,d0					; sin(Z)*cos(X)
		FPMULS	(sin,y),d0				; cos(X)*sin(Y)*sin(Z)
		move.w	(sin,x),d1				; sin(X)
		FPMULS	(cos,z),d1				; sin(X)*cos(Z)
		sub.w	d1,d0
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatF-SMCLoop(smc)
; G = −sin(Y)
		move.w	(sin,y),d0				; sin(Y)
		neg.w	d0					; -sin(Y)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatG-SMCLoop(smc)
; H = sin(X)*cos(Y)
		move.w	(sin,x),d0				; sin(X)
		FPMULS	(cos,y),d0				; sin(X)*cos(Y)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatH-SMCLoop(smc)
; I = cos(X)*cos(Y)
		move.w	(cos,x),d0				; cos(X)
		FPMULS	(cos,y),d0				; cos(X)*cos(Y)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatI-SMCLoop(smc)

;-------------------------------------------------------------------------------
Transform:

points		equr	a0
draw		equr	a1
clear		equr	a2
divtbl		equr	a3
multbl		equr	a5
tx		equr	d0					; transformed
ty		equr	d1
tz		equr	d2
ox		equr	d3					; original
oy		equr	d4
oz		equr	d5
r		equr	d6

		move.l	DrawPoints,points
		move.l	DrawBuffer,draw
		lea	DIW_BW/2+SCREEN_H/2*SCREEN_BW(draw),draw ; centered with top/left padding
		move.l	DrawClearList,clear
		lea	DivTab,divtbl
		lea	MulsTable+(256*127+128),multbl		; start at middle of table (0x)

		move.w	#POINTS_COUNT-1,d7
SMCLoop:
__SMC__ = $7f							; Values to be replaced in self-modifying code
		movem.w	(points)+,ox-oz/r			; d0 = x, d1 = y, d2 = z, d6 = r
		move.l	a0,-(sp)				; out of registers :-(
Martix:
; Get Z first - skip rest if <=0:
; z'=G*x+H*y+I*z
MatG		move.b	__SMC__(multbl,ox.w),tz
MatH		add.b	__SMC__(multbl,oy.w),tz
		bvs	SMCNext
MatI		add.b	__SMC__(multbl,oz.w),tz
		bvs	SMCNext
		ext.w	tz

		move.w	Zoom(pc),a0
		add.w	Zoom(pc),tz
		ble	SMCNext

; Finish the matrix:
; x'=A*x+B*y+C*z
MatA		move.b	__SMC__(multbl,ox.w),tx
MatB		add.b	__SMC__(multbl,oy.w),tx
		bvs	SMCNext
MatC		add.b	__SMC__(multbl,oz.w),tx
		bvs	SMCNext
; y'=D*x+E*y+F*z
MatD		move.b	__SMC__(multbl,ox.w),ty
MatE		add.b	__SMC__(multbl,oy.w),ty
		bvs	SMCNext
MatF		add.b	__SMC__(multbl,oz.w),ty
		bvs	SMCNext

;-------------------------------------------------------------------------------
Colour:
		move.w	tz,d3
		sub.w	a0,d3					; TODO: this is dumb
		add.w	#128,d3
		lsr	#3,d3
		lea	ScreenOffsets,a0
		and.w	#$3c,d3
		move.l	(a0,d3.w),d3

;-------------------------------------------------------------------------------
Perspective:
		ext.w	ty
		ext.w	tx
		add.w	tz,tz
		move.w	(divtbl,tz),d5				; d5 = 1/z
		muls	d5,tx
		asr.l	#15-DIST_SHIFT,tx
		muls	d5,ty
		asr.l	#15-DIST_SHIFT,ty
		mulu	d5,r
		asr.l	#15-DIST_SHIFT,r

;-------------------------------------------------------------------------------
Draw:
		move.w	d6,d2
		jsr	DrawCircle

SMCNext		move.l	(sp)+,a0
		dbf	d7,SMCLoop
		move.l	#0,(clear)+				; End clear list

;-------------------------------------------------------------------------------
; EOF
		ifne	PROFILE
		move.w	#$f00,color(a6)
		endc
		DebugStartIdle
		jsr	WaitEOF
		DebugStopIdle

		bra	Frame
		rts


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
		asr.w	#8,d2					; d2 = (x*y)/128
		move.b	d2,(a0)+				; write to table
		addq	#1,d1
		dbf	d6,.loop2
		addq	#1,d0
		dbf	d7,.loop1
		rts


********************************************************************************
InitParticles:
		lea	Particles,a0
		moveq	#POINTS_COUNT-1,d7
.l0
; x/y/z (-127-127)<<8 pre-shifted fom muls offset
		jsr	Random32
		move.b	d0,(a0)+
		clr.b	(a0)+
		jsr	Random32
		move.b	d0,(a0)+
		clr.b	(a0)+
		jsr	Random32
		move.b	d0,(a0)+
		clr.b	(a0)+
; r (1-7)
		jsr	Random32
		and.w	#3,d0
		move.w	d0,d1
		jsr	Random32
		and.w	#3,d0
		add.w	d1,d0
		add.w	#1,d0
		move.w	d0,(a0)+

		dbf	d7,.l0
		rts


********************************************************************************
InitBox:
		lea	BoxPoints,a0

		move.w	#$9300,d0
		moveq	#4-1,d7
.x
		move.w	#$9300,d1
		moveq	#4-1,d6
.y
		move.w	#$9300,d2
		moveq	#4-1,d5
.z
		move.w	d0,(a0)+
		move.w	d1,(a0)+
		move.w	d2,(a0)+
		move.w	#4,(a0)+				; r

		add.w	#$4800,d2
		dbf	d5,.z

		add.w	#$4800,d1
		dbf	d6,.y

		add.w	#$4800,d0
		dbf	d7,.x
		rts


********************************************************************************
InitSphere:
		lea	SpherePointsData,a0
		lea	SpherePoints,a1
		moveq	#POINTS_COUNT-1,d7
.l0
		move.b	(a0)+,d0
		move.b	(a0)+,d1
		move.b	(a0)+,d2
		lsl.w	#8,d0
		lsl.w	#8,d1
		lsl.w	#8,d2
		move.w	d0,(a1)+
		move.w	d1,(a1)+
		move.w	d2,(a1)+
		jsr	Random32
		and.w	#7,d0
		addq	#1,d0
		move.w	d0,(a1)+
		dbf	d7,.l0
		rts


********************************************************************************
InitLogo:
		lea	LogoPointsData,a0
		lea	LogoPoints,a1
		moveq	#2,d3
		moveq	#6-1,d7
.letter
		move.b	(a0)+,d0				; x offset
		move.b	(a0)+,d6				; count-1
		ext.w	d6
.pt
		move.b	(a0)+,d1
		move.b	(a0)+,d2
		add.b	d0,d1
		sub.b	#13,d1
		sub.b	#2,d2
		lsl.b	#3,d1
		lsl.b	#3,d2
		move.b	d1,(a1)+				; x
		clr.b	(a1)+
		move.b	d2,(a1)+				; y
		clr.b	(a1)+
		clr.w	(a1)+					; z
		move.w	d3,(a1)+				; r
		dbf	d6,.pt
		dbf	d7,.letter
		rts


********************************************************************************
LerpPoints:
		lea	LerpPointsIncs,a2
		lea	LerpPointsTmp,a4
		moveq	#POINTS_COUNT-1,d7
.l0
		movem.w	(a0)+,d0-d3
; write initial values to tmp
		move.w	d3,d4
		lsl.w	#8,d4					; r needs to be FP too
		movem.w	d0-d2/d4,(a4)
		addq	#8,a4
; get deltas
		sub.w	(a1)+,d0
		sub.w	(a1)+,d1
		sub.w	(a1)+,d2
		sub.w	(a1)+,d3
; store increments
		asr.w	#LERP_POINTS_SHIFT,d0
		asr.w	#LERP_POINTS_SHIFT,d1
		asr.w	#LERP_POINTS_SHIFT,d2
		ifgt	8-LERP_POINTS_SHIFT
		lsl.w	#8-LERP_POINTS_SHIFT,d3
		endc
		movem.w	d0-d3,(a2)
		addq	#8,a2
		dbf	d7,.l0

		move.w	#LERP_POINTS_LENGTH,LerpPointsRemaining
		rts


********************************************************************************
LerpPointsStep:
		tst.w	LerpPointsRemaining
		beq	.done

		lea	LerpPointsIncs,a0
		lea	LerpPointsTmp,a1
		lea	LerpPointsOut,a2
LERP_UNROLL = 4
		moveq	#POINTS_COUNT/LERP_UNROLL-1,d7
.l0
		rept	LERP_UNROLL
; get tmp values
		movem.w	(a1),d3-d6
; add increments
		sub.w	(a0)+,d3
		sub.w	(a0)+,d4
		sub.w	(a0)+,d5
		sub.w	(a0)+,d6
; update tmp
		movem.w	d3-d6,(a1)
		addq	#8,a1
; clean up tmp points for use
		clr.b	d3
		clr.b	d4
		clr.b	d5
		lsr.w	#8,d6
; write to points buffer
		movem.w	d3-d6,(a2)
		addq	#8,a2
		endr
		dbf	d7,.l0
		sub.w	#1,LerpPointsRemaining
		move.l	#LerpPointsOut,DrawPoints
.done		rts

LerpPointsRemaining: dc.w 0


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
Vars:
********************************************************************************

Zoom:		dc.w	0
ZoomBase:	dc.w	2000

ParticlesSpeed:
ParticlesSpeedX: dc.w	0					;-$100
ParticlesSpeedY: dc.w	0					;$400
ParticlesSpeedZ: dc.w	0					;-$200


********************************************************************************
Data:
********************************************************************************

ScreenOffsets:
		dc.l	SCREEN_BPL*4
		dc.l	SCREEN_BPL*3
		dc.l	SCREEN_BPL*2
		dc.l	SCREEN_BPL
		dc.l	0
		dc.l	0
		dc.l	0
		dc.l	0
		dc.l	0
		dc.l	0

Pal:
; dc.w $011,$344,$766,$ba8,$fda ; nic orange
; dc.w $011,$235,$468,$79c,$acf ; nice blue
; dc.w $011,$344,$576,$9b8,$cfa ; nice green
		dc.w	$011,$334,$757,$b8a,$fae		; nice pink
		dc.w	$011,$345,$768,$bab,$fdf		; nice
		dc.w	$020,$453,$787,$bca,$fff		; dark green
		dc.w	$020,$353,$687,$aba,$eff		; green screen
		dc.w	$101,$334,$668,$aab,$eff		; simple
		dc.w	$420,$743,$a65,$db8,$ffd
		dc.w	$114,$437,$869,$cbb,$ffd

Sin1:
		dc.w	0,804,1608,2410,3212,4011,4808,5602
		dc.w	6393,7179,7962,8739,9512,10278,11039,11793
		dc.w	12539,13279,14010,14732,15446,16151,16846,17530
		dc.w	18204,18868,19519,20159,20787,21403,22005,22594
		dc.w	23170,23731,24279,24811,25329,25832,26319,26790
		dc.w	27245,27683,28105,28510,28898,29268,29621,29956
		dc.w	30273,30571,30852,31113,31356,31580,31785,31971
		dc.w	32137,32285,32412,32521,32609,32678,32728,32757
Cos1:
		dc.w	32767,32757,32728,32678,32609,32521,32412,32285
		dc.w	32137,31971,31785,31580,31356,31113,30852,30571
		dc.w	30273,29956,29621,29268,28898,28510,28105,27683
		dc.w	27245,26790,26319,25832,25329,24811,24279,23731
		dc.w	23170,22594,22005,21403,20787,20159,19519,18868
		dc.w	18204,17530,16846,16151,15446,14732,14010,13279
		dc.w	12539,11793,11039,10278,9512,8739,7962,7179
		dc.w	6393,5602,4808,4011,3212,2410,1608,804
		dc.w	0,-804,-1608,-2410,-3212,-4011,-4808,-5602
		dc.w	-6393,-7179,-7962,-8739,-9512,-10278,-11039,-11793
		dc.w	-12539,-13279,-14010,-14732,-15446,-16151,-16846,-17530
		dc.w	-18204,-18868,-19519,-20159,-20787,-21403,-22005,-22594
		dc.w	-23170,-23731,-24279,-24811,-25329,-25832,-26319,-26790
		dc.w	-27245,-27683,-28105,-28510,-28898,-29268,-29621,-29956
		dc.w	-30273,-30571,-30852,-31113,-31356,-31580,-31785,-31971
		dc.w	-32137,-32285,-32412,-32521,-32609,-32678,-32728,-32757
		dc.w	-32767,-32757,-32728,-32678,-32609,-32521,-32412,-32285
		dc.w	-32137,-31971,-31785,-31580,-31356,-31113,-30852,-30571
		dc.w	-30273,-29956,-29621,-29268,-28898,-28510,-28105,-27683
		dc.w	-27245,-26790,-26319,-25832,-25329,-24811,-24279,-23731
		dc.w	-23170,-22594,-22005,-21403,-20787,-20159,-19519,-18868
		dc.w	-18204,-17530,-16846,-16151,-15446,-14732,-14010,-13279
		dc.w	-12539,-11793,-11039,-10278,-9512,-8739,-7962,-7179
		dc.w	-6393,-5602,-4808,-4011,-3212,-2410,-1608,-804
		dc.w	0,804,1608,2410,3212,4011,4808,5602
		dc.w	6393,7179,7962,8739,9512,10278,11039,11793
		dc.w	12539,13279,14010,14732,15446,16151,16846,17530
		dc.w	18204,18868,19519,20159,20787,21403,22005,22594
		dc.w	23170,23731,24279,24811,25329,25832,26319,26790
		dc.w	27245,27683,28105,28510,28898,29268,29621,29956
		dc.w	30273,30571,30852,31113,31356,31580,31785,31971
		dc.w	32137,32285,32412,32521,32609,32678,32728,32757

; https://stackoverflow.com/questions/9600801/evenly-distributing-n-points-on-a-sphere
; TODO: could calc this if needed
SpherePointsData:
		dc.b	0,120,0
		dc.b	-23,116,-21
		dc.b	3,112,41
		dc.b	31,108,-41
		dc.b	-58,104,10
		dc.b	54,100,34
		dc.b	-19,97,-69
		dc.b	-35,93,66
		dc.b	75,89,-28
		dc.b	-78,85,-33
		dc.b	37,81,79
		dc.b	27,78,-87
		dc.b	-82,74,47
		dc.b	94,70,20
		dc.b	-58,66,-82
		dc.b	-14,62,101
		dc.b	79,59,-68
		dc.b	-107,55,-5
		dc.b	76,51,76
		dc.b	-6,47,-111
		dc.b	-72,43,85
		dc.b	112,40,-16
		dc.b	-94,36,-66
		dc.b	25,32,112
		dc.b	57,28,-102
		dc.b	-112,24,35
		dc.b	107,20,49
		dc.b	-46,17,-110
		dc.b	-41,13,112
		dc.b	105,9,-56
		dc.b	-116,5,-31
		dc.b	64,1,100
		dc.b	20,-2,-119
		dc.b	-95,-6,73
		dc.b	119,-10,9
		dc.b	-81,-14,-88
		dc.b	0,-18,118
		dc.b	79,-21,-88
		dc.b	-117,-25,10
		dc.b	92,-29,70
		dc.b	-21,-33,-114
		dc.b	-61,-37,96
		dc.b	109,-40,-30
		dc.b	-100,-44,-52
		dc.b	38,-48,103
		dc.b	40,-52,-101
		dc.b	-97,-56,45
		dc.b	99,-60,30
		dc.b	-52,-63,-89
		dc.b	-21,-67,97
		dc.b	79,-71,-57
		dc.b	-94,-75,-12
		dc.b	59,-79,69
		dc.b	3,-82,-88
		dc.b	-59,-86,59
		dc.b	79,-90,-5
		dc.b	-59,-94,-49
		dc.b	9,-98,69
		dc.b	36,-101,-54
		dc.b	-58,-105,13
		dc.b	44,-109,25
		dc.b	-13,-113,-41
		dc.b	-13,-117,27
		dc.b	0,-120,-0
		printv	*-SpherePointsData


LogoPointsData:
; D
		dc.b	0,12-1					; x,count
		dc.b	0,0,0,1,0,2,0,3,0,4
		dc.b	1,0,2,0
		dc.b	3,1,3,2,3,3
		dc.b	1,4,2,4
; E
		dc.b	5,13-1
		dc.b	0,0,0,1,0,2,0,3,0,4
		dc.b	1,0,2,0,3,0
		dc.b	1,2,2,2
		dc.b	1,4,2,4,3,4
; S
		dc.b	10,10-1
		dc.b	1,0,2,0,3,0
		dc.b	0,1
		dc.b	1,2,2,2
		dc.b	3,3
		dc.b	0,4,1,4,2,4
; i
		dc.b	15,4-1
		dc.b	0,0,0,2,0,3,0,4
; R
		dc.b	17,12-1
		dc.b	0,0,0,1,0,2,0,3,0,4
		dc.b	1,0,2,0
		dc.b	3,1
		dc.b	1,2,2,2
		dc.b	3,3,3,4
; E
		dc.b	22,13-1
		dc.b	0,0,0,1,0,2,0,3,0,4
		dc.b	1,0,2,0,3,0
		dc.b	1,2,2,2
		dc.b	1,4,2,4,3,4

*******************************************************************************
		bss
*******************************************************************************

; Multiplication lookup-table
MulsTable:	ds.b	256*256

LerpWordsState:	ds.b	Lerp_SIZEOF*LERPS_WORDS_LEN

Particles:	ds.b	Point_SIZEOF*POINTS_COUNT
BoxPoints:	ds.b	Point_SIZEOF*POINTS_COUNT
SpherePoints:	ds.b	Point_SIZEOF*POINTS_COUNT
LogoPoints:	ds.b	Point_SIZEOF*POINTS_COUNT

LerpPointsIncs:	ds.w	Point_SIZEOF*POINTS_COUNT
LerpPointsTmp:	ds.b	Point_SIZEOF*POINTS_COUNT
LerpPointsOut:	ds.b	Point_SIZEOF*POINTS_COUNT

DrawPoints:	ds.l	1
