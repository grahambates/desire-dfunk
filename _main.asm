        include "_main.i"
        include "tentacles.i"
        include "rotate.i"

_start:
        include "PhotonsMiniWrapper1.04.i"

MUSIC_ENABLE = 1
MAX_CLEAR = 100*2+2
DMASET = DMAF_SETCLR!DMAF_MASTER!DMAF_RASTER!DMAF_COPPER!DMAF_BLITTER
INTSET = INTF_SETCLR!INTF_INTEN!INTF_VERTB
RANDOM_SEED = $12345678

; Display window:
DIW_W = 320
DIW_H = 256
BPLS = 5

; Screen buffer:
SCREEN_W = DIW_W+32
SCREEN_H = DIW_H+32

;-------------------------------------------------------------------------------
; Derived

COLORS = 1<<BPLS

SCREEN_BW = SCREEN_W/8						; byte-width of 1 bitplane line
SCREEN_BPL = SCREEN_BW*SCREEN_H					; bitplane offset (non-interleaved)
SCREEN_SIZE = SCREEN_BW*SCREEN_H*BPLS			; byte size of screen buffer

DIW_BW = DIW_W/8
DIW_MOD = SCREEN_BW-DIW_BW-2
DIW_XSTRT = ($242-DIW_W)/2
DIW_YSTRT = ($158-DIW_H)/2
DIW_XSTOP = DIW_XSTRT+DIW_W
DIW_YSTOP = DIW_YSTRT+DIW_H


********************************************************************************
Interrupt:
        movem.l d0-a6,-(sp)
        lea     custom,a6
        btst    #5,intreqr+1(a6)
        beq.s   .notvb

; Increment frame counter:
        lea     VBlank(pc),a0
        addq.l  #1,(a0)

        ; ifne    MUSIC_ENABLE
        ; jsr     Music_Play
        ; endc

        move.l InterruptRoutine,d0
        beq .noInt
        move.l d0,a0
        jsr (a0)
.noInt

        moveq   #INTF_VERTB,d0
        move.w  d0,intreq(a6)
        move.w  d0,intreq(a6)
.notvb: movem.l (sp)+,d0-a6
        rte

PokeBpls:
        move.l  ViewBuffer(pc),a0
        lea     bpl0pt+custom,a1
        rept    BPLS
        move.l  a0,(a1)+
        lea     SCREEN_BPL(a0),a0
        endr
        rts

InstallInterrupt:
        move.l a0,InterruptRoutine
        rts

InterruptRoutine:
        dc.l 0

********************************************************************************
Demo:
; Register debug resources:
        DebugRegisterResource DebugResScreen
        DebugRegisterResource DebugResScreen2
        DebugRegisterResource DebugResCop

        move.w  #0,color00(a6)                  ; clear bg during precalc
        move.l  #Cop,cop1lc(a6)
        move.l  #Interrupt,$6c(a4)

********************************************************************************
Precalc:
        move.w  #DMAF_SETCLR!DMAF_MASTER!DMAF_BLITTER,dmacon(a6)

********************************************************************************
; Initialise blitter circle data
;-------------------------------------------------------------------------------
; `BltCircBpl` is populated with a range of filled circles with radius from 1-MAX_R.
; `BltCircSizes` is populated with pointers to the bitplane data and blit
; parameters for each size.
;-------------------------------------------------------------------------------
InitBlitCircles:
        lea     BltCircBpl,a0
        lea     BltCircSizes,a1
        move.w  #BLTCIRC_MAX_R,d7
        move.b  #%10100000,(a0)                 ; fix up smallest circle
; Initial radius for smallest circle
        moveq   #1,d0                           ; d0 = radius
.l:
        move.w  d0,d2                           ; d2 = diameter
        add.w   d2,d2
; Calc byte width
        move.w  d2,d1                           ; d1 = byte width
        add.w   #31,d1                          ; round up + 1 word
        lsr.w   #4,d1                           ; /16
        add.w   d1,d1                           ; *2
