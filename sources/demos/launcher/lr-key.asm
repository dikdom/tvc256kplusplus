keyboard_start_loop:
	call restart_animations
keyboard_loop:
	rst $30
	db $93
	ld a, c
	cp $ff
	jr nz, keyboard_loop
	rst $30
	db $91
	
	ld hl, .key_codes
.key_check_loop
	ld a, (hl)
	or a
	jr z, keyboard_loop
	cp c
	inc hl
	jr z, .key_match
	ld a, c
	cp (hl)
	jr z, .key_match
	inc hl
	inc hl
	inc hl
	jr .key_check_loop
.key_match
	inc hl
	ld e, (hl)
	inc hl
	ld d, (hl)
	ld (.call_address + 1), de
.call_address
	call $0000
	jr z, keyboard_loop
	ret

.key_codes:
	db $05, $61	; joy up / A
	dw handle_key_up
	db $18, $79 ; joy down / Y
	dw handle_key_down
	db $13, ','	; joy left / .
	dw handle_key_left
	db $04, '.' ; joy right / -
	dw handle_key_right
	db $0d, $13 ; joy fire / RETURN
	dw handle_key_select
	db $1b, 'q'
	dw handle_key_esc
	db 'd', $01
	dw handle_drive_select
	db 'm', $01
	dw handle_toggle_music
	db 's', $01
	dw handle_sort_toggle
	db 'l', $01
	dw handle_load_to_psram
	db 'u', $01
	dw handle_umdsk
	db 0
	
handle_key_up
	call restart_animations
	ld a, (SELECTED_LINE)
	or a
	jr z, .top_of_box
	ld hl, SELECTED_LINE
	dec (hl)
	call print_file_list
	jr .done_here
.top_of_box
	ld hl, WINDOW_POS
	ld a, (hl)
	or a
	jr z, .done_here
	dec (hl)
	call print_file_list
.done_here
	xor a
	ret

handle_key_down
	call restart_animations
	ld a, (SELECTED_LINE)
	inc a
	ld hl, NUM_OF_ENTRIES
	cp (hl)
	jr z, .done_here
	cp 25
	jr z, .end_of_box
	ld (SELECTED_LINE), a
	call print_file_list
	jr .done_here
.end_of_box
	ld hl, WINDOW_POS
	add (hl)
	ld hl, NUM_OF_ENTRIES
	cp (hl)
	jr z, .done_here
	ld hl, WINDOW_POS
	inc (hl)
	call print_file_list
.done_here
	xor a
	ret

handle_key_left	; page up
	call restart_animations
	ld hl, WINDOW_POS
	xor a
	cp (hl)
	jr z, .already_at_top
	ld a, 25
	cp (hl)
	jr c, .more_than_enough
	xor a
	ld (hl), a
	jr .refresh_and_exit
.more_than_enough
	ld a, (hl)
	sub 25
	ld (hl), a
	jr .refresh_and_exit
.already_at_top
	ld a, (SELECTED_LINE)
	or a
	jr z, .done_here
	xor a
	ld (SELECTED_LINE), a
.refresh_and_exit
	call print_file_list
.done_here
	xor a
	ret
	
handle_key_right ; page down
	call restart_animations
	ld a, (NUM_OF_ENTRIES)
	cp 26
	jr c, .small_amount_of 
	sub 25
	ld b, a
	ld a, (WINDOW_POS)
	cp b
	jr z, .on_very_last_page
	add 25
	cp b
	jr nc, .not_enough_room_for_full_page
	ld (WINDOW_POS), a
	jr .refresh_and_exit
.not_enough_room_for_full_page
	ld a, b
	ld (WINDOW_POS), a
	jr .refresh_and_exit
.on_very_last_page
	ld a, 24
	ld (SELECTED_LINE), a
	jr .refresh_and_exit
.small_amount_of
	dec a
	ld (SELECTED_LINE), a
.refresh_and_exit
	call print_file_list
	xor a
	ret

