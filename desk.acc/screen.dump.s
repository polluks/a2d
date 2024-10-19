;;; ============================================================
;;; SCREEN.DUMP - Desk Accessory
;;;
;;; Dumps the contents of the graphics screen to an ImageWriter
;;; printer connected to a Super Serial Card in Slot 1.
;;; ============================================================

        .include "../config.inc"

        .include "apple2.inc"
        .include "../inc/apple2.inc"
        .include "../inc/macros.inc"
        .include "../inc/prodos.inc"
        .include "../mgtk/mgtk.inc"
        .include "../common.inc"
        .include "../desktop/desktop.inc"

;;; ============================================================

        DA_HEADER
        DA_START_MAIN_SEGMENT

;;; ============================================================

        JUMP_TABLE_MGTK_CALL MGTK::HideCursor
        jsr     JUMP_TABLE_HILITE_MENU
        jsr     DumpScreen
        jsr     JUMP_TABLE_HILITE_MENU
        JUMP_TABLE_MGTK_CALL MGTK::ShowCursor
        rts

;;; ============================================================

;;; Original code issued a "Zap" command to SSC to suppress further
;;; control character processing. This affects later use of the SSC
;;; so is disabled. ZAP = 1 to restore.

kSigLen = 4
sig_offsets:
        .byte   $05, $07, $0B, $0C
        ASSERT_TABLE_SIZE sig_offsets, kSigLen
sig_bytes:
        .byte   $38, $18, $01, $31
        ASSERT_TABLE_SIZE sig_bytes, kSigLen

.proc DumpScreen

        SLOT1   := $C100

        ;; Check for hardware signature - SSC in Slot 1

        ldy     #kSigLen-1
:       ldx     sig_offsets,y
        lda     SLOT1,x
        cmp     sig_bytes,y
        bne     ret
        dey
        bpl     :-


        hbasl := $6
        kScreenWidth  = 560
        kScreenHeight = 192

        sta     ALTZPOFF
        bit     ROMIN2

        jsr     PrintScreen

        sta     ALTZPON
        bit     LCBANK1
        bit     LCBANK1
ret:    rts

.proc SendSpacing
        ldy     #0
:       lda     spacing_sequence,y
        beq     done
        jsr     COut
        iny
        jmp     :-
done:   rts
.endproc ; SendSpacing