; Store address
        move.l  a0,(a1)+
; Modulo
        move.w  #SCREEN_BW,d4                   ; d4 = blit modulo
        sub.w   d1,d4
        move.w  d4,(a1)+
; Blit size
        move.w  d2,d3                           ; d3 = blit size
        lsl.w   #6,d3
        move.w  d1,d4
        lsr.w   d4
        add.w   d4,d3
        move.w  d3,(a1)+
; Draw the circle outline
        bsr     DrawCircleFill
; Next bpl:
        mulu    d2,d1                           ; offset = byte width * diameter
        lea     (a0,d1.w),a0
; Blitter fill (descending)
        lea     -1(a0),a2
        WAIT_BLIT
        move.l  #-1,bltafwm(a6)
        clr.l   bltamod(a6)
        move.l  #$09f00012,bltcon0(a6)
        move.l  a2,bltapth(a6)
        move.l  a2,bltdpth(a6)
        move.w  d3,bltsize(a6)
; Next radius
        addq    #1,d0
        cmp.w   d7,d0
        ble     .l

; Calc length for BSS
; sub.l #BltCircBpl,a0
; nop

********************************************************************************
; Populate square root lookup table
;-------------------------------------------------------------------------------
InitSqrt:
        lea     SqrtTab,a0
        moveq   #0,d0
.loop0: move.w  d0,d1
        add.w   d1,d1
.loop1: move.b  d0,(a0)+
        dbf     d1,.loop1
        addq.b  #1,d0
        bcc.s   .loop0


********************************************************************************
; Populate sin table
;-------------------------------------------------------------------------------
; https://eab.abime.net/showpost.php?p=1471651&postcount=24
; maxError = 26.86567%
; averageError = 8.483626%
;-------------------------------------------------------------------------------
InitSin:
        lea     Sin,a0
        moveq   #0,d0
        move.w  #16383,d1
        moveq   #32,d2
.loop:
        move.w  d0,d3
        muls    d1,d3
        asr.l   #8,d3
        asr.l   #4,d3
        move.w  d3,(a0)+
        neg.w   d3
        move.w  d3,1022(a0)
        add.w   d2,d0
        sub.w   d2,d1
        bgt.s   .loop
; Copy extra 90 deg for cosine
        lea Sin,a0
        lea Sin+1024*2,a1
        move.w #256/2,d0
.copy
        move.l (a0)+,(a1)+
        dbf d0,.copy


********************************************************************************
; Populate reciprocal division lookup table
;-------------------------------------------------------------------------------
InitDiv:
        lea     DivTab+2,a0
        moveq   #1,d7
.l:
        move.l  #$10000,d0
        divu    d7,d0
        move.w  d0,(a0)+
        addq    #1,d7
        cmp.w   #$fff,d7
        ble     .l


********************************************************************************
; Populate noise table:
; 256 steps of 1D perlin-like noise
;-------------------------------------------------------------------------------
InitValueNoise:
        move.w  #16,d1                          ; values
        move.w  #16,d2                          ; steps
        move.w  #0,d3                           ; range
        moveq   #3-1,d7
.octave:
        lea     ValueNoise,a0                   ; reset pointer
        move.w  #0,d4                           ; current value
        move.w  d1,d6
        subq    #1,d6
.value:
        jsr     Random32
        and.l   #$1fff,d0                       ; 31<<8 (fixed point)
        lsr.w   d3,d0
        sub.w   d4,d0
        ext.l   d0
        divs    d2,d0
        move.w  d2,d5
        subq    #1,d5
.step:
; lerp value
        add.w   d0,d4

; Need to shift >>8 before writing to table
; out of data regs - backup and restore d5
        move.w  d5,a1
        move.w  d4,d5
        lsr.w   #8,d5
        add.b   d5,(a0)+
        move.w  a1,d5

        dbf     d5,.step
        dbf     d6,.value
