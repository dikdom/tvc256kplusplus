close_handler:
            JP      p,.close_for_write 
            CALL    OPEN_FILE_4READ_CHECK ; is there a file open for read?
            LD      A,$E9
            RET     z ; there is not, error code is E9
            xor a
            ld (TVC256_CLOSE_TYPE), a

            jr .close_indeed

.close_for_write:
            CALL OPEN_FILE_4WRITE_CHECK 
            ld a, $83
            RET     z 
            ld a, 1
            ld (TVC256_CLOSE_TYPE), a

.close_indeed:
            ; copy back the fileHandle for sure
            LD HL, (TVC256_FILEHANDLE)
            LD (TVC256_INPUT_AREA), HL
            LD HL, (TVC256_FILEHANDLE+2)
            LD (TVC256_INPUT_AREA+2), HL

            call SET_C_SAVE_INC
            
            ld a, REG_USB_MSC_CMD
            out (C), A
            inc c
            ld a, TVC256_MSCMD_CLOSE
            out (C), A

            ld hl, 60000            ; 103 cycle loop (33us*60000), ~2 secs
.close_loop:
            in a, (c)               ; 12
            or a                    ;  4
            jr z, .close_done        ;  not taken: 7 (otherwise 12)
            bit 7, a                ;  7
            jr nz, .close_failed     ; not taken: 7
            call wait_39t           ; 39,  12.5us
            dec hl                  ;  6
            ld a, L                 ;  4
            or h                    ;  4
            jr nz, .close_loop      ; 12

.time_out:
.close_failed:
            ld (ix+1), a
            ld b, a
            ld a,$83
            jr .error_code_set
.close_done:
            ld a, (TVC256_CLOSE_TYPE)
            or a
            jr nz, .done_4_write
            ld (OPEN_FOR_READ_FILE_TYPE), a
            jr .error_code_set

.done_4_write:
            xor a
            LD (OPEN_FOR_WRITE_FILE_TYPE),A
.error_code_set:
            call RESTORE_INC_FROM_SAVE
            ret
