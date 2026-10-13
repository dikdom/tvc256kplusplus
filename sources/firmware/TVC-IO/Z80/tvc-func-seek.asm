seek_handler:
    CALL    OPEN_FILE_4READ_CHECK 
    jr nz, .file_open
    CALL    OPEN_FILE_4WRITE_CHECK 
    ld a, $E0
    RET z 
.file_open:
    ld hl, (TVC256_FILEHANDLE)
    ld ($D900), hl
    ld hl, (TVC256_FILEHANDLE+2)
    ld ($D900+2), hl

    ld hl, $D904
    ex de, hl
    ld bc, 4
    ldir

    call SET_C_SAVE_INC
    ld a, (TVC256_SELECTED_DRIVE)
    or a
    jr nz, .cached_dir
    call DETECT_USB
    jr nz, .no_usb

.cached_dir:
    ld a, REG_USB_MSC_CMD
    out (c), a
    inc c
    ld a, TVC256_MSCMD_SEEK   ; current workding directory or path of the working directory
    out (C), A
    ld b, 5
    call WAIT_FOR_RESULT
    jr z, .seek_done

.seek_failed:
    ld (ix+1), a
    xor a
    ld (de), a
    ld a, $E1
    jr .error_code_set
.no_usb:
    ld a, $82
    ld (ix+1), a
    ld a, $FE
.error_code_set:
    call RESTORE_INC_FROM_SAVE
    pop de
    ret 
.seek_done:
    ld hl, TVC256_OUTPUT_AREA
    ld a, (hl)
    ld c, a
    ld b, 0
    inc bc
    ldir
    xor a

    jr .error_code_set
