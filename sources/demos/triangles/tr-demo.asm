REG_SPRITE_ENABLE_LOW equ $90
REG_SPRITE_ENABLE_HIGH equ $91
REG_SPRITE_FOREGROUND_LOW equ $92
REG_SPRITE_FOREGROUND_HIGH equ $93

REG_SCREEN_VIDEOMODE equ $A0
REG_SCREEN_BITMAP_BASEADDR equ $A4
REG_SCREEN_Y equ $A8
REG_MEMORY_P2 equ $B0
REG_FUNCTION_EXEC equ $C0
REG_FUNCTION_PARAM_START equ $C1
REG_FUNCTION_RESULT equ $C2
REG_FUNCTION_MULTIEXEC equ $C6
REG_FUNCTION_BITMAP_BASE equ $C7

OP_ADD equ $01
OP_SUB equ $02
OP_MUL equ $03
OP_DIV equ $04
OP_SIN equ $0a
OP_COS equ $0b
OP_ROUND equ $0f

T_UINT8 equ $40
T_INT16 equ $41
T_INT32 equ $42
T_TVCFLOAT equ $43
T_FLOAT equ $44
T_VARREF equ $45

CONST_2PI equ $80
CONST_0_001 equ $83

FUNC_CLEAR_BITMAP equ $01
FUNC_MEMMOVE_SHORT equ $0b
FUNC_SET_PEN_COLOR equ $16
FUNC_EVAL_ME equ $25 ; 37 dec - evaluate mathematical expression
FUNC_DRAW_TRI equ $26 ; 38 dec - draw triangle

ADDR_FUNC_EXEC equ $8000
ADDR_EVAL_MATH equ $8200
ADDR_DRAW_TRIS equ $8400
ADDR_VAR_I equ $81F0

BORDER equ $0B4F

COUNTER_RESET equ 8

MEMPAGE2 equ 8


	org $19ef - $90
	include "cas-header.asm"
PROGRAM_START:
	include "basic-header.asm"
	org $1a00

	call set_base_port
	ret nz

	ld hl, base_port_addr_str
	call print_cstring
	ld a, (BASE_PORT)
	call print_hex_byte
	call print_newline

	call setup

.loop
	rst $30
	db $93
	ld a, c
	cp $ff
	jr nz, .loop
	
	rst $30
	db $91

	call teardown
	
	ld hl, 0
	ret

base_port_addr_str:
	dz "Base IO addr: "

quit_with_error:
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_SCREEN_VIDEOMODE
	out (c), a
	inc c
	xor a
	out (c), a
	ld hl, -1
	ret

teardown:
	di
	ld hl, (MY_IRQ.jump_out+1)
	ld ($003e), hl
	
	ld a, 14
	out ($70), a
	ld a, 14
	out ($71), a
	ei

	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_SCREEN_VIDEOMODE
	out (c), a
	inc c
	xor a
	out (c), a
	dec c
	
	ld a, REG_MEMORY_P2
	out (c), a
	inc c
	ld a, (ORIG_MEMPAGE)
	out (c), a
	dec c
	
	ld a, REG_FUNCTION_BITMAP_BASE
	out (c), a
	inc c
	ld a, $FF
	out (c), a
	dec c
	
	ld a, REG_SCREEN_BITMAP_BASEADDR
	out (c), a
	inc c
	ld a, $01
	out (c), a
	dec c

	
	xor a
	ld a, ($BC00)
	ld hl, $BC00
	ld de, $BC01
	ld bc, $03FF
	ldir
	
	ret

setup:
	; port increment set to 0 for IRQs
	ld a, (BASE_PORT)
	add a, 6
	ld c, a
	xor a
	out (c), a
	

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
	in a, (c)
	ld (ORIG_MEMPAGE), a
	ld a, MEMPAGE2
	out (c), a
	dec c
	
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc C
	ld a, FUNC_CLEAR_BITMAP
	out (c), a
	call wait_for_func_finish
	
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, 15
	ld ($8000), a
	ld a, FUNC_SET_PEN_COLOR
	out (c), a
	call wait_for_func_finish
	
	; set screen to gfx
	ld a, REG_SCREEN_VIDEOMODE
	out (c), a
	ld a, 3
	inc c
	out (c), a
	dec c
	
	; hide sprites
;	ld a, REG_SPRITE_ENABLE_LOW
;	out (c), a
;	xor a
;	inc c
;	out (c), a
;	dec c
	
;	ld a, REG_SPRITE_ENABLE_HIGH
;	out (c), a
;	xor a
;	inc c
;	out (c), a
;	dec c
	
