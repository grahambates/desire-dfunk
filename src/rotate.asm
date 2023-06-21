		include	src/_main.i
		include	rotate.i

ROTATE_END_FRAME = $1000

DIW_W = CIRCLES_DIW_W
DIW_H = CIRCLES_DIW_H
SCREEN_W = CIRCLES_SCREEN_W
SCREEN_H = CIRCLES_SCREEN_H
BPLS = 5

SIN_MASK = $1fe
SIN_SHIFT = 8

DIST_SHIFT = 7
ZOOM_SHIFT = 8
; FIXED_ZOOM = 300

POINTS_COUNT = 64
LERP_POINTS_SHIFT = 5
LERP_POINTS_LENGTH = 1<<LERP_POINTS_SHIFT

PROFILE = 0

		rsreset
Point_X		rs.w	1
Point_Y		rs.w	1
Point_Z		rs.w	1
Point_R		rs.w	1
Point_SIZEOF	rs.b	0


;-------------------------------------------------------------------------------
; Derived
COLORS = 1<<BPLS
SCREEN_BW = SCREEN_W/8
SCREEN_BPL = SCREEN_BW*SCREEN_H
SCREEN_SIZE = SCREEN_BW*SCREEN_H*BPLS
DIW_BW = DIW_W/8
DIW_MOD = SCREEN_BW-DIW_BW-2
DIW_XSTRT = ($242-DIW_W)/2
DIW_YSTRT = ($158-DIW_H)/2
DIW_XSTOP = DIW_XSTRT+DIW_W
DIW_YSTOP = DIW_YSTRT+DIW_H

Script:
		dc.l	0,CmdLerpPal,16,6,PalStart,Pal
		dc.l	0,CmdLerpWord,200,7,ZoomBase
; Cube
		dc.l	$180,CmdLerpPoints,SpherePoints,CubePoints
; Particles
		dc.l	$300,CmdLerpPoints,CubePoints,Particles
		dc.l	$300,CmdLerpWord,150,6,ZoomBase
; Start movement
		dc.l	$300+LERP_POINTS_LENGTH+1,SetParticles
		dc.l	$300+LERP_POINTS_LENGTH+1,CmdLerpWord,$200,3,ParticlesSpeedX
		dc.l	$300+LERP_POINTS_LENGTH+1,CmdLerpWord,$400,5,ParticlesSpeedY
		dc.l	$300+LERP_POINTS_LENGTH+1,CmdLerpWord,$400,3,ParticlesSpeedZ
; Stop movement
		dc.l	$480-(1<<3),CmdLerpWord,0,3,ParticlesSpeedX
		dc.l	$480-(1<<3),CmdLerpWord,0,3,ParticlesSpeedY
		dc.l	$480-(1<<3),CmdLerpWord,0,3,ParticlesSpeedZ
; Logo
		dc.l	$480+LERP_POINTS_LENGTH,CmdLerpPoints,Particles,LogoPoints
; Hearts
; dc.l $700,CmdLerpPoints,LogoPoints,HeartPoints
		dc.l	$680,CmdLerpPoints,LogoPoints,SpherePoints
; ; Zoom out
		dc.l	$700,CmdLerpWord,1000,8,ZoomBase
		dc.l	$800,CmdLerpPal,16,6,Pal,PalStart
		dc.l	0,0

SetParticles:
		move.l	Particles,DrawPoints
		rts


