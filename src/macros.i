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