;	ld a, REG_SPRITE_FOREGROUND_LOW
;	out (c), a
;	ld a, $ff
;	inc c
;	out (c), a
;	dec c
	
;	ld a, REG_SPRITE_FOREGROUND_HIGH
;	out (c), a
;	ld a, $ff
;	inc c
;	out (c), a
;	dec c

	
	
	ld hl, CALCXY
	ld de, ADDR_EVAL_MATH
	ld bc, CALCXY_END - CALCXY
	ldir
	
	ld hl, DRAW_TRI
	ld de, ADDR_DRAW_TRIS
	ld bc, DRAW_TRI_END - DRAW_TRI
	ldir
	
	ld hl, FUNC_EXEC
	ld de, ADDR_FUNC_EXEC
	ld bc, FUNC_EXEC_END - FUNC_EXEC
	ldir

	ld a, T_INT16
	ld (ADDR_VAR_I), a
	ld hl, 0
	ld (ADDR_VAR_I + 1), hl
	
	ld hl, COLORS
	ld (COLOR_P), hl
	
	ld a, COUNTER_RESET
	ld (COUNTER), a
	
	di
	ld a, 14
	out ($70), a
	ld a, 4
	out ($71), a
	
	ld a, 1
	ld (IRQ_NUM), a
	ld a, 0
	ld (TARGET_BITMAP), a

	
	ld hl, ($003e)
	ld (MY_IRQ.jump_out + 1), hl
	ld hl, MY_IRQ
	ld ($003e), hl
	ei
	
	ret
	
id_string:
  db 6, "256k++"
set_base_port:
	ld hl, $0040
.find_loop
	push hl
	ld de, id_string
	ld b, 7

	call .cmp_loop
	pop hl
	jr z, .id_found
	ld de, $0030
	add hl, de
	ld a, $01
	cp h
	jr nz, .find_loop
	ld hl, .no_id_found_str
	call print_cstring
	xor a
	inc a
	ret

.id_found:
	LD      A,L
	SUB     $10 
	AND     $C0 ; 0x00, 0x40, 0x80, 0xc0
	RRCA     
	RRCA     ; 0x00, 0x10, 0x20, 0x30
	ADD     A,$10
	LD      (BASE_PORT),A
	xor a
	ret
  
.cmp_loop:	
	ld a, (de)
	cp (hl)
	ret nz
	inc hl
	inc de
	djnz .cmp_loop
	xor a
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
	
wait_for_func_finish:
	ld b, 5
.check_exec_status
	ld hl, $a000
.wait_loop:
	in a, (c)
	cp $FF
	jr z, .check_result
	dec hl
	ld a, h
	or l
	jr nz, .wait_loop
	djnz .check_exec_status
	ld hl, .operation_timed_out_str
	call print_cstring
	xor a
	inc a
	ret
.check_result:
    dec c
	ld a, REG_FUNCTION_RESULT
	out (c), a
	inc c
	in a, (c)
	dec c
	or a
	ret z
	push af
	ld hl, .failed_operation_str
	call print_cstring
	pop af
	call print_hex_byte
	ld a, 1
	or a
	ret

.operation_timed_out_str:
	dz "Operation timed out!"
.failed_operation_str:
	dz "Failed operation, error code: "
	
TARGET_BITMAP:
	db 0
	
MY_IRQ:
	ld a, $82
	out ($00), a
	
	push hl
	push de
	push bc
	
	ld hl, IRQ_NUM
	ld a, 1
	sub (hl)
	ld (hl), a
	jr nz, .do_the_calc
	
	ld hl, TARGET_BITMAP
	ld a, (BASE_PORT)
	add 4
	ld c, a
	ld a, REG_FUNCTION_BITMAP_BASE
	out (c), a
	inc c
	ld a, (hl)
	add 2
	out (c), a
	dec c
	ld a, REG_SCREEN_BITMAP_BASEADDR
	out (c), a
	inc c
	ld a, 1
	sub (hl)
	ld (hl), a
	add 2
	out (c), a
	
	ld a, 14
	out ($70), a
	ld a, 4
	out ($71), a
	
	pop bc
	pop de
	pop hl
.jump_out
	jp $0000

	
	
.do_the_calc
	

; calculate the new xy coords
	ld a, $A0
	out ($00), a

	ld hl, (ADDR_VAR_I + 1)
	inc hl
	ld (ADDR_VAR_I + 1), hl
	
	
	ld hl, ADDR_EVAL_MATH - $8000
	ld (ADDR_FUNC_EXEC + (FE_SRC_ADDR - FUNC_EXEC) ), hl
	
	ld a, (BASE_PORT)
	add 4
	ld c, a
	ld a, REG_FUNCTION_MULTIEXEC
	out (c), a
	inc c
	ld a, 19
	out (c), a
	call wait_for_func_finish
	
