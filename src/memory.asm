		include	src/_main.i
		include	src/memory.i

CHIP_BUFFER_SIZE = 1024*200
PUBLIC_BUFFER_SIZE = 1024*280
; CHIP_BUFFER_SIZE = 1024*10
; PUBLIC_BUFFER_SIZE = 1024*10

********************************************************************************
; Memory
********************************************************************************

; TODO: limit check?
; TODO: bi-directional?

OutOfChip:
		move.w	#$ff0,color00(a6)
		bra	OutOfChip
OutOfPublic:
		move.w	#$00f,color00(a6)
		bra	OutOfPublic

********************************************************************************
; Allocate chip RAM
;-------------------------------------------------------------------------------
; d0 = bytes
; returns a0 = address
;-------------------------------------------------------------------------------
AllocChip:
		move.l	AllocChipOffs(pc),a0
		add.l	d0,AllocChipOffs
		move.l	d0,d1
		add.l	a0,d1
		cmp.l	#ChipBufferE,d1
		bgt	OutOfChip
		move.l	d1,AllocChipOffs
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
		move.l	d1,d2		; d2 = start address
		add.l	d0,d1		; d1 = end address
; compare upper word
		swap	d1
		swap	d2
		cmp.w	d1,d2
		beq	.ok
; Not ok, need to adjust start
		swap	d1		; clear lower word of end address
		clr.w	d1
		move.l	d1,a0		; update returned address
		add.l	d0,d1		; add bytes to new start
		swap	d1
.ok
; Ok, just swap back and set
		swap	d1
		cmp.l	#ChipBufferE,d1
		bgt	OutOfChip
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
		move.l	d0,d1
		add.l	a0,d1
		cmp.l	#PublicBufferE,d1
		bgt	OutOfPublic
		move.l	d1,AllocPublicOffs
		rts

********************************************************************************
; Free allocated RAM
;-------------------------------------------------------------------------------
Free:
		move.l	#PublicBuffer,AllocPublicOffs
		move.l	#ChipBuffer,AllocChipOffs
		rts


AllocPublicOffs	dc.l	0
AllocChipOffs	dc.l	0


*******************************************************************************
		bss
*******************************************************************************

PublicBuffer:
		ds.b	PUBLIC_BUFFER_SIZE
PublicBufferE:

*******************************************************************************
		bss_c
*******************************************************************************

ChipBuffer:
		ds.b	CHIP_BUFFER_SIZE
ChipBufferE:
