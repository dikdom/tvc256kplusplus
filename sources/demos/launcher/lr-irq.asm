own_irq_handler
;	ld a, $ff
;	out ($00), a
	push bc
	push de
	push hl
	call play_song
	call long_filename_scroller
	call worm_crawl
	call color_scroll
	pop hl
	pop de
	pop bc
;	ld a, 00000010b
;	out ($00), a
.jump_to_irq
	jp $0000

scroll_active:
	db 00
lf_counter:
	db 00

WAIT_FOR_LF_SCROLL equ 40
WAIT_FOR_WORM equ 1200

restart_animations:
	ld a, 1
	ld (scroll_active), a
	ld (worm_enabled), a
	ld a, WAIT_FOR_LF_SCROLL
	ld (lf_counter), a
	ld hl, WAIT_FOR_WORM
	ld (worm_counter), hl
	ld a, 3
	ld (worm_move_delay), a
	xor a
	ld (worm_phPos), a
	ld a, (BASE_PORT)
	add 4
	ld c, a
	xor a
	out (c), a
	inc c
	ld a, WORM_POS_INITX
	out (c), a
	
	ret

animations_disable
	xor a
	ld (worm_enabled), a
	ld a, (BASE_PORT)
	add 4
	ld c, a
	xor a
	out (c), a
	inc c
	ld a, WORM_POS_INITX
	out (c), a
key_counter_disable:
	xor a
	ld (scroll_active), a
	ret

long_filename_scroller:
	ld a, (scroll_active)
	or a
	ret z
	
	ld hl, lf_counter
	ld a, (hl)
	or a
	jr z, .scroll_it
	dec a
	ld (hl), a
	ret nz
	ld a, (WINDOW_POS)
	ld hl, SELECTED_LINE
	add (hl)
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
	ld a, (hl)
	cp 15
	jr nc, .long_file
	jr key_counter_disable
.long_file
	inc hl
	ld (.selected_filename_addr), hl
	sub 14
	ld (.selected_fn_pos_max), a
	ld (.selected_fn_pos_act), a
	ld a, 1
	ld (.filename_scroll_counter), a
	xor a
	ld (.filename_scroll_increase), a
	ret

.selected_filename_addr:
	dw 0
.selected_fn_pos_max:
	db 0
.selected_fn_pos_act:
	db 0
.filename_scroll_counter:
	db 0
.filename_scroll_increase:
	db 0
	
.scroll_it:
	ld hl, .filename_scroll_counter
	dec (hl)
	ret nz
	ld a, 10
	ld (hl), a

	ld a, (.filename_scroll_increase)
	or a
	ld a, (.selected_fn_pos_act)
	jr nz, .increase_pos
.decrease_pos	
	dec a
	ld (.selected_fn_pos_act), a
	or a
	jr nz, .pos_ok
	inc a
	ld (.filename_scroll_increase), a
	ld b, 30
	ld (hl), b
	jr .pos_ok
.increase_pos
	inc a
	ld (.selected_fn_pos_act), a
	ld hl, .selected_fn_pos_max
	cp (hl)
	jr c, .pos_ok
	xor a
	ld (.filename_scroll_increase), a
	ld a, 30
	ld (.filename_scroll_counter), a
.pos_ok
	ld a, (BASE_PORT)
	add 6
	ld c, a
	in a, (c)
	push af
	xor a
	out (c), a
	dec c
	dec c

	ld a, REG_FUNCTION_PARAM_START
	out (c), a
	inc c
	ld a, $f8	; params on -> FC00
	out (c), a
	dec c
	
	ld a, $b0	; U0-U1-U2-U3
	out ($02), a
	
	ld hl, $FC00
	ld (hl), FUNC_SET_XY
	inc hl
	ld (hl), 1
	inc hl
	ld a, (SELECTED_LINE)
	add 4
	ld (hl), a
	inc hl
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld (hl), $FF
	inc hl
	push hl
	ld hl, (.selected_filename_addr)
	ld a, (.selected_fn_pos_act)
	ld e, a
	ld d, 0
	add hl, de
	ex de, hl
	pop hl
	ld b, 14
.print_loop
	ld a, (de)
	ld (hl), a
	inc hl
	inc de
	djnz .print_loop
	
	xor a
	ld (hl), 0
		
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	inc c
	ld a, 2
	out (c), a
	call wait_for_func

	ld a, REG_FUNCTION_PARAM_START
	out (c), a
	inc c
	ld a, $fa	; params on -> FD00
	out (c), a
	ld a, $70	; U0-U1-U2-SYS, as the OS irq handler expects
	out ($02), a
	pop af
	inc c
	inc c
	out (c), a
	
	ret

worm_enabled
	db 0
worm_counter
	dw 0
worm_move_delay
	db 0
worm_xPos
	db 0
worm_phPos
	db 0
worm_phases
	db 4, 3, 2, 1, 0, 1, 2, 3, 255
	
WORM_POS_INITX equ 196
WORM_POS_INITY equ 255
WORM_MVD_VALUE equ 5

worm_crawl
	ld a, (worm_enabled)
	or a
	ret z
	
	ld hl, (worm_counter)
	ld a, h
	or l
	jr z, .move_worm
	dec hl
	ld (worm_counter), hl
	
	ld a, h
	or l
	ret nz
	ld a, WORM_POS_INITX
	ld (worm_xPos), a
	
.move_worm
	ld hl, worm_move_delay
	dec (hl)
	ret nz
	ld (hl), WORM_MVD_VALUE
	ld a, (worm_phPos)
	ld e, a
	ld d, 0
	ld hl, worm_phases
	add hl, de
	ld a, (hl)
	cp $ff
	jr nz, .phase_ok
	xor a
	ld (worm_phPos), a
	ld hl, worm_phases
