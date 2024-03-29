		include	"src/_main.i"

		include	"tentacles.i"
		include	"rotate.i"
		include	"tunnel.i"
		include	"girl.i"
		include	"dude.i"
		include	"image.i"
		include	"metabobs.i"

_start:
		include	"PhotonsMiniWrapper1.04.i"

MUSIC_ENABLE = 1
MUSIC_USE_CIA = 0
DMASET = DMAF_SETCLR!DMAF_MASTER!DMAF_RASTER!DMAF_COPPER!DMAF_BLITTER
INTSET = INTF_SETCLR!INTF_INTEN!INTF_VERTB|INTF_COPER
RANDOM_SEED = $a162b2c9


********************************************************************************
Demo:
********************************************************************************
		move.l	#MainInterrupt,$6c(a4)

		; Blank screen while precalcing
		lea	BlankCop,a0
		bsr	InstallCopper
		move.l	a0,cop1lc(a6)
		move.w	#DMASET,dmacon(a6)

; Precalc
		jsr	Tables_Precalc
		jsr	Circles_Precalc

		move.w	#INTSET,intena(a6)
		move.l	#MainCop,cop1lc(a6)

		bsr	StartMusic

;-------------------------------------------------------------------------------
; Effects
		jsr	Girl_Effect
		jsr	Tentacles_Effect
		jsr	Image_Effect
		jsr	Tunnel_Effect
		jsr	Dude_Effect
		jsr	Metabobs_Effect
		jsr	Rotate_Effect
		rts			; Exit demo


********************************************************************************
MainInterrupt:
********************************************************************************
		movem.l	d0-a6,-(sp)

		tst.w	MusicPlaying
		beq	.notStarted
		lea	$dff0a0,a6	; always set a6 to dff0a0 before calling LSP tick
		bsr	LSP_MusicPlayTick ; player music tick
.notStarted

		lea	custom,a6

;-------------------------------------------------------------------------------
; Vertical blank interrupt:
		btst	#INTB_VERTB,intreqr+1(a6)
		beq.s	.notvb
; Increment frame counter:
		lea	Vars(pc),a5
		addq.l	#1,VBlank-Vars(a5)
		addq.l	#1,CurrFrame-Vars(a5)
; Process active lerps
		jsr	LerpWordsStep	; TODO: should this be after Commander_Process?
		jsr	LerpPalStep
		jsr	Commander_Process
; Call effect interrupt if Installed
		move.l	VbiRoutine(pc),d0
		beq	.noInt
		move.l	d0,a0
		jsr	(a0)
.noInt
		moveq	#INTF_VERTB,d0
		move.w	d0,intreq(a6)
		move.w	d0,intreq(a6)
		bra	.end
.notvb:

;-------------------------------------------------------------------------------
; Copper interrupt
		btst	#INTB_COPER,intreqr+1(a6)
		beq.s	.end
		lea	$dff0a0,a6	; always set a6 to dff0a0 before calling LSP tick
		bsr	LSP_MusicPlayTick ; player music tick
		moveq	#INTF_COPER,d0
		move.w	d0,intreq+custom
		move.w	d0,intreq+custom
.end
		movem.l	(sp)+,d0-a6
		rte


********************************************************************************
; Start a new effect
;-------------------------------------------------------------------------------
; a0 - Copper
; a1 - Vbi (or 0)
;-------------------------------------------------------------------------------
StartEffect:
		move.l	a1,VbiRoutine
********************************************************************************
InstallCopper:
		ifeq	MUSIC_USE_CIA
		move.l	a0,d0
		swap.w	d0
		lea	Cop2Lc+2,a1
		move.w	d0,(a1)
		move.w	a0,4(a1)
		else
		move.l	a0,cop1lc(a6)
		endc
		rts

********************************************************************************
; d0.w - bg color
BlankScreen:
		lea	BlankCop,a0
		sub.l	a1,a1
		bra	StartEffect

********************************************************************************
ResetFrameCounter:
		clr.l	CurrFrame
		rts


********************************************************************************
; Random number generator
;-------------------------------------------------------------------------------
; Returns:
; d0 - random 32 bit value
;-------------------------------------------------------------------------------
Random32:
		move.l	RandomSeed(pc),d0
		add.l	d0,d0
		bcc.s	.done
		eori.b	#$af,d0
.done:		move.l	d0,RandomSeed
		rts
RandomSeed:	dc.l	RANDOM_SEED


********************************************************************************
StartMusic:
		ifne	MUSIC_ENABLE
		lea	LSPMusic,a0
		lea	LSPBank,a1

		ifeq	MUSIC_USE_CIA
		lea	CopDma+3,a2
		bsr	LSP_MusicInit
		move.w	#1,MusicPlaying
		move.w	#ADKF_USE0P1,adkcon(a6)
		else
		sub.l	a2,a2
		moveq	#0,d0
		bsr	LSP_MusicDriver_CIA_Start
		endc
		endc
		rts

********************************************************************************
StopMusic:
		ifne	MUSIC_ENABLE
		ifeq	MUSIC_USE_CIA
		clr.w	MusicPlaying
		else
		bsr	LSP_MusicDriver_CIA_Stop
		endc
		endc
		rts


********************************************************************************
Vars:
********************************************************************************

VBlank		dc.l	0
CurrFrame	dc.l	0
VbiRoutine	dc.l	0
MusicPlaying	dc.w	0


		ifne	MUSIC_USE_CIA
		include	"LightSpeedPlayer_cia.i"
		endc
		include	"LightSpeedPlayer.i"


********************************************************************************
Data:
********************************************************************************

LSPMusic:	incbin	"data/funky_shuffler.lsmusic"
		even


*******************************************************************************
		data_c
*******************************************************************************

LSPBank:	incbin	"data/funky_shuffler.lsbank"
		even

;-------------------------------------------------------------------------------
MainCop:
		dc.w	fmode,0
		ifne	MUSIC_ENABLE^MUSIC_USE_CIA
		COP_WAITV 11
CopDma:		dc.w	dmacon,$8000
		endc
Cop2Lc:		dc.w	cop2lc,0	; Address of installed copper
		dc.w	cop2lc+2,0
		dc.w	copjmp2,0	; Jump to installed copper


;-------------------------------------------------------------------------------
; Initial Copperlist for blank screen
BlankCop:
		dc.w	diwstrt,$2c81
		dc.w	diwstop,$2cc1
		dc.w	bplcon0,$200
		dc.w	color00
BlankBg		dc.w	0
		dc.l	-2
