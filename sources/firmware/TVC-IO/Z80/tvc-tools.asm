
wait_100us:          ; (17T to reach here)  312T to wait
            PUSH    af ; 11T                   77T is the frame
            PUSH    bc ; 11T
            LD      b,14 ; 6T    13*17 + 12 => Total wait time is 310T
.wait_100us_loop:
            NOP      ; 4T
            DJNZ    .wait_100us_loop ; 13T on jump, 8T on not jump
            POP     bc ; 11
            POP     af ; 11T

wait_39t:   ; 12.5us
            JR      wait_27t
wait_27t:   ; 8.6us, CALL and RET is 17T + 10T
            RET      

;   sets NOT VERIFY (00 into 0BF1) and checks if 0BF3 is 0
OPEN_FILE_4READ_CHECK:  
            XOR     a 
            LD      (VERIFY_ONGOING),a 
            LD      a,(OPEN_FOR_READ_FILE_TYPE) 
            OR      A
            RET
OPEN_FILE_4WRITE_CHECK:  
            LD      a,(OPEN_FOR_WRITE_FILE_TYPE) ; open for write
FILE_CHECK:          
            OR      a 
            LD      a,$E9 
            RET      

FILE_READ_CHECK:     
            LD      HL,ERROR_CODE
            LD      A,(HL) 
            OR      A 
            RET     z 
            LD      (HL), $ec 
            RET      

print_cstring:       
            push bc
            push af
.print_cstring_loop:
            LD      c,(hl) 
            XOR     a 
            CP      c 
            JR      z,.cstring_done 
            PUSH    hl 
            RST     30h 
            DB      $21 
            POP     hl 
            INC     hl 
            JR      .print_cstring_loop
.cstring_done:
            pop af
            pop bc
            RET      

print_pstring:
            push bc
            push af
            ld b, (hl)
            ld a, b
            or a
            jr z, .exit
.print_pstring_loop
            inc hl
            ld c, (hl)
            push bc
            RST     30h 
            DB      $21 
            pop bc
            djnz .print_pstring_loop
.exit
            pop af
            pop bc
            ret
print_newline:       
            LD      hl, .newline_str
            JR      print_cstring 
.newline_str:         
            db   "\r\n", 0

print_system_area_16:
            ld hl,$D800
            jr print_area_16
print_input_area_16:
            ld hl,$D900
            jr print_area_16
print_output_area_16:
            ld hl,$DA00
print_area_16:
            push hl
            call print_hex_word
            ld a, ':'
            call print_char
            pop hl
            ld b, 16
.print_area_loop
            ld a, (hl)
            push hl
            push bc
            call print_hex_byte
            ld a, ' '
            call print_char
            pop bc
            pop hl
            inc hl
            djnz .print_area_loop
            ld a,10
            call print_char
            ld a, 13
            call print_char
            ret

print_hex_word:
            ld a, h
            call print_hex_byte
            ld a, l
print_hex_byte:      
            PUSH    BC 
            PUSH    AF 
            RRCA     
            RRCA     
            RRCA     
            RRCA     
            AND     $0F 
            CALL    print_hex_digit
            POP     AF 
            AND     $0F 
            CALL    print_hex_digit
            POP     BC 
            RET      
print_hex_digit:     
            CP      10 
            JR      nc,.alpha_chars
            ADD     A,"0" 
            JR      print_char
.alpha_chars:         
            ADD     A,"A" - 10 
print_char:
            LD      C,A 
            RST     30h 
            DB      F_EDCHOUT
            RET


/**
function div32_by_10(n: uint32) -> (quotient: uint32, remainder: uint32)
    quotient  := 0
    remainder := 0
    for i from 31 down to 0:
        // bring next bit of n into remainder (MSB first)
        remainder := (remainder << 1) | ((n >> i) & 1)
        if remainder >= 10:
            remainder := remainder - 10
            quotient := quotient | (1 << i)
    return (quotient, remainder)
*/
; Divides a 32 bit number by 10 and returns the quotient and the remainder
; INPUT
;  HLDE : 32 bit number to be divided by 10
; OUTPUT
;  HLDE : quotient
;  A    : remainder
DIV32b_BY_10:
        push hl
        ld hl, 0
        ld (TVC256_DIV_BY_10_QUO), hl
        ld (TVC256_DIV_BY_10_QUO+2), hl
        pop hl
        ld b, 32
        xor a
