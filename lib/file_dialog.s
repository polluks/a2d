;;; ============================================================
;;; Common File Picker Dialog
;;;
;;; Required includes:
;;; * lib/file_dialog_res.s
;;; * lib/event_params.s
;;; * lib/muldiv.s
;;; Requires the following proc definitions:
;;; * `AdjustFileEntryCase`
;;; * `AdjustVolumeNameCase`
;;; * `ButtonClick`
;;; * `ButtonFlash`
;;; * `CheckMouseMoved`
;;; * `DetectDoubleClick`
;;; * `ModifierDown`
;;; * `ShiftDown`
;;; * `YieldLoop`
;;; * `MLIRelayImpl`
;;; * `MGTKRelayImpl`
;;; Requires the following data definitions:
;;; * `getwinport_params`
;;; * `window_grafport`
;;; Requires the following macro definitions:
;;;
;;; If `FD_EXTENDED` is defined as 1:
;;; * lib/line_edit_res.s is required to be previously included
;;; * `buf_text` must be defined
;;; * name field at bottom and extra clickable controls on right are supported
;;; * title passed to `DrawTitleCentered` in aux, `AuxLoad` is used

;;; ============================================================
;;; Memory map
;;;
;;;              Main
;;;          :           :
;;;          |           |
;;;          | DHR       |
;;;  $2000   +-----------+
;;;          |           |
;;;          |           |
;;;          |           |
;;;          |           |
;;;          | filenames | 128 x 16-byte filenames
;;;  $1800   +-----------+
;;;          | index     | position in list to filename
;;;  $1780   +-----------+
;;;          | (unused)  |
;;;  $1600   +-----------+
;;;          |           |
;;;          | dir buf   | current directory block
;;;  $1400   +-----------+
;;;          |           |
;;;          |           |
;;;          |           |
;;;          | IO Buffer | for reading directory
;;;  $1000   +-----------+
;;;          |           |
;;;          |           |
;;;          |           |
;;;          |           |
;;;          | (unused)  |
;;;   $800   +-----------+
;;;          |           |
;;;          :           :
;;;
;;; ============================================================



;;; Map from index in file_names to list entry; high bit is
;;; set for directories.
file_list_index := $1780

num_file_names  := $177F

;;; Sequence of 16-byte records, filenames in current directory.
file_names      := $1800

;;; ============================================================

        DEFINE_ON_LINE_PARAMS on_line_params, 0, on_line_buffer

        io_buf := $1000
        dir_read_buf := $1400
        kDirReadSize = $200

        DEFINE_OPEN_PARAMS open_params, path_buf, io_buf
        DEFINE_READ_PARAMS read_params, dir_read_buf, kDirReadSize
        DEFINE_CLOSE_PARAMS close_params

on_line_buffer: .res    16, 0
device_num:     .byte   0       ; current drive, index in DEVLST
path_buf:       .res    ::kPathBufferSize, 0  ; used in MLI calls, so must be in main memory

only_show_dirs_flag:            ; set when selecting copy destination
        .byte   0

dir_count:
        .byte   0

saved_stack:
        .byte   0

;;; Selection in listbox; high bit set if none.
selected_index:
        .byte   0

;;; Buffer used when selecting filename by holding Apple key and typing name.
;;; Length-prefixed string, initialized to 0 when the dialog is shown.
type_down_buf:
        .res    16, 0

;;; ============================================================

.if FD_EXTENDED
routine_table:
        .addr   kOverlayFileCopyAddress
        .addr   0               ; TODO: Remove this entire table
        .addr   kOverlayShortcutEditAddress
.endif

;;; ============================================================

;;; For FD_EXTENDED, A=routine to jump to from `routine_table`
;;; Otherwise, jumps to label `start`.

.proc Start
.if FD_EXTENDED
        sty     stash_y
        stx     stash_x
.endif
        tsx
        stx     saved_stack
.if FD_EXTENDED
        pha
.endif
        jsr     SetCursorPointer
        copy    DEVCNT, device_num

.if FD_EXTENDED
        jsr     LineEditInit
        copy    #kMaxPathLength, line_edit_res::max_length
.endif

        lda     #0
        sta     type_down_buf
        sta     only_show_dirs_flag
.if FD_EXTENDED
        sta     cursor_ibeam_flag
        sta     extra_controls_flag
.endif

        copy    #$FF, selected_index

        lda     #$40            ; not $00 or $80
        sta     open_button_dimmed_flag
        sta     close_button_dimmed_flag
        sta     change_drive_button_dimmed_flag

.if FD_EXTENDED
        pla
        asl     a
        tax
        copy16  routine_table,x, @jump
        ldy     stash_y
        ldx     stash_x

        @jump := *+1
        jmp     SELF_MODIFIED

stash_x:        .byte   0
stash_y:        .byte   0
.else
        jmp     start
.endif

.endproc

;;; ============================================================
;;; Flags set by invoker to alter behavior

;;; Set when `click_handler_hook` should be called and name input present.

extra_controls_flag:
        .byte   0

;;; ============================================================

.proc EventLoop
.if FD_EXTENDED
        bit     extra_controls_flag
    IF_NS
        jsr     Idle
    END_IF
.endif
        jsr     YieldLoop
        MGTK_CALL MGTK::GetEvent, event_params

        lda     event_params::kind
        cmp     #MGTK::EventKind::apple_key
        beq     is_btn
        cmp     #MGTK::EventKind::button_down
        bne     :+
        copy    #0, type_down_buf
is_btn: jsr     HandleButtonDown
        jmp     EventLoop

:       cmp     #MGTK::EventKind::key_down
        bne     :+
        jsr     HandleKeyEvent
        jmp     EventLoop

:       jsr     CheckMouseMoved
        bcc     EventLoop

        copy    #0, type_down_buf

        MGTK_CALL MGTK::FindWindow, findwindow_params
        lda     findwindow_params::which_area
        jeq     EventLoop

.if FD_EXTENDED
        lda     findwindow_params::window_id
        cmp     #file_dialog_res::kFilePickerDlgWindowID
    IF_EQ
        jsr     UnsetCursorIBeam
        jmp     EventLoop
    END_IF
.endif

        lda     #file_dialog_res::kFilePickerDlgWindowID
        sta     screentowindow_params::window_id
        MGTK_CALL MGTK::ScreenToWindow, screentowindow_params
        MGTK_CALL MGTK::MoveTo, screentowindow_params::window

.if FD_EXTENDED
        bit     extra_controls_flag
    IF_NS
        MGTK_CALL MGTK::InRect, file_dialog_res::input1_rect
        cmp     #MGTK::inrect_inside
      IF_EQ
        jsr     SetCursorIBeam
      ELSE
        jsr     UnsetCursorIBeam
      END_IF
    END_IF
.endif

        jmp     EventLoop
.endproc

;;; ============================================================

.proc HandleButtonDown
        ;; We allow Apple+Click just for Change Drive button
        ldx     #0
        lda     event_params::kind
        cmp     #MGTK::EventKind::apple_key
        bne     :+
        ldx     #$80
:       stx     is_apple_click_flag

        MGTK_CALL MGTK::FindWindow, findwindow_params
        lda     findwindow_params::which_area
        cmp     #MGTK::Area::content
        beq     :+
