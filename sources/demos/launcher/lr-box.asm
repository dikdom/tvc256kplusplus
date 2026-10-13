DEFAULT_COLOR equ $F7

draw_box
	ld a, b
	ld (BOX_WIDTH), a
	sub 1
	srl a
	add 1
	ld b, a
	
	ld a, c
	ld (BOX_HEIGHT), a
	sub 1
	srl a
	add 1
	ld c, a
	
	ld a, 10
	sub b
	ld (BOX_X), a
	ld a, 15
	sub c
	ld (BOX_Y), a
	
	call di_and_page
	ld hl, PARAM_BASE_ADDR
	
	ld (hl), FUNC_SET_TEXT_COLOR
	inc hl
	ld (hl), $0f
	inc hl

; position the text
	ld (hl), FUNC_SET_XY
	inc hl
	
	ld a, (BOX_X)
	ld (hl), a
	inc hl
	ld a, (BOX_Y)
	ld (hl), a
	inc hl
	
	
; print top row of box
	ld (hl), FUNC_PRINT_STRING_SCREEN_CODE
	inc hl

	ld (hl), 85
	inc hl

	ld a, (BOX_WIDTH)
	ld b, a
	ld a, 64
.top_line_loop
	ld (hl), a
	inc hl
	djnz .top_line_loop
	
	ld (hl), 73
	inc hl
	
	ld (hl), 0
	inc hl
	
	ld a, (BOX_HEIGHT)
	ld b, a
	ld a, (BOX_Y)
	inc a
	ld d, a
	
; left border
	ld (hl), FUNC_SET_XY
	inc hl
	
	ld a, (BOX_X)
	ld (hl), a
	inc hl
	
	ld (hl), d
	inc hl
	
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld a, 66 + $60
.print_left_border_loop
	ld (hl), a
	inc hl
	ld (hl), CURSOR_MOVE_LEFT
	inc hl
	ld (hl), CURSOR_MOVE_DOWN
	inc hl
	djnz .print_left_border_loop
	ld (hl), 0
	inc hl

; right border
	ld a, (BOX_HEIGHT)
	ld b, a

	ld (hl), FUNC_SET_XY
	inc hl
	
	ld a, (BOX_X)
	ld c, a
	ld a, (BOX_WIDTH)
	add c
	inc a
	ld (hl), a
	inc hl
	
	ld (hl), d
	inc hl
	
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld a, 66 + $60
.print_right_border_loop
	ld (hl), a
	inc hl
	ld (hl), CURSOR_MOVE_LEFT
	inc hl
	ld (hl), CURSOR_MOVE_DOWN
	inc hl
	djnz .print_right_border_loop
	ld (hl), 0
	inc hl


; -------- bottom line 
	ld (hl), FUNC_SET_XY
	inc hl
	
	ld a, (BOX_X)
	ld (hl), a
	inc hl
	ld a, (BOX_HEIGHT)
	add a, d
	ld (hl), a
	inc hl
	
; print bottom row of box
	ld (hl), FUNC_PRINT_STRING_SCREEN_CODE
	inc hl
	
	ld (hl), 74
	inc hl

	ld a, (BOX_WIDTH)
	ld b, a
	
	ld a, 64
.bottom_line_loop
	ld (hl), a
	inc hl
	djnz .bottom_line_loop
	
	ld a, 75
	ld (hl), a
	inc hl
	
	xor a
	ld (hl), a
	inc hl
	
	ld a, (BASE_PORT)
	ld c, a
	
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a

	inc c
	ld a, 9
	out (c), a
	call wait_for_func

	call ei_and_page
	ret

draw_no_box
	call di_and_page
	ld hl, PARAM_BASE_ADDR

; position the text
	ld (hl), FUNC_SET_XY
	inc hl
	
	ld a, (BOX_X)
	ld (hl), a
	inc hl
	ld a, (BOX_Y)
	ld (hl), a
	inc hl
	
