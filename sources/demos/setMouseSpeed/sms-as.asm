;PPREG_SPRITE_X equ $00
;PPREG_SPRITE_Y equ $20
;PPREG_SPRITE_COLOR equ $40
;PPREG_SPRITE_PHASE equ $50

;PPREG_SPRITE_ENABLE_LOW equ $90
;PPREG_SPRITE_ENABLE_HIGH equ $91
;PPREG_SPRITE_COLORMODE_LOW equ $94
;PPREG_SPRITE_COLORMODE_HIGH equ $95

BORDER_SHADOW equ $0b4F

REG_SPRITE_X equ $00
REG_SPRITE_Y equ $20
REG_SPRITE_PHASE equ $50
REG_SPRITE_ENABLE equ $70
REG_SPRITE_COLORMODE equ $80
PPREG_SCREEN_VIDEOMODE equ $A0
REG_MEMORY_P2 equ $B0
REG_USB_INIT equ $D0

POSX_MINUS equ 10
POSY_MINUS equ 6
POSX_PLUS equ  30
POSY_PLUS equ  6

	org $19ef - $90
	include "cas-header.asm"
PROGRAM_START:
	include "basic-header.asm"
	org $1a00
	
	rst $30
	db $5d
	or a
	jr nz, quit
	
	ld a, c
	ld (BASE_PORT), a
	add 4
	ld (BASE_PORT2), a

	call setup
	call main_loop
	call teardown
	ld b, 1
	ld c, 12
	rst $30
	db $23
	
	ld hl, 0
	ret

quit:
	ld hl, -1
	ret

main_loop:
	ld hl, actual_port_values
	ld de, shadow_port_values
	ld bc, 6
	ldir
	
	ld hl, shadow_port_values
	ld de, prev_port_values
	ld b, 6
	ld c, 0
.port_check_loop
	ld a, (de)
	cp (hl)
	call nz, .changed_port_value
	inc hl
	inc de
	inc c
	djnz .port_check_loop
	
	ld hl, actual_coords
	ld de, shadow_coords
	ld bc, 4
	di
	ldir
	ei
	
	ld c, 10
	ld b, 1
	rst $30
	db $23
	
	ld hl, (shadow_x)
	call print_hex_word
	call print_newline
	ld hl, (shadow_y)
	call print_hex_word
	
	ld de, 21 + ((POSY_MINUS - 2) * 10)
	xor a
	sbc hl, de
	jp c, .reset_borders
	ld hl, (shadow_y)
	ld de, 21 + ((POSY_MINUS + 1) * 10)
	xor a
	sbc hl, de
	jp nc, .reset_borders
	
	ld hl, (shadow_x)
	ld de, 24 + ((POSX_MINUS - 2) * 4)
	xor a
	sbc hl, de
	jp c, .reset_borders
	
	ld hl, (shadow_x)
	ld de, 24 + ((POSX_MINUS + 1) * 4)
	xor a
	sbc hl, de
	jr nc, .might_be_pos_plus
	
	ld a, (prev_border_minus)
	or a
	jr nz, .border_minus_drawn
	
	ld b, POSX_MINUS - 1
	ld c, POSY_MINUS - 1
	rst $30
	db $23
	
	ld hl, border_on
	call print_cstring
	ld a, 1
	ld (prev_border_minus), a

.border_minus_drawn:
	ld a, (BASE_PORT)
	ld c, a
	ld a, (prev_port_values + 1)
	cp 1
	jp z, .update_prev_values
	ld a, (shadow_port_values + 1)
	cp 1
	jp nz, .update_prev_values
	ld a, (shadow_port_values + 5)
	cp 1
	jp z, .update_prev_values
	dec a
	ld b, REG_USB_INIT + 5
	out (c), b
	inc c
	out (c), a
	jp .update_prev_values

.might_be_pos_plus:
	ld hl, (shadow_x)
	ld de, 24 + ((POSX_PLUS - 2) * 4)
	xor a
	sbc hl, de
	jp c, .reset_borders
	
	ld hl, (shadow_x)
	ld de, 24 + ((POSX_PLUS + 1) * 4)
	xor a
	sbc hl, de
	jp nc, .reset_borders
	
	ld a, (prev_border_plus)
	or a
	jr nz, .border_plus_drawn
	
	ld b, POSX_PLUS - 1
	ld c, POSY_PLUS - 1
	rst $30
	db $23
	
	ld hl, border_on
	call print_cstring
	ld a, 1
	ld (prev_border_plus), a

.border_plus_drawn:
	ld a, (BASE_PORT)
	ld c, a
	ld a, (prev_port_values+1)
	cp 1
	jr z, .update_prev_values
	ld a, (shadow_port_values + 1)
	cp 1
	jr nz, .update_prev_values
	ld a, (shadow_port_values + 5)
	cp $FF
	jr z, .update_prev_values
	inc a
	ld b, REG_USB_INIT + 5
	out (C), b
	inc c
	out (c), a
	jr .update_prev_values

