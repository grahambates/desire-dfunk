		include	_main.i
		include	rotate.i

DIW_W = 320
DIW_H = 256
DIW_BW = DIW_W/8
SCREEN_W = DIW_W+32
SCREEN_H = DIW_H+32
SCREEN_BW = SCREEN_W/8
SCREEN_BPL = SCREEN_BW*SCREEN_H

DIST_SHIFT = 8
MAX_PARTICLES = 70
FIXED_ZOOM=300

PROFILE=0

FPMULS		macro
		muls	\1,\2
		add.l	\2,\2
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

		move.w	#$222,color01(a6)
		move.w	#$444,color02(a6)
		move.w	#$555,color03(a6)
		move.w	#$777,color04(a6)
		move.w	#$888,color05(a6)
		move.w	#$888,color06(a6)
		move.w	#$999,color07(a6)
		move.w	#$aaa,color08(a6)
		move.w	#$aaa,color09(a6)
		move.w	#$bbb,color10(a6)
		move.w	#$bbb,color11(a6)
		move.w	#$ccc,color12(a6)
		move.w	#$ccc,color13(a6)
		move.w	#$ddd,color14(a6)
		move.w	#$ddd,color15(a6)
		move.w	#$eee,color16(a6)
		move.w	#$eee,color17(a6)
		move.w	#$eee,color18(a6)
		move.w	#$eee,color19(a6)
		move.w	#$eee,color20(a6)
		move.w	#$eee,color21(a6)
		move.w	#$eee,color22(a6)
		move.w	#$fff,color23(a6)
		move.w	#$fff,color24(a6)
		move.w	#$fff,color25(a6)
		move.w	#$fff,color26(a6)
		move.w	#$fff,color27(a6)
		move.w	#$fff,color28(a6)
		move.w	#$fff,color29(a6)
		move.w	#$fff,color30(a6)
		move.w	#$fff,color31(a6)

; Generate random particles
		lea	Particles,a0
		moveq	#MAX_PARTICLES-1,d7
.l0		bsr	InitParticle
		dbf	d7,.l0

Frame:
		move.w	#$000,color00(a6)
		jsr	SwapBuffers
		jsr	Clear

		lea	Particles,a0
		moveq	#MAX_PARTICLES-1,d7
.l0		add.w #$300,2(a0)
		sub.w #$400,4(a0)
		lea Particle_SIZEOF(a0),a0
		dbf	d7,.l0

; Zoom:
		lea	Sin,a0
		move.w	VBlank+2,d0
		lsl	#2,d0
		and.w	#$7fe,d0
		move.w	(a0,d0.w),d5
		asr	#8,d5
		add.w	#180,d5
		move.w	d5,Zoom
		; move.w #FIXED_ZOOM,Zoom

; Rotation:
		movem.w	Rot,d5-d7
		add.w	#2,d5
		add.w	#4,d6
		add.w	#2,d7
		movem.w	d5-d7,Rot

		and.w	#$1fe,d5
		and.w	#$1fe,d6
		and.w	#$1fe,d7

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
		asr.w	#8,d0
		move.b	d0,MatA-SMCLoop(smc)
; B = sin(X)*sin(Y)*cos(Z)−cos(X)*sin(Z)
		move.w	d2,d0					; sin(X)*sin(Y)
		FPMULS	(cos,z),d0				; sin(X)*sin(Y)*cos(Z)
		move.w	(cos,x),d1				; cos(X)
		FPMULS	(sin,z),d1				; cos(X)*sin(Z)
		sub.w	d1,d0					; sin(X)*sin(Y)*cos(Z)-cos(X)*sin(Z)
		asr.w	#8,d0
		move.b	d0,MatB-SMCLoop(smc)
; C = cos(X)*sin(Y)*cos(Z)+sin(X)*sin(Z)
		move.w	d4,d0					; cos(X)*cos(Z)
		FPMULS	(sin,y),d0				; cos(X)*cos(Z)*sin(Y)
		move.w	(sin,x),d1				; sin(X)
		FPMULS	(sin,z),d1				; sin(X)*sin(Z)
		add.w	d1,d0					; cos(X)*cos(Z)*sin(Y)+sin(X)*sin(Z)
		asr.w	#8,d0
		move.b	d0,MatC-SMCLoop(smc)
; D = cos(Y)*sin(Z)
		move.w	(cos,y),d0
		FPMULS	(sin,z),d0				; cos(Y)*sin(Z)
		asr.w	#8,d0
		move.b	d0,MatD-SMCLoop(smc)
; E = sin(X)*sin(Y)*sin(Z)+cos(X)*cos(Z)
		move.w	d2,d0					; sin(X)*sin(Y)
		FPMULS	(sin,z),d0				; sin(X)*sin(Y)*sin(Z)
		add.w	d4,d0					; sin(X)*sin(Y)*sin(Z)+cos(X)*cos(Z)
		asr.w	#8,d0
		move.b	d0,MatE-SMCLoop(smc)
