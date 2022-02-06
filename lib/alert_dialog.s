;;; ============================================================
;;; Alert Dialog Definition
;;;
;;; Requires the following proc definitions:
;;; * `pointer_cursor`
;;; * `Bell`
;;; * `DrawString`
;;; * `AlertYieldLoop`
;;; Requires the following data definitions:
;;; * `alert_grafport`
;;; Requires the following macro definitions:
;;; * `LIB_MGTK_CALL`
;;; ============================================================

.proc Alert
        jmp     start

alert_bitmap:
        .byte   PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1111100),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1111100),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1111100),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1111100),PX(%0000000),PX(%1111111),PX(%1111111),PX(%0000000),PX(%0000000)
        .byte   PX(%0111100),PX(%1111100),PX(%0000001),PX(%1110000),PX(%0000111),PX(%0000000),PX(%0000000)
        .byte   PX(%0111100),PX(%1111100),PX(%0000011),PX(%1100000),PX(%0000011),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1111100),PX(%0000111),PX(%1100111),PX(%1111001),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1111100),PX(%0001111),PX(%1100111),PX(%1111001),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1111100),PX(%0011111),PX(%1111111),PX(%1111001),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1111100),PX(%0011111),PX(%1111111),PX(%1110011),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1111100),PX(%0011111),PX(%1111111),PX(%1100111),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1111100),PX(%0011111),PX(%1111111),PX(%1001111),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1111100),PX(%0011111),PX(%1111111),PX(%0011111),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1111100),PX(%0011111),PX(%1111110),PX(%0111111),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1111100),PX(%0011111),PX(%1111100),PX(%1111111),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1111100),PX(%0011111),PX(%1111100),PX(%1111111),PX(%0000000),PX(%0000000)
        .byte   PX(%0111110),PX(%0000000),PX(%0111111),PX(%1111111),PX(%1111111),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1100000),PX(%1111111),PX(%1111100),PX(%1111111),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1100001),PX(%1111111),PX(%1111111),PX(%1111111),PX(%0000000),PX(%0000000)
        .byte   PX(%0111000),PX(%0000011),PX(%1111111),PX(%1111111),PX(%1111110),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1100000),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000)
        .byte   PX(%0111111),PX(%1100000),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000)
        .byte   PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000),PX(%0000000)

        kAlertXMargin = 20

.params alert_bitmap_params
        DEFINE_POINT viewloc, kAlertXMargin, 8
mapbits:        .addr   alert_bitmap
mapwidth:       .byte   7
reserved:       .byte   0
        DEFINE_RECT maprect, 0, 0, 36, 23
.endparams

pencopy:        .byte   0
penXOR:         .byte   2

event_params:   .tag    MGTK::Event
event_kind      := event_params + MGTK::Event::kind
event_coords    := event_params + MGTK::Event::xcoord
event_xcoord    := event_params + MGTK::Event::xcoord
event_ycoord    := event_params + MGTK::Event::ycoord
event_key       := event_params + MGTK::Event::key

kAlertRectWidth         = 420
kAlertRectHeight        = 55
kAlertRectLeft          = (::kScreenWidth - kAlertRectWidth)/2
kAlertRectTop           = (::kScreenHeight - kAlertRectHeight)/2

        DEFINE_RECT_SZ alert_rect, kAlertRectLeft, kAlertRectTop, kAlertRectWidth, kAlertRectHeight
        DEFINE_RECT_INSET alert_inner_frame_rect1, 4, 2, kAlertRectWidth, kAlertRectHeight
        DEFINE_RECT_INSET alert_inner_frame_rect2, 5, 3, kAlertRectWidth, kAlertRectHeight

.params screen_portbits
        DEFINE_POINT viewloc, 0, 0
mapbits:        .addr   MGTK::screen_mapbits
mapwidth:       .byte   MGTK::screen_mapwidth
reserved:       .byte   0
        DEFINE_RECT maprect, 0, 0, kScreenWidth-1, kScreenHeight-1
.endparams

.params portmap
        DEFINE_POINT viewloc, kAlertRectLeft, kAlertRectTop
mapbits:        .addr   MGTK::screen_mapbits
mapwidth:       .byte   MGTK::screen_mapwidth
reserved:       .byte   0
        DEFINE_RECT maprect, 0, 0, kAlertRectWidth, kAlertRectHeight
.endparams

        DEFINE_BUTTON ok,        res_string_button_ok,          300, 37
        DEFINE_BUTTON try_again, res_string_button_try_again,   300, 37
        DEFINE_BUTTON cancel,    res_string_button_cancel,       20, 37

        kTextLeft = 75
        kTextRight = kAlertRectWidth - kAlertXMargin
        kWrapWidth = kTextRight - kTextLeft

        DEFINE_POINT pos_prompt1, kTextLeft, 29-11
        DEFINE_POINT pos_prompt2, kTextLeft, 29

.params textwidth_params        ; Used for spitting/drawing the text.
data:   .addr   0
length: .byte   0
width:  .word   0
.endparams
len:    .byte   0               ; total string length
split_pos:                      ; last known split position
        .byte   0

