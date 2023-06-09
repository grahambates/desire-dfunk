		incdir	"src"
		include	"_main.i"
		include	"tentacles.i"
		include	"rotate.i"
		include	"zcircles.i"
		include	"tunnel.i"
		include	"girl.i"

_start:
		include	"PhotonsMiniWrapper1.04.i"

MUSIC_ENABLE = 1
DMASET = DMAF_SETCLR!DMAF_MASTER!DMAF_RASTER!DMAF_COPPER!DMAF_BLITTER
INTSET = INTF_SETCLR!INTF_INTEN!INTF_VERTB|INTF_COPER
RANDOM_SEED = $a162b2c9
LERPS_WORDS_LEN = 4

DIVS_RANGE = $7ff

CHIP_BUFFER_SIZE = 1024*270
PUBLIC_BUFFER_SIZE = 1024*240


********************************************************************************
Demo:
********************************************************************************
		move.l	#MainInterrupt,$6c(a4)

		; Blank screen while precalcing
		lea	BlankCop,a0
		bsr	InstallCopper
		move.l	a0,cop1lc(a6)

		move.w	#DMASET,dmacon(a6)

;-------------------------------------------------------------------------------
Precalc:
		bsr	PrecalcTables
		jsr	Circles_Precalc

StartMusic:
		ifne	MUSIC_ENABLE
		lea	LSPMusic,a0
		lea	LSPBank,a1
		lea	CopDma+3,a2
		bsr	LSP_MusicInit
		move.w	#ADKF_USE0P1,adkcon(a6)
		endc

		move.w	#INTSET,intena(a6)
		move.l	#MainCop,cop1lc(a6)

;-------------------------------------------------------------------------------
Effects:
		; jsr	Girl_Effect
		; jsr	Tentacles_Effect
		; jsr	Tunnel_Effect
		jsr	Rotate_Effect
		rts						; Exit demo


********************************************************************************
MainInterrupt:
********************************************************************************
		movem.l	d0-a6,-(sp)
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
		bsr	LerpWordsStep				; TODO: should this be after Commander_Process?

		bsr	Commander_Process

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
		lea	$dff0a0,a6				; always set a6 to dff0a0 before calling LSP tick
		bsr	LSP_MusicPlayTick			; player music tick
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
		move.l	a0,d0
		swap.w	d0
		lea	Cop2Lc+2,a1
		move.w	d0,(a1)
		move.w	a0,4(a1)
		rts

********************************************************************************
ResetFrameCounter:
		clr.l	CurrFrame
		rts

********************************************************************************
; Memory
********************************************************************************

; TODO: limit check?
; TODO: bi-directional?

********************************************************************************
; Allocate chip RAM
;-------------------------------------------------------------------------------
; d0 = bytes
; returns a0 = address
;-------------------------------------------------------------------------------
AllocChip:
		move.l	AllocChipOffs(pc),a0
		add.l	d0,AllocChipOffs
		rts

********************************************************************************
; Allocate chip RAM within a single high word offset.
; Used so we can update just the lower word in copperlist.
;-------------------------------------------------------------------------------
; d0 = bytes
; returns a0 = address
;-------------------------------------------------------------------------------
AllocChipAligned:
		move.l	AllocChipOffs(pc),a0
		move.l	a0,d1
		move.l	d1,d2					; d2 = start address
		add.l	d0,d1					; d1 = end address
; compare upper word
		swap	d1
		swap	d2
		cmp.w	d1,d2
		beq	.ok
		; Not ok, need to adjust start
		swap	d1					; clear lower word of end address
		clr.w	d1
		move.l	d1,a0					; update returned address
		add.l	d0,d1					; add bytes to new start
		swap	d1
.ok
		; Ok, just swap back and set
		swap	d1
		move.l	d1,AllocChipOffs
		rts

********************************************************************************
; Allocate public RAM
;-------------------------------------------------------------------------------
; d0 = bytes
; returns a0 = address
;-------------------------------------------------------------------------------
AllocPublic:
		move.l	AllocPublicOffs(pc),a0
		add.l	d0,AllocPublicOffs
		rts

********************************************************************************
; Free allocated RAM
;-------------------------------------------------------------------------------
Free:
		move.l	#PublicBuffer,AllocPublicOffs
		move.l	#ChipBuffer,AllocChipOffs
		rts


********************************************************************************
PrecalcTables:
;-------------------------------------------------------------------------------
; Populate square root lookup table
;-------------------------------------------------------------------------------
		lea	SqrtTab,a0
		moveq	#0,d0
.loop0:		move.w	d0,d1
		add.w	d1,d1
.loop1:		move.b	d0,(a0)+
		dbf	d1,.loop1
		addq.b	#1,d0
		bcc.s	.loop0

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