; F = cos(X)*sin(Y)*sin(Z)−sin(X)*cos(Z)
		move.w	d3,d0					; sin(Z)*cos(X)
		FPMULS	(sin,y),d0				; cos(X)*sin(Y)*sin(Z)
		move.w	(sin,x),d1				; sin(X)
		FPMULS	(cos,z),d1				; sin(X)*cos(Z)
		sub.w	d1,d0
		asr.w	#8,d0
		move.b	d0,MatF-SMCLoop(smc)
; G = −sin(Y)
		move.w	(sin,y),d0				; sin(Y)
		neg.w	d0					; -sin(Y)
		asr.w	#8,d0
		move.b	d0,MatG-SMCLoop(smc)
; H = sin(X)*cos(Y)
		move.w	(sin,x),d0				; sin(X)
		FPMULS	(cos,y),d0				; sin(X)*cos(Y)
		asr.w	#8,d0
		move.b	d0,MatH-SMCLoop(smc)
; I = cos(X)*cos(Y)
		move.w	d4,d0					; cos(X)*cos(Z)
		asr.w	#8,d0
		move.b	d0,MatI-SMCLoop(smc)

********************************************************************************
; Combined operation to rotate, translate and apply perspective to all the
; vertices in an object. The resulting 2d vertices are written back to the
; temporary 'Transformed' buffer.
;-------------------------------------------------------------------------------
Transform:

particles	equr	a0
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

		lea	Particles,particles
		move.l	DrawBuffer,draw
		lea	DIW_BW/2+SCREEN_H/2*SCREEN_BW(draw),draw	; centered with top/left padding
		move.l	DrawClearList,clear
		lea	DivTab,divtbl
		lea	MulsTable+(256*127+128),multbl		; start at middle of table (0x)

		move.w	#MAX_PARTICLES-1,d7
SMCLoop:
__SMC__ = $7f							; Values to be replaced in self-modifying code
		movem.w	(particles)+,ox-oz/r				; d0 = x, d1 = y, d2 = z, d6 = r
		move.l	a0,-(sp)				; out of registers :-(
Martix:
; Get Z first - skip rest if <=0:
; z'=G*x+H*y+I*z
MatG		move.b	__SMC__(multbl,ox.w),tz
MatH		add.b	__SMC__(multbl,oy.w),tz
		bvs SMCNext
MatI		add.b	__SMC__(multbl,oz.w),tz
		bvs SMCNext
		ext.w	tz

		move.w	Zoom(pc),a0
		add.w	Zoom(pc),tz
		ble	SMCNext

; Finish the matrix:
; x'=A*x+B*y+C*z
MatA		move.b	__SMC__(multbl,ox.w),tx
MatB		add.b	__SMC__(multbl,oy.w),tx
		bvs SMCNext
MatC		add.b	__SMC__(multbl,oz.w),tx
		bvs SMCNext
; y'=D*x+E*y+F*z
MatD		move.b	__SMC__(multbl,ox.w),ty
MatE		add.b	__SMC__(multbl,oy.w),ty
		bvs SMCNext
MatF		add.b	__SMC__(multbl,oz.w),ty
		bvs SMCNext

Colour:
		move.w	tz,d3
		sub.w	a0,d3				; TODO: this is dumb
		add.w	#128,d3
		lsr	#3,d3
		lea	Offsets,a0
		and.w	#$3c,d3
		move.l	(a0,d3.w),d3

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
Draw:
		move.w	d6,d2
		jsr	DrawCircle

SMCNext		move.l	(sp)+,a0

		dbf	d7,SMCLoop
		move.l	#0,(clear)+				; End clear list

; EOF
		ifne PROFILE
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
InitParticle:
; x
		jsr	Random32
		move.b	d0,d1
; y
		jsr	Random32
		move.b	d0,d2
; z
		jsr	Random32
		move.b	d0,d3

; ; Check dist from origin:
; 		move.b	d1,d4
; 		ext.w	d4
; 		muls	d4,d4
; 		move.b	d2,d5
; 		ext.w	d5
; 		muls	d5,d5
; 		move.b	d3,d6
; 		ext.w	d6
; 		muls	d6,d6
; 		add.l	d5,d4
; 		add.l	d6,d4
; ; Dist too great? Try again lol...
; 		cmp.l	#105*105,d4
; 		bge	InitParticle

		move.b	d1,(a0)+
		clr.b	(a0)+					; pre-shifted <<8 from muls offset
		move.b	d2,(a0)+
		clr.b	(a0)+
		move.b	d3,(a0)+
		clr.b	(a0)+
; r
		jsr	Random32
		and.w	#3,d0
		addq	#1,d0
		move.w	d0,(a0)+

		rts

Offsets:
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


Zoom:		dc.w	0

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


*******************************************************************************
		bss
*******************************************************************************

; Multiplication lookup-table
MulsTable:	ds.b	256*256

Particles:	ds.b	Particle_SIZEOF*MAX_PARTICLES

Rot:		ds.w	3
