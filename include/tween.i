              IFND       TWEEN_I
TWEEN_I       SET        1

TWEENS_LEN = 4                                      ; Array length

              rsreset
Tween_En      rs.w       1                          ; Enabled
Tween_Strt   rs.l       1                          ; Start frame
Tween_Ptr     rs.l       1                          ; Target address pointer
Tween_From    rs.w       1                          ; Start value
Tween_To      rs.w       1                          ; End value
Tween_Dur     rs.w       1                          ; Duration of transition in frames
Tween_SIZEOF  rs.w       0

********************************************************************************
; Start tween with commander
; target value, duration, ptr
;-------------------------------------------------------------------------------
; CmdTween:
;               move.l     (a5)+,d0
;               move.l     (a5)+,d1
;               move.l     (a5)+,a1

********************************************************************************
; Start a new tween
;-------------------------------------------------------------------------------
; d0.w - target value
; d1.w - duration
; a1 - ptr
;-------------------------------------------------------------------------------
TweenStart:
              lea        tweenArr,a2
              moveq      #TWEENS_LEN-1,d2
.l            tst.w      Tween_En(a2)
              beq        .free
              lea        Tween_SIZEOF(a2),a2
              dbf        d2,.l
              rts                                   ; no free slots
.free         move.w     #1,Tween_En(a2)
              move.l     VBlank,Tween_Strt(a2)
              move.w     d1,Tween_Dur(a2)
              move.l     a1,Tween_Ptr(a2)
              move.w     (a1),Tween_From(a2)
              move.w     d0,Tween_To(a2)
              rts

tweenArr:     ds.b       Tween_SIZEOF*TWEENS_LEN    ; Tweens array


********************************************************************************
; Continue any active tweens
;-------------------------------------------------------------------------------
TweenStep:
              lea        tweenArr,a0
              moveq      #TWEENS_LEN-1,d0
.l            tst.w      Tween_En(a0)               ; Skip if not enabled
              beq        .next
              move.l     Tween_Ptr(a0),a1           ; a1 = Address ptr
              move.l     VBlank,d1                  ; d1 = Step (VBlank-Start)
              sub.l      Tween_Strt(a0),d1
              move.w     Tween_Dur(a0),d4           ; d4 = duration
              cmp.w      d1,d4                      ; Check if finished
              bgt        .notFinished
.finished:
              move.w     Tween_To(a0),(a1)          ; write 'to' value
              move.w     #0,Tween_En(a0)            ; Disable
              bra        .next
.notFinished:
              move.w     Tween_From(a0),d2          ; d2 = From value
              move.w     Tween_To(a0),d3            ; d3 = Delta
              sub.w      d2,d3                      ; (To-From)*Step/Duration
              muls       d1,d3
              divs       d4,d3
              add.w      d3,d2                      ; d2 = New value (From+Delta)
              move.w     d2,(a1)                    ; Write new value
.next         lea        Tween_SIZEOF(a0),a0
              dbf        d0,.l
              rts

              ENDC
