		include	_main.i
		include	rotate.i

DIW_BW = 320/8
SCREEN_BW = 336/8
SCREEN_H = 256+16

DIST_SHIFT = 7
ZOOM = 150
MAX_PARTICLES = 75

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

; Generate random particles
		lea	Particles,a0
		moveq	#MAX_PARTICLES-1,d7
.l0		bsr	InitParticle
		dbf	d7,.l0

Frame:
		jsr	SwapBuffers
		jsr	Clear

; Get / update rotation angles
		movem.w	Rot,d5-d7
		add.w	#1,d5
		add.w	#2,d6
		add.w	#3,d7
		movem.w	d5-d7,Rot

		and.w	#$1fe,d5
		and.w	#$1fe,d6
		and.w	#$1fe,d7

		; lea Sin,a0
		; move.w VBlank+2,d0
		; lsr #1,d0
		; and.w #$7fe,d0
		; move.w (a0,d0.w),d5
		; lsr #6,d5
		; add.w d5,d5
		; ; and.w	#$1fe,d5

		; move.w VBlank+2,d0
		; and.w #$7fe,d0
		; move.w (a0,d0.w),d6
		; lsr #6,d6
		; add.w d6,d6
		; ; and.w	#$1fe,d6

		; move.w VBlank+2,d0
		; divu #3,d0
		; and.w #$7fe,d0
		; move.w (a0,d0.w),d7
		; lsr #6,d7
		; add.w d7,d7
		; ; and.w	#$1fe,d7

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

divtbl		equr	a3
multbl		equr	a5
tx		equr	d0					; transformed
ty		equr	d1
tz		equr	d2
ox		equr	d3					; original
oy		equr	d4
oz		equr	d5
r		equr	d6

		lea	Particles,a0
		lea	MulsTable+(256*127),multbl		; start at middle of table (0x)
		lea	DivTab,divtbl

		move.l	DrawBuffer,a1
		lea	DIW_BW/2+SCREEN_H/2*SCREEN_BW(a1),a1	; centered with top/left padding
		move.l	DrawClearList,a2

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

		add.w	#ZOOM,tz

; Apply perspective:
		add.w	tz,tz
		move.w	(divtbl,tz),d5				; d5 = 1/z
		move.w 	#15-DIST_SHIFT,d4
		muls	d5,tx
		asr.l	d4,tx
		muls	d5,ty
		asr.l	d4,ty
		muls	d5,r
		asr.l	d4,r

		move.l	a0,-(sp)

		move.w	d6,d2
		moveq	#0,d3
		jsr	DrawCircle

		move.l	(sp)+,a0

.next		dbf	d7,SMCLoop
		move.l	#0,(a2)+				; End clear list

; EOF
		move.w #$f00,color(a6)
		DebugStartIdle
		jsr	WaitEOF
		DebugStopIdle
		move.w #0,color(a6)

		bra	Frame
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


********************************************************************************
InitParticle:
; x
		jsr	Random32
		move.b d0,d1
; y
		jsr	Random32
		move.b d0,d2
; z
		jsr	Random32
		move.b d0,d3

; Check dist from origin:
		move.b d1,d4
		ext.w d4
		muls	d4,d4
		move.b d2,d5
		ext.w d5
		muls	d5,d5
		move.b d3,d6
		ext.w d6
		muls	d6,d6
		add.w d5,d4
		add.w d6,d4
; Dist too great? Try again lol...
		cmp.w #128*128,d4
		bge InitParticle

		move.b	d1,(a0)+
		clr.b	(a0)+ ; pre-shifted <<8 from muls offset
		move.b	d2,(a0)+
		clr.b	(a0)+
		move.b	d3,(a0)+
		clr.b	(a0)+
; r
		jsr	Random32
		and.w	#3,d0
		addq	#5,d0
		move.w	d0,(a0)+

		rts

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