ret:    rts
:
        lda     findwindow_params::window_id
        cmp     #file_dialog_res::kFilePickerDlgWindowID
        beq     :+
        bit     is_apple_click_flag
        bmi     ret             ; ignore except for Change Drive
        jmp     HandleListButtonDown
:
        lda     #file_dialog_res::kFilePickerDlgWindowID
        sta     screentowindow_params::window_id
        MGTK_CALL MGTK::ScreenToWindow, screentowindow_params
        MGTK_CALL MGTK::MoveTo, screentowindow_params::window

        ;; --------------------------------------------------
        ;; Change Drive button

        MGTK_CALL MGTK::InRect, file_dialog_res::change_drive_button_rect
        cmp     #MGTK::inrect_inside
    IF_EQ
        jsr     IsChangeDriveAllowed
        bcs     :+
        param_call ButtonClick, file_dialog_res::kFilePickerDlgWindowID, file_dialog_res::change_drive_button_rect
        bmi     :+
        jsr     DoChangeDrive
:       rts
    END_IF

        bit     is_apple_click_flag
        bmi     ret             ; ignore except for Change Drive

        ;; --------------------------------------------------
        ;; Open button

        MGTK_CALL MGTK::InRect, file_dialog_res::open_button_rect
        cmp     #MGTK::inrect_inside
     IF_EQ
        jsr     IsOpenAllowed
        bcs     :+
        param_call ButtonClick, file_dialog_res::kFilePickerDlgWindowID, file_dialog_res::open_button_rect
        bmi     :+
        jsr     DoOpen
:       rts
    END_IF

        ;; --------------------------------------------------
        ;; Close button

        MGTK_CALL MGTK::InRect, file_dialog_res::close_button_rect
        cmp     #MGTK::inrect_inside
    IF_EQ
        jsr     IsCloseAllowed
        bcs     :+
        param_call ButtonClick, file_dialog_res::kFilePickerDlgWindowID, file_dialog_res::close_button_rect
        bmi     :+
        jsr     DoClose
:       rts
    END_IF

        ;; --------------------------------------------------
        ;; OK button

        MGTK_CALL MGTK::InRect, file_dialog_res::ok_button_rect
        cmp     #MGTK::inrect_inside
    IF_EQ
        param_call ButtonClick, file_dialog_res::kFilePickerDlgWindowID, file_dialog_res::ok_button_rect
        bmi     :+
        jsr     HandleOk
:       rts
    END_IF

        ;; --------------------------------------------------
        ;; Cancel button

        MGTK_CALL MGTK::InRect, file_dialog_res::cancel_button_rect
        cmp     #MGTK::inrect_inside
    IF_EQ
        param_call ButtonClick, file_dialog_res::kFilePickerDlgWindowID, file_dialog_res::cancel_button_rect
        bmi     :+
        jsr     HandleCancel
:       rts
    END_IF


        ;; --------------------------------------------------
        ;; Extra controls
.if FD_EXTENDED
        bit     extra_controls_flag
    IF_NS
        ;; Text Edit
        MGTK_CALL MGTK::InRect, file_dialog_res::input1_rect
        cmp     #MGTK::inrect_inside
      IF_EQ
        jmp     Click
      END_IF

        ;; Additional controls
        jmp     click_handler_hook
    END_IF
.endif

        rts

is_apple_click_flag:
        .byte   0
.endproc

;;; ============================================================
;;; This vector gets patched by overlays that add controls.

click_handler_hook:
        jsr     NoOp
        rts

;;; ============================================================

.proc HandleListButtonDown
        MGTK_CALL MGTK::FindControl, findcontrol_params
        lda     findcontrol_params::which_ctl
        beq     in_list

        cmp     #MGTK::Ctl::vertical_scroll_bar
        bne     rts1
        lda     file_dialog_res::winfo_listbox::vscroll
        and     #MGTK::Scroll::option_active
        beq     rts1
        jmp     HandleVScrollClick

rts1:   rts

in_list:
        lda     #file_dialog_res::kEntryListCtlWindowID
        sta     screentowindow_params::window_id
        MGTK_CALL MGTK::ScreenToWindow, screentowindow_params
        add16   screentowindow_params::windowy, file_dialog_res::winfo_listbox::cliprect::y1, screentowindow_params::windowy
        ldax    screentowindow_params::windowy
        ldy     #kListItemHeight
        jsr     Divide_16_8_16
        new_index := screentowindow_params::windowy
        stax    screentowindow_params::windowy

        lda     selected_index
        cmp     new_index
        beq     same
        jmp     different

        ;; --------------------------------------------------
        ;; Click on the previous entry

same:   jsr     DetectDoubleClick
        beq     open
        rts

open:   ldx     selected_index
        lda     file_list_index,x
        bmi     folder

        ;; File - select it.
        param_call ButtonFlash, file_dialog_res::kFilePickerDlgWindowID, file_dialog_res::ok_button_rect
        jsr     HandleOk
        rts

        ;; Folder - open it.
folder: and     #$7F
        pha                     ; A = index
        param_call ButtonFlash, file_dialog_res::kFilePickerDlgWindowID, file_dialog_res::open_button_rect
        pla                     ; A = index
        jsr     GetNthFilename
        jsr     AppendToPathBuf

        jsr     UpdateListFromPath

        rts

        ;; --------------------------------------------------
        ;; Click on a different entry

different:
        lda     new_index
        cmp     num_file_names
        bcc     :+
        rts

:       lda     selected_index
        bmi     :+
        lda     selected_index
        jsr     InvertEntry
:       lda     new_index
        jsr     SetSelectedIndex
        jsr     InvertEntry

        jsr     DetectDoubleClick
        bmi     :+
        jmp     open

:       rts
.endproc

;;; ============================================================
;;; Refresh the list view from the current path
;;; Clears selection.

.proc UpdateListFromPath
        lda     #$FF
        jsr     SetSelectedIndex
        jsr     ReadDir
        jsr     UpdateScrollbar
        lda     #0
        jsr     ScrollClipRect
        jsr     UpdateDiskName
        jsr     UpdateDirName
        jmp     DrawListEntries
.endproc

;;; ============================================================

.proc HandleVScrollClick
        lda     findcontrol_params::which_part
        cmp     #MGTK::Part::up_arrow
        jeq     HandleLineUp

        cmp     #MGTK::Part::down_arrow
        jeq     HandleLineDown

        cmp     #MGTK::Part::page_up
        jeq     HandlePageUp

        cmp     #MGTK::Part::page_down
        jeq     HandlePageDown

        ;; Track thumb
        lda     #MGTK::Ctl::vertical_scroll_bar
        sta     trackthumb_params::which_ctl
        MGTK_CALL MGTK::TrackThumb, trackthumb_params
        lda     trackthumb_params::thumbmoved
        bne     :+
        rts

:       lda     trackthumb_params::thumbpos
        jmp     UpdateThumbCommon
.endproc

;;; ============================================================

.proc HandlePageUp
        lda     file_dialog_res::winfo_listbox::vscroll
        and     #MGTK::Scroll::option_active
        bne     :+
        rts
:
        lda     file_dialog_res::winfo_listbox::vthumbpos
        sec
        sbc     #file_dialog_res::kListRows
        bpl     :+
        lda     #0
:
        jmp     UpdateThumbCommon
.endproc