; New values for next octave
        lsl.w   d1                              ; values *= 2
        lsr.w   d2                              ; steps /= 2
        addq    #1,d3                           ; range shift
        dbf     d7,.octave

        ; ifne    MUSIC_ENABLE
        ; jsr     Music_Init
        ; endc

        move.w  #INTSET,intena(a6)
        bsr     WaitEOF
        move.w  #DMASET,dmacon(a6)

********************************************************************************
Effects:
        ; jsr     Tentacles_Effect
        jsr     Rotate_Effect
        rts                                     ; Exit demo


********************************************************************************
SwapBuffers:
        movem.l DblBuffers(pc),a0-a5
        exg     a0,a1
        exg     a2,a3
        exg     a4,a5
        movem.l a0-a5,DblBuffers
        rts


********************************************************************************
Clear:
        move.l  DrawClearList(pc),a0
        move.l  #$01000000,d0
        move.w  #DMAF_SETCLR!DMAF_BLITHOG,dmacon(a6) ; hog the blitter
.l:
        move.l  (a0)+,d1
        beq     .done                           ; address: end of array on zero
        move.w  (a0)+,d2                        ; mod/bit
        move.w  (a0)+,d3                        ; bltsize or zero for plot
        beq     .plot
; Clear blitted circle
        WAIT_BLIT
        move.l  d0,bltcon0(a6)
        move.l  d1,bltdpt(a6)
        move.w  d2,bltdmod(a6)
        move.w  d3,bltsize(a6)
        bra     .l
.plot:
; Clear plotted point
        move.l  d1,a2
        bclr    d2,(a2)
        bra     .l
.done:
        move.w  #DMAF_BLITHOG,dmacon(a6)
        rts


********************************************************************************
; Blit or plot circle with oob checks
;-------------------------------------------------------------------------------
DrawCircle:
; max x
        move.w  #DIW_W/2,d4
        add.w   d2,d4
        cmp.w   d4,d0
        bge     .skip
; min x
        neg.w   d4
        cmp.w   d4,d0
        ble     .skip
; max y
        move.w  #DIW_H/2,d4
        add.w   d2,d4
        cmp.w   d4,d1
        bge     .skip
; min y
        neg.w   d4
        cmp.w   d4,d1
        ble     .skip
; blit or plot
        tst.w   d2
        bne     BlitCircle
        bra     Plot
.skip:  rts

********************************************************************************
; Draw a circle using blitter
;-------------------------------------------------------------------------------
; d0.w - x
; d1.w - y
; d2.w - r
; d3.l - colour (bpl offset)
; a1 - dest bpl (centered)
; a2 - clear list
;-------------------------------------------------------------------------------
BlitCircle:
        cmp.w   #BLTCIRC_MAX_R,d2
        bgt     .skip
; Subract radius from coords to center
        sub.w   d2,d1
        sub.w   d2,d0
; Get blit params for radius:
        move.w  d2,d4
        subq    #1,d4
; mulu	#Blit_SIZEOF,d4
        lsl.w   #3,d4                           ; optimise
        ext.l   d4
        lea     BltCircSizes,a0
        lea     (a0,d4.w),a0
        movem.w Blit_Mod(a0),d6/a4
        move.l  Blit_Adr(a0),a0

        cmp.w #8,d2
        ble .noClip

; Clipping checks:
; Min Y:
        move.w  #-SCREEN_H/2,d4
        sub.w   d1,d4
        blt     .minYOk
        add.w   d4,d1                           ; offset y position
        move.w  #SCREEN_BW,d5                   ; get byte width from modulo
        sub.w   d6,d5
        muls    d4,d5
        add.l   d5,a0                           ; adjust src start
        lsl.w   #6,d4
        sub.w   d4,a4                           ; adjust bltsize
        bra     .checkX