handle_key_select ; ENTER
	call animations_disable
	ld a, (WINDOW_POS)
	ld hl, SELECTED_LINE
	add (hl)
	ld l, a
	ld h, 0
	add hl, hl
	ex de, hl
	ld hl, DIR_ENTRY_POIS
	add hl, de
	ld e, (hl)
	inc hl
	ld d, (hl)
	ex de, hl
	
	ld a, (hl)
	and $10
	jp nz, .directory
	ld (.file_entry_pos), hl
	ld de, 5
	add hl, de
	
	ld (print_one_line.selected_filename_pointer), hl
	ld a, (hl)
	cp 5
	jp c, .cannot_load
	sub 3
	ld e, a
	ld d, 0	; A/DE contains the end of the filename
	add hl, de
	ld (.file_extension_start), hl
	xor a
	ld (.extension_check_idx), a
.extensions_loop
	add a
	add a	; x4
	ld e, a
	ld d, 0
	ld hl, .extensions
	add hl, de
	xor a
	or (hl)
	jp z, .cannot_load
	ex de, hl
	ld hl, (.file_extension_start)
	ld b, 4
.extension_check_loop
	ld a, (hl)
	cp 'a'
	jr c, .right_caps
	sub 'a' - 'A'
.right_caps
	ld c, a
	ld a, (de)
	cp c
	jr nz, .not_a_match
	inc hl
	inc de
	djnz .extension_check_loop
	ld a, (.extension_check_idx)
	add a
	ld hl,.file_handling_entry_points
	ld e, a
	ld d, 0
	add hl, de
	ld e, (hl)
	inc hl
	ld d, (hl)
	ex de, hl
	jp (hl)

.not_a_match
	ld hl, .extension_check_idx
	inc (hl)
	ld a, (hl)
	jr .extensions_loop

.handle_cas	
	ld hl, (.file_entry_pos)
	call .filesize_lt_64k
	jr nz, .cannot_load
	ld hl, (print_one_line.selected_filename_pointer)
	
	ld bc, 16
	ld de, $19ce
	ldir
	
	ld a, (print_one_line.selected_filename_pointer)
	cp 16
	jr c, .filename_is_ok
	ld a, 15
	ld ($19ce), a
	dec de
	ld a, '*'
	ld (de), a

.filename_is_ok
	call teardown
	
	ld hl, $e951
	ld de, .tvc_e951_v12
	ld b, 6
.compare_loop
	ld a, (de)
	cp (hl)
	inc hl
	inc de
	jr nz, .tvc_22
	djnz .compare_loop
	
	jp $e951
.tvc_22
	
	jp $e4e8

.tvc_e951_v12
	db $cd, $35, $ea, $cd, $10, $de ; call $ea35 / call $de10

.directory:
	call animations_disable
	ld de, 5
	add hl, de
	ex de, hl
	rst $30
	db TVC_FUNC_SET_PWD
	or a
	jr nz, .cannot_load
	
	call get_current_path
	call load_directory
	ld hl, 20*256 + 29
	call animate_box
	call print_filelist_box_header
	call print_file_list
	
.cannot_load:
	call restart_animations
	xor a
	ret

.filesize_lt_64k
	ld de, 3
	add hl, de
	ld a, (hl)
	inc hl
	or (hl)
	ret

.handle_bmp
	call animations_disable
	
	call set_filename_params
	
.start_show_bmp
	call open_bmp_file
	jr nz, .file_open_error
	
	call load_bmp_header
	jr nz, .read_hdr_failed
	
	call check_bmp_header
	jr nz, .invalid_bmp
	call set_up_bitmap_screen
	call load_bitmap
	jr nz, .read_file_failed
.closeit
	call close_bmp_file
.bmp_keyboard_loop
	rst $30
	db $93
	ld a, c
	cp $ff
	jr nz, .bmp_keyboard_loop
	rst $30
	db $91
	ld a, $20
	cp c
	jr nz, .exit_with_closed_file

.check_next_file	
	ld a, (selected_file_pos)
	inc a
.store_selected_file_pos_for_next_bmp
	ld (selected_file_pos), a
	ld hl, NUM_OF_ENTRIES
	cp (hl)
	jr nz, .not_max
	xor a
	jr .store_selected_file_pos_for_next_bmp
.not_max
	ld l, a
	ld h, 0
	add hl, hl
	ld de, DIR_ENTRY_POIS
	add hl, de
	ld a, (hl)
	inc hl
	ld h, (hl)
	ld l, a
	ld de, 5
	add hl, de
	ld (selected_file_poi), hl
	ld a, (hl)
	cp 5
	jr c, .check_next_file
	sub 4
	ld e, a
	inc hl
	add hl, de
	ld de, .bmp_extension
	ex de, hl
	ld b, 4
