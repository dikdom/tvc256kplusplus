REG_SPRITE_ENABLE_LOW equ $90
REG_SPRITE_ENABLE_HIGH equ $91

REG_SCREEN_VIDEOMODE equ $A0
REG_SCREEN_SCROLL_X equ $A5
REG_SCREEN_Y equ $A8
REG_MEMORY_P2 equ $B0
REG_FUNCTION_EXEC equ $C0
REG_FUNCTION_PARAM_START equ $C1
REG_FUNCTION_RESULT equ $C2
FUNC_MEMMOVE_FULL equ $0C

	org $19ef - $90
	include "cas-header.asm"
PROGRAM_START:
	include "basic-header.asm"
	org $1a00
	
	call set_base_port
	ld hl, -2
	ret nz

	ld hl, base_port_addr_str
	call print_cstring
	ld a, (BASE_PORT)
	call print_hex_byte
	call print_newline

	call setup
	
	ld hl, copy_image_str
	call print_cstring
  
	ld hl, $8000	; dest, page 6-7
	ld ($8000), hl
	ld a, 1
	ld ($8002), a
	ld hl, $8000	; source, page 2-3
	ld ($8003), hl
	xor a
	ld ($8005), a
	ld hl, 128*240	; len
	ld ($8006), hl
	ld ($8008), a
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, FUNC_MEMMOVE_FULL
	out (c), a
	call wait_for_func
	jp nz, quit_with_error
	push hl
	ld a, b
	call print_hex_byte
	pop hl
	call print_hex_word
	call print_newline
	
	ld hl, open_file_str
	call print_cstring
	call open_file
	jp nz, quit_with_error
	
	ld hl, loading_clown_str
	call print_cstring
	call read_bitmap
	jp nz, quit_with_error
	
	ld hl, close_file_str
	call print_cstring
	call close_file
	jp nz, quit_with_error
	
	
	call copy_clown_head
	
	xor a
	ld ($8004), a

	ld hl, bounce
	ld ($003e), hl

.loop1
	ld a, ($0bE5)
	or a
	jr z, .loop1
	
	rst $30
	db $91
	
	di
	ld a, 14
	out ($70), a
	ld a, 5
	out ($71), a
	ei
	
.loop2
	ld a, ($0bE5)
	or a
	jr z, .loop2
	
	rst $30
	db $91
	
	di
	ld a, 14
	out ($70), a
	ld a, 14
	out ($71), a
	ei
	
	

	ld hl, (irq_jump+1)
	ld ($003e), hl
  
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_SCREEN_VIDEOMODE
	out (c), a
	inc c
	xor a
	out (c), a
	ld hl, 0
	ret

base_port_addr_str:
	dz "Base IO addr: "
copy_image_str:
	dz "Backing up image to buffer...\r\n"
open_file_str:
	dz "Opening file...\r\n"
loading_clown_str:
	dz "Loading clown head...\r\n"
close_file_str:
	dz "Closing file...\r\n"
quit_with_error:
	push af
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_SCREEN_VIDEOMODE
	out (c), a
	inc c
	xor a
	out (c), a
	pop af
	call print_hex_byte
	call print_newline
	di
	ld hl, (irq_jump+1)
	ld ($003e), hl
	ei
	
	ld hl, -1
	ret

setup:
    ld a, (BASE_PORT)
	ld c, a
	
	; port increment set to 0
	inc c
	inc c
	xor a
	out (c), a
	dec c
	dec c
	
	; parameter is read from $8000
	ld a, REG_FUNCTION_PARAM_START
	out (c), a
	xor a
	inc c
	out (c), a
	dec c
	
	; memory mapping set to page 4 -> 8000-bfff
	ld a, REG_MEMORY_P2
	out (c), a
	inc c
	ld a, 4
	out (c), a
	dec c
	
	; set screen to gfx
	ld a, REG_SCREEN_VIDEOMODE
	out (c), a
	ld a, 3
	inc c
	out (c), a
	dec c
	
	; hide sprites
	ld a, REG_SPRITE_ENABLE_LOW
	out (c), a
	xor a
	inc c
	out (c), a
	dec c
	
	ld a, REG_SPRITE_ENABLE_HIGH
	out (c), a
	xor a
	inc c
	out (c), a
	dec c
	
	ld hl, ($003e)
	ld (irq_jump+1), hl
	
	ret


