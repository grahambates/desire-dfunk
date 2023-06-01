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
; FIXED_ZOOM = 300

POINTS_COUNT = 64
LERP_POINTS_SHIFT = 8
LERP_POINTS_LENGTH = 1<<LERP_POINTS_SHIFT

PROFILE = 1

FPMULS		macro
		muls	\1,\2
		add.l	\2,\2
		swap	\2
		endm

		rsreset
Point_X		rs.w	1
Point_Y		rs.w	1
Point_Z		rs.w	1
Point_R		rs.w	1
Point_SIZEOF	rs.b	0


********************************************************************************
Rotate_Vbl:
********************************************************************************
		jsr PokeBpls

; Scripting:
		move.w	VBlank+2,d0
; lerp1
		cmp.w	#$100,d0
		blt	.lerp1Done
		bne	.lerp1Step
		lea	SpherePoints,a0
		lea	BoxPoints,a1
		bsr	LerpPointsStart
		bra	.lerp1Done
.lerp1Step
		cmp.w	#$100+LERP_POINTS_LENGTH,d0
		bgt	.lerp1Done
		bsr	LerpPointsStep
		move.l	#LerpPointsOut,DrawPoints
.lerp1Done

; lerp2
		cmp.w	#$300,d0
		blt	.scr
		bne	.lerp2Step
		lea	BoxPoints,a0
		lea	Particles,a1
		bsr	LerpPointsStart
		bra	.scr
.lerp2Step
		cmp.w	#$300+LERP_POINTS_LENGTH,d0
		bgt	.lerp2Done
		bsr	LerpPointsStep
		move.l	#LerpPointsOut,DrawPoints
		bra .scr
.lerp2Done
		move.w #120,ZoomBase
; Update particles:
		lea	Particles,a0
		move.l	a0,DrawPoints
		moveq	#POINTS_COUNT-1,d7
.l0
		sub.w	#$100,(a0)
		add.w	#$400,2(a0)
		sub.w	#$200,4(a0)
		lea	Point_SIZEOF(a0),a0
		dbf	d7,.l0
.scr
	rts


********************************************************************************
Rotate_Effect:
********************************************************************************
		lea	Rotate_Vbl(pc),a0
		jsr	InstallInterrupt

		bsr	InitMulsTbl
		bsr	InitParticles
		bsr	InitBox

		move.w	#200,ZoomBase
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

		move.w	Pal,color(a6)

;-------------------------------------------------------------------------------
SetZoom:
		lea	Sin,a0
		move.w	VBlank+2,d0
		lsl	#2,d0
		and.w	#$7fe,d0
		move.w	(a0,d0.w),d5
		asr	#8,d5
		add.w	ZoomBase(pc),d5
		move.w	d5,Zoom
		ifd FIXED_ZOOM
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
		move.w	#15-DIST_SHIFT,d4
		muls	d5,tx
		asr.l	d4,tx
		muls	d5,ty
		asr.l	d4,ty
		mulu	d5,r
		asr.l	d4,r

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
		move.w	#$005,color(a6)
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
LerpPointsStart:
		lea	LerpPointsIncs,a2
		lea	LerpPointsTmp,a4
		moveq	#POINTS_COUNT-1,d7
.l0
		movem.w	(a0)+,d0-d3
; write initial values to tmp
		move.w	d0,(a4)+
		move.w	d1,(a4)+
		move.w	d2,(a4)+
		move.w	d3,d4
		lsl.w	#8,d4					; r needs to be FP too
		move.w	d4,(a4)+
; get deltas
		sub.w	(a1)+,d0
		sub.w	(a1)+,d1
		sub.w	(a1)+,d2
		sub.w	(a1)+,d3
; store increments
		asr.w	#LERP_POINTS_SHIFT,d0
		asr.w	#LERP_POINTS_SHIFT,d1
		asr.w	#LERP_POINTS_SHIFT,d2
		move.w	d0,(a2)+
		move.w	d1,(a2)+
		move.w	d2,(a2)+
		move.w	d3,(a2)+
		dbf	d7,.l0
		rts


********************************************************************************
LerpPointsStep:
		lea	LerpPointsIncs,a0
		lea	LerpPointsTmp,a1
		lea	LerpPointsOut,a2
		moveq	#POINTS_COUNT-1,d7
.l0
; get increments
		movem.w	(a0)+,d0-d2/a3
; get tmp values
		movem.w	(a1),d3-d6
; add increments
		sub.w	d0,d3
		sub.w	d1,d4
		sub.w	d2,d5
		sub.w	a3,d6
; update tmp
		move.w	d3,(a1)+
		move.w	d4,(a1)+
		move.w	d5,(a1)+
		move.w	d6,(a1)+
; clean up tmp points for use
		clr.b	d3
		clr.b	d4
		clr.b	d5
		lsr.w	#8,d6