; print top row of box
	ld (hl), FUNC_PRINT_STRING_SCREEN_CODE
	inc hl
	
	ld a, (BOX_WIDTH)
	add 2
	ld b, a
	ld a, 32
.top_line_loop
	ld (hl), a
	inc hl
	djnz .top_line_loop
	
	ld (hl), 0
	inc hl
	
	ld a, (BOX_HEIGHT)
	ld b, a
	ld a, (BOX_Y)
	inc a
	ld d, a
	
; left border
	ld (hl), FUNC_SET_XY
	inc hl
	
	ld a, (BOX_X)
	ld (hl), a
	inc hl
	
	ld a, d
	ld (hl), a
	inc hl
	
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld a, ' '
.print_left_border_loop
	ld (hl), a
	inc hl
	ld (hl), CURSOR_MOVE_LEFT
	inc hl
	ld (hl), CURSOR_MOVE_DOWN
	inc hl
	djnz .print_left_border_loop
	ld (hl), 0
	inc hl

; right border
	ld a, (BOX_HEIGHT)
	ld b, a

	ld (hl), FUNC_SET_XY
	inc hl
	
	ld a, (BOX_X)
	ld c, a
	ld a, (BOX_WIDTH)
	add c
	inc a
	ld (hl), a
	inc hl
	
	ld a, d
	ld (hl), a
	inc hl
	
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld a, ' '
.print_right_border_loop
	ld (hl), a
	inc hl
	ld (hl), CURSOR_MOVE_LEFT
	inc hl
	ld (hl), CURSOR_MOVE_DOWN
	inc hl
	djnz .print_right_border_loop
	ld (hl), 0
	inc hl
	

; -------- bottom line 
	ld (hl), FUNC_SET_XY
	inc hl
	
	ld a, (BOX_X)
	ld (hl), a
	inc hl
	ld a, (BOX_HEIGHT)
	add a, d
	ld (hl), a
	inc hl
	
; print bottom row of box
	ld (hl), FUNC_PRINT_STRING_SCREEN_CODE
	inc hl
	
	ld a, (BOX_WIDTH)
	add 2
	ld b, a
	
	ld a, 32
.bottom_line_loop
	ld (hl), a
	inc hl
	djnz .bottom_line_loop
	
	xor a
	ld (hl), a
	inc hl
	
	ld a, (BASE_PORT)
	ld c, a
	
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	inc c

	ld a, 8
	out (c), a
	call wait_for_func

.ok
	call ei_and_page
	ret

BOX_WIDTH:
	db 0
BOX_HEIGHT: 
	db 0
BOX_X: 
	db 0
BOX_Y: 
	db 0

print_box_header_str
	db $6b
	ds $40, MAX_B
	db $73, 0
box_header_drive_str:
	dz "Drive: "
box_header_path_str:
	dz "Path: "

print_filelist_box_header
	call di_and_page
	ld hl, PARAM_BASE_ADDR
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 0
	inc hl
	ld (hl), 3
	inc hl
	ld (hl), FUNC_PRINT_STRING_SCREEN_CODE
	inc hl
	ld a, $6b
	ld (hl), a
	inc hl
	ld b, MAX_B
	ld a, $40
.header_loop
	ld (hl), a
	inc hl
	djnz .header_loop
	ld a, $73
	ld (hl), a
	inc hl
	xor a
	ld (hl), a

	ld a, (BASE_PORT)
	ld c, a
	
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	inc c
	ld a, 2
	out (c), a
	call wait_for_func
	
	ld hl, PARAM_BASE_ADDR
	ld (hl), FUNC_SET_XY
	inc hl
	ld a, 1
	ld (hl), a
	inc hl
	ld (hl), a
	inc hl
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld de, box_header_drive_str
.drive_loop:
	ld a,(de)
	ld (hl), a
	inc hl
	inc de
	or a
	jr nz, .drive_loop
	
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 1
	inc hl
	ld (hl), 2
	inc hl
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld de, box_header_path_str
.path_loop:
	ld a,(de)
	ld (hl), a
	inc hl
	inc de
	or a
	jr nz, .path_loop
	
	ld a, (BASE_PORT)
	ld c, a
	
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	inc c
	ld a, 4
	out (c), a
	call wait_for_func
	
	call print_active_drive
	
	call print_path
	
	call ei_and_page
	ret

