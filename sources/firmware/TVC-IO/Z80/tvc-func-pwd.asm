; D6 - PWD
; INPUT
;   DE: pointer to a 256 byte long buffer 
; OUTPUT:
;   A:
;     - 00: OK, buffer filled with a null terminated string
;     - EE: ERR, no USB
;     - ED: ERR, getting PWD failed
; ============================================================
; 56 - CD
; INPUT
;   DE: points a TVC string, max 255 characters (len + chars)
; OUTPUT:
;   A :
;     - 00: OK, buffer filled with a null terminated string
;     - ED: ERR, getting PWD failed

pwd_handler:
            jp p, set_current_working_directory
.get_current_working_directory:
            push de
            call SET_C_SAVE_INC
            ld a, (TVC256_SELECTED_DRIVE)
            or a
            jr nz, .files_cached
            call DETECT_USB
            jr nz, .no_usb
.files_cached
            ld a, REG_USB_MSC_CMD
            out (c), a
            inc c
            ld a, TVC256_MSCMD_GETCWD   ; current workding directory or path of the working directory
            out (C), A
            ld b, 2
            call WAIT_FOR_RESULT
            jr z, .pwd_done

.pwd_failed:
            ld (ix+1), a
            xor a
            ld (de), a
            ld a, $ED
            jr .error_code_set
.no_usb:
            ld a, $82
            ld (ix+1), a
            ld a, $FE
.error_code_set:
            call RESTORE_INC_FROM_SAVE
            pop de
            ret 
.pwd_done:
            ld hl, TVC256_OUTPUT_AREA
            ld a, (hl)
            ld c, a
            ld b, 0
            inc bc
            ldir
            xor a

            jr .error_code_set

;==========================================================================================
;==========================================================================================
;==========================================================================================

set_current_working_directory:
            push de
            call SET_C_SAVE_INC
            ld a, (TVC256_SELECTED_DRIVE)
            or a
            jr nz, .dir_change
            call DETECT_USB
            jr nz,.no_usb

.dir_change
            push bc
            ld a, (de)
            ld c, a
            ld b, 0
            inc bc
            ld hl, $D900
            ex de, hl
            ldir
            pop bc

            ld a, REG_USB_MSC_CMD
            out (c), a
            inc c
            ld a, TVC256_MSCMD_CHDIR   ; change current workding directory
            out (C), A
            ld b, 2
            call WAIT_FOR_RESULT
            jr z, .chdir_done

.chdir_failed:
            ld (ix+1), a
            ld a, $EF
            jr .error_code_set
.no_usb:
            ld a, $82
            ld (ix+1), a
            ld a, $FE
.error_code_set:
            call RESTORE_INC_FROM_SAVE
            pop de
            ret 
.chdir_done:
            xor a
            jr .error_code_set