.params alert_params
text:           .addr   0
buttons:        .byte   0       ; AlertButtonOptions
options:        .byte   0       ; AlertOptions flags
.endparams

        ;; Actual entry point
start:
        ;; Copy passed params
        stax    @addr
        ldx     #.sizeof(alert_params)-1
        @addr := *+1
:       lda     SELF_MODIFIED,x
        sta     alert_params,x
        dex
        bpl     :-

        LIB_MGTK_CALL MGTK::SetCursor, pointer_cursor

        ;; --------------------------------------------------
        ;; Play bell

        bit     alert_params::options
    IF_NS                       ; N = play sound
        jsr     Bell
    END_IF

        ;; --------------------------------------------------
        ;; Draw alert

        LIB_MGTK_CALL MGTK::HideCursor

        bit     alert_params::options
    IF_VS                       ; V = use save area
        ;; Compute save bounds
        ldax    portmap::viewloc::xcoord ; left
        jsr     CalcXSaveBounds
        sty     save_x1_byte
        sta     save_x1_bit

        lda     portmap::viewloc::xcoord ; right
        clc
        adc     portmap::maprect::x2
        pha
        lda     portmap::viewloc::xcoord+1
        adc     portmap::maprect::x2+1
        tax
        pla
        jsr     CalcXSaveBounds
        sty     save_x2_byte
        sta     save_x2_bit

        lda     portmap::viewloc::ycoord ; top
        sta     save_y1
        clc
        adc     portmap::maprect::y2 ; bottom
        sta     save_y2

        jsr     DialogBackgroundSave
    END_IF

        ;; Set up GrafPort
        LIB_MGTK_CALL MGTK::InitPort, alert_grafport
        LIB_MGTK_CALL MGTK::SetPort, alert_grafport

        LIB_MGTK_CALL MGTK::SetPortBits, screen_portbits ; viewport for screen

        ;; Draw alert box and bitmap - coordinates are in screen space
        LIB_MGTK_CALL MGTK::SetPenMode, pencopy
        LIB_MGTK_CALL MGTK::PaintRect, alert_rect ; alert background
        LIB_MGTK_CALL MGTK::SetPenMode, penXOR ; ensures corners are inverted
        LIB_MGTK_CALL MGTK::FrameRect, alert_rect ; alert outline

        LIB_MGTK_CALL MGTK::SetPortBits, portmap ; viewport for remaining operations

        ;; Draw rest of alert - coordinates are relative to portmap
        LIB_MGTK_CALL MGTK::FrameRect, alert_inner_frame_rect1 ; inner 2x border
        LIB_MGTK_CALL MGTK::FrameRect, alert_inner_frame_rect2
        LIB_MGTK_CALL MGTK::SetPenMode, pencopy
        LIB_MGTK_CALL MGTK::PaintBits, alert_bitmap_params

        ;; Draw appropriate buttons
        LIB_MGTK_CALL MGTK::SetPenMode, penXOR

        bit     alert_params::buttons ; high bit clear = Cancel
        bpl     ok_button

        ;; Cancel button
        LIB_MGTK_CALL MGTK::FrameRect, cancel_button_rect
        LIB_MGTK_CALL MGTK::MoveTo, cancel_button_pos
        param_call DrawString, cancel_button_label

        bit     alert_params::buttons
        bvs     ok_button

        ;; Try Again button
        LIB_MGTK_CALL MGTK::FrameRect, try_again_button_rect
        LIB_MGTK_CALL MGTK::MoveTo, try_again_button_pos
        param_call DrawString, try_again_button_label

        jmp     draw_prompt

        ;; OK button
ok_button:
        LIB_MGTK_CALL MGTK::FrameRect, ok_button_rect
        LIB_MGTK_CALL MGTK::MoveTo, ok_button_pos
        param_call DrawString, ok_button_label

        ;; Prompt string
draw_prompt:
.scope
        ;; Measure for splitting
        ldx     alert_params::text
        ldy     alert_params::text + 1
        inx
        bne     :+
        iny
:       stx     textwidth_params::data
        sty     textwidth_params::data + 1

        ptr := $06
        copy16  alert_params::text, ptr
        ldy     #0
        sty     split_pos       ; initialize
        lda     (ptr),y
        sta     len             ; total length

        ;; Search for space or end of string
advance:
:       iny
        cpy     len
        beq     test
        lda     (ptr),y
        cmp     #' '
        bne     :-

        ;; Does this much fit?
test:   sty     textwidth_params::length
        LIB_MGTK_CALL MGTK::TextWidth, textwidth_params
        cmp16   textwidth_params::width, #kWrapWidth
        bpl     split           ; no! so we know where to split now

        ;; Yes, record possible split position, maybe continue.
        ldy     textwidth_params::length
        sty     split_pos
        cpy     len             ; hit end of string?
        bne     advance         ; no, keep looking

        ;; Whole string fits, just draw it.
        copy    len, textwidth_params::length
        LIB_MGTK_CALL MGTK::MoveTo, pos_prompt2
        LIB_MGTK_CALL MGTK::DrawText, textwidth_params
        jmp     done

        ;; Split string over two lines.
