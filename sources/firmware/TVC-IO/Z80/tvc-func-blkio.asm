blockio_handler:
            JP      p,block_out

block_in:
            CALL    OPEN_FILE_4READ_CHECK 
            ld      a, $E9
            RET     z

            ld a, (BORDER_COLOR)
            ld (TVC256_BORDER_SAVE), a

            ld a, $ff
            ld (ix+3), a

            ld (TVC256_BLKIO_TOREAD), bc
            ld (TVC256_BLKIO_DEST), de
            
            ; copy back the fileHandle for sure
            LD HL, (TVC256_FILEHANDLE)
            LD (TVC256_INPUT_AREA), HL
            LD HL, (TVC256_FILEHANDLE+2)
            LD (TVC256_INPUT_AREA+2), HL

            call SET_C_SAVE_INC ; C will not be used...

.blkread_loop:
            ld a, (TVC256_BORDER_SAVE)
            AND 1
            jr nz, .skip_border_striping
            ld a, 0x02  ; dark blue
            ld (BORDER_COLOR), a
            out ($00), a
.skip_border_striping:
            ld hl, (TVC256_BLKIO_TOREAD)
            ld de, $0400
            xor a
            sbc hl, de
            jr c, .less_than_400
            ex de, hl   ; HL <= 0x0400
            jr .input_set
.less_than_400:
            ld hl, (TVC256_BLKIO_TOREAD)
.input_set:
            ld (TVC256_INPUT_AREA + 4), hl

            ld a, (TVC256_IOPORT)
            ld c, a
            ld a, REG_USB_MSC_CMD
            out (c), a
            inc c
            ld a, TVC256_MSCMD_READ
            out (C), A

            ld hl, 60000            ; 103 cycle loop, ~2 secs
.read_loop:
            in a, (c)               ; 12
            or a                    ;  4
            jr z, .read_done        ;  not taken: 7 (otherwise 12)
            bit 7, a                ;  8
            jr nz, .read_failed     ; not taken: 7
            call wait_39t   ; 12.5us, 39
            dec hl                  ;  6
            ld a, L                 ;  4
            or h                    ;  4
            jr nz, .read_loop       ; 12

.time_out:
.read_failed:
            ld (ix+1), a
            ld b, a
            ld a, (TVC256_BORDER_SAVE)
            ld (BORDER_COLOR), a
            out ($00), a
            ld a, $85
            jr .retval_set

.read_done:
            ld bc, (TVC256_OUTPUT_AREA) ; read bytes in BC
            ld a, b
            or c
            jr z, .end_of_file_reached

            ld a, (TVC256_BORDER_SAVE)
            AND 1
            jr nz, .skip_border_striping_end

            ld a, 0x82
            ld (BORDER_COLOR), a
            out ($00), a

.skip_border_striping_end:
            ld de, (TVC256_BLKIO_DEST)
            ld hl, TVC256_OUTPUT_AREA+2
            ldir                        ; BC is used here!
            ld (TVC256_BLKIO_DEST), de
            ld hl, (TVC256_BLKIO_TOREAD)
            ld de, (TVC256_OUTPUT_AREA)
            xor a
            sbc hl, de
            ld a, h
            or l
            jr z, .block_read_done
            ld (TVC256_BLKIO_TOREAD), hl
            jp .blkread_loop

.end_of_file_reached:
            ld a, (TVC256_BORDER_SAVE)
            ld (BORDER_COLOR), a
            out ($00), a
            LD a, $EC
            LD (END_OF_FILE),A ; not null: end of file
            ld bc, (TVC256_BLKIO_TOREAD)
            jr .retval_set

.block_read_done:
            ld a, (TVC256_BORDER_SAVE)
            ld (BORDER_COLOR), a
            out ($00), a
            ld bc, 0
            xor a
.retval_set:
            push bc
            call RESTORE_INC_FROM_SAVE
            pop bc
            ret


