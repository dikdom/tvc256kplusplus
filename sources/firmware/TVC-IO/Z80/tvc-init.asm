init:                
            PUSH    IX ; IX points to the 30h bytes long buffer assigned to this IO card (40h, 70h, A0h, D0h)
            POP     HL ; HL= IX
            LD      A,L
            push hl
            ld hl, TVC256_CARD_RAM_AREA
            ld (hl), a
            pop hl
            SUB     $10 
            AND     $C0 ; 0x00, 0x40, 0x80, 0xc0
            LD      (PORT03_SHADOW), A
            LD      (TVC256_MEMSHADOW), A
            RRCA     
            RRCA     ; 0x00, 0x10, 0x20, 0x30
            ADD     A,$10
            LD      (IX+8),A 

            ld      c, $FF

.loop_not_ok
            ld      (TVC256_IOPORT), a
            inc c
            ld a, C
            out ($00), a
            ld hl, TVC256_IOPORT
            ld a, (ix+8)
            cp (hl)
            jr nz, .loop_not_ok

;             LD      (IX+8),A 
            RRCA     
            RRCA     
            RRCA     
            RRCA     
            SUB     $01 
            OR      $80     ; $80, $81, $82, $83 - card slots
;           CAS read routines
            LD      (CAS_IN_HW_REDIRECT_ADDR),A 
;           CAS write routines
            LD      (CAS_OUT_HW_REDIRECT_ADDR),A 
            ld  (TVC256_CAS_REDIRECT), a

            LD      a,$f0 ; U0-U1-U2-EXT
            LD      (PORT02_SHADOW),A 

            ld a, 0x08
            ld (TVC256_BORDER_RED), a

            ; call INIT_SCREEN

            ld a, ($0b21)
            inc a
            jr z, .extsetup_done

            call SET_C_SAVE_INC
            call CHECK_PENDRIVE_PRESENCE
            ld a, 2
            jr nz, .set_drive
            ld a, 0
.set_drive
            ld (TVC256_SELECTED_DRIVE), a
            jr nz, .restore_inc

            call CACHE_DIRECTORY_FROM_USB
.restore_inc:
            call RESTORE_INC_FROM_SAVE

            call SETUP_EXT
.extsetup_done:

;    ld hl, mouse_print
;    ld de, $4000
;    ld bc, mouse_print_end - mouse_print
;    ldir

;    ld hl, test_border_and_U2
;    ld de, $9000
;    ld bc, test_border_and_U2_end - test_border_and_U2
;    ldir

;    ld hl, test_collision_clear
;    ld de, $a000
;    ld bc, test_collision_clear_end - test_collision_clear
;    ldir

;    ld hl, scroll_demo
;    ld de, $7000
;    ld bc, scroll_demo_end - scroll_demo
;    ldir

    RET


CHECK_PENDRIVE_PRESENCE
            ld a, REG_USB_DETECTED
            out (C), a
            inc C
            in a, (C)
            dec c
            cp $02  ; No pendrive present
            ret


AUTO_FILE_NAME:
    db 12, "auto256k.tvc"

CACHE_DIRECTORY_FROM_USB:
            call .open_auto_file
            ret nz

            ld hl, (TVC256_OUTPUT_AREA)
            ld (TVC256_INPUT_AREA), hl ; copy file handle to input area for read command
            ld hl, (TVC256_OUTPUT_AREA+2)
            ld (TVC256_INPUT_AREA+2), hl ; copy file handle to input area for read command
            call .read_file_content
            ret nz
            call .close_file
            ret nz
            call .get_auto_content
            ret nz
            call .initiate_cache_directory

            ret

.print_char:
            push bc
            push af
            ld c, a
            rst $30
            db $21
            pop af
            pop bc
            ret

.open_auto_file:
            push bc
            ld a, 1     ; file access mode (READ)
            ld (TVC256_OPEN_IN_MODE), a

            ld hl, AUTO_FILE_NAME
            ld de, TVC256_OPEN_IN_FN_LEN ; filename length and chars
            ld bc, 13
            ldir

            pop bc

            ld a, REG_USB_MSC_CMD
            out (C), a
            inc C
            ld a, TVC256_MSCMD_OPEN ; open file
            out (C), a
            call .wait_for_finish
            ret

.read_file_content:
            ld hl, $0100
            ld (TVC256_BLKIO_IN_SIZE), hl ; read 256 bytes
            ld a, REG_USB_MSC_CMD
            out (C), a
            inc C
            ld a, $03 ; read file content
            out (C), a
            call .wait_for_finish
            ret nz
            ld hl, (TVC256_BLKIO_OUT_SIZE)
            ld de, $DA02
            add hl, de
            xor a
            ld (hl), a
            ret