; copy calculated xy coords
	ld a, $88
	out ($00), a
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + 0 * (CXY_1FUNC_END - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY_SOURCES - DRAW_TRI) + 0 * 2), hl
		
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + 1 * (CXY_1FUNC_END - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY_SOURCES - DRAW_TRI) + 1 * 2), hl
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + 2 * (CXY_1FUNC_END - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY_SOURCES - DRAW_TRI) + 2 * 2), hl
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + 3 * (CXY_1FUNC_END - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY_SOURCES - DRAW_TRI) + 3 * 2), hl
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + 4 * (CXY_1FUNC_END - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY_SOURCES - DRAW_TRI) + 4 * 2), hl
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + 5 * (CXY_1FUNC_END - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY_SOURCES - DRAW_TRI) + 5 * 2), hl
	
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + (TRIX10 - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY1 - DRAW_TRI) + 0 * 2), hl
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + (TRIY10 - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY1 - DRAW_TRI) + 1 * 2), hl
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + (TRIX11 - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY1 - DRAW_TRI) + 2 * 2), hl
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + (TRIY11 - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY1 - DRAW_TRI) + 3 * 2), hl
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + (TRIX12 - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY1 - DRAW_TRI) + 4 * 2), hl
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + (TRIY12 - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY1 - DRAW_TRI) + 5 * 2), hl
	
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + (TRIX20 - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY2 - DRAW_TRI) + 0 * 2), hl
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + (TRIY20 - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY2 - DRAW_TRI) + 1 * 2), hl
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + (TRIX21 - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY2 - DRAW_TRI) + 2 * 2), hl
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + (TRIY21 - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY2 - DRAW_TRI) + 3 * 2), hl
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + (TRIX22 - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY2 - DRAW_TRI) + 4 * 2), hl
	
	ld hl, (ADDR_FUNC_EXEC + (FUNC_EXEC_END - FUNC_EXEC) + 2 + (TRIY22 - CALCXY) )
	ld (ADDR_DRAW_TRIS + (DT_XY2 - DRAW_TRI) + 5 * 2), hl
	
	
	ld hl, COUNTER
	dec (hl)
	jr nz, .skip_color_scroll

	ld a, COUNTER_RESET
	ld (COUNTER), a
	
	ld hl, (COLOR_P)
	ld a, (hl)
	or a
	jr nz, .color_ok
	ld hl, COLORS
	ld a, (hl)
.color_ok
	inc hl
	ld (COLOR_P), hl
	ld (ADDR_DRAW_TRIS + (DT_COLOR - DRAW_TRI) ), a
	ld (ADDR_DRAW_TRIS + (DT_COLOR1 - DRAW_TRI) ), a
	ld (ADDR_DRAW_TRIS + (DT_COLOR2 - DRAW_TRI) ), a
	

.skip_color_scroll

; draw triangle
	ld a, $20
	out ($00), a

	ld hl, ADDR_DRAW_TRIS - $8000
	ld (ADDR_FUNC_EXEC + (FE_SRC_ADDR - FUNC_EXEC) ), hl
	
	ld a, REG_FUNCTION_MULTIEXEC
	out (c), a
	inc c
	ld a, 6
	out (c), a
	call wait_for_func_finish
	
.end_my_irq
	ld a, $82
	out ($00), a

	ld a, 14
	out ($70), a
	ld a, 14
	out ($71), a
	ld a, (BORDER)

	pop bc
	pop de
	pop hl
	out ($00), a
	pop af

	out ($07), a
	ei
	ret
	
XAMPL equ 20
YAMPL equ 20

X0 EQU 128
Y0 EQU 20
X1 EQU 30
Y1 EQU 220
X2 EQU 230
Y2 EQU 200

X10 equ 30
Y10 equ 30
R1  equ 35
RSPEED1 equ 45

X20 equ 220
Y20 equ 30
R2  equ 25
RSPEED2 equ 35



CALCXY:	; (6)
; x0  x0 .001 11 * VR * SIN 20 * + ROUND
	db FUNC_EVAL_ME, T_UINT8, X0, CONST_0_001, T_UINT8, 11, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, OP_SIN, T_UINT8, XAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