.check_bmp_extension_loop
	ld a, (de)
	cp 'a'
	jr c, .bmp_check_letter_ok
	cp 'z'+1
	jr nc, .bmp_check_letter_ok
	sub 'a'-'A'
.bmp_check_letter_ok
	cp (hl)
	inc hl
	inc de
	jr nz, .check_next_file
	djnz .check_bmp_extension_loop
	jr .start_show_bmp
	
.exit_with_closed_file
	call reset_text_screen
	call restart_animations
	xor a
	ret

.file_open_error
	push af
	call close_bmp_file
	pop af
	ld hl, .file_open_error_str
	jr .bmp_error
	
.read_hdr_failed
	push af
	call close_bmp_file
	pop af
	ld hl, .read_hdr_failed_str
	jr .bmp_error
	
.invalid_bmp
	push af
	call close_bmp_file
	pop af
	ld hl, .invalid_bmp_str
	jr .bmp_error

.read_file_failed
	push af
	call close_bmp_file
.loop_file_read_err
	rst $30
	db $93
	ld a, $ff
	cp c
	jr nz, .loop_file_read_err
	rst $30
	db $91
	pop af
	ld hl, .read_file_failed_str
	xor a
	jr .bmp_error

.bmp_error
	call show_bmp_error_dialog
	
	ld hl, 20*256 + 29
	call animate_box
	call print_filelist_box_header
	call print_file_list
	call restart_animations
	xor a
	ret

.handle_dsk
	call animations_disable
	
	call set_filename_params
	
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_DRIVE_SELECT
	out (c), a
	inc c
	in a, (c)
	ld (selected_drive), a
	dec c
	push bc
	
	rst $30 ; umount first - doesn't care about retVal
	db TVC_FUNC_UMNT_DSK
	
	pop bc
	ld a, REG_DRIVE_SELECT
	out (c), a
	inc c
	ld a, (selected_drive)
	out (c), a
	
	ld de, (selected_file_poi)
	rst $30
	db TVC_FUNC_MNT_DSK
	
	or a
	jr z, .mnt_done_ok
	
    ret
.mnt_done_ok
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_DRIVE_SELECT
	out (c), a
	inc c
	ld a, 3
	out (c), a
	ld (selected_drive), a
	
	call get_current_path
	call load_directory
	ld hl, 20*256 + 29
	call animate_box
	call print_filelist_box_header
	call print_file_list
	xor a
	ret
	
	

.file_open_error_str
	db $FC
	dz "Error opening"
	dz "file"
	db 0
.read_hdr_failed_str
	db $FC
	dz "Error loading"
	dz "BMP header"
	db 0
.invalid_bmp_str
	db $FC
	dz "Invalid BMP"
	dz "header "
	db 0
.read_file_failed_str
	db $FC
	dz "Error reading"
	dz "BMP data"
	db 0
.extensions
	db ".CAS"
.bmp_extension
	db ".BMP"
.dsk_extension
	db ".DSK"
;.tim_extension
;	db ".TIM"
;.sis_extension
;	db ".SIS"
	db 0
.file_handling_entry_points
	dw .handle_cas
	dw .handle_bmp
	dw .handle_dsk
;	dw .handle_tim
;	dw .handle_sis
.extension_check_idx
	db 0
.file_extension_start
	dw 0
.file_entry_pos
	dw 0

handle_key_esc ; ESC
	xor a
	inc a
	ret

handle_drive_select:
	call animations_disable
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_DRIVE_SELECT
	out (c), a
	inc c
	in a, (c)
	ld (.current_drive), a
	ld (selected_drive), a
	dec c
	
	call check_available_drives

	ld bc, $0101
	call draw_box
	ld hl, $0806
	call animate_box
	call print_driveselect_box
	
	call drive_keyboard_loop
	
	call restart_animations
	
	xor a
	ret
	
.current_drive
	db 00
.available_drives
	db 00
selected_drive
	db 00