set_base_port:
	rst $30
	db $5D
	ld a, c
	LD (BASE_PORT),A
	cp $FF
	jr z, .no_id_found
	xor a
	ret
.no_id_found
	ld hl, .no_id_found_str
	call print_cstring
	call print_newline
	xor a
	inc a
	ret

.no_id_found_str:
  dz "TVC 256k++ not found!"  

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
	
wait_for_func:
	push bc
	ld b, 5
	ld hl, $0000
.wait_for_func_loop
	in a, (c)
	cp $ff
	jr z, .done_waiting
	dec hl
	ld a, h
	or l
	jr nz, .wait_for_func_loop
	djnz .wait_for_func_loop
	xor a
	dec a
	pop bc
	dec c
	ret
.done_waiting
	dec c
	ld a, REG_FUNCTION_RESULT
	out (C), a
	inc c
	in a, (c)
	pop bc
	dec c
	or a
	ret
			
BASE_PORT:
  db 00
	include "load-bitmap.asm"

copy_clown_head:
	ld b, 100
	ld hl, $4000	; dest, page 5
	ld ($8000), hl
	ld a, 1
	ld ($8002), a
	ld hl, $8000	; source, page 2-3
	ld ($8003), hl
	xor a
	ld ($8005), a
	ld hl, 50	; len
	ld ($8006), hl
	ld ($8008), a

.loop_copy
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, FUNC_MEMMOVE_FULL
	out (c), a
	call wait_for_func
	jp nz, quit_with_error
	
	ld hl, ($8000)
	ld de, 50
	add hl, de
	ld ($8000), hl
	ld hl, ($8003)
	ld de, 128
	add hl, de
	ld ($8003), hl
	djnz .loop_copy
	ret


setup_back_copy_params:
	ld a, 100
	ld ($8004), a	; width of clown
	ld ($8005), a	; height of clown
	ld hl, ($8000)
	ld ($8006), hl
	ld hl, ($8002)
	ld ($8008), hl
	ld hl, 256
	ld ($800a), hl
	ld hl, 240
	ld ($800c), hl
	ld hl, $8000
	ld ($800e), hl
	ld a, 1
	ld ($8010), a
	dec a
	ld ($8011), a
	ret
	
setup_clown_copy_params:
	ld a, 100
	ld ($8004), a	; width of clown
	ld ($8005), a	; height of clown
	ld hl, $4000
	ld ($8006), hl
	ld a, 1
	ld ($8008), a
	ret
	
setup_fullscreen_copy:
	ld hl, $8000
	ld ($8000), hl
	ld ($8003), hl
	ld ($8006), hl
	xor a
	ld ($8002), a
	ld ($8008), a
	inc a
	ld ($8005), a
	ret
	
bounce:
	ld a, $88
	out ($00), a
	push hl
	push bc
	push de
	
;	ld a, ($8004)
;	cp 100
;	jr nz, .back_ok
;	call setup_back_copy_params
;	ld a, $a0
;	out ($00), a
	
;	ld a, (BASE_PORT)
;	ld c, a
;	ld a, REG_FUNCTION_EXEC
;	out (c), a
;	inc c
;	ld a, 33
;	out (c), a
;	CALL wait_for_func

	call setup_fullscreen_copy
	ld a, $a2
	out ($00), a

	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, FUNC_MEMMOVE_FULL
	out (c), a
	CALL wait_for_func
	
	
.back_ok
	ld a, $88
	out ($00), a
	call setup_clown_copy_params
	call fill_coords
	ld a, $82
	out ($00), a
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, 32
	out (c), a
	CALL wait_for_func
	
	pop de
	pop bc
	pop hl
	jp irq_jump


fill_coords:
	ld hl, xpos
	inc (hl)