********************************************************************************
Rotate_Effect:
********************************************************************************
		jsr	Free
		jsr	ResetFrameCounter

		lea	BlankCop,a0
		sub.l	a1,a1
		jsr	StartEffect

		; Allocate and clear screen memory
		move.l	#SCREEN_SIZE,d0
		; screen 1
		jsr	AllocChip
		move.l	a0,DrawBuffer
		WAIT_BLIT
		move.l	a0,bltdpt(a6)
		move.l	#$01000000,bltcon0(a6)
		clr.l	bltdmod(a6)
		move.w	#(SCREEN_H*3)<<6!(SCREEN_BW/2),bltsize(a6)
		WAIT_BLIT
		move.w	#(SCREEN_H*2)<<6!(SCREEN_BW/2),bltsize(a6)
		; screen 2
		jsr	AllocChip
		move.l	a0,ViewBuffer
		WAIT_BLIT
		move.l	a0,bltdpt(a6)
		move.w	#(SCREEN_H*3)<<6!(SCREEN_BW/2),bltsize(a6)
		WAIT_BLIT
		move.w	#(SCREEN_H*2)<<6!(SCREEN_BW/2),bltsize(a6)

		; Allocate data mem
		move.l	#Point_SIZEOF*POINTS_COUNT,d0
		jsr	AllocPublic
		move.l	a0,Particles
		jsr	AllocPublic
		move.l	a0,CubePoints
		jsr	AllocPublic
		move.l	a0,SpherePoints
		jsr	AllocPublic
		move.l	a0,HeartPoints
		jsr	AllocPublic
		move.l	a0,LogoPoints
		jsr	AllocPublic
		move.l	a0,LerpPointsTmp
		jsr	AllocPublic
		move.l	a0,LerpPointsOut
		move.l	#Point_SIZEOF*POINTS_COUNT*2,d0
		jsr	AllocPublic
		move.l	a0,LerpPointsIncs

		bsr	Rotate_Precalc

		move.l	SpherePoints(pc),DrawPoints
		; move.l	HeartPoints(pc),DrawPoints

		lea	Cop,a0
		lea	Rotate_Vbi(pc),a1
		jsr	StartEffect

		lea	Script,a0
		jsr	Commander_Init

********************************************************************************
Frame:
		move.l	PalOut,a0
		bsr	LoadPalette

		bsr	LerpPointsStep	; TODO: vbi?

UpdateParticles:
		move.l	Particles(pc),a0
		move.l	DrawPoints(pc),a1
		cmp.l	a0,a1
		bne	.skipUpdate
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
.skipUpdate

;-------------------------------------------------------------------------------
SetZoom:
		lea	Sin,a0
		move.w	CurrFrame+2,d0
		lsl	#3,d0
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
		move.w	CurrFrame+2,d4
		; x
		move.w	d4,d5
		lsl	#1,d5
		add.w	#$200,d5
		and.w	#$7fe,d5
		move.w	(a0,d5.w),d5
		lsr	#4,d5
		and.w	#SIN_MASK,d5
		; y
		move.w	d4,d6
		lsl	#1,d6
		; add.w	#$200,d6
		and.w	#$7fe,d6
		move.w	(a0,d6.w),d6
		lsr	#4,d6
		and.w	#SIN_MASK,d6
		; z
		move.w	d4,d7
		muls	#3,d7
		and.w	#SIN_MASK,d7

		; move.w	#0,d5
		; move.w	#0,d6
		move.w	#0,d7

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
		FPMULS	(sin,y),d2	; d2 = sin(X)*sin(Y)
		move.w	(cos,x),d3
		FPMULS	(sin,z),d3	; d3 = sin(Z)*cos(X)
		move.w	(cos,x),d4
		FPMULS	(cos,z),d4	; d4 = cos(X)*cos(Z)

; A = cos(Y)*cos(Z)
		move.w	(cos,y),d0
		FPMULS	(cos,z),d0	; cos(Y)*cos(Z)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatA-SMCLoop(smc)
; B = sin(X)*sin(Y)*cos(Z)−cos(X)*sin(Z)
		move.w	d2,d0		; sin(X)*sin(Y)
		FPMULS	(cos,z),d0	; sin(X)*sin(Y)*cos(Z)
		move.w	(cos,x),d1	; cos(X)
		FPMULS	(sin,z),d1	; cos(X)*sin(Z)
		sub.w	d1,d0		; sin(X)*sin(Y)*cos(Z)-cos(X)*sin(Z)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatB-SMCLoop(smc)
