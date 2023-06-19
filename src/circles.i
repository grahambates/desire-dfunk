CIRCLES_DIW_W = 320
CIRCLES_DIW_H = 256
CIRCLES_PAD = CIRCLES_MAX_R*2
CIRCLES_SCREEN_W = CIRCLES_DIW_W+CIRCLES_PAD
CIRCLES_SCREEN_H = CIRCLES_DIW_H+CIRCLES_PAD
; Maximum radius for blitter circles
; Need to adjust BltCircBpl size when you change this
CIRCLES_MAX_R = 24

		rsreset
Blit_Adr	rs.l	1
Blit_Mod	rs.w	1
Blit_Sz		rs.w	1
Blit_SIZEOF	rs.b	0

		xdef	Circles_Precalc
		xdef	ClearCircles
		xdef	DrawCircle
		xdef	BlitCircle
		xdef	Plot
		xdef	BltCircSizes
		xdef	ClearList1
		xdef	ClearList2
		xdef	DrawCircleFill