check_available_drives:
	xor a
	ld hl, handle_drive_select.available_drives
	ld (hl), a
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_USB_INIT
	out (c), a
	inc c
	in a, (c)
	dec c
	AND 2
	jr z, .skip_usb
	ld a, 1
	ld (hl), a
.skip_usb
	ld a, REG_DRIVE_PSRAM_VALID
	out (c), a
	inc c
	in a, (c)
	dec c
	or a
	jr z, .skip_psram
	
	ld a, 2
	or (hl)
	ld (hl), a

.skip_psram
	ld a, REG_DRIVE_FLASH_VALID
	out (c), a
	inc c
	in a, (c)
	dec c
	or a
	jr z, .skip_flash
	
	ld a, 4
	or (hl)
	ld (hl), a
	
.skip_flash
	ld a, REG_DRIVE_DSK_VALID
	out (c), a
	inc c
	in a, (c)
	dec c
	or a
	jr z, .skip_dsk
	
	ld a, 8
	or (hl)
	ld (hl), a
.skip_dsk
	ret

drive_keyboard_loop
.keyboard_loop
	rst $30
	db $93
	ld a, c
	cp $ff
	jr nz, .keyboard_loop
	rst $30
	db $91
	
	ld hl, .key_codes
.key_check_loop
	ld a, (hl)
	or a
	jr z, .keyboard_loop
	cp c
	inc hl
	jr z, .key_match
	ld a, c
	cp (hl)
	jr z, .key_match
	inc hl
	inc hl
	inc hl
	jr .key_check_loop
.key_match
	inc hl
	ld e, (hl)
	inc hl
	ld d, (hl)
	ld (.call_address + 1), de
.call_address
	call $0000
	jr z, .keyboard_loop
	ret

.key_codes:
	db $1b, 'q'
	dw ds_handle_key_esc
	db $05, $61	; joy up / A
	dw ds_handle_key_up
	db $18, $79 ; joy down / Y
	dw ds_handle_key_down
	db $0d, $13 ; joy fire / RETURN
	dw ds_handle_key_select
	db 0



ds_handle_key_esc ; ESC
	call animations_disable
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_DRIVE_SELECT
	out (c), a
	inc c
	ld a, (handle_drive_select.current_drive)
	out (c), a
	dec c
	
	call print_file_list
	xor a
	inc a
	ret

ds_handle_key_up
	ld a, (selected_drive)
	or a
	ret z
	ld hl, handle_drive_select.available_drives
.dec_loop
	dec a
	cp $FF
	ret z
	cp 2
	jr z, .flash_to_select
	cp 1
	jr z, .psram_to_select
.usb_to_select
	ld a, (hl)
	and $01
	ret z
	dec a
	ld (selected_drive), a	; set 0
	call print_driveselect_box
	xor a
	ret
.psram_to_select
	ld b, a
	ld a, (hl)
	and $02
	ld a, b
	jr z, .dec_loop
	ld a, 1
	ld (selected_drive), a	; set 1 - psram
	call print_driveselect_box
	xor a
	ret
.flash_to_select
	ld b, a
	ld a, (hl)
	and $04
	ld a, b
	jr z, .dec_loop
	ld a, 2
	ld (selected_drive), a	; set 1 - flash
	call print_driveselect_box
	xor a
	ret
	
ds_handle_key_down
	ld a, (selected_drive)
	cp 3
	ret z
	ld hl, handle_drive_select.available_drives
.inc_loop
	inc a
	cp $04
	ret z
	cp 3
	jr z, .dsk_to_select
	cp 2
	jr z, .flash_to_select
.psram_to_select
	ld b, a
	ld a, (hl)
	and $02
	ld a, b
	jr z, .inc_loop
	ld a, 1
	ld (selected_drive), a	; set 1 - psram
	call print_driveselect_box
	xor a
	ret
.flash_to_select
	ld b, a
	ld a, (hl)
	and $04
	ld a, b
	jr z, .inc_loop
	ld a, 2
	ld (selected_drive), a	; set 1 - flash
	call print_driveselect_box
	xor a
	ret
.dsk_to_select
	ld b, a
	ld a, (hl)
	and $08
	ld a, b
	jr z, .inc_loop
	ld a, 3
	ld (selected_drive), a	; set 1 - flash
	call print_driveselect_box
	xor a
	ret