.minYOk:
; Max Y:
        move.w  #SCREEN_H/2,d4
        sub.w   d2,d4
        sub.w   d2,d4
        sub.w   d1,d4
        bge     .maxYOk
        neg.w   d4
        move.w  #SCREEN_BW,d5                   ; get byte width from modulo
        sub.w   d6,d5
        muls    d4,d5
        lsl.w   #6,d4
        sub.w   d4,a4                           ; adjust bltsize
.maxYOk:
.checkX:
; Min X:
        move.w  #-DIW_W/2,d4
        sub.w   d0,d4
        move.w  d0,d4                           ; x/16 - DIW_BW/4
        asr.w   #4,d4
        sub.w   #-DIW_BW/4,d4
        bge     .minXOk
        neg.w   d4
        subq    #1,d4
        sub.w   d4,a4                           ; adjust bltsize
        add.w   d4,d4
        lea     (a0,d4.w),a0                    ; offset source x
        add.w   d4,d6                           ; adjust modulo
        swap    d6
        add.w   d4,d6
        swap    d6
        asl.w   #3,d4                           ; offset x position
        add.w   d4,d0
.minXOk:
; Max X:
        move.w  d0,d4
        asr.w   #3,d4
        add.w   #SCREEN_BW,d4                   ; get byte width from modulo
        sub.w   d6,d4
        sub.w   #DIW_BW/2,d4
        ble     .maxXOk
        lsr.w   #1,d4
        sub.w   d4,a4                           ; adjust bltsize
        add.w   d4,d4                           ; byte offset
        add.w   d4,d6                           ; adjust modulo
        swap    d6
        add.w   d4,d6
        swap    d6
.maxXOk:
.noClip

; Prepare and store blit params:
; Lookup bltcon value for x shift
        moveq   #15,d4
        and.w   d0,d4
; Offset dest for x/y/color
        muls    #SCREEN_BW,d1                   ; d1 = yOffset (bytes)
        asr.w   #3,d0                           ; d0 = xOffset (bytes)
        add.w   d0,d1                           ; d1 = totalOffset = yOffset + xOffset
        move.l  a1,d5                           ; d5 = dest pointer with offset
        ext.l   d1
        add.l   d1,d5
        add.l   d3,d5                           ; add colour bpl offset to dest
; Save to clear list
        move.l  d5,(a2)+
        move.w  d6,(a2)+
        move.w  a4,(a2)+

; Do blit:
        WAIT_BLIT
        move.l  d6,bltamod(a6)
        move.w  d6,bltcmod(a6)
        move.l  #-1,d6
        lsl.l   d4,d6
        move.l  d6,bltafwm(a6)
        lsl.w   #2,d4                           ; d4 = offset into bltcon table
        move.l  .bltcon(pc,d4),bltcon0(a6)
        move.l  d5,bltcpt(a6)
        move.l  a0,bltapt(a6)
        move.l  d5,bltdpt(a6)
        move.w  a4,bltsize(a6)
.skip:  rts

; Table for combined minterm and shifts for bltcon0/bltcon1
.bltcon: dc.l   $0bfa0000,$1bfa1000,$2bfa2000,$3bfa3000
        dc.l    $4bfa4000,$5bfa5000,$6bfa6000,$7bfa7000
        dc.l    $8bfa8000,$9bfa9000,$abfaa000,$bbfab000
        dc.l    $cbfac000,$dbfad000,$ebfae000,$fbfaf000


********************************************************************************
; Plot point
;-------------------------------------------------------------------------------
; d0 - x
; d1 - y
; d3 - colour (bpl offset)
; a1 - dest (centered)
; a2 - clear list
;-------------------------------------------------------------------------------
Plot:
        moveq   #$f,d2
        and.w   d0,d2
        not.w   d2
        asr.w   #3,d0
        muls    #SCREEN_BW,d1
        add.w   d0,d1
        lea     (a1,d1.w),a4
        add.l   d3,a4                           ; colour bpl offset
        bset    d2,(a4)
        move.l  a4,(a2)+
        move.w  d2,(a2)+
        move.w  #0,(a2)+
        rts