;;; ============================================================

.proc HandlePageDown
        lda     file_dialog_res::winfo_listbox::vscroll
        and     #MGTK::Scroll::option_active
        bne     :+
        rts
:
        lda     file_dialog_res::winfo_listbox::vthumbpos
        clc
        adc     #file_dialog_res::kListRows
        cmp     file_dialog_res::winfo_listbox::vthumbmax
        beq     :+
        bcc     :+
        lda     file_dialog_res::winfo_listbox::vthumbmax
:
        jmp     UpdateThumbCommon
.endproc

;;; ============================================================

.proc HandleLineUp
        lda     file_dialog_res::winfo_listbox::vthumbpos
        bne     :+
        rts

:       sec
        sbc     #file_dialog_res::kLineDelta
        jsr     UpdateThumbCommon
        jsr     CheckArrowRepeat
        jmp     HandleLineUp
.endproc

;;; ============================================================

.proc HandleLineDown
        lda     file_dialog_res::winfo_listbox::vthumbpos
        cmp     file_dialog_res::winfo_listbox::vthumbmax
        bne     :+
        rts

:       clc
        adc     #file_dialog_res::kLineDelta
        jsr     UpdateThumbCommon
        jsr     CheckArrowRepeat
        jmp     HandleLineDown
.endproc

;;; ============================================================

.proc UpdateThumbCommon
        sta     updatethumb_params::thumbpos
        lda     #MGTK::Ctl::vertical_scroll_bar
        sta     updatethumb_params::which_ctl
        MGTK_CALL MGTK::UpdateThumb, updatethumb_params
        lda     updatethumb_params::thumbpos
        jsr     ScrollClipRect
        jmp     DrawListEntries
.endproc

;;; ============================================================

.proc CheckArrowRepeat
        MGTK_CALL MGTK::PeekEvent, event_params
        lda     event_params::kind
        cmp     #MGTK::EventKind::button_down
        beq     :+
        cmp     #MGTK::EventKind::drag
        bne     cancel
:
        MGTK_CALL MGTK::GetEvent, event_params
        MGTK_CALL MGTK::FindWindow, findwindow_params
        lda     findwindow_params::window_id
        cmp     #file_dialog_res::kEntryListCtlWindowID
        bne     cancel

        lda     findwindow_params::which_area
        cmp     #MGTK::Area::content
        bne     cancel

        MGTK_CALL MGTK::FindControl, findcontrol_params
        lda     findcontrol_params::which_ctl
        cmp     #MGTK::Ctl::vertical_scroll_bar
        bne     cancel

        lda     findcontrol_params::which_part
        cmp     #MGTK::Part::page_up ; up_arrow or down_arrow ?
        bcc     ret                  ; Yes, continue

cancel: pla
        pla

ret:    rts
.endproc

;;; ============================================================

.if FD_EXTENDED
.proc UnsetCursorIBeam
        bit     cursor_ibeam_flag
        bpl     :+
        jsr     SetCursorPointer
        copy    #0, cursor_ibeam_flag
:       rts
.endproc
.endif

;;; ============================================================

.proc SetCursorPointer
        MGTK_CALL MGTK::SetCursor, pointer_cursor
        rts
.endproc

;;; ============================================================

.if FD_EXTENDED
.proc SetCursorIBeam
        bit     cursor_ibeam_flag
        bmi     :+
        MGTK_CALL MGTK::SetCursor, ibeam_cursor
        copy    #$80, cursor_ibeam_flag
:       rts
.endproc

cursor_ibeam_flag:              ; high bit set when cursor is I-beam
        .byte   0
.endif

;;; ============================================================
;;; Get the current path, including the selection (if any)

;;; Inputs: A,X = buffer to copy path into
.proc GetPath
        stax    ptr

        ;; Any selection?
        ldx     selected_index
    IF_NC
        ;; Append filename temporarily
        lda     file_list_index,x
        and     #$7F
        jsr     GetNthFilename
        jsr     AppendToPathBuf
    END_IF

        ldy     path_buf
:       lda     path_buf,y
        ptr := *+1
        sta     SELF_MODIFIED,y
        dey
        bpl     :-

        bit     selected_index
    IF_NC
        jsr     StripPathBufSegment
    END_IF

        rts
.endproc

;;; ============================================================

.proc DoOpen
        ldx     selected_index
        lda     file_list_index,x
        and     #$7F

        jsr     GetNthFilename
        jsr     AppendToPathBuf

        jmp     UpdateListFromPath
.endproc

;;; ============================================================

.proc DoChangeDrive
        jsr     ModifierDown
        sta     drive_dir_flag
        jsr     ShiftDown
        ora     drive_dir_flag
        sta     drive_dir_flag

        jsr     NextDeviceNum
        jsr     DeviceOnLine

        jsr     UpdateListFromPath

        rts
.endproc

;;; ============================================================

;;; Output: C=0 if allowed, C=1 if not.
.proc IsChangeDriveAllowed
        lda     DEVCNT
        beq     no

        clc
        rts

no:     sec
        rts
.endproc

;;; ============================================================

;;; Output: C=0 if allowed, C=1 if not.
.proc IsOpenAllowed
        lda     selected_index
        bmi     no              ; no selection
        tax
        lda     file_list_index,x
        bpl     no              ; not a folder

        clc
        rts

no:     sec
        rts
.endproc

;;; ============================================================

;;; Output: C=0 if allowed, C=1 if not.
.proc IsCloseAllowed
        ;; Walk back looking for last '/'
        ldx     path_buf
        beq     no
:       lda     path_buf,x
        cmp     #'/'
        beq     :+
        dex
        bpl     :-
        bmi     no

        ;; Volume?
:       cpx     #1
        beq     no

        clc
        rts

no:     sec
        rts
.endproc

;;; ============================================================

.proc DoClose
        jsr     IsCloseAllowed
        bcs     ret

        ;; Remove last segment
        jsr     StripPathBufSegment

        jsr     UpdateListFromPath

ret:    rts
.endproc

;;; ============================================================
;;; Key handler

.proc HandleKeyEvent
        ldx     event_params::modifiers
    IF_NE
        ;; With modifiers
        lda     event_params::key

        jsr     CheckTypeDown
        jeq     exit

        copy    #0, type_down_buf
        ldx     event_params::modifiers
        lda     event_params::key
        cmp     #CHAR_TAB
        jeq     KeyTab

        cpx     #3
      IF_EQ
        ;; Double modifiers
        cmp     #CHAR_DOWN
        jeq     ScrollListBottom ; end of list

        cmp     #CHAR_UP
        jeq     ScrollListTop   ; start of list
      ELSE
        ;; Single modifier
        cmp     #CHAR_DOWN
        jeq     HandlePageDown

        cmp     #CHAR_UP
        jeq     HandlePageUp
      END_IF


.if FD_EXTENDED
        bit     extra_controls_flag
      IF_NS
        ;; Hook for clients
        cmp     #'0'
        bcc     :+
        cmp     #'9'+1
        jcc     key_meta_digit
:
        ;; Edit control
        jmp     Key
      END_IF
.endif

    ELSE
        ;; --------------------------------------------------
        ;; No modifiers

.if !FD_EXTENDED
        lda     event_params::key
        jsr     CheckTypeDown
        jeq     exit
