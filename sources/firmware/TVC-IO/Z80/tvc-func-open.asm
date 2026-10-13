RECEIVED_FILENAME EQU $0BF5 

open_handler:        
            OR      A ; checking bit7
            JP      P,open_write 
open_read:       
            CALL    OPEN_FILE_4READ_CHECK ; is there a file open for read?
            LD      A,$EB 
            RET     nz ; there is, error code is EB
            CALL    OPEN_FILE_4WRITE_CHECK ; is there a file open for write?
            LD      A,$E6 
            RET     nz ; there is, error code is E6


            push de
            ld hl, SEARCHING_STR
            call print_cstring
            pop hl


            ld a, 1 ; FA_READ(1) + FA_OPEN_EXISTING(0)
            ld (TVC256_OPEN_IN_MODE), a
            ld de, TVC256_OPEN_IN_FN_LEN
            ld c, (hl)
            ld b, 0
            inc bc
            ldir

            ; Fix for the launcher, this clears the filename buffer, so next, no param LOAD would work properly
            xor a   
            ld ($19ce),a

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
            ld a, TVC256_MSCMD_OPEN
            out (C), a

            ld b,10                 ; 10 secs for mounting (first time usb access) and open
.outer_open_loop:
            ld hl, 30000            ; 103 cycle loop, ~1 secs
.open_loop:
            in a, (c)               ; 12
            or a                    ;  4
            jr z, .open_done        ;  not taken: 7 (otherwise 12)
            bit 7, a                ;  8
            jr nz, .open_failed     ; not taken: 7
            call wait_39t   ; 12.5us, 39
            dec hl                  ;  6
            ld a, L                 ;  4
            or h                    ;  4
            jr nz, .open_loop       ; 12
            djnz .outer_open_loop

.time_out:
.open_failed:
            ld (ix+1), a
            cp 128+21  ; file-type is neither 01 nor 11 (buffered/unbuffered)
            jr z, .simple_failure ; probably file not found
            ld hl, FILE_NOT_FOUND_STR
            call print_cstring
            ld a, $E7 ; invalid file type
            jr .error_code_set
.simple_failure:
            ld hl, FILE_TYPE_ERROR_STR
            call print_cstring
            ld a,$80
.error_code_set:
            call RESTORE_INC_FROM_SAVE
            ret
.no_usb:
            ld hl, NO_USB_STR
            call print_cstring
            ld a, $82
            ld (IX+1), a
            ld a, $FE ; no usb detected
            jr .error_code_set
.open_done:
            ld a, 0x11
            ld (OPEN_FOR_READ_FILE_TYPE), a

            ld hl, FILE_FOUND_STR
            call print_cstring

            ld hl, TVC256_OUTPUT_AREA+9
            call print_cstring
            ld hl, CRLF_STR
            call print_cstring

            ld hl, (TVC256_OUTPUT_AREA)
            ld (TVC256_FILEHANDLE), hl
            ld hl, (TVC256_OUTPUT_AREA+2)
            ld (TVC256_FILEHANDLE+2), hl

            xor a
            jr .error_code_set


open_write:
            CALL    OPEN_FILE_4WRITE_CHECK ; is there a file open for write?
            LD      A,$EB 
            RET     nz ; there is, error code is EB

; ok, so there is no file open for write so far. Let's create one..
            ld a, (de)
            ld c, a ; length of file name
            inc de
            ld a, (de)
            dec de
            cp '@'  ; sign for rewrite
            ld a, 2 ; FA_WRITE(2)
            jr nz, .create_new
            or a, 8 ; create always - creates if doesn't exists, open for rewrite if exists
            ld (TVC256_OPEN_IN_MODE), a
            dec c   ; let's not include @ in fname len
            ld a, c
            ld (TVC256_OPEN_IN_FN_LEN), a
            inc de  ; skip filename length
            inc de  ; skip @
            ex de, hl
            ld de, TVC256_OPEN_IN_FNAME
            ld b, 0
            ldir
            jr .file_name_copied
.create_new:
            or a, 4 ; FA_CREATE_NEW
            ld (TVC256_OPEN_IN_MODE), a
            ex de, hl
            ld de, TVC256_OPEN_IN_FN_LEN
            ld b, 0
            inc bc
            ldir
.file_name_copied
            LD      A,(BUFFER) ; let's send the buffer type also (buffered, non-buffered)
            OR      A 
            LD      A,$01               ; buffered
            JR      nz,.file_type_set
            LD      A,$11               ; non-buffered
.file_type_set:
            ld (TVC256_OPEN_IN_TYPE), a
            LD ($0E2F),A 

; all set for creating/opening for write
            call SET_C_SAVE_INC
            ld a, (TVC256_SELECTED_DRIVE)
            or a
            jr nz, .cached_dir_write
            call DETECT_USB
            jr nz, .no_usb
.cached_dir_write
            ld a, REG_USB_MSC_CMD
            out (c), a
            inc c
            ld a, TVC256_MSCMD_OPEN
            out (C), a

            ld b,10                  ; 10 secs for mounting (first time usb access) and open
.outer_open_loop:
            ld hl, 30000            ; 103 cycle loop, ~1 secs
.open_loop:
            in a, (c)               ; 12
            or a                    ;  4
            jr z, .open_done        ;  not taken: 7 (otherwise 12)
            bit 7, a                ;  8
            jr nz, .open_failed     ; not taken: 7
            call wait_39t   ; 12.5us, 39
            dec hl                  ;  6
            ld a, L                 ;  4
            or h                    ;  4
            jr nz, .open_loop       ; 12
            djnz .outer_open_loop

.time_out:
.open_failed:
            ld (ix+1), a
            cp $88
            jr nz, .other_failure
            ld hl, FILE_ALREADY_EXISTS_STR
            call print_cstring
.other_failure
            ld a,$81
.error_code_set:
            call RESTORE_INC_FROM_SAVE
            ret
.no_usb:
            ld hl, NO_USB_STR
            call print_cstring
            ld a, $82
            ld (IX+1), a
            ld a, $FE ; no usb detected
            jr .error_code_set
.open_done:
            ld a, (TVC256_OPEN_IN_TYPE)
            ld (OPEN_FOR_WRITE_FILE_TYPE), a

            ld hl, (TVC256_OPEN_OUT_FHANDLE)
            ld (TVC256_FILEHANDLE), hl
            ld hl, (TVC256_OPEN_OUT_FHANDLE + 2)
            ld (TVC256_FILEHANDLE + 2), hl

            xor a
            jr .error_code_set
            
SEARCHING_STR:
            db   "Searching\r\n", 0x00

FILE_FOUND_STR:
            db   "Found: ", 0x00

FILE_NOT_FOUND_STR:  
            db   "File Not Found\r\n", 0x00

CRLF_STR:
            db   "\r\n", 0x00

FILE_TYPE_ERROR_STR:
            db "Invalid file type\r\n", 0x00
FILE_ALREADY_EXISTS_STR:
            db "File already exists\r\n", 0x00
NO_USB_STR:
            db "No mass storage USB device\r\n", 0x00