.inc_x
	ld a, (xpos)
	ld l, a
	ld h, 0
	add hl, hl
	ex de, hl
	ld hl, xcrds
	add hl, de
	ld e, (hl)
	inc hl
	ld d, (hl)
	ld hl, $8000
	xor a
	sbc hl, de
	jr nz, .x_ok
	xor a
	ld (xpos), a
	jr .inc_x
.x_ok
	ld ($8000), de

	ld hl, ypos
	inc (hl)
.inc_y
	ld a, (ypos)
	ld l, a
	ld h, 0
	add hl, hl
	ex de, hl
	ld hl, ycrds
	add hl, de
	ld e, (hl)
	inc hl
	ld d, (hl)
	ld hl, $8000
	xor a
	sbc hl, de
	jr nz, .y_ok
	xor a
	ld (ypos), a
	jr .inc_y
.y_ok
	ld ($8002), de
	ret

irq_jump:
	jp $0000
	
xpos:
	db 0
ypos:
	db 0

xcrds:
	dw 50 , 55 , 61 , 66 , 71 , 76 , 81 , 87 , 92 , 97 , 101 , 106 , 111 , 116 , 120 , 124 , 129 , 133 , 137 , 141 , 144 , 148 , 151 , 154 , 157 , 160 , 163 , 165 , 167 , 169 , 171 , 173 , 174 , 175 , 176 , 177 , 178 , 178 , 178 , 178 , 178 , 177 , 176 , 175 , 174 , 173 , 171 , 169 , 167 , 165 , 163 , 160 , 157 , 154 , 151 , 148 , 144 , 141 , 137 , 133 , 129 , 124 , 120 , 116 , 111 , 106 , 101 , 97 , 92 , 87 , 81 , 76 , 71 , 66 , 61 , 55 , 50 , 45 , 39 , 34 , 29 , 24 , 19 , 13 , 8 , 3 , -1 , -6 , -11 , -16 , -20 , -24 , -29 , -33 , -37 , -41 , -44 , -48 , -51 , -54 , -57 , -60 , -63 , -65 , -67 , -69 , -71 , -73 , -74 , -75 , -76 , -77 , -78 , -78 , -78 , -78 , -78 , -77 , -76 , -75 , -74 , -73 , -71 , -69 , -67 , -65 , -63 , -60 , -57 , -54 , -51 , -48 , -44 , -41 , -37 , -33 , -29 , -24 , -20 , -16 , -11 , -6 , -1 , 3 , 8 , 13 , 19 , 24 , 29 , 34 , 39 , 45
	dw $8000
ycrds:
	dw 50 , 55 , 59 , 64 , 68 , 73 , 77 , 81 , 86 , 90 , 94 , 99 , 103 , 107 , 111 , 115 , 118 , 122 , 126 , 129 , 132 , 136 , 139 , 142 , 145 , 147 , 150 , 152 , 155 , 157 , 159 , 161 , 162 , 164 , 165 , 166 , 167 , 168 , 169 , 169 , 170 , 170 , 170 , 170 , 169 , 169 , 168 , 167 , 166 , 165 , 164 , 162 , 161 , 159 , 157 , 155 , 152 , 150 , 147 , 145 , 142 , 139 , 136 , 132 , 129 , 126 , 122 , 118 , 115 , 111 , 107 , 103 , 99 , 94 , 90 , 86 , 81 , 77 , 73 , 68 , 64 , 59 , 55 , 50 , 45 , 41 , 36 , 32 , 27 , 23 , 19 , 14 , 10 , 6 , 1 , -3 , -7 , -11 , -15 , -18 , -22 , -26 , -29 , -32 , -36 , -39 , -42 , -45 , -47 , -50 , -52 , -55 , -57 , -59 , -61 , -62 , -64 , -65 , -66 , -67 , -68 , -69 , -69 , -70 , -70 , -70 , -70 , -69 , -69 , -68 , -67 , -66 , -65 , -64 , -62 , -61 , -59 , -57 , -55 , -52 , -50 , -47 , -45 , -42 , -39 , -36 , -32 , -29 , -26 , -22 , -18 , -15 , -11 , -7 , -3 , 1 , 6 , 10 , 14 , 19 , 23 , 27 , 32 , 36 , 41 , 45
	dw $8000

PROGRAM_END:  