.else
        bit     extra_controls_flag
      IF_NC
        lda     event_params::key
        jsr     CheckTypeDown
        jeq     exit
      END_IF
.endif

        copy    #0, type_down_buf
        lda     event_params::key

        cmp     #CHAR_RETURN
        jeq     KeyReturn

        cmp     #CHAR_ESCAPE
        jeq     KeyEscape

        cmp     #CHAR_TAB
        jeq     KeyTab

        cmp     #CHAR_CTRL_O
        jeq     KeyOpen

        cmp     #CHAR_CTRL_C
        jeq     KeyClose

        cmp     #CHAR_DOWN
        jeq     KeyDown

        cmp     #CHAR_UP
        jeq     KeyUp

.if FD_EXTENDED
        bit     extra_controls_flag
      IF_NS
        ;; Edit control
        jmp     Key
      END_IF
.endif
    END_IF

exit:   rts

;;; ============================================================

.proc KeyOpen
        jsr     IsOpenAllowed
        bcs     ret

        param_call ButtonFlash, file_dialog_res::kFilePickerDlgWindowID, file_dialog_res::open_button_rect
        jsr     DoOpen

ret:    rts
.endproc

;;; ============================================================

.proc KeyClose
        jsr     IsCloseAllowed
        bcs     ret

        param_call ButtonFlash, file_dialog_res::kFilePickerDlgWindowID, file_dialog_res::close_button_rect
        jsr     DoClose

ret:    rts
.endproc

;;; ============================================================

.proc KeyReturn
        param_call ButtonFlash, file_dialog_res::kFilePickerDlgWindowID, file_dialog_res::ok_button_rect
        jmp     HandleOk
.endproc

;;; ============================================================

.proc KeyEscape
        param_call ButtonFlash, file_dialog_res::kFilePickerDlgWindowID, file_dialog_res::cancel_button_rect
        jmp     HandleCancel
.endproc

;;; ============================================================

.proc KeyTab
        jsr     IsChangeDriveAllowed
        bcs     ret

        param_call ButtonFlash, file_dialog_res::kFilePickerDlgWindowID, file_dialog_res::change_drive_button_rect
        jsr     DoChangeDrive
ret:    rts
.endproc

;;; ============================================================
;;; This vector gets patched by overlays that add controls.

key_meta_digit:
        jmp     NoOp

;;; ============================================================

.proc KeyDown
        lda     num_file_names
        beq     l1
        lda     selected_index
        bmi     l3
        tax
        inx
        cpx     num_file_names
        bcc     l2
l1:     rts

l2:     jsr     InvertEntry
        ldx     selected_index
        inx
        txa
        jmp     UpdateListSelection

l3:     lda     #0
        jmp     UpdateListSelection
.endproc

;;; ============================================================

.proc KeyUp
        lda     num_file_names
        beq     l1
        lda     selected_index
        bmi     l3
        bne     l2
l1:     rts

l2:     jsr     InvertEntry
        ldx     selected_index
        dex
        txa
        jmp     UpdateListSelection

l3:     ldx     num_file_names
        dex
        txa
        jmp     UpdateListSelection
.endproc

;;; ============================================================

.proc CheckTypeDown
        jsr     UpcaseChar
        cmp     #'A'
        bcc     :+
        cmp     #'Z'+1
        bcc     file_char

:       ldx     type_down_buf
        beq     not_file_char

        cmp     #'.'
        beq     file_char
        cmp     #'0'
        bcc     not_file_char
        cmp     #'9'+1
        bcc     file_char

not_file_char:
        return  #$FF

file_char:
        ldx     type_down_buf
        cpx     #15
        bne     :+
        rts                     ; Z=1 to consume
:
        inx
        stx     type_down_buf
        sta     type_down_buf,x

        jsr     FindMatch
        bmi     done
        cmp     selected_index
        beq     done
        pha
        lda     selected_index
        bmi     :+
        jsr     InvertEntry
:       pla
        jmp     UpdateListSelection

done:   return  #0

.proc FindMatch
        lda     num_file_names
        bne     :+
        return  #$FF
:
        copy    #0, index

loop:   ldx     index
        lda     file_list_index,x
        and     #$7F
        jsr     SetPtrToNthFilename

        ldy     #0
        lda     ($06),y
        sta     len

        ldy     #1              ; compare strings (length >= 1)
cloop:  lda     ($06),y
        jsr     UpcaseChar
        cmp     type_down_buf,y
        bcc     next
        beq     :+
        bcs     found
:
        cpy     type_down_buf
        beq     found

        iny
        cpy     len
        bcc     cloop
        beq     cloop

next:   inc     index
        lda     index
        cmp     num_file_names
        bne     loop
        dec     index
found:  return  index

len:    .byte   0
.endproc

index:  .byte   0
char:   .byte   0

.endproc ; CheckAlpha

.endproc ; HandleKeyEvent

;;; ============================================================

;;; Input: A = index
;;; Output: A,X = filename
.proc GetNthFilename
        ldx     #$00
        stx     hi

        asl     a               ; * 16
        rol     hi
        asl     a
        rol     hi
        asl     a
        rol     hi
        asl     a
        rol     hi

        clc
        adc     #<file_names
        tay
        hi := *+1
        lda     #SELF_MODIFIED_BYTE
        adc     #>file_names

        tax
        tya
        rts
.endproc

;;; Input: A = index
;;; Output: $06 and A,X = filename
.proc SetPtrToNthFilename
        jsr     GetNthFilename
        stax    $06
        rts
.endproc

;;; ============================================================

.proc UpcaseChar
        cmp     #'a'
        bcc     done
        cmp     #'z'+1
        bcs     done
        and     #(CASE_MASK & $7F) ; convert lowercase to uppercase
done:   rts
.endproc

;;; ============================================================

.proc ScrollListTop
        lda     num_file_names
        beq     done
        lda     selected_index
        bmi     select
        bne     deselect
done:   rts

deselect:
        jsr     InvertEntry

select:
        lda     #$00
        jmp     UpdateListSelection
.endproc

;;; ============================================================

.proc ScrollListBottom
        lda     num_file_names
        beq     done
        ldx     selected_index
        bmi     l1
        inx
        cpx     num_file_names
        bne     :+
done:   rts

:       dex
        txa
        jsr     InvertEntry
l1:     ldx     num_file_names
        dex
        txa
        jmp     UpdateListSelection
.endproc

;;; ============================================================

;;; Inputs: A=index
;;; Outputs: A=index
.proc SetSelectedIndex
        pha
        sta     selected_index
        jsr     SetPortForDialog
        jsr     DrawChangeDriveLabel
        jsr     DrawOpenLabel
        jsr     DrawCloseLabel
        pla
        rts
.endproc

;;; ============================================================

;;; Inputs: A=index
.proc UpdateListSelection
        jsr     SetSelectedIndex

        lda     selected_index
        jsr     CalcTopIndex
        cmp     file_dialog_res::winfo_listbox::vthumbpos
        beq     :+

        ;; View changed - redraw everything
        jsr     UpdateScrollbarWithIndex
        jmp     DrawListEntries
:
        ;; No change - just adjust highlights
        lda     selected_index
        jmp     InvertEntry
.endproc

;;; ============================================================

.proc NoOp
        rts
.endproc

;;; ============================================================