.loop
        sla E
        RL d
        RL l
        RL h
        RLA
        cp 10
        push af
        ccf
        call .shift_quo
        pop af  ; restore Cy flag, ruin A
        jr c, .skip_sub
        sub a, 10
.skip_sub
        djnz .loop
        ld hl, (TVC256_DIV_BY_10_QUO)
        ex de, hl
        ld hl, (TVC256_DIV_BY_10_QUO+2)
        ret
.shift_quo
        push hl
        push de
        ld hl, (TVC256_DIV_BY_10_QUO)
        ex de, hl
        ld hl, (TVC256_DIV_BY_10_QUO+2)
        RL e
        RL d
        RL l
        RL h
        ld (TVC256_DIV_BY_10_QUO+2), hl
        ex de, hl
        ld (TVC256_DIV_BY_10_QUO), hl
        pop de
        pop hl
        ret
        

GET_DECIMAL_DIGIT:   
            INC     C 
            SBC     HL,DE 
            JR      nc,GET_DECIMAL_DIGIT 
            DEC     C 
            ADD     HL,DE 
            RET      

PRINT_16BIT_DECIMAL_NUMBER:  
            PUSH    AF 
            PUSH    BC 
            PUSH    DE 
            PUSH    HL 
            LD      B,0 
            LD      c,0 
PRINT_DECIMAL_LOOP:  
            PUSH    bc 
            LD      a,c 
            RLC     a ; MUL by 2
            LD      de,DECIMAL_NUMS 
            ADD     a,e 
            LD      e,a 
            LD      a,$00 
            ADC     a,d 
            LD      d,a 
            PUSH    hl 
            EX      de,hl 
            LD      e,(hl) 
            INC     hl 
            LD      d,(hl) 
            POP     hl 

            LD      c,0 
            CALL    GET_DECIMAL_DIGIT 
            LD      a,e 
            CP      1 
            JR      z,PRINT_DIGIT ; last digit, must print even on zero
            LD      A,B 
            OR      C 
            JR      z,SKIP_DIGIT_PRINT 
PRINT_DIGIT:         
            INC     B 
            LD      A,C 
            ADD     a,"0" 
            PUSH    bc 
            CALL    print_char 
            POP     bc 
            JR      SKIP_SPACE_PRINT 
SKIP_DIGIT_PRINT:    
            LD      a," " 
            PUSH    bc 
            CALL    print_char 
            POP     bc 
SKIP_SPACE_PRINT:    
            LD      a,b 
            POP     bc 
            INC     c 
            LD      b,a 
            LD      a,c 
            CP      5 
            JR      nz,PRINT_DECIMAL_LOOP 

            POP     HL 
            POP     DE 
            POP     BC 
            POP     AF 
            RET      

print_dec_byte:
        push bc
        push de
        push hl
        LD b,0 
        ld hl, DECIMAL_NUMS_8BIT
.loop_start
        ld c, 0
        ld e, a
        ld a, (hl)
        cp 1
        jr nz, .not_last_digit
        inc b   ; last digit, must print even on zero, so we set b to 1 to force printing of the last digit
.not_last_digit:
        ld d, a
        ld a, e
.sub_loop:
        inc c
        sub d
        jr nc, .sub_loop
        dec c
        add a, d
        ld e, a
        xor a
        cp c
        jr nz, .print_digit_inc_b
        ld a, b
        or a
        jr nz, .print_digit
        jr .skip_digit_print
.print_digit_inc_b:
        inc b
.print_digit:
        ld a, c
        add a, "0"
        push bc
        push de
        call print_char
        pop de
        pop bc
.skip_digit_print
        ld a, d
        cp 1
        jr z, .loop_done
        inc hl
        ld a, e
        jr .loop_start
.loop_done:

        pop hl
        pop de
        pop bc
        ret
DECIMAL_NUMS_8BIT:        
            DB      100 
            DB      10 
            DB      1

DECIMAL_NUMS:        
            DW      10000 
            DW      1000 
            DW      100 
            DW      10 
            DW      1 
; ; fills memory starting from HL with BC 0 bytes
clean_memory:        
            LD      (hl),00 
            INC     hl 
            DEC     bc 
            LD      a,b 
            OR      c 
            JR      nz,clean_memory 
            RET      

; Uses C, Destroys A
DETECT_USB:
        ld a, REG_USB_DETECTED
        out (c), a
        inc c
        in a, (c)
        dec c
        cp $02
        ret