********************************************************************************
; Random number generator
;-------------------------------------------------------------------------------
; Returns:
; d0 - random 32 bit value
;-------------------------------------------------------------------------------
Random32:
        move.l  RandomSeed(pc),d0
        add.l   d0,d0
        bcc.s   .done
        eori.b  #$af,d0
.done:  move.l  d0,RandomSeed
        rts
RandomSeed: dc.l RANDOM_SEED


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
        move.w  #$f0,d2
        cmp.w   #$8000,d0
        blo.s   .l
.cp:    move.w  (a1)+,(a2)+
        dbf     d1,.cp
        bra.s   .end
.l:     move.w  (a0)+,d3
        move.w  (a1)+,d4
        bsr     DoLerpCol
        move.w  d7,(a2)+
        dbf     d1,.l
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
        move.w  #$f0,d2

DoLerpCol:
        move.w  d3,d5                           ; R
        clr.b   d5
        move.w  d4,d7
        clr.b   d7
        sub.w   d5,d7
        add.w   d7,d7
        muls    d0,d7
        swap    d7
        add.w   d5,d7
        move.w  d3,d5                           ; G
        and.w   d2,d5
        move.w  d4,d6
        and.w   d2,d6
        sub.w   d5,d6
        add.w   d6,d6
        muls    d0,d6
        swap    d6
        add.w   d5,d6
        and.w   d2,d6
        move.b  d6,d7
        moveq   #$f,d6
        and.w   d6,d3
        and.w   d6,d4
        sub.w   d3,d4                           ; B
        add.w   d4,d4
        muls    d0,d4
        swap    d4
        add.w   d3,d4
        or.w    d4,d7
        rts


********************************************************************************
; Precalc routines:
********************************************************************************


********************************************************************************
; Bresenham circle for blitter fill
;-------------------------------------------------------------------------------
; a0 - Dest ptr
; d0 - Radius
; d1 - byte width
;-------------------------------------------------------------------------------
DrawCircleFill:
        movem.l d0-a7,-(sp)
        move.w  d0,d2
        move.w  d0,d4                           ; d4 = x = r
        moveq   #0,d5                           ; d5 = y = 0
        neg.w   d0                              ; d0 = P = 1 - r
        addq    #1,d0

; Plot first point:
        move.w  d4,d6                           ; X,Y
        moveq   #0,d7
        bsr     .plot
        move.w  d4,d6                           ; -X,Y
        neg.w   d6
        moveq   #0,d7
        bsr     .plot

.l:
        cmp.w   d5,d4                           ; x > y?
        ble     .done

        tst.w   d0                              ; P < 0?
        blt     .inside
        subq    #1,d4                           ; x--;
        sub.w   d4,d0                           ; P -= x
        sub.w   d4,d0                           ; P -= x

.inside:
        addq    #1,d5                           ; y++

        add.w   d5,d0                           ; P += y
        add.w   d5,d0                           ; P += y
        addq    #1,d0                           ; P += 1

        cmp.w   d5,d4                           ; x < y?
        blt     .done

; Plot:

; Only mirror y if x will  change on next loop
; Avoid multiple pixels on same row as the breaks blitter fill
        tst.w   d0                              ; if (P >= 0)
        blt     .noMirror
        cmp.w   d5,d4                           ; if (x != y):
        beq     .noMirror
        move.w  d5,d6                           ; Y,X
        move.w  d4,d7
        subq    #1,d7
        bsr     .plot
        move.w  d5,d6                           ; -Y,X
        neg.w   d6
        move.w  d4,d7
        subq    #1,d7
        bsr     .plot
        move.w  d5,d6                           ; Y,-X
        move.w  d4,d7
        neg.w   d7
        bsr     .plot
        move.w  d5,d6                           ; -Y,-X
        neg.w   d6
        move.w  d4,d7
        neg.w   d7
        bsr     .plot