.proc OpenWindow
.if FD_EXTENDED
        bit     extra_controls_flag
    IF_NS
        copy16  #file_dialog_res::kFilePickerDlgExLeft,  file_dialog_res::winfo::viewloc::xcoord
        copy16  #file_dialog_res::kFilePickerDlgExTop,   file_dialog_res::winfo::viewloc::ycoord
        copy16  #file_dialog_res::kFilePickerDlgExWidth, file_dialog_res::winfo::cliprect::x2
        copy16  #file_dialog_res::kFilePickerDlgExHeight,file_dialog_res::winfo::cliprect::y2

        copy16  #file_dialog_res::winfo_listbox::kExLeft, file_dialog_res::winfo_listbox::viewloc::xcoord
        copy16  #file_dialog_res::winfo_listbox::kExTop,  file_dialog_res::winfo_listbox::viewloc::ycoord
    ELSE
        copy16  #file_dialog_res::kFilePickerDlgLeft,  file_dialog_res::winfo::viewloc::xcoord
        copy16  #file_dialog_res::kFilePickerDlgTop,   file_dialog_res::winfo::viewloc::ycoord
        copy16  #file_dialog_res::kFilePickerDlgWidth, file_dialog_res::winfo::cliprect::x2
        copy16  #file_dialog_res::kFilePickerDlgHeight,file_dialog_res::winfo::cliprect::y2

        copy16  #file_dialog_res::winfo_listbox::kLeft, file_dialog_res::winfo_listbox::viewloc::xcoord
        copy16  #file_dialog_res::winfo_listbox::kTop,  file_dialog_res::winfo_listbox::viewloc::ycoord
    END_IF
.endif

        MGTK_CALL MGTK::OpenWindow, file_dialog_res::winfo
        MGTK_CALL MGTK::OpenWindow, file_dialog_res::winfo_listbox
        jsr     SetPortForDialog
        MGTK_CALL MGTK::SetPenMode, file_dialog_res::notpencopy

.if FD_EXTENDED
        bit     extra_controls_flag
    IF_NS
        MGTK_CALL MGTK::FrameRect, file_dialog_res::input1_rect
    END_IF
.endif
        MGTK_CALL MGTK::SetPenSize, file_dialog_res::pensize_frame
.if !FD_EXTENDED
        MGTK_CALL MGTK::FrameRect, file_dialog_res::dialog_frame_rect
.else
        bit     extra_controls_flag
    IF_NS
        MGTK_CALL MGTK::FrameRect, file_dialog_res::dialog_ex_frame_rect
    ELSE
        MGTK_CALL MGTK::FrameRect, file_dialog_res::dialog_frame_rect
    END_IF
.endif
        MGTK_CALL MGTK::SetPenSize, file_dialog_res::pensize_normal
        MGTK_CALL MGTK::SetPenMode, file_dialog_res::penXOR

        MGTK_CALL MGTK::FrameRect, file_dialog_res::ok_button_rect
        MGTK_CALL MGTK::FrameRect, file_dialog_res::cancel_button_rect
        MGTK_CALL MGTK::FrameRect, file_dialog_res::change_drive_button_rect
        MGTK_CALL MGTK::FrameRect, file_dialog_res::open_button_rect
        MGTK_CALL MGTK::FrameRect, file_dialog_res::close_button_rect

        MGTK_CALL MGTK::MoveTo, file_dialog_res::ok_button_pos
        param_call DrawString, file_dialog_res::ok_button_label
        MGTK_CALL MGTK::MoveTo, file_dialog_res::cancel_button_pos
        param_call DrawString, file_dialog_res::cancel_button_label

        jsr     DrawChangeDriveLabel
        jsr     DrawOpenLabel
        jsr     DrawCloseLabel

        MGTK_CALL MGTK::SetPenMode, file_dialog_res::penXOR
        MGTK_CALL MGTK::SetPattern, file_dialog_res::checkerboard_pattern
        MGTK_CALL MGTK::MoveTo, file_dialog_res::button_sep_start
        MGTK_CALL MGTK::LineTo, file_dialog_res::button_sep_end

.if FD_EXTENDED
        bit     extra_controls_flag
    IF_NS
        MGTK_CALL MGTK::SetPattern, file_dialog_res::winfo::penpattern
        MGTK_CALL MGTK::MoveTo, file_dialog_res::dialog_sep_start
        MGTK_CALL MGTK::LineTo, file_dialog_res::dialog_sep_end
    END_IF
.endif
        rts
.endproc

;;; ============================================================

;;; bit 7 set = dimmed, $00 = not dimmed, anything else = ???
open_button_dimmed_flag:
        .byte   0
close_button_dimmed_flag:
        .byte   0
change_drive_button_dimmed_flag:
        .byte   0

;;; ============================================================

.proc DrawOpenLabel
        jsr     IsOpenAllowed
        lda     #0
        ror                     ; C into high bit
        cmp     open_button_dimmed_flag
        beq     ret             ; no change

        sta     open_button_dimmed_flag
        MGTK_CALL MGTK::MoveTo, file_dialog_res::open_button_pos
        param_call DrawString, file_dialog_res::open_button_label
        bit     open_button_dimmed_flag
        bpl     ret
        param_call DisableButton, file_dialog_res::open_button_rect

ret:    rts
.endproc

;;; ============================================================

.proc DrawCloseLabel
        jsr     IsCloseAllowed
        lda     #0
        ror                     ; C into high bit
        cmp     close_button_dimmed_flag
        beq     ret             ; no change

        sta     close_button_dimmed_flag
        MGTK_CALL MGTK::MoveTo, file_dialog_res::close_button_pos
        param_call DrawString, file_dialog_res::close_button_label
        bit     close_button_dimmed_flag
        bpl     ret
        param_call DisableButton, file_dialog_res::close_button_rect

ret:    rts
.endproc

;;; ============================================================

.proc DrawChangeDriveLabel
        jsr     IsChangeDriveAllowed
        lda     #0
        ror                     ; C into high bit
        cmp     change_drive_button_dimmed_flag
        beq     ret             ; no change

        sta     change_drive_button_dimmed_flag
        MGTK_CALL MGTK::MoveTo, file_dialog_res::change_drive_button_pos
        param_call DrawString, file_dialog_res::change_drive_button_label
        bit     change_drive_button_dimmed_flag
        bpl     ret
        param_call DisableButton, file_dialog_res::change_drive_button_rect

ret:    rts
.endproc

;;; ============================================================

.proc DisableButton
        ptr := $06
        stax    ptr

        ldy     #0
        add16in (ptr),y, #1, file_dialog_res::tmp_rect::x1
        iny
        add16in (ptr),y, #1, file_dialog_res::tmp_rect::y1
        iny
        sub16in (ptr),y, #1, file_dialog_res::tmp_rect::x2
        iny
        sub16in (ptr),y, #1, file_dialog_res::tmp_rect::y2

        MGTK_CALL MGTK::SetPattern, file_dialog_res::checkerboard_pattern
        MGTK_CALL MGTK::SetPenMode, file_dialog_res::penOR
        MGTK_CALL MGTK::PaintRect, file_dialog_res::tmp_rect
        rts
.endproc

;;; ============================================================