ds_handle_key_select
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_DRIVE_SELECT
	out (c), a
	inc c
	ld a, (selected_drive)
	out (c), a
	call get_current_path
	call load_directory
	ld hl, 20*256 + 29
	call animate_box
	call print_filelist_box_header
	call print_file_list
	xor a
	inc a
	ret
	
handle_toggle_music:
	call restart_animations
	di
	ld a, (music_enabled)
	ld b, a
	ld a, 1
	sub b
	ld (music_enabled), a
	ei
	cp 0
	jr z, .disabled
.enabled
	xor a
	call mt_init
	xor a
	ret
.disabled
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_VSID_BASE + $18	; vSID Volume
	out (c), a
	xor a
	inc c
	out (c), a
	or a
	ret
	
selected_sort_plan
	db 0
	
handle_sort_toggle
	call animations_disable
	ld a, (selected_sort_plan)
	inc a
	cp 4
	jr nz, .sort_plan_fine
	xor a
.sort_plan_fine
	ld (selected_sort_plan), a
	call load_directory
	ld hl, 20*256 + 29
	call animate_box
	call print_filelist_box_header
	call print_file_list
	call restart_animations
	
	ld a, (selected_sort_plan)
	add a
	add a
	ld e, a
	ld d, 0
	ld hl, .sort_strs
	add hl, de
	ex de, hl
	call di_and_page
	ld hl, PARAM_BASE_ADDR
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 27
	inc hl
	ld (hl), 22
	inc hl
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld (hl), $FB
	inc hl
	ex de, hl
	ld bc, 4
	ldir
	ex de, hl
	ld (hl), $FF
	inc hl
	ld (hl), 0

	call ei_and_page
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	inc c
	ld a, 2
	out (c), a
	call wait_for_func
	
	xor a
	ret

.sort_strs:
	dz " - "
	dz "cas"
	dz "asc"
	dz "dsc"
	
set_filename_params
	ld a, (SELECTED_LINE)
	ld hl, WINDOW_POS
	add (hl)
	ld (selected_file_pos), a
	ld l, a
	ld h, 0
	add hl, hl
	ld de, DIR_ENTRY_POIS
	add hl, de
	ld a, (hl)
	inc hl
	ld h, (hl)
	ld l, a
	ld de, 5
	add hl, de
	ld (selected_file_poi), hl
	ret

selected_file_pos
	db 0
selected_file_poi
	dw 0

handle_load_to_psram
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_DRIVE_SELECT
	out (c), a
	inc c
	in a, (c)
	ld (selected_drive), a
	dec c
	
	or a
	jr z, .usb_active_drive
	xor a
	ret
.usb_active_drive
	call set_filename_params
	ld de, 5
	xor a
	sbc hl, de
	ld a, (hl)
	and $10
	ret z	; not a directory
	add hl, de
	push hl
	ld a, 2
	cp (hl)
	jr nz, .not_parent_dir
	inc hl
	ld a, '.'
	cp (hl)
	jr nz, .not_parent_dir
	inc hl
	cp (hl)
	jr nz, .not_parent_dir
	pop hl
	ret 
.not_parent_dir
	xor a
	ld (scroll_active), a
	pop hl
	push bc
	ld bc, $0201
	call draw_box
	
	call di_and_page
	ld hl, (selected_file_poi)
	ld a, (hl)
	ld hl, CURRENT_PATH
	ld de, PARAM_BASE_ADDR
	ld c, (hl)
	ld b, 0
	add (hl)
	ld (de), a
	inc hl
	inc de
	ldir
	ld a, (CURRENT_PATH)
	cp 1
	jr z, .path_ok
	ld a, '/'
	ld (de), a
	inc de
	push hl
	ld hl, PARAM_BASE_ADDR
	inc (hl)
	pop hl
.path_ok
	ld hl, (selected_file_poi)
	ld c, (hl)
	inc hl
	ldir
	xor a
	ld (de), a
	
	ld a, (PARAM_BASE_ADDR)
	ld (.prev_progress), a
	
	call ei_and_page
	pop bc
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, FUNC_LOAD_DIR_TO_PSRAM
	out (c), a
	dec c
	
.loop_load_to_psram
	ld hl, $1000