; C = cos(X)*sin(Y)*cos(Z)+sin(X)*sin(Z)
		move.w	d4,d0		; cos(X)*cos(Z)
		FPMULS	(sin,y),d0	; cos(X)*cos(Z)*sin(Y)
		move.w	(sin,x),d1	; sin(X)
		FPMULS	(sin,z),d1	; sin(X)*sin(Z)
		add.w	d1,d0		; cos(X)*cos(Z)*sin(Y)+sin(X)*sin(Z)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatC-SMCLoop(smc)
; D = cos(Y)*sin(Z)
		move.w	(cos,y),d0
		FPMULS	(sin,z),d0	; cos(Y)*sin(Z)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatD-SMCLoop(smc)
; E = sin(X)*sin(Y)*sin(Z)+cos(X)*cos(Z)
		move.w	d2,d0		; sin(X)*sin(Y)
		FPMULS	(sin,z),d0	; sin(X)*sin(Y)*sin(Z)
		add.w	d4,d0		; sin(X)*sin(Y)*sin(Z)+cos(X)*cos(Z)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatE-SMCLoop(smc)
; F = cos(X)*sin(Y)*sin(Z)−sin(X)*cos(Z)
		move.w	d3,d0		; sin(Z)*cos(X)
		FPMULS	(sin,y),d0	; cos(X)*sin(Y)*sin(Z)
		move.w	(sin,x),d1	; sin(X)
		FPMULS	(cos,z),d1	; sin(X)*cos(Z)
		sub.w	d1,d0
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatF-SMCLoop(smc)
; G = −sin(Y)
		move.w	(sin,y),d0	; sin(Y)
		neg.w	d0		; -sin(Y)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatG-SMCLoop(smc)
; H = sin(X)*cos(Y)
		move.w	(sin,x),d0	; sin(X)
		FPMULS	(cos,y),d0	; sin(X)*cos(Y)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatH-SMCLoop(smc)
; I = cos(X)*cos(Y)
		move.w	(cos,x),d0	; cos(X)
		FPMULS	(cos,y),d0	; cos(X)*cos(Y)
		asr.w	#SIN_SHIFT,d0
		move.b	d0,MatI-SMCLoop(smc)



;-------------------------------------------------------------------------------
; EOF
		ifne	PROFILE
		move.w	#$f00,color(a6)
		endc
		DebugStartIdle
		jsr	WaitEOF
		DebugStopIdle

		jsr	SwapBuffers

		move.l	DrawClearList(pc),a0
		jsr	ClearCircles


;-------------------------------------------------------------------------------
Transform:

points		equr	a0
draw		equr	a1
clear		equr	a2
divtbl		equr	a3
multbl		equr	a5
tx		equr	d0		; transformed
ty		equr	d1
tz		equr	d2
ox		equr	d3		; original
oy		equr	d4
oz		equr	d5
r		equr	d6

		move.l	DrawPoints,points
		move.l	DrawBuffer,draw
		lea	DIW_BW/2+DIW_H/2*SCREEN_BW(draw),draw ; centered with top/left padding
		move.l	DrawClearList,clear
		lea	MulsTable+256*127+128,multbl ; start at middle of table (0x)

		move.w	#POINTS_COUNT-1,d7