.proc CloseWindow
        MGTK_CALL MGTK::CloseWindow, file_dialog_res::winfo_listbox
        MGTK_CALL MGTK::CloseWindow, file_dialog_res::winfo
        copy    #0, file_dialog::only_show_dirs_flag
.if FD_EXTENDED
        copy    #0, line_edit_res::blink_ip_flag
        jsr     UnsetCursorIBeam
.endif
        rts
.endproc

;;; ============================================================
;;; Inputs: A,X = string
;;; Output: Copied to `file_dialog_res::filename_buf`
;;; Assert: 15 characters or less

.proc CopyFilenameToBuf
        stax    ptr
        ldx     #kMaxFilenameLength
        ptr := *+1
:       lda     SELF_MODIFIED,x
        sta     file_dialog_res::filename_buf,x
        dex
        bpl     :-
        rts
.endproc

;;; ============================================================

.proc DrawString
        ptr := $06
        params := $06

        stax    ptr
        ldy     #0
        lda     (ptr),y
        beq     ret
        sta     params+2
        inc16   params
        MGTK_CALL MGTK::DrawText, params
ret:    rts
.endproc

;;; ============================================================

.proc MeasureString
        ptr := $06
        params := $06

        stax    ptr
        ldy     #0
        lda     (ptr),y
        sta     params+2
        inc16   params
        MGTK_CALL MGTK::TextWidth, params
        ldax    params+3
        rts
.endproc

;;; ============================================================

.proc DrawTitleCentered
        text_params     := $6
        text_addr       := text_params + 0
        text_length     := text_params + 2
        text_width      := text_params + 3

        stax    text_addr       ; input is length-prefixed string

        jsr     SetPortForDialog

.if FD_EXTENDED
        ldax    text_addr
        jsr     AuxLoad
.else
        ldy     #0
        lda     (text_addr),y
.endif
        sta     text_length
        inc16   text_addr ; point past length byte
        MGTK_CALL MGTK::TextWidth, text_params

.if !FD_EXTENDED
        sub16   #file_dialog_res::kFilePickerDlgWidth, text_width, file_dialog_res::pos_title::xcoord
.else
        bit     extra_controls_flag
    IF_NS
        sub16   #file_dialog_res::kFilePickerDlgExWidth, text_width, file_dialog_res::pos_title::xcoord
    ELSE
        sub16   #file_dialog_res::kFilePickerDlgWidth, text_width, file_dialog_res::pos_title::xcoord
    END_IF
.endif
        lsr16   file_dialog_res::pos_title::xcoord ; /= 2
        MGTK_CALL MGTK::MoveTo, file_dialog_res::pos_title
        MGTK_CALL MGTK::DrawText, text_params
        rts
.endproc

;;; ============================================================

.if FD_EXTENDED
.proc DrawInput1Label
        stax    $06
        MGTK_CALL MGTK::MoveTo, file_dialog_res::input1_label_pos
        ldax    $06
        jsr     DrawString
        rts
.endproc
.endif

;;; ============================================================

.proc DeviceOnLine
retry:  ldx     device_num
        lda     DEVLST,x

        and     #UNIT_NUM_MASK
        sta     on_line_params::unit_num
        MLI_CALL ON_LINE, on_line_params
        lda     on_line_buffer
        and     #NAME_LENGTH_MASK
        sta     on_line_buffer
        bne     found
        jsr     NextDeviceNum
        jmp     retry

found:  param_call AdjustVolumeNameCase, on_line_buffer
        lda     #0
        sta     path_buf
        param_call AppendToPathBuf, on_line_buffer
        lda     #$FF
        jsr     SetSelectedIndex
        rts
.endproc

;;; ============================================================

drive_dir_flag:
        .byte   0

.proc NextDeviceNum
        bit     drive_dir_flag
        bmi     incr

        ;; Decrement
        dec     device_num
        bpl     :+
        copy    DEVCNT, device_num
:       rts

        ;; Increment
incr:   ldx     device_num
        cpx     DEVCNT
        bne     :+
        ldx     #AS_BYTE(-1)
:       inx
        stx     device_num
        rts
.endproc

;;; ============================================================
;;; Init `device_number` (index) from the most recently accessed
;;; device via ProDOS Global Page `DEVNUM`. Used when the dialog
;;; is initialized with a specific path.

.if FD_EXTENDED
.proc InitDeviceNumber
        lda     DEVNUM
        sta     last

        ldx     DEVCNT
        inx
:       dex
        lda     DEVLST,x
        and     #UNIT_NUM_MASK
        cmp     last
        bne     :-
        stx     device_num
        rts

last:   .byte   0
.endproc
.endif

;;; ============================================================

.proc OpenDir
.if !FD_EXTENDED
retry:
.endif
        lda     #$00
        sta     open_dir_flag
.if FD_EXTENDED
retry:
.endif
        MLI_CALL OPEN, open_params
        beq     :+
        jsr     DeviceOnLine
        lda     #$FF
        jsr     SetSelectedIndex
.if !FD_EXTENDED
        lda     #$FF
.endif
        sta     open_dir_flag
        jmp     retry

:       lda     open_params::ref_num
        sta     read_params::ref_num
        sta     close_params::ref_num
        MLI_CALL READ, read_params
        beq     :+
        jsr     DeviceOnLine
        lda     #$FF
        jsr     SetSelectedIndex
.if FD_EXTENDED
        sta     open_dir_flag
.endif
        jmp     retry

:       rts
.endproc

open_dir_flag:
        .byte   0

;;; ============================================================

.proc AppendToPathBuf
        ptr := $06
        stax    ptr
        ldx     path_buf
        lda     #'/'
        sta     path_buf+1,x
        inc     path_buf
        ldy     #0
        lda     (ptr),y
        tay
        clc
        adc     path_buf
.if FD_EXTENDED
        ;; Enough room?
        cmp     #kPathBufferSize
        bcc     :+
        return  #$FF            ; failure
:
.endif
        pha
        tax
:       lda     (ptr),y
        sta     path_buf,x
        dey
        dex
        cpx     path_buf
        bne     :-

        pla
        sta     path_buf

.if FD_EXTENDED
        lda     #0
.endif
        rts
.endproc

;;; ============================================================

.proc StripPathBufSegment
:       ldx     path_buf
        cpx     #0
        beq     :+
        dec     path_buf
        lda     path_buf,x
        cmp     #'/'
        bne     :-
:       rts
.endproc

;;; ============================================================

.proc ReadDir
        jsr     OpenDir
        lda     #0
        sta     d1
        sta     d2
        sta     dir_count
        lda     #1
        sta     d3
        copy16  dir_read_buf+SubdirectoryHeader::entry_length, entry_length
        lda     dir_read_buf+SubdirectoryHeader::file_count
        and     #$7F
        sta     num_file_names
        bne     :+
        jmp     close

        ptr := $06
:       copy16  #dir_read_buf+.sizeof(SubdirectoryHeader), ptr

l1:     param_call_indirect AdjustFileEntryCase, ptr

        ldy     #0
        lda     (ptr),y
        and     #NAME_LENGTH_MASK
        bne     l2
        jmp     l6

l2:     ldx     d1
        txa
        sta     file_list_index,x
        ldy     #0
        lda     (ptr),y
        and     #STORAGE_TYPE_MASK
        cmp     #ST_LINKED_DIRECTORY << 4
        beq     l3
        bit     only_show_dirs_flag
        bpl     l4
        inc     d2
        jmp     l6

