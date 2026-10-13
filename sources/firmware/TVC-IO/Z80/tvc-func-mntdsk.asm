mount_dsk_handler:
            JP p,umount_dsk
            push de
            call SET_C_SAVE_INC

.mount_dsk
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
            ld a, TVC256_MSCMD_MOUNTDSK   ; change current workding directory
            out (C), A
            ld b, 10
            call WAIT_FOR_RESULT
            jr z, .mount_done

.mount_failed:
            ld (ix+1), a
            ld a, $EF
            jr .error_code_set

.error_code_set:
            call RESTORE_INC_FROM_SAVE
            pop de
            ret 
.mount_done:
            xor a
            jr .error_code_set


umount_dsk
            call SET_C_SAVE_INC

.umount_dsk
            ld a, REG_USB_MSC_CMD
            out (c), a
            inc c
            ld a, TVC256_MSCMD_UNMOUNTDSK   ; unmount dsk 
            out (C), A
            ld b, 2
            call WAIT_FOR_RESULT
            jr z, .mount_done

.umount_failed:
            ld (ix+1), a
            ld a, $EF
            jr .error_code_set
.error_code_set:
            call RESTORE_INC_FROM_SAVE
            ret 
.mount_done:
            xor a
            jr .error_code_set