SMCLoop:
__SMC__ = $7f				; Values to be replaced in self-modifying code
		movem.w	(points)+,ox-oz/r ; d0 = x, d1 = y, d2 = z, d6 = r
		move.l	a0,-(sp)	; out of registers :-(
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
		sub.w	a0,d3		; TODO: this is dumb
		asr.w	#5,d3
		lsl.w	#2,d3
		lea	ScreenOffsets,a0
		move.l	(a0,d3.w),d3

;-------------------------------------------------------------------------------
Perspective:
		ext.w	ty
		ext.w	tx
		add.w	tz,tz
		lea	DivTab,divtbl
		move.w	(divtbl,tz),d5	; d5 = 1/z
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
		move.l	#0,(clear)+	; End clear list

		jsr	WaitEOF
		cmp.l	#ROTATE_END_FRAME,CurrFrame
		blt	Frame

		rts


********************************************************************************
Rotate_Vbi:
********************************************************************************
; Set bpl ptrs
		move.l	ViewBuffer(pc),a0
		lea	bpl0pt+custom,a1
		rept	BPLS
		move.l	a0,(a1)+
		lea	SCREEN_BPL(a0),a0
		endr
		rts


********************************************************************************
Rotate_Precalc:
********************************************************************************
		bsr	InitParticles
		bsr	InitCube
		bsr	InitSphere
		; bsr InitHeart
		bsr	InitLogo
		bsr	BuildPalette
		rts


********************************************************************************
BuildPalette:
		lea	PalE,a1
		move.w	#31-1,d6
.col
		lea	Colors+12,a2
		moveq	#0,d0		; r
		moveq	#0,d1		; g
		moveq	#0,d2		; b
		moveq	#5-1,d5		; iterate channels
.chan1
		move.w	-(a2),d4	; Channel color
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
		rts


********************************************************************************
InitParticles:
		move.l	Particles(pc),a0
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
		and.w	#7,d0
		add.w	d1,d0
		add.w	#1,d0
		move.w	d0,(a0)+

		dbf	d7,.l0
		rts


********************************************************************************
InitCube:
		move.l	CubePoints(pc),a0

PAD = $30
RANGE = $100-PAD-PAD
INC = RANGE/3
START = -$80+PAD

		move.w	#START<<8,d0
		moveq	#4-1,d7
.x
		move.w	#START<<8,d1
		moveq	#4-1,d6
.y
		move.w	#START<<8,d2
		moveq	#4-1,d5
.z
		move.w	d0,(a0)+
		move.w	d1,(a0)+
		move.w	d2,(a0)+
		move.w	#6,(a0)+	; r

		add.w	#INC<<8,d2
		dbf	d5,.z

		add.w	#INC<<8,d1
		dbf	d6,.y

		add.w	#INC<<8,d0
		dbf	d7,.x
		rts


********************************************************************************
InitSphere:
		lea	SpherePointsData(pc),a0
		move.l	SpherePoints(pc),a1
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

; ********************************************************************************
; InitHeart:
; 	lea	HeartPointsData(pc),a0
; 	move.l	HeartPoints(pc),a1
; 	moveq	#POINTS_COUNT-1,d7
; .l0
; 	move.b	(a0)+,d0
; 	move.b	(a0)+,d1
; 	move.b	(a0)+,d2
; 	lsl.w	#8,d0
; 	lsl.w	#8,d1
; 	lsl.w	#8,d2
; 	move.w	d0,(a1)+
; 	move.w	d1,(a1)+
; 	move.w	d2,(a1)+
; 	jsr	Random32
; 	and.w	#3,d0
; 	addq	#2,d0
; 	move.w	d0,(a1)+
; 	dbf	d7,.l0
; 	rts


********************************************************************************
InitLogo:
		lea	LogoPointsData,a0
		move.l	LogoPoints(pc),a1
		moveq	#2,d3
		moveq	#6-1,d7
.letter
		move.b	(a0)+,d0	; x offset
		move.b	(a0)+,d6	; count-1
		ext.w	d6
.pt
		move.b	(a0)+,d1
		move.b	(a0)+,d2
		add.b	d0,d1
		sub.b	#13,d1
		sub.b	#2,d2
		lsl.b	#3,d1
		lsl.b	#3,d2
		move.b	d1,(a1)+	; x
		clr.b	(a1)+
		move.b	d2,(a1)+	; y
		clr.b	(a1)+
		clr.w	(a1)+		; z
		move.w	d3,(a1)+	; r
		dbf	d6,.pt
		dbf	d7,.letter
		rts


********************************************************************************
LerpPoints:
		move.l	LerpPointsIncs(pc),a2
		move.l	LerpPointsTmp(pc),a4
		moveq	#POINTS_COUNT-1,d7
.l0
		movem.w	(a0)+,d0-d3
; write initial values to tmp
		move.w	d3,d4
		lsl.w	#8,d4		; r needs to be FP too
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

		move.l	LerpPointsIncs(pc),a0
		move.l	LerpPointsTmp(pc),a1
		move.l	LerpPointsOut(pc),a2
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
		move.l	LerpPointsOut(pc),DrawPoints
.done		rts

LerpPointsRemaining: dc.w 0

********************************************************************************
; LerpPoints for commander
CmdLerpPoints:
		movem.l	(a5)+,a0-a1
		move.l	(a0),a0
		move.l	(a1),a1
		jmp	LerpPoints


********************************************************************************
SwapBuffers:
		movem.l	DblBuffers(pc),a0-a3
		exg	a0,a1
		exg	a2,a3
		movem.l	a0-a3,DblBuffers
		rts


********************************************************************************
LoadPalette:
		lea	color01(a6),a1
		addq	#2,a0
		move.w	#32/2-1,d0
.col		move.l	(a0)+,(a1)+
		dbf	d0,.col
		rts


********************************************************************************
Vars:
********************************************************************************

DblBuffers:
DrawClearList:	dc.l	ClearList2
ViewClearList:	dc.l	ClearList1
DrawBuffer:	dc.l	0
ViewBuffer:	dc.l	0

Zoom:		dc.w	0
ZoomBase:	dc.w	1500

DrawPoints:	dc.l	0

ParticlesSpeed:
ParticlesSpeedX: dc.w	0		;-$100
ParticlesSpeedY: dc.w	0		;$400
ParticlesSpeedZ: dc.w	0		;-$200


Allocated:
Particles:	dc.l	0
CubePoints:	dc.l	0
SpherePoints:	dc.l	0
HeartPoints:	dc.l	0
LogoPoints:	dc.l	0
LerpPointsTmp:	dc.l	0
LerpPointsOut:	dc.l	0
LerpPointsIncs:	dc.l	0

********************************************************************************
Data:
********************************************************************************

		dc.l	SCREEN_BPL*4
		dc.l	SCREEN_BPL*4
		dc.l	SCREEN_BPL*4
		dc.l	SCREEN_BPL*3
ScreenOffsets:	dc.l	SCREEN_BPL*2
		dc.l	SCREEN_BPL
		dc.l	0
		dc.l	0
		dc.l	0

Pal:		ds.w	32
PalE:

PalStart:
		rept	32
		dc.w	$024
		endr


Colors:
		; ; green / cyan
		; dc.w $123,$164,$3a4,$4c8,$5dc,$5ef ; https://gradient-blaster.grahambates.com/?points=123@0,3a4@2,5ef@5&steps=6&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
		; ; pink / cyan
		dc.w	$024,$636,$a39,$a7b,$9bd,$5ef ; https://gradient-blaster.grahambates.com/?points=123@0,a39@2,5ef@5&steps=6&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
		; ; bright pink / cyan
		; dc.w $123,$737,$d0b,$c8d,$abe,$5ef ; https://gradient-blaster.grahambates.com/?points=123@0,d1b@2,5ef@5&steps=6&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40

		; bright pink / blue
		; dc.w	$123,$228,$40d,$84d,$b5e,$f5d ; https://gradient-blaster.grahambates.com/?points=123@0,41d@2,f5d@5&steps=6&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40

		; dc.w	$000,$f00,$0f0,$00f,$0ff,$fff ; test
		; dc.w $011,$344,$766,$ba8,$fda ; nic orange
		; dc.w $011,$235,$468,$79c,$acf ; nice blue
		; dc.w $011,$344,$576,$9b8,$cfa ; nice green

		;; dc.w	$123,$336,$649,$86a,$a7b,$b9b
		; dc.w	$000,$324,$649,$86a,$a7b,$b9b		; https://gradient-blaster.grahambates.com/?points=001@0,649@2,b9b@5&steps=6&blendMode=oklab&ditherMode=blueNoise&target=amigaOcs&ditherAmount=40
		; dc.w	$011,$334,$757,$b8a,$fae,$fff		; nice pink

		; dc.w	$011,$345,$768,$bab,$fdf		; nice
		; dc.w	$020,$453,$787,$bca,$fff		; dark green
		; dc.w	$020,$353,$687,$aba,$eff		; green screen
		;; dc.w	$101,$334,$668,$aab,$eff		; simple

		;; dc.w	$420,$743,$a65,$db8,$ffd
		; dc.w	$114,$437,$869,$cbb,$ffd

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

; HeartPointsData:
; 	dc.b 8,40,-68
; 	dc.b -8,46,-68
; 	dc.b 20,51,-55
; 	dc.b 6,65,-56
; 	dc.b -4,72,-48
; 	dc.b -18,56,-55
; 	dc.b -15,70,-41
; 	dc.b -3,55,64
; 	dc.b -8,35,69
; 	dc.b 9,41,67
; 	dc.b 1,19,67
; 	dc.b -18,18,60
; 	dc.b -21,48,55
; 	dc.b -13,69,46
; 	dc.b 5,67,53
; 	dc.b 19,55,55
; 	dc.b 17,24,61
; 	dc.b -14,-16,36
; 	dc.b -4,-40,14
; 	dc.b 19,0,46
; 	dc.b 5,-9,50
; 	dc.b -6,74,-24
; 	dc.b -7,62,0
; 	dc.b 8,73,-24
; 	dc.b 17,68,-43
; 	dc.b 23,61,-29
; 	dc.b -29,25,-35
; 	dc.b -23,12,-47
; 	dc.b -25,-26,-3
; 	dc.b -24,39,-53
; 	dc.b -24,57,-41
; 	dc.b -30,13,0
; 	dc.b -24,58,-23
; 	dc.b 9,-17,-40
; 	dc.b 1,17,-66
; 	dc.b 18,17,-59
; 	dc.b -12,15,-63
; 	dc.b -12,-19,-36
; 	dc.b 10,65,10
; 	dc.b -6,74,22
; 	dc.b 18,51,1
; 	dc.b 18,69,37
; 	dc.b 6,75,33
; 	dc.b -17,69,29
; 	dc.b -18,52,1
; 	dc.b -29,30,37
; 	dc.b -24,42,0
; 	dc.b -26,54,33
; 	dc.b -26,6,36
; 	dc.b 28,18,39
; 	dc.b 24,42,52
; 	dc.b 26,56,36
; 	dc.b 27,44,-43
; 	dc.b 26,9,-39
; 	dc.b 6,63,-3
; 	dc.b 26,-20,-1
; 	dc.b 30,7,0
; 	dc.b 19,-35,-7
; 	dc.b 25,39,1
; 	dc.b -4,-47,-3
; 	dc.b -16,-40,-5
; 	dc.b -17,-36,8
; 	dc.b 14,-40,7
; 	dc.b 8,-44,-6



LogoPointsData:
; D
		dc.b	0,12-1		; x,count
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

		printt	"Rotate: Data"
		printv	*-Data


*******************************************************************************
		data_c
*******************************************************************************

;-------------------------------------------------------------------------------
; Cirlces copper list:
Cop:
		dc.w	dmacon,DMAF_SPRITE
		dc.w	diwstrt,DIW_YSTRT<<8!DIW_XSTRT
		dc.w	diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
		dc.w	ddfstrt,(DIW_XSTRT-17)>>1&$fc
		dc.w	ddfstop,(DIW_XSTRT-17+(SCREEN_W>>4-1)<<4)>>1&$fc
		dc.w	bpl1mod,DIW_MOD
		dc.w	bpl2mod,DIW_MOD
		dc.w	bplcon0,BPLS<<12!$200
		dc.w	bplcon1,0
		dc.w	color,$024
		dc.l	-2
CopE:
