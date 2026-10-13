TVC_FUNC_SET_PWD   equ $56
TVC_FUNC_GET_PWD   equ $D6
TVC_FUNC_OPEN_DIR  equ $D7
TVC_FUNC_READ_DIR  equ $D8
TVC_FUNC_CLOSE_DIR equ $58
TVC_FUNC_MNT_DSK   equ $DF
TVC_FUNC_UMNT_DSK  equ $5F

REG_SPRITE0_X equ $00
REG_SPRITE0_Y equ $20

REG_SPRITE0_COLOR equ $40
REG_SPRITE0_PHASE equ $50

REG_SPRITE_ENABLE_LOW equ $90
REG_SPRITE_ENABLE_HIGH equ $91
REG_SPRITE_FOREGROUND_LOW equ $92
REG_SPRITE_COLORMODE_LOW equ $94

REG_SCREEN_VIDEOMODE equ $A0
REG_SCREEN_SCROLL_X equ $A5
REG_SCREEN_SCROLL_Y equ $A5
REG_SCREEN_Y equ $A8
REG_MEMORY_P2 equ $B0
REG_MEMORY_P3 equ $B1

REG_FUNCTION_EXEC equ $C0
REG_FUNCTION_PARAM_START equ $C1
REG_FUNCTION_RESULT equ $C2
REG_FW_VERSION_MAJOR equ $C3
REG_FW_VERSION_MINOR equ $C4
REG_DRIVE_SELECT equ $C5
REG_FUNCTION_MULTI_EXECUTE equ $C6
REG_DRIVE_PSRAM_VALID equ $C8
REG_DRIVE_FLASH_VALID equ $C9
REG_DRIVE_DSK_VALID equ $CA
REG_USB_INIT equ $D0
REG_VSID_BASE equ $E0


FUNC_CLEAR_TEXT_SCREEN equ $00
FUNC_CLEAR_BITMAP_SCREEN equ $01
FUNC_PRINT_CHAR_SCREEN_CODE equ $02
FUNC_PRINT_HEX_BYTE equ $03
FUNC_PRINT_HEX_WORD equ $04
FUNC_PRINT_STRING_SCREEN_CODE equ $05
FUNC_PRINT_STRING_ASCII equ $06
FUNC_SET_TEXT_COLOR equ $08
FUNC_SET_XY equ $0a
FUNC_LOAD_DIR_TO_PSRAM equ $0f
FUNC_OPEN_FILE equ $80+1
FUNC_CLOSE_FILE equ $80+2
FUNC_READ_FILE equ $80+3
FUNC_FILE_READ_DEST equ $80+9
FUNC_FILE_SEEK equ $80+10

WORK_PAGE_P2 equ $0e
WORK_PAGE_P3 equ $0f


CURSOR_MOVE_RIGHT equ $04
CURSOR_MOVE_LEFT  equ $13
CURSOR_MOVE_DOWN  equ $18
CURSOR_MOVE_UP    equ $05

P_SAVE equ $0003
BORDER equ $0b4f
PARAM_BASE_ADDR equ $FD00
PARAM_BASE_ADDR_IRQ equ $FC00

	org $19ef - $90
	include "cas-header.asm"
PROGRAM_START:
	include "basic-header.asm"
	org $1a00
	
	call set_base_port
	ld hl, -2
	ret nz
	
	call check_fw_version
	ld hl, -3
	ret nz
	
	call set_fw_version_in_creds
	
	call setup
	call print_legend
	call load_directory
	ld hl, 20*256 + 29
	call animate_box
	call print_filelist_box_header
	call print_file_list
	call keyboard_start_loop
	call teardown
	ld hl, 0
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
	
	; memory mapping set to page 14 -> 8000-bfff
	ld a, REG_MEMORY_P2
	out (c), a
	inc c
	in a, (c)
	ld (P2_STORAGE), a	 ; but store first for teardown
	ld a, WORK_PAGE_P2   ; let's set something extraordinary fastRAM page
	out (c), a
	dec c
	
	ld a, REG_MEMORY_P3
	out (c), a
	inc c
	in a, (c)
	ld (P3_STORAGE), a	; but store first for teardown
	ld a, WORK_PAGE_P3
	out (c), a
	dec c

	; parameter is read from $FD00 (FA means params are on U3 + 3D00 => FD00)
	ld a, REG_FUNCTION_PARAM_START
	out (c), a
	ld a, $FA
	inc c
	out (c), a
	dec c
	
	call di_and_page
	
	ld a, $0f
	ld (PARAM_BASE_ADDR), a
	ld a, REG_FUNCTION_EXEC
	out (c), a
	ld a, FUNC_SET_TEXT_COLOR
	inc c
	out (c), a

	call wait_for_func
	
	call ei_and_page
	
	
	ld a, REG_FUNCTION_EXEC
	out (c), a
	ld a, FUNC_CLEAR_TEXT_SCREEN
	inc c
	out (c), a
	dec c

	; set screen to 2c text
	ld a, REG_SCREEN_VIDEOMODE
	out (c), a
	ld a, 1
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
	
	ld a, c
	add 4
	
    ld      (REGptc1+01h),a
    ld      (REGptc2+01h),a
    inc     a
    ld      (REGptc3+01h),a
	
	xor a
	call mt_init
	ld a,1
	ld (music_enabled), a
	ld (selected_sort_plan), a
	
	ld a, 10000010b ; light blue border
	ld (BORDER), a
	out ($00),a
	
	ld a, 01000001b ; light blue pal#0
	out ($60), a
	
	rst $30	; clear screen
	db $05
	
	xor a
	ld (scroll_active), a
	ld (worm_enabled), a
	call sprites_init
	
	ld hl, 800
	ld (color_scroll_counter), hl
	xor a
	ld (color_scroll_idx), a
	
	call setup_irq
	
	call init_dirs
	
	ret
	
