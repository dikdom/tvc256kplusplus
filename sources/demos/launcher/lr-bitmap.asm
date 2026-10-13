bitmap_width
	dw 0
bitmap_height
	dw 0

file_handle
	dw 0
	dw 0
	
open_bmp_file
	call di_and_page
	ld hl, PARAM_BASE_ADDR
	ld (hl), $01	; READ
	inc hl
	inc hl
	ex de, hl
	ld hl, (selected_file_poi)
	ld c, (hl)
	inc c
	ld b, 0
	ldir
	call ei_and_page
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, FUNC_OPEN_FILE
	out (c), a
	call wait_for_func
	push af
	call di_and_page
	ld hl, (PARAM_BASE_ADDR)
	ld (file_handle), hl
	ld hl, (PARAM_BASE_ADDR+2)
	ld (file_handle+2), hl
	call ei_and_page
	pop af
	ret

load_bmp_header
	call di_and_page
	ld hl, (file_handle)
	ld (PARAM_BASE_ADDR), hl
	ld hl, (file_handle+2)
	ld (PARAM_BASE_ADDR+2), hl
	
	ld hl, PARAM_BASE_ADDR+4
	ld (hl), 118
	inc hl
	ld (hl), 0
	call ei_and_page
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, FUNC_READ_FILE
	out (c), a
	jp wait_for_func

check_bmp_header
	call di_and_page
	; check size of read header, must be 118
	ld hl, (PARAM_BASE_ADDR+4)
	ld de, 118
	sub hl, de
	ld a, 1
	jp nz ,.header_check_failed
	; check 'BM' at the beg of file
	ld hl, PARAM_BASE_ADDR+6
	ld a, 'B'
	cp (hl)
	ld a, 2
	jr nz, .header_check_failed
	inc hl
	ld a, 'M'
	cp (hl)
	ld a, 2
	jr nz, .header_check_failed
	; check width of bmp, must be <= 256
	ld hl, PARAM_BASE_ADDR + 6 + 18	; width
	ld e, (hl)
	inc hl
	ld d, (hl)
	inc hl
	ld a, a
	or d
	ld a, 3
	jr c, .header_check_failed
	push hl
	ld hl, 256
	sub hl, de
	pop hl
	ld a, 3
	jr c, .header_check_failed
	xor a
	cp (hl)
	ld a, 3
	jr nz, .header_check_failed
	inc hl
	xor a
	cp (hl)
	ld a, 3
	jr nz, .header_check_failed
	ld (bitmap_width), de
	; check height of bmp, must be <= 240
	ld hl, PARAM_BASE_ADDR + 6 + 22	; width
	ld e, (hl)
	inc hl
	ld d, (hl)
	inc hl
	ld a, e
	or d
	ld a, 3
	jr c, .header_check_failed
	push hl
	ld hl, 240
	sub hl, de
	pop hl
	ld a, 3
	jr c, .header_check_failed
	xor a
	cp (hl)
	ld a, 3
	jr nz, .header_check_failed
	inc hl
	xor a
	cp (hl)
	ld a, 3
	jr nz, .header_check_failed
	ld (bitmap_height), de
	; check bits per pixel, must be 4
	ld hl, (PARAM_BASE_ADDR + 6 + 28)	; width
	ld de, 4
	sub hl, de
	ld a, 4
	jr nz, .header_check_failed
	ld hl, PARAM_BASE_ADDR + 6 + 30 - 1
	ld b, 4
.check_packing_of_bmp_loop
	xor a
	inc hl
	cp (hl)
	ld a, 5
	jr nz, .header_check_failed
	djnz .check_packing_of_bmp_loop
	
	call ei_and_page
	xor a
	ret
.header_check_failed
	push af
	call ei_and_page
	xor a
	inc a
	pop bc
	ld a, b
	ret

	
set_up_bitmap_screen
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_SPRITE_ENABLE_LOW
	out (c), a
	xor a
	inc c
	out (c), a
	dec c
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, FUNC_CLEAR_BITMAP_SCREEN
	out (c), a
	call wait_for_func
	xor a
	out ($60), a
	ld (BORDER), a
	ld a, REG_SCREEN_VIDEOMODE
	out (C), a
	inc c
	ld a, 3
	out (c), a
	dec c
	ret

load_bitmap
	ld hl, (bitmap_width)
	srl h
	rr l
	ld a, l
.loop_padding
	push af
	and $03
	jr z, .padding_ok
	pop af
	inc a
	jr .loop_padding
.padding_ok
	pop bc
	call di_and_page
	ld a, b
	ld hl, PARAM_BASE_ADDR + 4
	ld (hl), a
	inc hl
	xor a
	ld (hl), a
	inc hl
	ld (hl), a
	call ei_and_page
	ld hl, (bitmap_width)
	ld de, 256
	ex de, hl
	sub hl, de
	srl l
	srl l
	ld h, 0
	push hl	; centering on X pos offset, in bytes
	ld hl, (bitmap_height)
	ld de, 240
	ex de, hl
	sub hl, de
	srl l
	ld h, 0
	ld de, (bitmap_height)
	add hl, de
	dec hl
	ld b, l
	ld hl, 0
	ld de, 128
	xor a
	cp b
	jr z, .image_start_yoffs_ok
.end_of_image:
	add hl, de
	djnz .end_of_image
.image_start_yoffs_ok
	pop de
	add hl, de
	ld de, $8000
	add hl, de
	; ld hl, $8000 + 239*128
	call di_and_page
	ld (PARAM_BASE_ADDR + 4 + 3), hl
	xor a
	ld (PARAM_BASE_ADDR + 9), a
	call ei_and_page
	ld hl, (bitmap_height)
	ld b, l
	
.loop_read_bitmap_lines
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, FUNC_FILE_READ_DEST
	out (c), a
	call wait_for_func
	ret nz

	call di_and_page
	ld hl, (PARAM_BASE_ADDR + 4 + 3)
	ld de, 128
	or a
	sbc hl, de
	ld (PARAM_BASE_ADDR + 4 + 3), hl
	call ei_and_page
	djnz .loop_read_bitmap_lines
	
	call ei_and_page
	xor a
	ret
	
close_bmp_file:
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, FUNC_CLOSE_FILE
	out (c), a
	jp wait_for_func
	
reset_text_screen:	
	ld a, (BASE_PORT)
	ld c, a
	ld a, 01000001b
	out ($60), a
	ld a, 10000010b
	ld (BORDER), a
	ld a, REG_SCREEN_VIDEOMODE
	out (C), a
	inc c
	ld a, 1
	out (c), a
	dec c
	ld a, REG_SPRITE_ENABLE_LOW
	out (c), a
	ld a, 7
	inc c
	out (c), a
	dec c

	
	ret
	
show_bmp_error_dialog
	push af
	push hl
	ld a, 2
	ld (.num_of_function_calls), a
	call reset_text_screen
	ld bc, $0101
	call draw_box
	ld hl, 15 * 256 + 2
	call animate_box
	call di_and_page
	pop de
	ld hl, PARAM_BASE_ADDR
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 3
	inc hl
	ld (hl), 15
	inc hl
.print_error_msg
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ex de, hl
.copy_errmsg_loop
	ld a, (hl)
	ld (de), a
	inc hl
	inc de
	or a
	jr nz, .copy_errmsg_loop
	ld a, (hl)
	or a
	jr z, .no_more_text
	ex de, hl
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 3
	inc hl
	ld (hl), 16
	inc hl
	ld a, (.num_of_function_calls)
	add 2
	ld (.num_of_function_calls), a
	jr .print_error_msg
	
.no_more_text
	inc hl
	ex de, hl
	pop af
	or a
	jr z, .skip_error_code
	ld (hl), FUNC_PRINT_HEX_BYTE
	inc hl
	ld (hl), a
	inc hl
	ld a, (.num_of_function_calls)
	inc a
	ld (.num_of_function_calls), a
.skip_error_code
	call ei_and_page
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	inc c
	ld a, (.num_of_function_calls)
	out (c), a
.bmp_keyboard_loop
	rst $30
	db $93
	ld a, c
	cp $ff
	jr nz, .bmp_keyboard_loop
	rst $30
	db $91
	ld bc, 15*256 + 02
	call draw_box
	ret
	
.num_of_function_calls
	db 0