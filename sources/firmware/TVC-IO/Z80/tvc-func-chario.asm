chario_handler:
            JP      p,char_out
char_in:
            CALL    OPEN_FILE_4READ_CHECK 
            LD      A, $E9  ; no open file
            RET     z
; check 0D0B, for the last error
            CALL    FILE_READ_CHECK 
            RET     nz

            ld a, (BORDER_COLOR)
            and 1
            jr nz, .skip_border_striping

            ld a, (TVC256_BORDER_RED)
            xor a, $80
            ld (TVC256_BORDER_RED), a
            out ($00), a

.skip_border_striping:
            ; copy back the fileHandle for sure
            LD HL, (TVC256_FILEHANDLE)
            LD (TVC256_INPUT_AREA), HL
            LD HL, (TVC256_FILEHANDLE+2)
            LD (TVC256_INPUT_AREA+2), HL

            ; read only 1 byte of data
            LD HL, 1
            LD (TVC256_INPUT_AREA+4),HL

quick_read:
            call SET_C_SAVE_INC

            ld a, REG_USB_MSC_CMD
            out (c), a
            inc c
            ld a, TVC256_MSCMD_READ
            out (C), A

            ld hl, 60000            ; 103 cycle loop (33us*60), ~2 secs
.read_byte_loop:
            in a, (c)               ; 12
            or a                    ;  4
            jr z, .read_done        ;  not taken: 7 (otherwise 12)
            bit 7, a                ;  7
            jr nz, .read_failed     ; not taken: 7
            call wait_39t           ; 39,  12.5us
            dec hl                  ;  6
            ld a, L                 ;  4
            or h                    ;  4
            jr nz, .read_byte_loop  ; 12

.time_out:
.read_failed:
            ld (ix+1), a
            ld b, a
            ld      a, 133          ; Read failed
            LD      (END_OF_FILE),A ; not null: end of file
            ld d, 0
            jr      .error_code_set
.read_done:
            ld hl, (TVC256_OUTPUT_AREA)
            ld a, h
            or l
            jr z, .read_failed
            ld a, (TVC256_OUTPUT_AREA+2)
            ld d, a
            ld a, (BORDER_COLOR)
            out ($00), a
            xor a
.error_code_set:
            call RESTORE_INC_FROM_SAVE
            ld c, d
            ret

; 
; OUT DATA
;

char_out:            
            CALL    OPEN_FILE_4WRITE_CHECK 
            RET     z 

            ld a, (BORDER_COLOR)
            and 1
            jr nz, .skip_border_striping
            ld a, (TVC256_BORDER_RED)
            xor a, $80
            ld (TVC256_BORDER_RED), a
            out ($00), a

.skip_border_striping:
            LD HL, (TVC256_FILEHANDLE)
            LD (TVC256_INPUT_AREA), HL
            LD HL, (TVC256_FILEHANDLE+2)
            LD (TVC256_INPUT_AREA+2), HL

            ; write only 1 byte of data
            LD HL, 1
            LD (TVC256_INPUT_AREA+4),HL

            ; write C to the buffer
            ld A, C
            ld (TVC256_INPUT_AREA+6), A

            call SET_C_SAVE_INC
            ld a, REG_USB_MSC_CMD
            out (C), A
            inc c
            ld a, TVC256_MSCMD_WRITE
            out (C), A

            ld b, 5
            call WAIT_FOR_RESULT
            jr z, .write_done

;            ld hl, 60000            ; 105 cycle loop, ~2 secs
;.write_byte_loop:
;            in a, (c)               ; 12
;            cp $00                  ;  7
;            jr z, .write_done       ;  not taken: 7 (otherwise 12)
;            and $80                 ;  7
;            jr nz, .write_failed    ; not taken: 7
;            call wait_39t   ; 12.5us, 39
;            dec hl                  ;  6
;            ld a, L                 ;  4
;            or h                    ;  4
;            jr nz, .write_byte_loop ; 12

.time_out:
.write_failed:
            ld (ix+1), a
            ld b, a
            ld a, (BORDER_COLOR)
            out ($00), a
            LD      A,$84   ; WRITE ERROR
            OR      A
            call RESTORE_INC_FROM_SAVE
            ret
.write_done:
            ld a, (BORDER_COLOR)
            out ($00), a
            xor a
            call RESTORE_INC_FROM_SAVE
            ret