.noMirror:
        move.w  d4,d6                           ; X,Y
        move.w  d5,d7
        subq    #1,d7
        bsr     .plot
        move.w  d4,d6                           ; -X,Y
        neg.w   d6
        move.w  d5,d7
        subq    #1,d7
        bsr     .plot
        move.w  d4,d6                           ; X,-Y
        move.w  d5,d7
        neg.w   d7
        bsr     .plot
        move.w  d4,d6                           ; -X,-Y
        neg.w   d6
        move.w  d5,d7
        neg.w   d7
        bsr     .plot

        bra     .l

.done:
        movem.l (sp)+,d0-a7
        rts

.plot:
        add.w   d2,d6
        add.w   d2,d7
        muls    d1,d7
        move.w  d6,d3
        not.w   d3
        asr.w   #3,d6
        add.w   d7,d6
        bset    d3,(a0,d6.w)
        rts

********************************************************************************
Vars:
********************************************************************************

VBlank: dc.l    0

DblBuffers:
DrawBuffer: dc.l Screen2
ViewBuffer: dc.l Screen1
DrawClearList: dc.l ClearList2
ViewClearList: dc.l ClearList1


********************************************************************************
* Data
********************************************************************************

; Debug resource data:
DebugResScreen: DebugResourceBitmap Screen1,"Screen.bpl",SCREEN_W,SCREEN_H,BPLS,0
DebugResScreen2: DebugResourceBitmap Screen2,"Screen2.bpl",SCREEN_W,SCREEN_H,BPLS,0
DebugResCop: DebugResourceCopperlist Cop,"Cop",CopE-Cop


*******************************************************************************
        data_c
*******************************************************************************

; Main copper list:
Cop:
        dc.w    fmode,0
        dc.w    diwstrt,DIW_YSTRT<<8!DIW_XSTRT
        dc.w    diwstop,(DIW_YSTOP-256)<<8!(DIW_XSTOP-256)
        dc.w    ddfstrt,(DIW_XSTRT-17)>>1&$fc
        dc.w    ddfstop,(DIW_XSTRT-17+(SCREEN_W>>4-1)<<4)>>1&$fc
        dc.w    bpl1mod,DIW_MOD
        dc.w    bpl2mod,DIW_MOD
        dc.w    bplcon0,BPLS<<12!$200
        dc.w    bplcon1,0
CopEnd: dc.l    -2
CopE:


*******************************************************************************
        bss
*******************************************************************************
; Ptrs to circle images / blit params for each radius
BltCircSizes: ds.b Blit_SIZEOF*BLTCIRC_MAX_R

; Double buffered list of clear data to restore blits/plots
ClearList1: ds.b Blit_SIZEOF*MAX_CLEAR+4
ClearList2: ds.b Blit_SIZEOF*MAX_CLEAR+4

; Precalced sqrt LUT data
SqrtTab: ds.b   $100*$100

; FP 2/14
; +-16384
; ($c000-$4000) over 1024 ($400) steps
Sin:    ds.w    256
Cos:    ds.w    1024

Pal0:   ds.w    32
Pal1:   ds.w    32
Pal2:   ds.w    32
Pal3:   ds.w    32

DivTab: ds.w    $fff
ValueNoise: ds.b 256


*******************************************************************************
        bss_c
*******************************************************************************

; Double buffered screens
Screen1: ds.b   SCREEN_SIZE
Screen2: ds.b   SCREEN_SIZE
        printt  Screens
        printv  *-Screen1

BlankBpl: ds.b  SCREEN_BPL
        printt  BlankBpl
        printv  *-BlankBpl

; Blitter circle bitplane data for all sizes. Generated by InitCircles
BltCircBpl: ds.b $00028eac                      ; calculated in InitBlitCircles
        printt  BltCircBpl
        printv  *-BltCircBpl