.reset_borders
	ld a, (prev_border_minus)
	or a
	jr z, .check_border_plus
	xor a
	ld (prev_border_minus), a
	ld b, POSX_MINUS-1
	ld c, POSY_MINUS-1
	rst $30
	db $23
	ld hl, border_off
	call print_cstring
	jr .update_prev_values
.check_border_plus
	ld a, (prev_border_plus)
	or a
	jr z, .update_prev_values
	xor a
	ld (prev_border_plus), a
	ld b, POSX_PLUS-1
	ld c, POSY_PLUS-1
	rst $30
	db $23
	ld hl, border_off
	call print_cstring

.update_prev_values

	ld hl, shadow_port_values
	ld de, prev_port_values
	ld bc, 6
	ldir
	
	ld a, ($0bE5)
	or a
	jp z, main_loop
	
	ret

	
	
.changed_port_value:
	push de
	push hl
	push bc
	ld b, c
	xor a
	cp b
	jr z, .b_ok
	xor a
.add_8_loop
	add 8
	djnz .add_8_loop
	ld b, a
.b_ok
	inc b
	ld c, 3
	rst $30
	db $23
	
	pop bc
	push bc
	ld hl, shadow_port_values
	ld e, c
	ld d, 0
	add hl, de
	ld a, (hl)
	call print_dec_byte
	ld hl, erase_str
	call print_cstring
	
	pop bc
	pop hl
	pop de
	ret

setup:
; set port increment to 1
    ld a, (BASE_PORT2)
	add a, 2
	ld c, a
	ld a, 1
	out (c), a
	
	ld a, (BASE_PORT)
	add a, 2
	ld c, a
	ld a, 1
	out (c), a


; set videomode to 2c
	ld c, 0
	rst $30
	db $04
	
; previous port values are set to $fe, so initially thez will be printed out!
	ld hl, prev_port_values
	ld a, $fe
	ld b, 6
.fill_prev_port_values_loop
	ld (hl), a
	inc hl
	djnz .fill_prev_port_values_loop
	
; setup sprite
; pos
	ld hl, 128
	ld (actual_x), hl
	ld (actual_y), hl
	
; phase
; save P2 memory map
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_MEMORY_P2
	out (c), A
	inc c
	in a, (c)
	ld (p2_mem_store), a
	dec c

; set to 0. page
	ld a, REG_MEMORY_P2
	out (c), A
	inc c
	xor a
	out (c), a
	dec c

; copy phase data
	ld hl, sprite_arrow
	ld de, $8000
	ld bc, 63
	ldir

; map p2 back to original
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_MEMORY_P2
	out (c), A
	inc c
	ld a, (p2_mem_store)
	out (c), a
	dec c

	ld a, REG_SPRITE_PHASE
	out (c), a
	inc c
	xor a
	out (c), a
	dec c
	
	ld a, REG_SPRITE_ENABLE
	out (c), a
	inc c
	ld a, 1
	out (c), a
	dec c
	
	ld a, REG_SPRITE_COLORMODE
	out (c), a
	inc c
	xor a
	out (c), a
	dec c
	
; setup screen 
	ld hl, base_port_addr_str
	call print_cstring
	ld a, (BASE_PORT)
	call print_hex_byte
	call print_newline
	
	ld hl, header_str
	call print_cstring
	
	ld b, POSX_PLUS
	ld c, POSY_PLUS
	rst $30
	db $23
	ld a, '+'
	call print_char
	
	ld b, POSX_MINUS
	ld c, POSY_MINUS
	rst $30
	db $23
	ld a, '-'
	call print_char
	
; reroute interrupt to my_isr
	di
	ld a, ($003d)
	ld hl, ($003e)
	ld (orig_jump), A
	ld (orig_jump+1), hl
	
	ld hl, my_isr
	ld ($003e), hl
	ei
	
	ret
	
my_isr:
	push af
    ld a, $82
	out ($00), a
	push bc
	push de
	push hl
	ld a, (BASE_PORT2)
	ld c, a
	ld a, REG_USB_INIT
	out (c), a
	ld hl, actual_port_values
	ld b, 6
	inc c
.loop
	in a, (c)
	ld (hl), a
	inc hl
	djnz .loop
	dec c
	
	ld a, (actual_port_values)
	cp 1
	jp nz, .isr_done
	
	ld d, 0
	ld hl, (actual_x)
	ld a, (actual_port_values+2)
	or a
	jr z, .calc_y
	jp m, .sub_x
	ld e, a
	add hl, de
	ld (actual_x), hl
	ld de, 256+23
	xor a
	sbc hl, de
	jr c, .calc_y
	ld (actual_x), de
	jr .calc_y