setup_irq:
	di
	ld hl, ($003e)
	ld (own_irq_handler.jump_to_irq+1), hl
	ld hl, own_irq_handler
	ld ($003e), hl
	ei
	ret

teardown:
	xor a
	ld (BORDER), a
	out ($00),a
	
	out ($60), a
	
	call teardown_irq
	
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_SCREEN_VIDEOMODE
	out (c), a
	xor a		; set screen to no_vid
	inc c
	out (c), a
	dec c
	
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, FUNC_CLEAR_TEXT_SCREEN
	out (c), a
	dec c
	
	ld a, REG_MEMORY_P2
	out (c), a
	inc c
	ld a, (P2_STORAGE)
	out (c), a
	dec c
	
	ld a, REG_MEMORY_P3
	out (c), a
	inc c
	ld a, (P3_STORAGE)
	out (c), a
	dec c
	
	ld a, REG_SPRITE_ENABLE_LOW
	out (c), a
	inc c
	ld a, 0
	out (c), a
	dec c
	
	ld a, REG_SPRITE_FOREGROUND_LOW
	out (c), a
	inc c
	ld a, $ff
	out (c), a
	dec c
	
	ld a, REG_VSID_BASE + $18
	out (c), a
	inc c
	xor a
	out (c), a

	
	ret
	
teardown_irq:
	di
	ld hl, (own_irq_handler.jump_to_irq+1)
	ld ($003e), hl
	ei
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

di_and_page
	di
	ld a, $b0	; U0-U1-U2-U3
	out ($02), a
	ret

ei_and_page
	ld a, (P_SAVE)
	out ($02), a
	ei
	ret
			
BASE_PORT:
  db 00
  
load_directory:
	ld bc, $0201
	call draw_box
	
	call load_dir_entries
	
	ret

MAX_B equ 20
MAX_C equ 29
animate_box:
	push hl
	
	call di_and_page
	ld hl, PARAM_BASE_ADDR
	ld (hl), $0f
	call ei_and_page
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, FUNC_SET_TEXT_COLOR
	out (c), a
	call wait_for_func

	pop hl
	ld a, (BOX_WIDTH)
	ld b, a
	ld a, (BOX_HEIGHT)
	ld c, a
;	ld bc, $0201
.animate_box_loop_b
	ld a, b
	cp h
	jr z, .skip_inc_b
;	inc b
	inc b
.skip_inc_b
	ld a, c
	cp l
	jr z, .skip_inc_c
;	inc c
	inc c
.skip_inc_c
	push hl
	push bc
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_SCREEN_Y
	out (c), a
	inc c
	ld b, 1
.loop_rasterline_1
	in a, (c)
	cp $f8
	jr nz, .loop_rasterline_1
.loop_rasterline_2
	in a, (c)
	cp $f8
	jr z, .loop_rasterline_2
	djnz .loop_rasterline_1
	call draw_no_box
	pop bc
	push bc
	call draw_box
	pop bc
	pop hl
	ld a, b
	cp h
	jr nz, .animate_box_loop_b
	ld a, c
	cp l
	jr nz, .skip_inc_b
	
	ret
	
P2_STORAGE
	db 00
P3_STORAGE
	db 00
	
check_fw_version
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_FW_VERSION_MAJOR
	out (c), a
	inc c
	in a, (c)
	dec c
	cp 1
	jr nc, .ok
	ld a, REG_FW_VERSION_MINOR
	out (c), a
	inc c
	in a, (c)
	cp 20
	jr nc, .ok
	ld hl, .req_fw_version_str
	call print_cstring
	xor a
	inc a
	ret
.ok
	xor a
	ret
.req_fw_version_str
	dz "Minimum fw version is 0.20\r\n"
	