split:  copy    split_pos, textwidth_params::length
        LIB_MGTK_CALL MGTK::MoveTo, pos_prompt1
        LIB_MGTK_CALL MGTK::DrawText, textwidth_params
        lda     textwidth_params::data
        clc
        adc     split_pos
        sta     textwidth_params::data
        bcc     :+
        inc     textwidth_params::data + 1
:       lda     len
        sec
        sbc     split_pos
        sta     textwidth_params::length
        LIB_MGTK_CALL MGTK::MoveTo, pos_prompt2
        LIB_MGTK_CALL MGTK::DrawText, textwidth_params

done:
.endscope

        LIB_MGTK_CALL MGTK::ShowCursor

        ;; --------------------------------------------------
        ;; Event Loop

event_loop:
        jsr     AlertYieldLoop
        LIB_MGTK_CALL MGTK::GetEvent, event_params
        lda     event_kind
        cmp     #MGTK::EventKind::button_down
        beq     HandleButtonDown

        cmp     #MGTK::EventKind::key_down
        bne     event_loop

        ;; --------------------------------------------------
        ;; Key Down
        lda     event_key
        bit     alert_params::buttons ; has Cancel?
        bpl     check_only_ok   ; nope

        cmp     #CHAR_ESCAPE
        bne     :+

do_cancel:
        LIB_MGTK_CALL MGTK::SetPenMode, penXOR
        LIB_MGTK_CALL MGTK::PaintRect, cancel_button_rect
        lda     #kAlertResultCancel
        jmp     finish

:       bit     alert_params::buttons ; has Try Again?
        bvs     check_ok        ; nope
        cmp     #TO_LOWER(kShortcutTryAgain)
        bne     :+

do_try_again:
        LIB_MGTK_CALL MGTK::SetPenMode, penXOR
        LIB_MGTK_CALL MGTK::PaintRect, try_again_button_rect
        lda     #kAlertResultTryAgain
        jmp     finish

:       cmp     #kShortcutTryAgain
        beq     do_try_again
        cmp     #CHAR_RETURN    ; also allow Return as default
        beq     do_try_again
        bne     event_loop

check_only_ok:
        cmp     #CHAR_ESCAPE    ; also allow Escape as default
        beq     do_ok
check_ok:
        cmp     #CHAR_RETURN
        bne     event_loop

do_ok:  LIB_MGTK_CALL MGTK::SetPenMode, penXOR
        LIB_MGTK_CALL MGTK::PaintRect, ok_button_rect
        lda     #kAlertResultOK
        jmp     finish          ; not a fixed value, cannot BNE/BEQ

        ;; --------------------------------------------------
        ;; Buttons

HandleButtonDown:
        jsr     MapEventCoords
        LIB_MGTK_CALL MGTK::MoveTo, event_coords

        bit     alert_params::buttons ; Cancel showing?
        bpl     check_ok_rect   ; nope

        LIB_MGTK_CALL MGTK::InRect, cancel_button_rect ; Cancel?
        cmp     #MGTK::inrect_inside
        bne     :+
        param_call AlertButtonEventLoop, cancel_button_rect
        bne     no_button
        lda     #kAlertResultCancel
        .assert kAlertResultCancel <> 0, error, "kAlertResultCancel must be non-zero"
        bne     finish          ; always

:       bit     alert_params::buttons ; Try Again showing?
        bvs     check_ok_rect   ; nope

        LIB_MGTK_CALL MGTK::InRect, try_again_button_rect ; Try Again?
        cmp     #MGTK::inrect_inside
        bne     no_button
        param_call AlertButtonEventLoop, try_again_button_rect
        bne     no_button
        lda     #kAlertResultTryAgain
        .assert kAlertResultTryAgain = 0, error, "kAlertResultTryAgain must be non-zero"
        beq     finish          ; always

check_ok_rect:
        LIB_MGTK_CALL MGTK::InRect, ok_button_rect ; OK?
        cmp     #MGTK::inrect_inside
        bne     no_button
        param_call AlertButtonEventLoop, ok_button_rect
        bne     no_button
        lda     #kAlertResultOK
        jmp     finish          ; not a fixed value, cannot BNE/BEQ

no_button:
        jmp     event_loop

;;; ============================================================

finish:

        bit     alert_params::options
    IF_VS                       ; V = use save area
        pha
        LIB_MGTK_CALL MGTK::HideCursor
        jsr     DialogBackgroundRestore
        LIB_MGTK_CALL MGTK::ShowCursor
        pla
    END_IF

        rts

;;; ============================================================

.proc MapEventCoords
        sub16   event_xcoord, portmap::viewloc::xcoord, event_xcoord
        sub16nc event_ycoord, portmap::viewloc::ycoord, event_ycoord
        rts
.endproc

        .include "alertbuttonloop.s"
        .include "savedialogbackground.s"
        DialogBackgroundSave := dialog_background::Save
        DialogBackgroundRestore := dialog_background::Restore

.endproc