; Destroys A, Uses C
SET_C_SAVE_INC:
        ld a, (TVC256_IOPORT)
        add a, 2
        ld c, a
        in a, (c) ; read the current addr increment value
        ld (TVC256_INCREMENT_SAVE), a ; save it, we'll restore it later
        xor a
        out (c), a ; reset to 0 the addr increment
        dec c
        dec c
        ret

; Destroys BC and HL
RESTORE_INC_FROM_SAVE:
        ld hl, TVC256_IOPORT
        ld c, (hl)
        ld hl, TVC256_INCREMENT_SAVE
        ld b, (hl)
        inc c
        inc c
        out (c), b
        ret

WAIT_FOR_RESULT:
        ld hl, 30340            ; 103 cycle loop (33us*30340), ~1 secs (1000006.4 us)
.loop_for_result:
        in a, (c)               ; 12
        or a                    ;  4
        jr z, .io_finished     ;  not taken: 7 (otherwise
        bit 7, a                ;  8
        jr nz, .io_finished ; not taken: 7
        call wait_39t           ; 39,  12.5us
        dec hl                  ;  6
        ld a, L                 ;  4
        or h                    ;  4
        jr nz, .loop_for_result ; 12
        djnz WAIT_FOR_RESULT
.io_timeout
        ld a, $90
        or a
.io_finished:
        ret


/*
stripes:             
            LD      hl,$0000 
            PUSH    af 
            PUSH    hl 
.stripes_loop:        
            LD      a,l 
            OUT     (0),a 
            DEC     hl 
            LD      a,h 
            OR      l 
            JR      nz,.stripes_loop 
            POP     hl 
            POP     af 
            RET      
*/


/*
IOBASE equ $30
IODATA equ $31
ROUTINE_SELECT equ $B0
ROUTINE_PSTART equ $B1

mouse_print:
    phase $4000
        xor a
        out (IOBASE + 2), a
        ld a, $90 ; video mode
        out (IOBASE), a
        ld a, 1   ; 2c text
        out (IODATA), a
        call .clear_screen
        ld a, ROUTINE_PSTART ; param start
        out (IOBASE), a
        xor a; starts at $8000
        out (IODATA), a
        call .print_hdr
.start_loop:
        ld c, 0
.print_loop:        
        call .set_row_col
        ld a, $c0
        add a, c
        out (IOBASE), a
        in a, (IODATA)
        ld b, a
        call .print_value
        ld a, 2
        cp c
        call z, .set_x
        ld a, 3
        cp c
        call z, .set_y
        inc c
        ld a, $04
        cp c
        jr nz, .print_loop
        ld a, $98   ; Current Y
        out (IOBASE), a
.wait_for_screen:
        in a, (IODATA)
        cp $d0
        jr nz, .wait_for_screen

        
        ld hl, (.x)
        xor a
        out (IOBASE), a
        ld a, l
        out (IODATA), a
        ld a, 1
        out (IOBASE), a
        ld a, h
        out (IODATA), a
        ld hl, (.y)
        ld a, $20
        out (IOBASE), a
        ld a, l
        out (IODATA), a
        ld a, $21
        out (IOBASE), a
        ld a, h
        out (IODATA), a

        jr .start_loop

.clear_screen:
        ld a, ROUTINE_SELECT
        out (IOBASE), a
        xor a ; 0: clear_screen
        out (IODATA), a
        jr .wait_for_routine_finish
.print_hdr:
        ld hl, .hdr_str
        ld de, $8000
        ld bc, .hdr_str_end - .hdr_str
        ldir
        ld a, ROUTINE_SELECT
        out (IOBASE), a
        ld a, $06
        out (IODATA), a
        jr .wait_for_routine_finish

.set_row_col:
        ld a, 4
        ld ($8000), a
        ld a, c
        inc a
        ld ($8001), a
        ld a, $b0
        out (IOBASE), a
        ld a, $0A
        out (IODATA), a
        jr .wait_for_routine_finish

.print_value:
        ld ($8000), a
        ld a, ROUTINE_SELECT
        out (IOBASE), a
        ld a, $03
        out (IODATA), a
        jr .wait_for_routine_finish

.wait_for_routine_finish:
        in a, (IODATA)
        inc a
        jr nz, .wait_for_routine_finish
        ret
.set_x:
        ld d, 0
        ld e, b
        bit 7, e
        jr z, .xd_set
        ld d, $FF
.xd_set:
        ld hl, (.x)
        add hl, de
        ld a, h
        cp $ff
        jr nz, .xnot_low
        ld hl, 0
.xnot_low:
        cp $02
        jr nz, .xok
        ld hl, 256+48
.xok:
        ld (.x), hl
        ret
.set_y:
        ld d, 0
        ld e, b
        bit 7, e
        jr z, .yd_set
        ld d, $FF
.yd_set:
        ld hl, (.y)
        add hl, de
        ld a, h
        cp $ff
        jr nz, .ynot_low
        ld hl, 0
.ynot_low:
        cp $02
        jr nz, .yok
        ld hl, 240+42
.yok:
        ld (.y), hl
        ret

.hdr_str: 
        db 128+14, 13, "S:", 13, "B:", 13, "X:", 13, "Y:", 0
.hdr_str_end:
.x:
    dw 128+24
.y:
    dw 120+21
    DEPHASE
mouse_print_end:

test_border_and_U2:
  phase $9000
  di
  ld hl, .isr
  ld de, $0038
  ld bc, .isr_end-.isr
  ldir
  ei
  ld hl, .counter
.loop
  inc (hl)
  ld a, (hl)
  out ($00),a
  jr .loop
.counter
  db 00
.isr
  push af
  xor a
  ld (.counter), a
  pop af
  out ($07), a
  ei
  ret
.isr_end
  dephase
test_border_and_U2_end:

test_collision_clear:
  phase $a000
  ld a, 4
  out ($32), a
.loop:
  ld a, 134
  out ($30), a
  in a, ($31)
  in a, ($31)
  jr .loop
  dephase
test_collision_clear_end:


POSY EQU 28
STARTLINE EQU 21 + POSY * 8 - 1
scroll_demo:
  phase $7000

  xor a
  out ($32), a

  ld a, $a0     ; map in page 0
  out ($30),a
  xor a
  out ($31),a

;   ld hl, $8400 + (POSY-1) * 32
;   ld de, $8400 + (POSY-1) * 32 + 1
;   ld bc, $5F
;   ld a, $01
;   ld (hl), a
;   ldir

  ld hl, $8400 + (POSY) * 32
  ld de, $8400 + (POSY) * 32 + 1
  ld bc, $1F
  ld a, $20
  ld (hl), a
  ldir

  inc hl
  ld de, $20
  add hl, de

  xor a
.print_charset_loop
  ld (hl), a
  inc hl
  inc a
  jr nz, .print_charset_loop


  ld a, 144
  out ($30),a
  ld a, 1
  out ($31), a

.main_loop

  ld a, 152     ; read y
  out ($30), a
.loop_till_no:
  in a, ($31)
  cp STARTLINE
  jr nz, .loop_till_no

  ld a, 144
  out ($30),a
  ld a, 1
  out ($31), a

  ld a, $82     ; dark blue border
  out ($00), a
  ld hl, .current_scroll
  ld a, 149
  out ($30), a
  ld a, (hl)
  out ($31), a

  ld a, 152
  out ($30), a
.loop_till_yes:
  in a, ($31)
  cp STARTLINE + 8
  jr nz, .loop_till_yes

  ld a, 144
  out ($30),a
  ld a, 3
  out ($31), a

  ld a, $A0     ; light green border
  out ($00),a

  dec (hl)
  ld a, (hl)
  cp $80
  jr nc, .we_are_done

  ld a, $87
  ld (hl), a
  ld hl, $8400 + POSY * 32 + 1
  ld de, $8400 + POSY * 32 + 0
  ld bc, 31
  ldir

  ld hl, (.current_pos)
  inc hl
  ld a, (hl)
  or a
  jr nz, .pos_ok
  ld hl, .text
  ld a, (hl)
.pos_ok
  ld (.current_pos), hl

  cp 'A'
  jr c, .char_converted
  cp 'Z'+1
  jr nc, .check_small
  sub 'A'-1
  jr .char_converted
.check_small:
  cp 'a'
  jr c, .char_converted
  cp 'z' + 1
  jr nc, .char_converted
  sub 'a'- 1 + $80
.char_converted
  ld ($8400 + POSY * 32 + 31), a

.we_are_done
  ld a, (BORDER_COLOR)
  out ($00),a
  
  ld a, 149
  out ($30), a
  xor a
  out ($31), a
  
  jr .main_loop

  
.current_scroll:
  db $88
.current_pos:
  dw .text
.text:
  db " Hello!  This is a simple scroll test of the TVC256k++ !! You can see that there is no problem with smooth scrolling on the TVC"
  db " computers anymore. Greetings to Debrecen, to C", $e2, "vis Mikroklub!   2026.03.07. by Sanyi    *** ", 0
  dephase
scroll_demo_end:

*/