set_fw_version_in_creds:
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_FW_VERSION_MAJOR
	out (c), a
	inc c
	in a, (c)
	add '0'
	ld hl, creds_launcher_fw_version
	ld (hl), a
	dec c
	ld a, REG_FW_VERSION_MINOR
	out (c), a
	inc c
	in a, (c)
	ld b, 0
.decimal_loop
	inc b
	sub 10
	jr nc, .decimal_loop
	dec b
	add 10
	push af
	ld a, b
	add '0'
	inc hl
	inc hl
	ld (hl), a
	pop af
	add '0'
	inc hl
	ld (hl), a
	ret
	
	
	
	
	
print_legend
	call di_and_page
	ld de, PARAM_BASE_ADDR
	ld hl, LEGEND_STRING
	ld bc, LEGEND_STRING_END - LEGEND_STRING
	ldir
	call ei_and_page
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	inc c
	ld a, (LEGEND_NUM_OF_FUNCS)
	out (c), a
	call wait_for_func
	ret
	
LEGEND_X equ 22
LEGEND_STRING
	db FUNC_SET_XY
	db LEGEND_X, 1
	db FUNC_PRINT_STRING_ASCII
	db $FF, "Launcher", CURSOR_MOVE_DOWN, 0
	db FUNC_SET_XY
	db LEGEND_X+2, 255
	db FUNC_PRINT_STRING_ASCII
	db "by Sanyi", 0

	db FUNC_SET_XY
	db LEGEND_X, 9
	db FUNC_PRINT_STRING_ASCII
	db $FB, "Move: ", CURSOR_MOVE_DOWN, 0
	db FUNC_SET_XY
	db LEGEND_X+1, 255
	db FUNC_PRINT_STRING_ASCII
	db "JOY/AY,.", CURSOR_MOVE_DOWN, CURSOR_MOVE_DOWN, 0
	
	db FUNC_SET_XY
	db LEGEND_X, 255
	db FUNC_PRINT_STRING_ASCII
	db "Select:", CURSOR_MOVE_DOWN, 0
	db FUNC_SET_XY
	db LEGEND_X+1, 255
	db FUNC_PRINT_STRING_ASCII
	db "FIRE/RET", CURSOR_MOVE_DOWN, CURSOR_MOVE_DOWN, 0
	
	db FUNC_SET_XY
	db LEGEND_X, 255
	db FUNC_PRINT_STRING_ASCII
	db "Change", CURSOR_MOVE_DOWN, 0
	db FUNC_SET_XY
	db LEGEND_X+1, 255
	db FUNC_PRINT_STRING_ASCII
	db "drive: D", CURSOR_MOVE_DOWN, CURSOR_MOVE_DOWN, 0
	
	db FUNC_SET_XY
	db LEGEND_X, 255
	db FUNC_PRINT_STRING_ASCII
	db "Load dir", CURSOR_MOVE_DOWN, 0
	db FUNC_SET_XY
	db LEGEND_X, 255
	db FUNC_PRINT_STRING_ASCII
	db "to PSRAM:L", CURSOR_MOVE_DOWN, 0
	
	db FUNC_SET_XY
	db LEGEND_X, 255
	db FUNC_PRINT_STRING_ASCII
	db "Sort list:", 0
	db FUNC_SET_XY
	db LEGEND_X+1, 255
	db FUNC_PRINT_STRING_ASCII
	db "S  (cas)", CURSOR_MOVE_DOWN, CURSOR_MOVE_DOWN, 0
	
	db FUNC_SET_XY
	db LEGEND_X, 255
	db FUNC_PRINT_STRING_ASCII
	db "Toggle", CURSOR_MOVE_DOWN, 0
	db FUNC_SET_XY
	db LEGEND_X+1, 255
	db FUNC_PRINT_STRING_ASCII
	db "music: M", CURSOR_MOVE_DOWN, CURSOR_MOVE_DOWN, 0
	
	db FUNC_SET_XY
	db LEGEND_X, 255
	db FUNC_PRINT_STRING_ASCII
	db "Exit:", CURSOR_MOVE_DOWN, 0
	db FUNC_SET_XY
	db LEGEND_X, 255
	db FUNC_PRINT_STRING_ASCII
	db " ESC or Q", $FF, 0
LEGEND_STRING_END:
LEGEND_NUM_OF_FUNCS:
	db 32

	include "lr-box.asm"
	include "lr-dir.asm"
	include "lr-key.asm"
	include "lr-bitmap.asm"
	include "lr-irq.asm"
	include "lr-sprites.asm"
	include "playerz80.src"

CURRENT_PATH:
WORK_AREA equ CURRENT_PATH + 256
DIR_ENTRY_POIS equ WORK_AREA + 512
DIR_ENTRIES equ DIR_ENTRY_POIS + 512
PROGRAM_END:

