; INPUT
;   DE: points a TVC string, max 255 characters (len + chars)
; OUTPUT:
;   A :
;     - 00: OK, delete successful
;     - ED: ERR, delete failed

delete_handler:
            push de
            call SET_C_SAVE_INC
            ld a, (TVC256_SELECTED_DRIVE)
            or a
            jr nz, .cached_dir
            call DETECT_USB
            jr nz,.no_usb

.cached_dir
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
            ld a, TVC256_MSCMD_DELETE ; delete
            out (C), A
            ld b, 5
            call WAIT_FOR_RESULT
            jr z, .delete_done

.delete_failed:
            ld (ix+1), a
            ld b, a
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
.delete_done:
            xor a
            jr .error_code_set