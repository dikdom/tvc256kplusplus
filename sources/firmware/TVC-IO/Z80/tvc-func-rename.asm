; INPUT
;   DE: points to two consequent TVC strings, max 512 characters 2*(len + chars)
; OUTPUT:
;   A :
;     - 00: OK, rename successful
;     - ED: ERR, rename failed

rename_handler:
            push de
            call SET_C_SAVE_INC
            call DETECT_USB
            jr nz,.no_usb

            push bc
            ld a, (de)
            ld c, a
            ld b, 0
            inc bc
            ld hl, $D900
            ex de, hl
            ldir

            ld a, (hl)
            ld c, a
            ld b, 0
            inc bc
            ldir

            pop bc

            ld a, REG_USB_MSC_CMD
            out (c), a
            inc c
            ld a, TVC256_MSCMD_RENAME   ; rename
            out (C), A
            ld b, 5
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