; expects di_and_page, C port
print_active_drive
	ld hl, PARAM_BASE_ADDR
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 8
	inc hl
	ld (hl), 1
	inc hl
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	push hl
	
	ld hl, .drives_str
	ld a, REG_DRIVE_SELECT
	out (c), a
	inc c
	in a, (c)
	dec c
	ld de, 6
.drive_select_loop
	cp 0
	jr z, .drive_str_done
	add hl, de
	dec a
	jr nz, .drive_select_loop
.drive_str_done
	ex de, hl
	pop hl
.print_str
	ld a, (de)
	ld (hl), a
	inc hl
	inc de
	or a
	jr nz, .print_str
	
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	inc c
	ld a, 2
	out (c), a
	call wait_for_func
	ret
	
.drives_str
	dz "USB  "
	dz "PSRAM"
	dz "FLASH"
	dz "DSK  "
	

; expects di_and_page
print_path
	ld hl, PARAM_BASE_ADDR
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 7
	inc hl
	ld (hl), 2
	inc hl
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	
	ld de, CURRENT_PATH+1
	ld a, (CURRENT_PATH)
	cp 13
	jr c, .de_set
	ld (hl), '~' ; left arrow
	inc hl
	ld b, a
	sub 12
	push hl
	ex de, hl
	ld d, 0
	ld e, a
	add hl, de
	ex de, hl
	pop hl
.de_set
	ld a, (de)
	ld (hl), a
	inc hl
	inc de
	or a
	jr nz, .de_set
	
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	inc c
	ld a, 2
	out (c), a
	call wait_for_func
	
	ret
	
print_driveselect_box:
	call di_and_page
	ld hl, PARAM_BASE_ADDR
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 8
	inc hl
	ld (hl), 13
	inc hl
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld (hl), $ff
	inc hl
	ld de, .drive_select_title_str
.print_title_loop
	ld a, (de)
	ld (hl), a
	inc hl
	inc de
	or a
	jr nz, .print_title_loop
	
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 6
	inc hl
	ld (hl), 14
	inc hl
	ld (hl), FUNC_PRINT_STRING_SCREEN_CODE
	inc hl
	ld a, $6b
	ld (hl), a
	inc hl
	ld b, 8
	ld a, $40
.header_loop
	ld (hl), a
	inc hl
	djnz .header_loop
	ld a, $73
	ld (hl), a
	inc hl
	xor a
	ld (hl), a
	inc hl
	
; USB
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 7
	inc hl
	ld (hl), 15
	inc hl
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld a, (selected_drive)
	or a
	ld b, $ff
	jr z, .color_selected_usb
	ld a, (handle_drive_select.available_drives)
	and 1
	ld b, $f7
	jr nz, .color_selected_usb
	ld b, $f0
.color_selected_usb
	ld (hl), b
	inc hl
	ex de, hl
	ld hl, print_active_drive.drives_str
	ld bc, 6
	ldir
	ex de, hl

;PSRAM
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 7
	inc hl
	ld (hl), 16
	inc hl
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld a, (selected_drive)
	cp 1
	ld b, $ff
	jr z, .color_selected_psram
	ld a, (handle_drive_select.available_drives)
	and 2
	ld b, $f7
	jr nz, .color_selected_psram
	ld b, $f0
.color_selected_psram
	ld (hl), b
	inc hl
	ex de, hl
	ld hl, print_active_drive.drives_str + 6
	ld bc, 6
	ldir
	ex de, hl
	