; write to points buffer
		move.w	d3,(a2)+
		move.w	d4,(a2)+
		move.w	d5,(a2)+
		move.w	d6,(a2)+
		dbf	d7,.l0
		rts


********************************************************************************
Vars:
********************************************************************************

Zoom:		dc.w	0
ZoomBase:	dc.w	0


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

Pal:		dc.w	$114,$437,$869,$cbb,$ffd

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
SpherePoints:
		dc.w	0<<8,120<<8,0<<8,4
		dc.w	-23<<8,116<<8,-21<<8,4
		dc.w	3<<8,112<<8,41<<8,4
		dc.w	31<<8,108<<8,-41<<8,4
		dc.w	-58<<8,104<<8,10<<8,4
		dc.w	54<<8,100<<8,34<<8,4
		dc.w	-19<<8,97<<8,-69<<8,4
		dc.w	-35<<8,93<<8,66<<8,4
		dc.w	75<<8,89<<8,-28<<8,4
		dc.w	-78<<8,85<<8,-33<<8,4
		dc.w	37<<8,81<<8,79<<8,4
		dc.w	27<<8,78<<8,-87<<8,4
		dc.w	-82<<8,74<<8,47<<8,4
		dc.w	94<<8,70<<8,20<<8,4
		dc.w	-58<<8,66<<8,-82<<8,4
		dc.w	-14<<8,62<<8,101<<8,4
		dc.w	79<<8,59<<8,-68<<8,4
		dc.w	-107<<8,55<<8,-5<<8,4
		dc.w	76<<8,51<<8,76<<8,4
		dc.w	-6<<8,47<<8,-111<<8,4
		dc.w	-72<<8,43<<8,85<<8,4
		dc.w	112<<8,40<<8,-16<<8,4
		dc.w	-94<<8,36<<8,-66<<8,4
		dc.w	25<<8,32<<8,112<<8,4
		dc.w	57<<8,28<<8,-102<<8,4
		dc.w	-112<<8,24<<8,35<<8,4
		dc.w	107<<8,20<<8,49<<8,4
		dc.w	-46<<8,17<<8,-110<<8,4
		dc.w	-41<<8,13<<8,112<<8,4
		dc.w	105<<8,9<<8,-56<<8,4
		dc.w	-116<<8,5<<8,-31<<8,4
		dc.w	64<<8,1<<8,100<<8,4
		dc.w	20<<8,-2<<8,-119<<8,4
		dc.w	-95<<8,-6<<8,73<<8,4
		dc.w	119<<8,-10<<8,9<<8,4
		dc.w	-81<<8,-14<<8,-88<<8,4
		dc.w	0<<8,-18<<8,118<<8,4
		dc.w	79<<8,-21<<8,-88<<8,4
		dc.w	-117<<8,-25<<8,10<<8,4
		dc.w	92<<8,-29<<8,70<<8,4
		dc.w	-21<<8,-33<<8,-114<<8,4
		dc.w	-61<<8,-37<<8,96<<8,4
		dc.w	109<<8,-40<<8,-30<<8,4
		dc.w	-100<<8,-44<<8,-52<<8,4
		dc.w	38<<8,-48<<8,103<<8,4
		dc.w	40<<8,-52<<8,-101<<8,4
		dc.w	-97<<8,-56<<8,45<<8,4
		dc.w	99<<8,-60<<8,30<<8,4
		dc.w	-52<<8,-63<<8,-89<<8,4
		dc.w	-21<<8,-67<<8,97<<8,4
		dc.w	79<<8,-71<<8,-57<<8,4
		dc.w	-94<<8,-75<<8,-12<<8,4
		dc.w	59<<8,-79<<8,69<<8,4
		dc.w	3<<8,-82<<8,-88<<8,4
		dc.w	-59<<8,-86<<8,59<<8,4
		dc.w	79<<8,-90<<8,-5<<8,4
		dc.w	-59<<8,-94<<8,-49<<8,4
		dc.w	9<<8,-98<<8,69<<8,4
		dc.w	36<<8,-101<<8,-54<<8,4
		dc.w	-58<<8,-105<<8,13<<8,4
		dc.w	44<<8,-109<<8,25<<8,4
		dc.w	-13<<8,-113<<8,-41<<8,4
		dc.w	-13<<8,-117<<8,27<<8,4
		dc.w	0<<8,-120<<8,-0<<8,4


*******************************************************************************
		bss
*******************************************************************************

; Multiplication lookup-table
MulsTable:	ds.b	256*256

Particles:	ds.b	Point_SIZEOF*POINTS_COUNT
BoxPoints:	ds.b	Point_SIZEOF*POINTS_COUNT

LerpPointsIncs:	ds.w	Point_SIZEOF*POINTS_COUNT
LerpPointsTmp:	ds.b	Point_SIZEOF*POINTS_COUNT
LerpPointsOut:	ds.b	Point_SIZEOF*POINTS_COUNT

DrawPoints:	ds.l	1