block_out:
            CALL    OPEN_FILE_4WRITE_CHECK 
            RET     z 

            ld a, (BORDER_COLOR)
            ld (TVC256_BORDER_SAVE), a

            ld a, $ff
            ld (ix+3), a

            ld (TVC256_BLKIO_TOWRITE), bc
            ld (TVC256_BLKIO_SOURCE), de
            
            ; copy back the fileHandle for sure
            LD HL, (TVC256_FILEHANDLE)
            LD (TVC256_BLKIO_IN_FHANDLE), HL
            LD HL, (TVC256_FILEHANDLE + 2)
            LD (TVC256_BLKIO_IN_FHANDLE + 2), HL

            call SET_C_SAVE_INC ; C will not be used...

.blkwrite_loop:
            ld a, (TVC256_BORDER_SAVE)
            AND 1
            jr nz, .skip_border_striping
            ld a, 0x02  ; dark blue
            ld (BORDER_COLOR), a
            out ($00), a
.skip_border_striping
            ld hl, (TVC256_BLKIO_TOWRITE)
            ld de, $0400
            xor a
            sbc hl, de
            jr c, .less_than_400
            ld bc, 0x400
            jr .bc_set
.less_than_400:
            ld bc, (TVC256_BLKIO_TOWRITE)
.bc_set:
            push bc
            pop hl
            ld (TVC256_BLKIO_IN_SIZE), hl

            ld hl, (TVC256_BLKIO_SOURCE)
            ld de, TVC256_BLKIO_IN_DATA
            ldir

            ld a, (TVC256_IOPORT)
            ld c, a
            ld a, REG_USB_MSC_CMD
            out (c), a
            inc c
            ld a, TVC256_MSCMD_WRITE
            out (C), A

            ld hl, 60000            ; 103 cycle loop, ~2 secs
.write_loop:
            in a, (c)               ; 12
            or a                    ;  4
            jr z, .write_done        ;  not taken: 7 (otherwise 12)
            bit 7, a                ;  8
            jr nz, .write_failed     ; not taken: 7
            call wait_39t   ; 12.5us, 39
            dec hl                  ;  6
            ld a, L                 ;  4
            or h                    ;  4
            jr nz, .write_loop       ; 12
.time_out:
            ld a, $02
.write_failed:
            ld (ix+1), a
            ld a, (TVC256_BORDER_SAVE)
            ld (BORDER_COLOR), a
            out ($00), a
            ld bc, (TVC256_BLKIO_TOWRITE)
            ld a, $84
.retval_set:
            push bc
            call RESTORE_INC_FROM_SAVE
            pop bc
            ret
.write_done:
            ld de, (TVC256_BLKIO_OUT_SIZE)
            ld a, d
            or e
            jr z, .end_of_file_reached

            ld a, (TVC256_BORDER_SAVE)
            AND 1
            jr nz, .skip_border_striping_end
            ld a, 0x82
            ld (BORDER_COLOR), a
            out ($00), a
.skip_border_striping_end:
            ld hl, (TVC256_BLKIO_SOURCE)
            add hl, de
            ld (TVC256_BLKIO_SOURCE), hl

            ld hl, (TVC256_BLKIO_TOWRITE)
            xor a
            sbc hl, de
            ld a, h
            or l

            jr z, .block_write_done
            ld (TVC256_BLKIO_TOWRITE), hl
            jp .blkwrite_loop

.end_of_file_reached:
            ld a, (TVC256_BORDER_SAVE)
            ld (BORDER_COLOR), a
            out ($00), a
            LD a, $EC
            LD (END_OF_FILE),A ; not null: end of file
            ld (ix+2), a
            ld bc, (TVC256_BLKIO_TOREAD)
            jr .retval_set

.block_write_done:
            ld a, (TVC256_BORDER_SAVE)
            ld (BORDER_COLOR), a
            out ($00), a

            ld bc, 0
            xor a
            jr .retval_set