.close_file:
            ld a, REG_USB_MSC_CMD
            out (C), a
            inc C
            ld a, $02 ; close file
            out (C), a
            call .wait_for_finish
            ret


.wait_for_finish:
            ld b,3                  ; 3 secs for mounting (first time usb access) and open
.outer_loop:
            ld hl, 30000            ; 103 cycle loop, ~1 secs
.loop:
            in a, (c)               ; 12
            or a                    ;  4
            jr z, .ok        ;  not taken: 7 (otherwise 12)
            bit 7, a                ;  8
            jr nz, .failed     ; not taken: 7
            call wait_39t   ; 12.5us, 39
            dec hl                  ;  6
            ld a, L                 ;  4
            or h                    ;  4
            jr nz, .loop       ; 12
            djnz .outer_loop
.failed:
            dec c
            xor a
            inc a
            ret
.ok:
            dec c
            or a
            ret

.string_separators:
            db $00, " ", $09, $0d, $0a
.get_auto_content:
            ld hl, TVC256_OUTPUT_AREA+2
.loop_find_dirname_start:
            ld de, .string_separators
            ld b, 5
.loop_check_separator_start:
            ld a, (de)
            cp (hl)
            jr z, .leading_ws
            inc de
            djnz .loop_check_separator_start
            or a
            jr z, .no_content_found
            push hl
.loop_find_dirname_end:
            ld de, .string_separators
            ld b, 5
.loop_check_separator_end:
            ld a, (de)
            cp (hl)
            jr z, .trailing_ws_found
            inc de
            djnz .loop_check_separator_end
            inc hl
            jr .loop_find_dirname_end
.no_content_found:
            xor a
            inc a
            ret
.leading_ws:
            inc hl
            jr .loop_find_dirname_start
.trailing_ws_found:
            pop de
            push de
            xor a
            sbc hl, de
            ld b, l
            pop hl  ; hl-start,b - length
            xor a
            ret

.initiate_cache_directory:
            ; $C0 param call at $8000
            ld a, REG_FUNCTON_PARAM_SELECT
            out (C), a
            inc c
            xor a
            out (C), a
            dec c

            ; copy directory name
            ld a, b
            ld ($8000), a
            ld de, $8001
.copy_dirname_loop:
            ld a, (hl)
            ld (de), a
            inc hl
            inc de
            djnz .copy_dirname_loop

            ld a, REG_FUNCTON_EXECUTE
            out (C), a
            inc c
            ; copy_dir_to_psram
            ld a, $0f
            out (C), a
            dec c

            ret

SETUP_EXT:
            ld a, (IX+8) ; 0x10, 0x20, 0x30, 0x40
            SRL a
            SRL a
            SRL a
            SRL a   ; 1, 2, 3, 4
            dec a   ; 0, 1, 2, 3
            push af     ; store 0,1,2,3                                     ; stack: IDX of card
            SLA a   ; 0, 2, 4, 6
            ld e, a
            ld d, 0
            ld hl, $0021 ; EXT0
            add hl, de  ; HL contains the address of the selexted EXT jump addr
            ld (TVC256_EXT_VECTOR_ADDR), hl
            push hl                                                         ; stack: addr of ext vect, idx of card
            push ix                                                         ; stack: io card mem, addr of ext vect, idx of card
            pop de                                                          ; stack: addr of ext vect, idx of card
            ld hl, $0010
            add hl, de
            ld (TVC256_JUMP_CODE_ADDR), hl
            ex de, hl                                                       ; de-> addr of jump vect
            pop hl                                                          ; hl-> addr of ext vect, stack: idx of card
            ld (hl), e
            inc hl
            ld (hl), d
            push de                                                         ; stack: addr of jump code, idx of card
            ld hl, .common_jump_code
            ld bc, .common_jump_code_end - .common_jump_code
            ldir
            pop hl                                                          ; hl: addr of jump code

            pop af                                                          ;  a: idx of card
            RRCA  ; 00, 01, 02, 03 -> 00, 80, 01, 81
            RRCA  ; 00, 80, 01, 81 -> 00, 40, 80, C0
            ld de, .card_select - .common_jump_code + 1
            add hl, de
            ld (hl),a

            ; backup and overwrite ISR's first 3 bytes (JP .common_jump_code)
            ld hl, ($0038)
            ld (TVC256_ORIG_ISR), hl
            ld a, ($003a)
            ld (TVC256_ORIG_ISR+2), a
            
            ld a, $c3   ; JP
            ld ($0038), a
            ld hl, (TVC256_JUMP_CODE_ADDR)
            ex de, hl
            ld hl, $0039
            ld (hl), e
            inc hl
            ld (hl), d