l3:     lda     file_list_index,x
        ora     #$80
        sta     file_list_index,x
        inc     dir_count
l4:     ldy     #$00
        lda     (ptr),y
        and     #NAME_LENGTH_MASK
        sta     (ptr),y

        dst_ptr := $08
        lda     d1
        jsr     GetNthFilename
        stax    dst_ptr

        ldy     #0
        lda     (ptr),y
        tay
:       lda     (ptr),y
        sta     (dst_ptr),y
        dey
        bpl     :-

        inc     d1
        inc     d2
l6:     inc     d3
        lda     d2
        cmp     num_file_names
        bne     next

close:  MLI_CALL CLOSE, close_params
        bit     only_show_dirs_flag
        bpl     :+
        lda     dir_count
        sta     num_file_names
:       jsr     SortFileNames
        jsr     SetPtrAfterFilenames
        lda     open_dir_flag
        bpl     l9
        sec
        rts

l9:     clc
        rts

next:   lda     d3
        cmp     d4
        beq     :+
        add16_8 ptr, entry_length, ptr
        jmp     l1

:       MLI_CALL READ, read_params
        copy16  #dir_read_buf+$04, ptr
        lda     #$00
        sta     d3
        jmp     l1

d1:     .byte   0
d2:     .byte   0
d3:     .byte   0
entry_length:
        .byte   0
d4:     .byte   0
.endproc

;;; ============================================================

.proc DrawListEntries
        jsr     SetPortForList
        MGTK_CALL MGTK::PaintRect, file_dialog_res::winfo_listbox::cliprect
        copy    #file_dialog_res::kListEntryNameX, file_dialog_res::picker_entry_pos::xcoord ; high byte always 0
        copy16  #kListItemHeight-1, file_dialog_res::picker_entry_pos::ycoord
        copy    #0, index

loop:   lda     index
        cmp     num_file_names
        bne     :+
        rts

:       MGTK_CALL MGTK::MoveTo, file_dialog_res::picker_entry_pos
        ldx     index
        lda     file_list_index,x
        and     #$7F

        jsr     GetNthFilename
        jsr     CopyFilenameToBuf
        param_call DrawString, file_dialog_res::filename_buf
        ldx     index
        lda     file_list_index,x
        bpl     :+

        ;; Folder glyph
        copy    #file_dialog_res::kListEntryGlyphX, file_dialog_res::picker_entry_pos::xcoord
        MGTK_CALL MGTK::MoveTo, file_dialog_res::picker_entry_pos
        param_call DrawString, file_dialog_res::str_folder
        copy    #file_dialog_res::kListEntryNameX, file_dialog_res::picker_entry_pos::xcoord

:       lda     index
        cmp     selected_index
        bne     l2
        jsr     InvertEntry
l2:     inc     index

        add16_8 file_dialog_res::picker_entry_pos::ycoord, #kListItemHeight, file_dialog_res::picker_entry_pos::ycoord
        jmp     loop

index:  .byte   0
.endproc

;;; ============================================================

UpdateScrollbar:
        lda     #$00

.proc UpdateScrollbarWithIndex
        sta     index
        lda     num_file_names
        cmp     #file_dialog_res::kListRows + 1
        bcs     :+
        ;; Deactivate scrollbar
        copy    #MGTK::Ctl::vertical_scroll_bar, activatectl_params::which_ctl
        copy    #MGTK::activatectl_deactivate, activatectl_params::activate
        MGTK_CALL MGTK::ActivateCtl, activatectl_params
        copy    #0, file_dialog_res::winfo_listbox::vthumbmax
        lda     #0
        jmp     ScrollClipRect
:
        ;; Activate scrollbar
        lda     num_file_names
        sec
        sbc     #file_dialog_res::kListRows
        cmp     file_dialog_res::winfo_listbox::vthumbmax
        beq     :+
        sta     file_dialog_res::winfo_listbox::vthumbmax
        .assert MGTK::Ctl::vertical_scroll_bar = MGTK::activatectl_activate, error, "need to match"
        lda     #MGTK::Ctl::vertical_scroll_bar
        sta     activatectl_params::which_ctl
        sta     activatectl_params::activate
        MGTK_CALL MGTK::ActivateCtl, activatectl_params
:
        ;; Update position
        lda     index
        cmp     file_dialog_res::winfo_listbox::vthumbpos
    IF_NE
        sta     updatethumb_params::thumbpos
        jsr     ScrollClipRect
        lda     #MGTK::Ctl::vertical_scroll_bar
        sta     updatethumb_params::which_ctl
        MGTK_CALL MGTK::UpdateThumb, updatethumb_params
    END_IF

        rts

index:  .byte   0
.endproc

;;; ============================================================

.proc UpdateDiskName
        jsr     SetPortForDialog
        MGTK_CALL MGTK::PaintRect, file_dialog_res::disk_name_rect
        copy16  #path_buf, $06

        ;; Copy first segment
        ldy     #0
        ldx     #2              ; skip leading slash
:       lda     path_buf,x
        cmp     #'/'
        beq     finish
        iny
        sta     file_dialog_res::filename_buf,y
        cpx     path_buf
        beq     finish
        inx
        bne     :-              ; always

finish: sty     file_dialog_res::filename_buf

        param_call MeasureString, file_dialog_res::filename_buf
        text_width := $06
        stax    text_width
        lsr16   text_width
        sub16   #file_dialog_res::kDiskLabelCenterX, text_width, file_dialog_res::disk_label_pos::xcoord
        MGTK_CALL MGTK::MoveTo, file_dialog_res::disk_label_pos
        param_call DrawString, file_dialog_res::filename_buf

        rts
.endproc

;;; ============================================================

.proc UpdateDirName
        jsr     SetPortForDialog
        MGTK_CALL MGTK::PaintRect, file_dialog_res::dir_name_rect
        copy16  #path_buf, $06

        ;; Copy last segment
        ldx     path_buf
:       lda     path_buf,x
        cmp     #'/'
        beq     :+
        dex
        bne     :-              ; always
:       inx

        ldy     #1
:       lda     path_buf,x
        sta     file_dialog_res::filename_buf,y
        cpx     path_buf
        beq     :+
        iny
        inx
        bne     :-              ; always
:       sty     file_dialog_res::filename_buf

        param_call MeasureString, file_dialog_res::filename_buf
        text_width := $06
        stax    text_width
        lsr16   text_width
        sub16   #file_dialog_res::kDirLabelCenterX, text_width, file_dialog_res::dir_label_pos::xcoord
        MGTK_CALL MGTK::MoveTo, file_dialog_res::dir_label_pos
        param_call DrawString, file_dialog_res::filename_buf

        rts
.endproc

;;; ============================================================

.proc ScrollClipRect
        sta     tmp
        clc
        adc     #file_dialog_res::kListRows
        cmp     num_file_names
        beq     l1
        bcs     l2
l1:     lda     tmp
        jmp     l4

l2:     lda     num_file_names
        cmp     #file_dialog_res::kListRows+1
        bcs     l3
        lda     tmp
        jmp     l4

l3:     sec
        sbc     #file_dialog_res::kListRows