.sub_x
	neg
	ld e, a
	xor a
	sbc hl, de
	ld (actual_x), hl
	jr nc, .gtzerox
	ld hl, 24
	ld (actual_x), hl
	jr .calc_y
.gtzerox
	ld de, 24
	xor a
	sbc hl, de
	jr nc, .calc_y
	ld (actual_x), de

.calc_y:
	ld d, 0
	ld hl, (actual_y)
	ld a, (actual_port_values+3)
	or a
	jp m, .sub_y
	jr z, .calc_done
	ld e, a
	add hl, de
	ld (actual_y), hl
	ld de, 240+20
	xor a
	sbc hl, de
	jr c, .calc_done
	ld (actual_y), de
	jr .calc_done
.sub_y
	neg
	ld e, a
	xor a
	sbc hl, de
	ld (actual_y), hl
	jr nc, .gtzeroy
	ld hl, 21
	ld (actual_y), hl
	jr .calc_done
.gtzeroy
	ld de, 21
	xor a
	sbc hl, de
	jr nc, .calc_done
	ld (actual_y), de

.calc_done
	ld hl, actual_x
	ld a, (BASE_PORT2)
	ld c, a
	ld a, 0
	out (c), a
	inc c
	ld a, (hl)
	out (c), a
	inc hl
	ld a, (hl)
	out (c), a
	dec c
	
	ld a, $20
	out (c), a
	inc c
	inc hl
	ld a, (hl)
	out (c), a
	inc hl
	ld a, (hl)
	out (c), a
	dec c

.isr_done
	pop hl
	pop de
	pop bc
    ld a, (BORDER_SHADOW)
	out ($00), a
	
	pop af

	jp orig_jump
	

	
teardown:
	ld a, (BASE_PORT)
	ld c, a
	
	ld a, REG_SPRITE_ENABLE
	out (c), a
	inc c
	xor a
	out (c), a
	dec c
	
	di
	ld hl, (orig_jump+1)
	ld ($003e), hl
	ei
	
	ld b, 1
	ld c, 7
	rst $30
	db $23
	
	ld a, ($0bE5)
	or a
	jr z, .done
	rst $30
	db $91
.done
	ret

print_cstring:       
	push bc
	push af
.print_cstring_loop:
	LD  a,(hl) 
	or	a
	JR  z,.cstring_done 
	ld 	c, a
	RST 30h 
	DB  $21 
	INC hl 
	JR  .print_cstring_loop
.cstring_done:
	pop af
	pop bc
	RET
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
	DB      $21
	RET
	
print_newline:
	ld hl, .newline
	call print_cstring
	ret
.newline
	dz "\r\n"
	
print_dec_byte:
        push bc
        push de
        push hl
		or a
		jp p, .positive_number
		push af
		ld c, '-'
		rst $30
		db $21
		pop af
		neg
.positive_number		
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


base_port_addr_str:
	dz "Base IO addr: "
header_str:
	dz "STAT   BTN     dX      dY      (dw)    SPD"
erase_str:
	db "   ", 0

border_on:
	db 137, 155, 153, 19, 19, 19, 24
	db 139,   4, 139, 19, 19, 19, 24
	db 138, 155, 154,  0

border_off:
	db  32,  32,  32, 19, 19, 19, 24
	db  32,   4,  32, 19, 19, 19, 24
	db  32,  32,  32,  0
	
	
sprite_arrow:
	db $ff,$ff,$80
	db $ff,$ff,$00
	db $c0,$06,$00
	db $c0,$0c,$00
	db $ce,$18,$00
	db $cc,$30,$00
	db $c8,$30,$00
	db $c0,$18,$00
	db $c0,$0c,$00
	db $c3,$06,$00
	db $c7,$83,$00
	db $cc,$c1,$80
	db $d8,$60,$c0
	db $f0,$30,$60
	db $e0,$18,$30
	db $c0,$0c,$18
	db $00,$06,$30
	db $00,$03,$60
	db $00,$01,$c0
	db $00,$00,$00
	db $00,$00,$00
			
BASE_PORT:
  db 00
BASE_PORT2:
  db 00
orig_jump:
  db 00, 00, 00
  
actual_port_values:
	ds 6
shadow_port_values:
	ds 6
prev_port_values:
	ds 6

actual_coords:
actual_x:
	dw 128
actual_y:
	dw 128

shadow_coords:
shadow_x:
	dw 0
shadow_y:
	dw 0

prev_coords:
prev_x:
	dw 0
prev_y:
	dw 0
p2_mem_store:
	db 0
prev_border_minus:
	db 0
prev_border_plus:

PROGRAM_END:  