.phase_ok
	ld a, (BASE_PORT)
	add 4
	ld c, a
	ld a, REG_SPRITE0_PHASE
	out (c), a
	inc c
	ld a, (hl)
	out (c), a
	dec c
	
	ld hl, worm_xPos
	ld a, (hl)
	sub 2
	ld (hl), a
	cp 4
	jr c, .end_of_crawl
	ld b, a
	ld a, REG_SPRITE0_X
	out (c), a
	inc c
	ld a, b
	out (c), a
	dec c
	ld hl, worm_phPos
	inc (hl)
	ret
.end_of_crawl
	ld hl, WAIT_FOR_WORM
	ld (worm_counter), hl
	ret
	
color_scroll_idx
	db 0

color_scroll_counter
	dw 100
	
color_scroll_delay
	db 0

credits_idx
	db 0

color_scroll
	ld hl, (color_scroll_counter)
	ld a, h
	or l
	jr z, .do_it
	dec hl
	ld (color_scroll_counter), hl
	ret
.do_it
	ld a, (color_scroll_delay)
	inc a
	ld (color_scroll_delay), a
	and 3
	ret nz

	ld a, $b0	; U0-U1-U2-U3
	out ($02), a
	ld a, (BASE_PORT)
	add 4
	ld c, a
	ld a, REG_MEMORY_P2
	out (c), a
	inc c
	xor a
	out (c), a
	dec c
	push bc
	
	ld hl, $8820 + 22 + 8
	ld de, $8820 + 22 + 9
	ld bc, 9
	lddr
	ld hl, color_scroll_idx
	ld a, (hl)
	inc (hl)
	cp $0a
	jr c, .color_ok
	cp $1b
	jr c, .set_color09
	cp $1c
	jr c, .switch_credits
	cp $2d
	jr c, .color_ok
	cp $42
	jr c, .set_color0f
	jr .end_of_color_scroll

.set_color09
	ld a, $09
	jr .color_ok
.set_color0f
	ld a, $0f
.color_ok
	and $0f
	ld ($8820 + 22), a
	ld a, ($8820 + 31)
	ld ($8840 + 22), a
	ld hl, $8840 + 22 + 8
	ld de, $8840 + 22 + 9
	ld bc, 9
	lddr
.done_color_scroll
	pop bc
	ld a, REG_MEMORY_P2
	out (c), a
	inc c
	ld a, 14
	out (c), a
	ld a, $70	; U0-U1-U2-SYS, as the OS irq handler expects
	out ($02), a
	ret
.end_of_color_scroll
	ld hl, 600
	ld (color_scroll_counter), hl
	xor a
	ld (color_scroll_idx), a
	jr .done_color_scroll
.switch_credits
	ld hl, credits_idx
	inc (hl)
	ld a, (hl)
	cp 5
	jr c, .credits_idx_ok
	xor a
	ld (hl), a
.credits_idx_ok
	add a
	ld e, a
	ld d, 0
	ld hl, .creds_pois
	add hl, de
	ld e, (hl)
	inc hl
	ld d, (hl)
	ex de, hl
	ld de, $8420 + 22
	ld bc, 10
	ldir
	ld de, $8440 + 22
	ld bc, 10
	ldir

	jr .done_color_scroll
.creds_pois
	dw creds_sanyi
	dw creds_noel
	dw creds_cadaver
	dw creds_launcher
	dw creds_date
creds_sanyi:
;	db "Launcher    by Sanyi"
	db 'L' - $40, 'a' + $20, 'u' + $20, 'n' + $20, 'c' + $20, 'h' + $20, 'e' + $20, 'r' + $20, "  "
	db "  ", 'b' + $20, 'y' + $20, ' ', 'S' - $40, 'a' + $20, 'n' + $20, 'y' + $20, 'i' + $20
	
creds_noel
;	db "Sng player   by Noel"
	db 'S' - $40, 'n' + $20, 'g' + $20, ' ', 'p' + $20, 'l' + $20, 'a' + $20, 'y' + $20, 'e' + $20, 'r' + $20
	db "   ", 'b' + $20, 'y' + $20, ' ', 'N' - $40, 'o' + $20, 'e' + $20, 'l' + $20
creds_cadaver
;	db "Song by      Cadaver"
	db 'S' - $40, 'o' + $20, 'n' + $20, 'g' + $20, ' ', 'b' + $20, 'y' + $20, "   "
	db "   ", 'C' - $40, 'a' + $20, 'd' + $20, 'a' + $20, 'v' + $20, 'e' + $20, 'r' + $20

creds_launcher
    db 'L' - $40, 'n' + $20, 'c' + $20, 'h' + $20, 'r' + $20, ": ", "1.3"
	db 'F'-$40, 'w' + $20 , ":  ", 'v'+$20
creds_launcher_fw_version:
	db "0.00"
	
creds_date
;	db "   v1.0 2026.07.23"
;    db "          "
	db 'B'-$40, 'u'+$20, 'd'+$20, 'a'+$20, 'p'+$20, 'e'+$20, 's'+$20, 't'+$20, "  "
	db "2026.10.04"
	
	


music_enabled:
	db 1
play_song:
	ld a, (music_enabled)
	or a
	ret z
	ld a, (BASE_PORT)
	add 6
	ld c,a
	ld a,1
	out (c), a
	push ix
	xor a
	ld b, a
	ld d, a
	call mt_play
	pop ix
	ld a, (BASE_PORT)
	add 6
	ld c,a
	xor a
	out (c), a
	ret