.proc SendRestoreState
.ifdef ZAP
        ;; Per Apple II Super Serial Card Installation and Operating Manual
        ;; "The only way to reinstate command recognition after the Z
        ;; command is to reinitialize the SSC, or clear the high-order bit
        ;; at location $5F8+s (where s is the slot in which the SSC is
        ;; installed)."

        ;; TODO: Does not seem to work on Virtual ][ ???
        lda     $5F8+1
        and     %01111111
        sta     $5F8+1
.endif

        ldy     #$00
:       lda     restore_state,y
        beq     done
        jsr     COut
        iny
        jmp     :-
done:   rts
.endproc ; SendRestoreState

.proc SendInitGraphics
        ldx     #0
:       lda     init_graphics,x
        jsr     COut
        inx
        cpx     #6
        bne     :-
        rts
init_graphics:
        .byte   CHAR_ESCAPE,"G0560"     ; Graphics, 560 data bytes
.endproc ; SendInitGraphics

.proc SendRow
        ;; Tell printer to expect graphics
        jsr     SendInitGraphics
        ldy     #0
        sty     col_num
        lda     #1
        sta     mask
        copy16  #0, x_coord

col_loop:
        lda     #4              ; 8 vertical pixels per row (doubled)
        sta     count
        lda     y_row
        sta     y_coord

        ;; Accumulate 8 pixels
y_loop: lda     y_coord
        jsr     ComputeHBASL    ; Row address in screen

        lda     col_num
        lsr     a               ; Even or odd column?
        tay
        sta     PAGE2OFF        ; By default, read main mem $2000-$3FFF
        bcs     :+              ; But even columns come from aux, so...
        sta     PAGE2ON         ; Read aux mem $2000-$3FFF

:       lda     (hbasl),y       ; Grab the whole byte
        and     mask            ; Isolate the pixel we care about
        cmp     #1              ; Set carry if non-zero
        php
        ror     accum           ; And slide it into place
        plp
        ror     accum           ; Doubled
        inc     y_coord
        dec     count
        bne     y_loop

        ;; Send the 8 pixels to the printer.
        lda     accum           ; Now output it
        eor     #$FF            ; Invert pixels (screen vs. print)
        sta     PAGE2OFF        ; Read main mem $2000-$3FFF
        jsr     COut            ; And actually print

.ifndef ZAP
        ;; If Ctrl+I, send again (default SSC control character)
        cmp     #CHAR_TAB
        bne     :+
        jsr     COut
:
.endif

        ;; Done all pixels across?
        lda     x_coord
        cmp     #<(kScreenWidth-1)
        bne     :+
        lda     x_coord+1
        cmp     #>(kScreenWidth-1)
        beq     done

        ;; Next pixel to the right
:       asl     mask
        bpl     :+              ; Only 7 pixels per column
        lda     #1
        sta     mask
        inc     col_num

:       inc     x_coord
        bne     col_loop
        inc     x_coord+1
        bne     col_loop

done:   sta     PAGE2OFF        ; Read main mem $2000-$3FFF
        rts
.endproc ; SendRow

.proc PrintScreen
        ;; Save
        lda     COUT_HOOK
        pha
        lda     COUT_HOOK+1
        pha

        ;; Init printer
        jsr     PRNum1
        jsr     SendSpacing

        lda     #0
        sta     y_row

        ;; Print a row (560x8), CR+LF
loop:   jsr     SendRow
        lda     #CHAR_RETURN
        jsr     COut
        lda     #CHAR_DOWN
        jsr     COut

        lda     y_coord
        sta     y_row
        cmp     #kScreenHeight
        bcc     loop

        ;; Finish up
        lda     #CHAR_RETURN
        jsr     COut
        lda     #CHAR_RETURN
        jsr     COut
        jsr     SendRestoreState

        ;; Restore
        pla
        sta     COUT_HOOK+1
        pla
        sta     COUT_HOOK

        rts
.endproc ; PrintScreen

        ;; Given y-coordinate in A, compute HBASL-equivalent
.proc ComputeHBASL
        pha
        and     #$C7
        eor     #$08
        sta     hbasl+1
        and     #$F0
        lsr     a
        lsr     a
        lsr     a
        sta     hbasl
        pla
        and     #$38
        asl     a
        asl     a
        eor     hbasl
        asl     a
        rol     hbasl+1
        asl     a
        rol     hbasl+1
        eor     hbasl
        sta     hbasl
        rts
.endproc ; ComputeHBASL

.proc PRNum1
        lda     #>SLOT1
        sta     COUT_HOOK+1
        lda     #<SLOT1
        sta     COUT_HOOK
        lda     #(CHAR_RETURN | $80)
        jmp     invoke_slot1
.endproc ; PRNum1

.proc COut
        jsr     COUT
        rts
.endproc ; COut

y_row:  .byte   0              ; y-coordinate of row start (0, 8, ...)
x_coord:.word   0              ; x-coordinate of pixels being accumulated
y_coord:.byte   0              ; iterates y_row to y_row+7
mask:   .byte   0              ; mask for pixel being processed
accum:  .byte   0              ; accumulates pixels for output
count:  .byte   0              ; 8...1 while a row is output
col_num:.byte   0              ; 0...79

        .byte   0, 0

spacing_sequence:
        .byte   CHAR_ESCAPE,'n'    ; IW2: 72 DPI (horizontal; "Extended")
        .byte   CHAR_ESCAPE,"T16"  ; IW2: 72 DPI (vertical; 8 strikers / 72 = 16/144")
        .byte   CHAR_TAB,"L D",$8D ; SSC: Disable LF after CR
.ifdef ZAP
        .byte   CHAR_TAB,"Z",$8D   ; SSC: Zap (suppress) further control characters
.endif
        .byte   0

restore_state:
        .byte   CHAR_ESCAPE,'N'    ; IW2: 80 DPI (horizontal)
        .byte   CHAR_ESCAPE,"T24"  ; IW2: distance between lines (24/144")
        .byte   CHAR_TAB,"L E",$8D ; SSC: Enable LF after CR
        .byte   0

invoke_slot1:
        jmp     SLOT1

.endproc ; DumpScreen

;;; ============================================================

        DA_END_MAIN_SEGMENT

;;; ============================================================