;	db FUNC_EVAL_ME, T_UINT8, X0, CONST_0_001, T_UINT8, 11, OP_MUL, T_INT16, 0, 0, OP_MUL, OP_SIN, T_UINT8, XAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
;	db FUNC_EVAL_ME, T_UINT8, X0, CONST_2PI, CONST_0_001, OP_MUL, T_UINT8, 11, OP_MUL, T_UINT8, 5, OP_MUL, OP_SIN, T_UINT8, XAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
CXY_1FUNC_END	
; y0
	db FUNC_EVAL_ME, T_UINT8, Y0, CONST_0_001, T_UINT8, 37, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, OP_COS, T_UINT8, YAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
;	db FUNC_EVAL_ME, T_UINT8, Y0, CONST_0_001, T_UINT8, 37, OP_MUL, T_INT16, 0, 0, OP_MUL, OP_COS, T_UINT8, YAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
;	db FUNC_EVAL_ME, T_UINT8, Y0, CONST_2PI, CONST_0_001, OP_MUL, T_UINT8, 37, OP_MUL, T_UINT8, 5, OP_MUL, OP_COS, T_UINT8, YAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
; x1
	db FUNC_EVAL_ME, T_UINT8, X1, CONST_0_001, T_UINT8, 31, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, OP_SIN, T_UINT8, XAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
;	db FUNC_EVAL_ME, T_UINT8, X1, CONST_0_001, T_UINT8, 31, OP_MUL, T_INT16, 0, 0, OP_MUL, OP_SIN, T_UINT8, XAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
;	db FUNC_EVAL_ME, T_UINT8, X1, CONST_2PI, CONST_0_001, OP_MUL, T_UINT8, 31, OP_MUL, T_UINT8, 5, OP_MUL, OP_SIN, T_UINT8, XAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
; y1
	db FUNC_EVAL_ME, T_UINT8, Y1, CONST_0_001, T_UINT8, 23, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, OP_COS, T_UINT8, YAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
;	db FUNC_EVAL_ME, T_UINT8, Y1, CONST_0_001, T_UINT8, 23, OP_MUL, T_INT16, 0, 0, OP_MUL, OP_COS, T_UINT8, YAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
;	db FUNC_EVAL_ME, T_UINT8, Y1, CONST_2PI, CONST_0_001, OP_MUL, T_UINT8, 23, OP_MUL, T_UINT8, 5, OP_MUL, OP_COS, T_UINT8, YAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
; x2
	db FUNC_EVAL_ME, T_UINT8, X2, CONST_0_001, T_UINT8, 17, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, OP_SIN, T_UINT8, XAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
;	db FUNC_EVAL_ME, T_UINT8, X2, CONST_0_001, T_UINT8, 17, OP_MUL, T_INT16, 0, 0, OP_MUL, OP_SIN, T_UINT8, XAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
;	db FUNC_EVAL_ME, T_UINT8, X2, CONST_2PI, CONST_0_001, OP_MUL, T_UINT8, 17, OP_MUL, T_UINT8, 5, OP_MUL, OP_SIN, T_UINT8, XAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
; y2
	db FUNC_EVAL_ME, T_UINT8, Y2, CONST_0_001, T_UINT8, 29, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, OP_COS, T_UINT8, YAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
;	db FUNC_EVAL_ME, T_UINT8, Y2, CONST_0_001, T_UINT8, 29, OP_MUL, T_INT16, 0, 0, OP_MUL, OP_COS, T_UINT8, YAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
;	db FUNC_EVAL_ME, T_UINT8, Y2, CONST_2PI, CONST_0_001, OP_MUL, T_UINT8, 29, OP_MUL, T_UINT8, 5, OP_MUL, OP_COS, T_UINT8, YAMPL, OP_MUL, OP_ADD, OP_ROUND, 0
; x01
TRIX10
	db FUNC_EVAL_ME, T_UINT8, X10, CONST_0_001, T_UINT8, RSPEED1, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, OP_SIN, T_UINT8, R1, OP_MUL, OP_ADD, OP_ROUND, 0
; y01	
TRIY10
	db FUNC_EVAL_ME, T_UINT8, Y10, CONST_0_001, T_UINT8, RSPEED1, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, OP_COS, T_UINT8, R1, OP_MUL, OP_ADD, OP_ROUND, 0
; x11
TRIX11
	db FUNC_EVAL_ME, T_UINT8, X10, CONST_0_001, T_UINT8, RSPEED1, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, CONST_2PI, T_UINT8, 3, OP_DIV, OP_ADD, OP_SIN, T_UINT8, R1, OP_MUL, OP_ADD, OP_ROUND, 0
; y11
TRIY11	
	db FUNC_EVAL_ME, T_UINT8, Y10, CONST_0_001, T_UINT8, RSPEED1, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, CONST_2PI, T_UINT8, 3, OP_DIV, OP_ADD, OP_COS, T_UINT8, R1, OP_MUL, OP_ADD, OP_ROUND, 0