;FLASH
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 7
	inc hl
	ld (hl), 17
	inc hl
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld a, (selected_drive)
	cp 2
	ld b, $ff
	jr z, .color_selected_flash
	ld a, (handle_drive_select.available_drives)
	and 4
	ld b, $f7
	jr nz, .color_selected_flash
	ld b, $f0
.color_selected_flash
	ld (hl), b
	inc hl
	ex de, hl
	ld hl, print_active_drive.drives_str + 12
	ld bc, 6
	ldir
	ex de, hl
	
;DSK
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 7
	inc hl
	ld (hl), 18
	inc hl
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld a, (selected_drive)
	cp 3
	ld b, $ff
	jr z, .color_selected_dsk
	ld a, (handle_drive_select.available_drives)
	and 8
	ld b, $f7
	jr nz, .color_selected_dsk
	ld b, $f0
.color_selected_dsk
	ld (hl), b
	inc hl
	ex de, hl
	ld hl, print_active_drive.drives_str + 18
	ld bc, 6
	ldir
	
	call ei_and_page

	ld a, (BASE_PORT)
	ld c, a
	
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	inc c
	ld a, 12
	out (c), a
	call wait_for_func

	ret
.drive_select_title_str
	dz "Drives"

SELECTED_LINE
	db 0
WINDOW_POS
	db 0
CURRENT_LINE_POS
	db 0
WINDOW_SIZE equ 15

print_file_list
	call di_and_page
	
	call init_cursor
	
	ld b, 0
	ld a, (WINDOW_POS)
	ld (CURRENT_LINE_POS), a
	
	ld hl, NUM_OF_ENTRIES
	cp (hl)
	jr nc, .end_of_list
	
	ld l, a
	ld h, 0
	add hl, hl
	ld de, DIR_ENTRY_POIS
	add hl, de
.loop_print_box
	push hl		; -> pointer to list of pointers in stack
	ld e, (hl)
	inc hl
	ld d, (hl)
	ex de, hl	; -> hl points to a dir entry structure, de points to the actual direntry address (higher byte)
;	push hl
	call print_one_line
	
	ld hl, CURRENT_LINE_POS
	inc (hl)
	ld a, (hl)
	ld hl, NUM_OF_ENTRIES
	inc b
	cp (hl)
	pop hl
	jr z, .end_of_list
	ld a, 25
	cp b
	jr z, .end_of_list
	inc hl
	inc hl
	jr .loop_print_box

.end_of_list
	ld a, 25
	cp b
	jr z, .end_of_box
	jr c, .end_of_box
	push bc
	
	ld hl, PARAM_BASE_ADDR
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld (hl), CURSOR_MOVE_DOWN
	inc hl
	ld (hl), 0
	inc hl
	
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 1
	inc hl
	ld (hl), 255
	inc hl
	
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld a, ' '
	ld (hl), a
	push hl
	pop de
	inc de
	ld bc, MAX_B
	ldir
	ld (hl), 0
	pop bc
	
	
.empty_lines_loop	
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	inc c
	ld a, 3
	out (c), a
	call wait_for_func
	inc b
	ld a, 25
	cp b
	jr nz, .empty_lines_loop
	
	
.end_of_box
	call ei_and_page
	ret


init_cursor
	ld hl, PARAM_BASE_ADDR
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 0
	inc hl
	ld (hl), 3
	inc hl
	ld (hl), FUNC_SET_TEXT_COLOR
	inc hl
	ld (hl), DEFAULT_COLOR AND $0F
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	inc c
	ld a, 2
	out (c), a
	call wait_for_func
	
	ret

print_one_line
	push bc
	ld (.dir_entry_start), hl	; let's store the direntry address
	ex de, hl					; and move it to de also
	ld hl, PARAM_BASE_ADDR
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld (hl), $0d
	inc hl
	ld (hl), $0a
	inc hl
	ld (hl), CURSOR_MOVE_RIGHT
	inc hl
	
	ld a, b	 ; A contains the current line being printed
	push hl
	ld hl, SELECTED_LINE
	cp (hl)
	pop hl
	jr nz, .no_selection
	ld (hl), $ff
	inc hl
