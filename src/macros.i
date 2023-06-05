
WAIT_BLIT	macro
		; tst.w	(a6)					;for compatibility with A1000
.\@:		btst	#DMAB_BLTDONE,dmaconr(a6)
		bne.s	.\@
		endm

; Fixed point multiplication for 1/15 format
FPMULS		macro
		muls	\1,\2
		add.l	\2,\2
		swap	\2
		endm

********************************************************************************
; Allocate memory
;-------------------------------------------------------------------------------
; \1 - byteSize
; \2 - locationDest (optional)
; a6 - exec
; trashes:
; d0-d1/a0
;-------------------------------------------------------------------------------
ALLOC_MEM       macro
                move.l      #\1,d0
                moveq       #MEMF_PUBLIC,d1
                jsr         _LVOAllocMem(a6)
                ifnb        \2
                move.l      d0,\2
                endc
                endm


********************************************************************************
; Allocate memory - zeroed
;-------------------------------------------------------------------------------
; \1 - byteSize
; \2 - locationDest (optional) - resulting location is copied here
; a6 - exec
; trashes:
; d0-d1/a0
;-------------------------------------------------------------------------------
ALLOC_MEM_CLR   macro
                move.l      #\1,d0
                move.l      #MEMF_PUBLIC!MEMF_CLEAR,d1
                jsr         _LVOAllocMem(a6)
                ifnb        \2
                move.l      d0,\2
                endc
                endm


********************************************************************************
; Allocate chip memory
;-------------------------------------------------------------------------------
; \1 - byteSize
; \2 - locationDest (optional) - resulting location is copied here
; a6 - exec
; trashes:
; d0-d1/a0
;-------------------------------------------------------------------------------
ALLOC_MEM_CHIP  macro
                move.l      #\1,d0
                moveq       #MEMF_CHIP,d1
                jsr         _LVOAllocMem(a6)
                ifnb        \2
                move.l      d0,\2
                endc
                endm


********************************************************************************
; Allocate memory at a given location
;-------------------------------------------------------------------------------
; \1 - byteSize
; \2 - location
; \3 - locationDest (optional) - resulting location is copied here
; a6 - exec
; trashes:
; d0-d1/a0-a1
;-------------------------------------------------------------------------------
ALLOC_ABS       macro
                move.l      #\1,d0
                move.l      \2,a1
                jsr         _LVOAllocAbs(a6)
                ifnb        \3
                move.l      d0,\3
                endc
                endm


********************************************************************************
; Free memory at a given location
;-------------------------------------------------------------------------------
; \1 - byteSize
; \2 - location
; a6 - exec
; trashes:
; d0-d1/a0-a1
;-------------------------------------------------------------------------------
FREE_MEM        macro
                move.l      #\1,d0
                move.l      \2,a1
                jsr         _LVOFreeMem(a6)
                endm