;             ld b, 32
;             ld hl, $00b0
; .print_isr_loop:
;             push hl
;             push bc
;             ld a, (hl)
;             call print_hex_byte
;             ld a, ' '
;             call print_char
;             pop bc
;             pop hl
;             inc hl
;             djnz .print_isr_loop
; .loop:
;             jr .loop

            ret



.common_jump_code:
            push af        ; This needed when the ISR uses this jump code, doesn't interfere with EXT
            di             ; This is needed when the EXT uses this jump code, doesn't interfere with ISR
            ld a, $F0 ; U0-U1-U2-EXT
            out ($02), a
.card_select:
            ld a, $00 ; filled by INIT->SETUP_EXT routine
            out ($03), a
.call_position:
            call .temporary_isr

            pop af
            ld (PORT03_SHADOW), a
            out ($03), a
            pop af
            ld (PORT02_SHADOW), a
            out ($02), a

            pop af          ; it is needed because we pushed AF
            ei              ; this both needed when EXT and ISR uses this jump code
            ret
.common_jump_code_end:

.temporary_isr: 
            ; same setup is required as in EXT, because 
            ; they share the jumpcode in U0 and 
            ld (TVC256_FILEHANDLE), hl      ; FILEHANDLE STORAGE is not used during temporary ISR!
            ld (TVC256_FILEHANDLE+2), bc
            pop hl  ; return address
            ld b, a ; a contains the actual card select. Now b also.
            ld a, (PORT02_SHADOW)
            push af ; PORT02 shadow
            ld a, (PORT03_SHADOW)
            push af ; PORT03 shadow
            push hl ; return address
            and $3F
            or b
            ld (PORT03_SHADOW), a
            ld a, $F0
            ld (PORT02_SHADOW),a

            ld hl, (TVC256_EXT_VECTOR_ADDR)

            ld a, (hl)
            inc hl
            or (hl) ; is the EXT vector already zeroed. If not yet, leave...
            jr nz, .not_yet

            ; set jump code address into EXT vector
            ; but first store DE also
            ld (TVC256_FILEHANDLE+4), de
            dec hl
            ld de, (TVC256_JUMP_CODE_ADDR)
            ld (hl), e
            inc hl
            ld (hl), d

            ; reset call code address to EXT code in jump code
            ld hl, (TVC256_JUMP_CODE_ADDR)
            ld de, .call_position - .common_jump_code + 1
            add hl, de
            ld de, .ext_code
            ld (hl), e
            inc hl
            ld (hl), d

            ; reset original ISR code
            ld hl, (TVC256_ORIG_ISR)
            ld ($0038), hl
            ld a, (TVC256_ORIG_ISR+2)
            ld ($003a), a
            ld de, (TVC256_FILEHANDLE+4)

.not_yet
            ld bc, (TVC256_FILEHANDLE+2)
            ld hl, (TVC256_FILEHANDLE)
            OUT  ($07),A            ; Ack CRTC's cursor interrupt

            ret

.ext_code:
            pop hl  ; return address
            ld b, a ; a contains the actual card select. Now b also.
            ld a, (PORT02_SHADOW)
            push af ; PORT02 shadow
            ld a, (PORT03_SHADOW)
            push af ; PORT03 shadow
            push hl ; return address
            and $3F
            or b
            ld (PORT03_SHADOW), a
            ld a, $F0
            ld (PORT02_SHADOW),a
            ei

            call cli_parser

            di
            ret

; INIT_SCREEN:         
;             LD      a,01 
;             LD      (INK_COLOR),a ; ink
;             LD      a,0 
;             LD      (PAPER_COLOR),a ; paper
;             LD      a,00 
;             LD      ($0b73),a ; resolution
;             LD      a,00 
;             LD      ($0b4f),a ; background

; ; white for characters
;             LD      a,$00 
;             OUT     ($60),a 
;             LD      a,$50 ; 
;             OUT     ($61),a 
;             LD      a,$10 
;             OUT     ($62),a 
;             LD      a,$ff 
;             OUT     ($62),a 
;             LD      C,00 ;   VID-MODE , 2-col
;             RST     $30 
;             DB      F_VIDMODE 
;             RET       