.no_selection
	ld c, 0
	push hl
	ld hl, 5
	add hl, de
	ld a, (hl)
	sub 15
	ex de, hl	; de points to filename
	inc de
	pop hl
	jr c, .less_than_14chars
;	ld (hl), $C6 ; long filenames start with checker board
	ld (hl), '~' ; long filenames start with a left arrow
	inc hl
	add 2
	ld b, a
	inc c
.loop_de_inc
	inc de
	djnz .loop_de_inc
.less_than_14chars
.copy_filename_loop
	ld a, (de)
	ld (hl), a
	inc hl
	inc de
	inc c
	or a
	jr nz, .copy_filename_loop
	dec hl
	ld d, $20
	ld a, 15
.padding_loop
	cp c
	jr c, .done_padding
	ld (hl), d
	inc hl
	inc c
	jr .padding_loop
.done_padding
	xor a
	ld (hl), a
	inc hl
	
	ld de, (.dir_entry_start)
	ld a,(de)
	and $10
	jr nz, .directory
	push hl
	
	inc de
	push de
	inc de
	inc de
	ld a, (de)
	ex de, hl
	inc hl
	or (hl)
	pop de
	pop hl
	jr nz, .gt_64k
	
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	call .print_dec_num

	jr .entry_done
.gt_64k
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld de, .gt64k_str
.gt64k_loop
	ld a, (de)
	ld (hl), a
	inc de
	inc hl
	or a
	jr nz, .gt64k_loop
	jr .entry_done
.directory
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld de, .dir_str
.dir_str_copy_loop
	ld a, (de)
	ld (hl), a
	inc hl
	inc de
	or a
	jr nz, .dir_str_copy_loop
.entry_done
	ld (hl), FUNC_SET_TEXT_COLOR
	inc hl
	
	ld (hl), DEFAULT_COLOR and $0f

	pop bc

	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	inc c
	ld a, 3
	out (c), a
	call wait_for_func
	ret
	
.print_dec_num
	ld (.buffer_store), hl
	xor a
	ld (.printed_digit), a
	
	ex de, hl
	ld a, (hl)
	inc hl
	ld h, (hl)
	ld l, a
	ld (.file_len_store), hl

	ld hl, .tensof
	push hl

	ld e, (hl)
	inc hl
	ld d, (hl)
	
.calc_loop	
	ld hl, (.file_len_store)
	ld b, 255
.sub_loop
	inc b
	xor a 			; clear c flag
	sbc hl, de
	jr nc, .sub_loop
	add hl, de
	
	ld (.file_len_store), hl
;	xor a 		; A is already 0	
	cp b
	jr nz, .print_digit
	ld a, (.printed_digit)
	or a
	jr nz, .print_digit
	ld a, $20
	jr .digit_set
.print_digit
	ld a, '0'
	add b
	ld (.printed_digit), a
.digit_set
	ld hl, (.buffer_store)
	ld (hl), a
	inc hl
	ld (.buffer_store), hl
	
	pop de
	inc de
	inc de
	push de
	
	ex de, hl
	ld e, (hl)
	inc hl
	ld d, (hl)
	ld a, d
	or e
	jr nz, .calc_loop

	pop de
	ld hl, (.file_len_store)
	ld a, l
	add '0'
	ld hl, (.buffer_store)
	ld (hl), a
	inc hl
	xor a
	ld (hl), a
	inc hl
	ret
	
	
.tensof
	dw 10000, 1000, 100, 10, 0
.file_len_store
.selected_filename_pointer
	dw 0
.buffer_store
	dw 0
.printed_digit
	db 0
.dir_entry_start
	dw 0
.dir_str
	dz "<DIR>"
.gt64k_str
	dz ">64kB"
.color_cnt
	db 0
.line_colors
	db $03, $06