; x21
TRIX12	
	db FUNC_EVAL_ME, T_UINT8, X10, CONST_0_001, T_UINT8, RSPEED1, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, CONST_2PI, T_UINT8, 2, OP_MUL, T_UINT8, 3, OP_DIV, OP_ADD, OP_SIN, T_UINT8, R1, OP_MUL, OP_ADD, OP_ROUND, 0
; y21	
TRIY12
	db FUNC_EVAL_ME, T_UINT8, Y10, CONST_0_001, T_UINT8, RSPEED1, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, CONST_2PI, T_UINT8, 2, OP_MUL, T_UINT8, 3, OP_DIV, OP_ADD, OP_COS, T_UINT8, R1, OP_MUL, OP_ADD, OP_ROUND, 0
	
TRIX20
	db FUNC_EVAL_ME, T_UINT8, X20, CONST_0_001, T_UINT8, RSPEED2, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, OP_SIN, T_UINT8, R2, OP_MUL, OP_ADD, OP_ROUND, 0
; y01	
TRIY20
	db FUNC_EVAL_ME, T_UINT8, Y20, CONST_0_001, T_UINT8, RSPEED2, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, OP_COS, T_UINT8, R2, OP_MUL, OP_ADD, OP_ROUND, 0
; x11
TRIX21
	db FUNC_EVAL_ME, T_UINT8, X20, CONST_0_001, T_UINT8, RSPEED2, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, CONST_2PI, T_UINT8, 3, OP_DIV, OP_ADD, OP_SIN, T_UINT8, R2, OP_MUL, OP_ADD, OP_ROUND, 0
; y11
TRIY21	
	db FUNC_EVAL_ME, T_UINT8, Y20, CONST_0_001, T_UINT8, RSPEED2, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, CONST_2PI, T_UINT8, 3, OP_DIV, OP_ADD, OP_COS, T_UINT8, R2, OP_MUL, OP_ADD, OP_ROUND, 0
; x21
TRIX22	
	db FUNC_EVAL_ME, T_UINT8, X20, CONST_0_001, T_UINT8, RSPEED2, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, CONST_2PI, T_UINT8, 2, OP_MUL, T_UINT8, 3, OP_DIV, OP_ADD, OP_SIN, T_UINT8, R2, OP_MUL, OP_ADD, OP_ROUND, 0
; y21	
TRIY22
	db FUNC_EVAL_ME, T_UINT8, Y20, CONST_0_001, T_UINT8, RSPEED2, OP_MUL, T_VARREF, LOW ADDR_VAR_I, ( HIGH ADDR_VAR_I ) - $80, MEMPAGE2 / 4, OP_MUL, CONST_2PI, T_UINT8, 2, OP_MUL, T_UINT8, 3, OP_DIV, OP_ADD, OP_COS, T_UINT8, R2, OP_MUL, OP_ADD, OP_ROUND, 0	

	
CALCXY_END

DRAW_TRI: ; (4)
	db FUNC_CLEAR_BITMAP
DT_XY_TARGETS
	db FUNC_SET_PEN_COLOR
	db $0f
	db FUNC_DRAW_TRI
DT_XY_SOURCES
	dw 0, 0, 0, 0, 0, 0
DT_COLOR
	db $ff
	db FUNC_DRAW_TRI
DT_XY1
	dw 0, 0, 0, 0, 0, 0
DT_COLOR1
	db $f2
	db FUNC_DRAW_TRI
DT_XY2
	dw 0, 0, 0, 0, 0, 0
DT_COLOR2
	db $f2
DRAW_TRI_END
	

FUNC_EXEC:
;	   Memmove_short, page:4, dest:$0008
	DB FUNC_MEMMOVE_SHORT, MEMPAGE2,  8, 0
FE_SRC_ADDR
	DB 0, $02
FE_SIZE
	DB LOW (CALCXY_END - CALCXY), HIGH (CALCXY_END - CALCXY)
FUNC_EXEC_END

COLORS:
	db $81, $11, $19, $99, $9F, $FF, $F9, $99, $91, $11, $18, $88
	db $82, $22, $2a, $aa, $aF, $ff, $fa, $aa, $a2, $22, $28, $88
	db $84, $44, $4C, $cc, $CF, $ff, $fc, $cc, $c4, $44, $48, $88
	db $83, $33, $3b, $bb, $bf, $ff, $fb, $bb, $b3, $33, $38, $88
	db $00

COLOR_P
	dw 00
	
COUNTER
	db 00
	
BASE_PORT:
  db 00
  
IRQ_NUM
  db 1
  
ORIG_MEMPAGE
  db 00

PROGRAM_END:
