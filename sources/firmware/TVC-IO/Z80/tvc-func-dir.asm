; To obtain the directory list of the current path from the card
; OPENDIR must be called first (bit 7 is irrelevant). Check its return value, 
; then call READDIR (bit 7 must be set) in loop - checking its retval. If 
; bit 7 is clear during READDIR call, the directory read iteration is broken, 
; and the opened directory handle will be closed/released after the READDIR call.
; READDIR though will fill in the given structure - if there is a valid entry to read.
; 
;
; OPENDIR
; INPUT
;    -
; OUTPUT
;    - A: $F0 Failed directory read
;         $00 Structure filled with data
;         $01 End of list reached
;
;
;
; READDIR
; INPUT
;    - direction bit (bit 7) shall be set on function code
;      - if it is clear on READDIR, that will close the directory read iteration,
;        next read is not possible
;    - DE: pointer to a 256+1+4+13=274 bytes long directory buffer, where the data is copied
; OUTPUT
;    - A:  $F0 Failed directory read
;          $00 Structure filled with data
;          $80+ unhandled error code - should not leak back to enduser..
;    - DE: points to a filled directory record structure (see below). If there is no more 
;          entry in in the directory, then the filename is 0 long (first byte in structure is 0)
; 
; Directory record structure:
; - 256 bytes long buffer for a pascal style string of the file name
;   Length is zero if end of directory reached
; - 1 byte file type where bit 4 is set on directory
;   AM_RDO	0x01	/* Read only */
;   AM_HID	0x02	/* Hidden */
;   AM_SYS	0x04	/* System */
;   AM_DIR	0x10	/* Directory */
;   AM_ARC	0x20	/* Archive */
; - 4 bytes file length (09012345h long file length is stored in the following 
;   order: 45h 23h 01h 09h )
; - 13 bytes short filename: filled only when filename contains a >12 long filename

opendir_handler:
            call SET_C_SAVE_INC
            ld a, (TVC256_SELECTED_DRIVE)
            or a
            jr nz, .cached_dir
            call DETECT_USB
            jr nz, .no_usb
.cached_dir
            ld a, 1
            ld (TVC256_INPUT_AREA), a
            ld a, '.'
            ld (TVC256_INPUT_AREA+1), a

            ld a, REG_USB_MSC_CMD
            out (c), a
            inc c
            ld a, TVC256_MSCMD_OPENDIR   ; current workding directory or path of the working directory
            out (C), A
            ld b, 5
            call WAIT_FOR_RESULT
            jr z, .opendir_done
.opendir_failed:
            ld (ix+1), a
            ld b, a
            ld a, $F0
            jr .error_code_set
.no_usb:
            ld a, $82
            ld (ix+1), a
            ld a, $FE
.error_code_set:
            call RESTORE_INC_FROM_SAVE
            ret
.opendir_done:
            ld hl, (TVC256_OPEN_OUT_FHANDLE)
            ld (TVC256_DIRHANDLE), hl
            ld hl, (TVC256_OPEN_OUT_FHANDLE + 2)
            ld (TVC256_DIRHANDLE + 2), hl
            xor a
            jr .error_code_set


readdir_handler:
            jp p, closedir_handler  ; positive, meaning no bit 7 set
.readdir_entry:
            call SET_C_SAVE_INC
            ld a, (TVC256_SELECTED_DRIVE)
            or a
            jr nz, .cached_dir_open
            call DETECT_USB
            jr nz, .no_usb
.cached_dir_open
            ld hl, (TVC256_DIRHANDLE)
            ld (TVC256_INPUT_AREA), hl
            ld hl, (TVC256_DIRHANDLE + 2)
            ld (TVC256_INPUT_AREA + 2), hl

            ld a, REG_USB_MSC_CMD
            out (c), a
            inc c
            ld a, TVC256_MSCMD_READDIR
            out (C), A
            ld b, 5
            call WAIT_FOR_RESULT
            jr z, .readdir_done
.readdir_failed:
            ld (IX+1), a
            ld b, a
            ld a, $f1
.error_code_set:
            call RESTORE_INC_FROM_SAVE
            ret
.no_usb:
            ld a, $82
            ld (IX+1), a
            ld a, $FE
            jr .error_code_set

.readdir_done:
            push de
            ld bc, $0112
            ld hl, TVC256_OUTPUT_AREA
            ldir

            pop de
            xor a
            jr .error_code_set

closedir_handler:
            call SET_C_SAVE_INC
            ld a, (TVC256_SELECTED_DRIVE)
            or a
            jr nz, .cached_dir
            call DETECT_USB
            jr nz,.no_usb
.cached_dir

            ld hl, (TVC256_DIRHANDLE)
            ld (TVC256_INPUT_AREA), hl
            ld hl, (TVC256_DIRHANDLE + 2)
            ld (TVC256_INPUT_AREA + 2), hl

            ld a, REG_USB_MSC_CMD
            out (c), a
            inc c
            ld a, TVC256_MSCMD_CLOSEDIR
            out (C), A
            ld b, 2
            call WAIT_FOR_RESULT
            jr z, .closedir_done
.closedir_failed:
            ld (IX+1), a
            ld b, a
            ld a, $f2
.error_code_set:
            call RESTORE_INC_FROM_SAVE
            ret
.no_usb:
            ld a, $82
            ld (IX+1), a
            ld a, $FE
            jr .error_code_set

.closedir_done:
            xor a
            jr .error_code_set

