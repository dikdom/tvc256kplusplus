civis_bmp_name:
    db 6, "08.bmp"

open_file:
	ld hl, civis_bmp_name
	ld de, $8002
	ld bc, 7
	ldir
	ld a, $01		; open for read
	ld ($8000), a

	ld a, (BASE_PORT)
	ld c, a
	ld a, PPREG_FUNCTION_EXEC
	out (c), a
	ld a, $80 + 1 ; open file
	inc c
	out (c), a
	
	call wait_for_func_finish
	ret
	
read_bitmap:
	; seek to 118
	ld a, 118
	ld ($8004), a
	xor a
	ld ($8005), a
	ld ($8006), a
	ld ($8007), a
	
	ld a, (BASE_PORT)
	ld c, a
	ld a, PPREG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, $80 + 10 ; file_seek
	out (c), a
	call wait_for_func_finish
	ret nz
	
	ld a, 128
	ld ($8004), a
	xor a
	ld ($8005), a
	ld ($8006), a
	ld ($8009), a
	
	ld hl, $8000+239*128
.loop_load_data
	push hl
	ld ($8007), hl
	
	ld a, PPREG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, $80 + 9 ; read_to_dest
	out (c), a
	call wait_for_func_finish
	pop hl
	ret nz
	xor a
	ld de, 128
	sbc hl, de
	ld a, h
	cp $80
	jr nc, .loop_load_data
	xor a
	ret 
	
close_file:
	ld a, (BASE_PORT)
	ld c, a
	ld a, PPREG_FUNCTION_EXEC
	out (c), a
	inc c
	ld a, $80 + 2 ; close file
	out (c), a
	call wait_for_func_finish
	ret

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
	ld a, PPREG_FUNCTION_RESULT
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