l4:     ldx     #$00            ; A,X = line
        ldy     #kListItemHeight
        jsr     Multiply_16_8_16
        stax    file_dialog_res::winfo_listbox::cliprect::y1
        add16_8 file_dialog_res::winfo_listbox::cliprect::y1, #file_dialog_res::winfo_listbox::kHeight, file_dialog_res::winfo_listbox::cliprect::y2
        rts

tmp:    .byte   0
.endproc

;;; ============================================================
;;; Inputs: A = entry index

.proc InvertEntry
        ldx     #0              ; A,X = entry
        ldy     #kListItemHeight
        jsr     Multiply_16_8_16
        stax    file_dialog_res::rect_selection::y1
        addax   #kListItemHeight-1, file_dialog_res::rect_selection::y2

        jsr     SetPortForList
        MGTK_CALL MGTK::SetPenMode, file_dialog_res::penXOR
        MGTK_CALL MGTK::PaintRect, file_dialog_res::rect_selection
        rts
.endproc

;;; ============================================================

.proc SetPortForDialog
        lda     #file_dialog_res::kFilePickerDlgWindowID
        bne     SetPortForWindow ; always
.endproc
.proc SetPortForList
        lda     #file_dialog_res::kEntryListCtlWindowID
        FALL_THROUGH_TO SetPortForWindow
.endproc
.proc SetPortForWindow
        sta     getwinport_params::window_id
        MGTK_CALL MGTK::GetWinPort, getwinport_params
        MGTK_CALL MGTK::SetPort, window_grafport
        rts
.endproc

;;; ============================================================
;;; Sorting

.proc SortFileNames
        lda     #$7F            ; beyond last possible name char
        ldx     #15
:       sta     name_buf+1,x
        dex
        bpl     :-

        lda     #0
        sta     outer_index
        sta     inner_index

loop:   lda     outer_index     ; outer loop
        cmp     num_file_names
        bne     loop2
        jmp     finish

loop2:  lda     inner_index     ; inner loop
        jsr     SetPtrToNthFilename
        ldy     #0
        lda     ($06),y
        bmi     next_inner
        and     #NAME_LENGTH_MASK
        sta     name_buf        ; length

        ldy     #1
l3:     lda     ($06),y
        jsr     UpcaseChar
        cmp     name_buf,y
        beq     :+
        bcs     next_inner
        jmp     l5

:       cpy     name_buf
        beq     l5
        iny
        cpy     #16
        bne     l3
        jmp     next_inner

l5:     lda     inner_index
        sta     d1

        ldx     #15
        lda     #' '            ; before first possible name char
:       sta     name_buf+1,x
        dex
        bpl     :-

        ldy     name_buf
:       lda     ($06),y
        jsr     UpcaseChar
        sta     name_buf,y
        dey
        bne     :-

next_inner:
        inc     inner_index
        lda     inner_index
        cmp     num_file_names
        beq     :+
        jmp     loop2

:       lda     d1
        jsr     SetPtrToNthFilename
        ldy     #0              ; mark as done
        lda     ($06),y
        ora     #$80
        sta     ($06),y

        lda     #$7F            ; beyond last possible name char
        ldx     #15             ; max length
:       sta     name_buf+1,x
        dex
        bpl     :-

        ldx     outer_index
        lda     d1
        sta     d2,x
        lda     #0
        sta     inner_index
        inc     outer_index
        jmp     loop

        ;; Finish up
finish: ldx     num_file_names
        dex
        stx     outer_index
l10:    lda     outer_index
        bpl     l14
        ldx     num_file_names
        beq     done
        dex
l11:    lda     d2,x
        tay
        lda     file_list_index,y
        bpl     l12
        lda     d2,x
        ora     #$80
        sta     d2,x
l12:    dex
        bpl     l11

        ldx     num_file_names
        beq     done
        dex
:       lda     d2,x
        sta     file_list_index,x
        dex
        bpl     :-

done:   rts

l14:    jsr     SetPtrToNthFilename
        ldy     #0
        lda     ($06),y
        and     #$7F
        sta     ($06),y
        dec     outer_index
        jmp     l10

inner_index:
        .byte   0
outer_index:
        .byte   0
d1:     .byte   0
name_buf:
        .res    17, 0

d2:     .res    127, 0

.endproc ; SortFileNames

;;; ============================================================

.proc SetPtrAfterFilenames
        ptr := $06

        lda     num_file_names
        bne     iter
done:   rts

iter:   lda     #0
        sta     index
        copy16  #file_names, ptr
loop:   lda     index
        cmp     num_file_names
        beq     done
        inc     index

        ;; TODO: Replace this with <<4
        lda     ptr
        clc
        adc     #16
        sta     ptr
        bcc     loop
        inc     ptr+1

        jmp     loop

index:  .byte   0
.endproc

;;; ============================================================
;;; Find index to filename in file_list_index.
;;; Input: $06 = ptr to filename
;;; Output: A = index, or $FF if not found

.if FD_EXTENDED
.proc FindFilenameIndex
        stax    $06
        ldy     #$00
        lda     ($06),y
        tay
:       lda     ($06),y
        sta     d2,y
        dey
        bpl     :-
        lda     #$00
        sta     d1
        copy16  #file_names, $06
l1:     lda     d1
        cmp     num_file_names
        beq     l4
        ldy     #$00
        lda     ($06),y
        cmp     d2
        bne     l3
        tay
l2:     lda     ($06),y
        cmp     d2,y
        bne     l3
        dey
        bne     l2
        jmp     l5

l3:     inc     d1
        lda     $06
        clc
        adc     #$10
        sta     $06
        bcc     l1
        inc     $07
        jmp     l1

l4:     return  #$FF

l5:     ldx     num_file_names
l6:     dex
        lda     file_list_index,x
        and     #$7F
        cmp     d1
        bne     l6
        txa
        rts

d1:     .byte   0
d2:     .res    16, 0
.endproc
.endif

;;; ============================================================
;;; Input: A = Selection, or $FF if none
;;; Output: top index to show so selection is in view

.proc CalcTopIndex
        bpl     has_sel
        return  #0

has_sel:
        cmp     file_dialog_res::winfo_listbox::vthumbpos
    IF_LT
        rts
    END_IF

        sec
        sbc     #file_dialog_res::kListRows-1
        bmi     no_change
        cmp     file_dialog_res::winfo_listbox::vthumbpos
        beq     no_change
    IF_GE
        rts
    END_IF

no_change:
        lda     file_dialog_res::winfo_listbox::vthumbpos
        rts
.endproc

;;; ============================================================
;;; Text Edit Control
;;; ============================================================

.if FD_EXTENDED

.scope f1
        textpos := file_dialog_res::input1_textpos
        clear_rect := file_dialog_res::input1_clear_rect
        click_coords := screentowindow_params::window
        SetPort := SetPortForDialog

        .include "../lib/line_edit.s"

.endscope ; f1

LineEditInit    := f1::Init
Idle            := f1::Idle
Activate        := f1::Activate
Deactivate      := f1::Deactivate
Key             := f1::Key
Click           := f1::Click


;;; Dynamically altered table of handlers.

kJumpTableSize = 6
jump_table:
HandleOk:       jmp     0
HandleCancel:   jmp     0
        .assert * - jump_table = kJumpTableSize, error, "Table size mismatch"

;;; ============================================================

.endif ; FD_EXTENDED