.delay_loop
	dec hl
	ld a, h
	or l
	nop
	jr nz, .delay_loop
	
	call .print_loaded_file_hexnum
	call check_function_result
	jr nz, .loop_load_to_psram
	
	ld a, REG_FUNCTION_RESULT
	out (c), a
	inc c
	in a, (c)
	dec c
	
	or a
	jr nz, .failed_to_load
.directory_loaded
	ld hl, .dir_loaded_str
	call print_dialog_box
	ld a, REG_DRIVE_SELECT
	out (c), a
	inc c
	ld a, 1 ; PSRAM drive
	out (c), a
	dec c
	
	call get_current_path
	call load_directory
.failed_to_load
	ld hl, 20*256 + 29
	call animate_box
	call print_filelist_box_header
	call print_file_list
	xor a
	ret

.prev_progress
	db $ff

.print_loaded_file_hexnum
	push bc
	ld hl, PARAM_BASE_ADDR
	call di_and_page
	ld a, (.prev_progress)
	cp (hl)
	jr z, .onscreen_value_ok
	call .my_print_hex
.onscreen_value_ok
	call ei_and_page
	pop bc
	ret
.my_print_hex
	ld a, (hl)
	ld (.prev_progress), a
	push af
	ld a, REG_MEMORY_P2
	out (c), a
	inc c
	xor a
	out (c), a
	dec c
	pop af
	push af
	rrca
	rrca
	rrca
	rrca
	and $0F
	cp $0a
	jr c, .number1
	sub (9 + '0')
.number1
	add '0'
	ld ($8400 + 15*32 + 10), a
	ld a, $0f
	ld ($8800 + 15*32 + 10), a
	pop af
	and $0F
	cp $0a
	jr c, .number2
	sub (9 + '0')
.number2
	add '0'
	ld ($8400 + 15*32 + 11), a
	ld a, $0f
	ld ($8800 + 15*32 + 11), a
	
	ld a, REG_MEMORY_P2
	out (c), a
	inc c
	ld a, WORK_PAGE_P2
	out (c), a
	dec c
	
	ret

.dir_loaded_str
	dz "  Dir load OK  "

check_function_result
	ld a, REG_FUNCTION_EXEC
	out (c), a
	inc c
	in a, (c)
	dec c
	cp $FF
	ret
	
handle_umdsk
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_DRIVE_DSK_VALID
	out (c), a
	inc c
	in a, (c)
	ld (.prev_current_drive), a
	or a
	jr z, .no_dsk_mounted
	rst $30
	db TVC_FUNC_UMNT_DSK
	or a
	jr nz, .umount_failed
.umount_ok
	ld hl, .dsk_umount_ok_str
	call print_dialog_box
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_DRIVE_DSK_VALID
	out (c), a
	inc c
	in a, (c)
	ld hl, .prev_current_drive
	cp (hl)
	jr z, .no_drive_change
	call get_current_path
	call load_directory
.no_drive_change
	ld hl, 20*256 + 29
	call animate_box
	call print_filelist_box_header
	call print_file_list
	xor a
	ret
	
.no_dsk_mounted
	ld hl, .no_dsk_mounted_str
	call print_dialog_box
	jr .no_drive_change
.umount_failed
	ld hl, .umount_dsk_failed_str
	call print_dialog_box
	jr .no_drive_change
.prev_current_drive
	db 0
.no_dsk_mounted_str
	dz "No DSK mounted"
.umount_dsk_failed_str
	dz "Umnt DSK failed"
.dsk_umount_ok_str
	dz "  Umnt DSK OK  "
	
print_dialog_box
	push hl
	ld bc, $0201
	call draw_box
	ld hl, 15*256 + 1
	call animate_box
	call di_and_page
	ld hl, PARAM_BASE_ADDR
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 3
	inc hl
	ld (hl), 15
	inc hl
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld (hl), $FF
	inc hl
	pop de
.copy_str_loop
	ld a, (de)
	ld (hl), a
	inc hl
	inc de
	or a
	jr nz, .copy_str_loop
	call ei_and_page
	ld a, (BASE_PORT)
	ld c, a
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	inc c
	ld a, 2
	out (c), a
	call wait_for_func
.wait_for_keyboard_loop
	rst $30
	db $93
	ld a, c
	cp $ff
	jr nz, .wait_for_keyboard_loop
	rst $30
	db $91
	ret