********************************************************************************
* Simple command scripter
* Processes a list of subroutines to call on a given frame
*
* Each line of the script follows the format:
* dc.l  {frameNumber},{subroutine}[,...{args}]
*
* frameNumber: Frame to wait for before proceeding
* subroutine:  Subroutine to call or zero to end script
* args:        Additional data that the routine will read in as arguments.
*              The routine is responsible for reading args, incrementing from
*              (a5)+, leaving it intact and pointing to the next line.

********************************************************************************

********************************************************************************
; Load command script
;-------------------------------------------------------------------------------
; a0 - Command script ptr
;-------------------------------------------------------------------------------
Commander_Init:
		move.l	a0,cmdP
		rts


********************************************************************************
; Read script and process commands for this frame
;-------------------------------------------------------------------------------
; returns:
; d0.l - 1 = Finished script
;-------------------------------------------------------------------------------
Commander_Process:
		move.l	cmdP(pc),d1
		beq	.finished
		move.l	d1,a5
.next		move.l	CurrFrame(pc),d0
		cmp.l	(a5)+,d0				; Read frameNumber and comapre to current frame
		blt	.waiting				; Return 0 if waiting for frame
		move.l	(a5)+,d1				; Read routine to call
		beq	.finished				; Zero means the script is finished - return 1
		move.l	d1,a1					; Call the routine
		jsr	(a1)
		move.l	a5,cmdP					; Update position
		bra	.next
.waiting	moveq	#0,d0
		rts
.finished	moveq	#1,d0
		rts

; Current script position ptr
cmdP		dc.l	0


********************************************************************************
; Standard Commands:
;-------------------------------------------------------------------------------
; Equivalent to standard ASM mnemonics where args map to operators
;
; e.g.
; dc.l 100,CmdAddIL,10,XSpeed
;
; On frame 100, add 10 to longword address XSpeed
; equivalent to
; addi.l #10,XSpeed
********************************************************************************

CmdMoveIL:
		move.l	(a5)+,d0
		move.l	(a5)+,a1
		move.l	d0,(a1)
		rts
CmdMoveIW:
		move.l	(a5)+,d0
		move.l	(a5)+,a1
		move.w	d0,(a1)
		rts
CmdMoveIB:
		move.l	(a5)+,d0
		move.l	(a5)+,a1
		move.b	d0,(a1)
		rts
CmdAddIL:
		move.l	(a5)+,d0
		move.l	(a5)+,a1
		add.l	d0,(a1)
		rts
CmdAddIW:
		move.l	(a5)+,d0
		move.l	(a5)+,a1
		add.w	d0,(a1)
		rts
CmdAddIB:
		move.l	(a5)+,d0
		move.l	(a5)+,a1
		add.b	d0,(a1)
		rts
CmdSubIL:
		move.l	(a5)+,d0
		move.l	(a5)+,a1
		sub.l	d0,(a1)
		rts
CmdSubIW:
		move.l	(a5)+,d0
		move.l	(a5)+,a1
		sub.w	d0,(a1)
		rts
CmdSubIB:
		move.l	(a5)+,d0
		move.l	(a5)+,a1
		sub.b	d0,(a1)
		rts

CmdLerpWord:
		movem.l	(a5)+,d0-d1/a1
		jmp	LerpWord


********************************************************************************
Vars:
********************************************************************************

VBlank		dc.l	0
CurrFrame	dc.l	0
VbiRoutine	dc.l	0
AllocPublicOffs	dc.l	0
AllocChipOffs	dc.l	0


		; Include generic LSP player
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
		ifne	MUSIC_ENABLE
		dc.l	$009c8000|(1<<4)			; fire copper interrupt
		dc.l	(11<<24)|($09fffe)			; wait scanline 11
CopDma:		dc.w	dmacon,$8000
		endc
Cop2Lc:		dc.w	cop2lc,0				; Address of installed copper
		dc.w	cop2lc+2,0
		dc.w	copjmp2,0				; Jump to installed copper


;-------------------------------------------------------------------------------
; Initial Copperlist for blank screen
BlankCop:
		dc.w	diwstrt,$2c81
		dc.w	diwstop,$2cc1
		dc.w	bplcon0,$200
		dc.w	color00,$123
		dc.l	-2

*******************************************************************************
		bss_c
*******************************************************************************

ChipBuffer:
		ds.b	CHIP_BUFFER_SIZE
ChipBufferE:


*******************************************************************************
		bss
*******************************************************************************

PublicBuffer:
		ds.b	PUBLIC_BUFFER_SIZE
PublicBufferE:

; Precalced sqrt LUT data
SqrtTab:	ds.b	$100*$100

; FP 2/14
; +-16384
; ($c000-$4000) over 1024 ($400) steps
Sin:		ds.w	256
Cos:		ds.w	1024

DivTab:		ds.w	DIVS_RANGE

LerpWordsState:	ds.b	Lerp_SIZEOF*LERPS_WORDS_LEN

		section	anim,data
; incbin foo.BPL
