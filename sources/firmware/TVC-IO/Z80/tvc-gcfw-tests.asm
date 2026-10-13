  DEFPAGE 0, $C000

  PAGE 0
  CODE @ $C000

  db "MOPS"
  db 5
  db "TVC++"
  
  code @ $c00b
  dw init
  db 1
  dw 0

PRINT_CHARACTER equ 2
PRINT_HEX_BYTE equ 3
PRINT_HEX_WORD equ 4
PRINT_STRING_SCREEN_CODE equ 5
GET_TEXT_COLOR equ 6
SET_TEXT_COLOR equ 7  
GET_XY equ 8
SET_XY equ 9

init:
  ld a, 00000010b  ; i0g0r0b0
  out ($00),a ; blue border

  ld hl, mem_test
  ld de, $3000
  ld bc, mem_test_end - mem_test
  ldir

  ld hl, mem_test_in_extram
  ld de, $a000
  ld bc, mem_test_in_extram_end - mem_test_in_extram
  ldir

  ld hl, load_bmp
  ld de, $8000
  ld bc, load_bmp_end - load_bmp
  ldir
  ret
.tight_loop:
  in a, ($31)
  jr .tight_loop

  ld a, 10000010b  ; i0g0r0b0
  out ($00),a ; blue border

  ld a, $F0 ; U0-U1-U2-EXT
  out ($02),a

  ld a, 10100000b
  out ($00),a ; green border

  ld a, 00100000b
  out ($00),a ; dark green border

  ld a, 0
  out ($32),a ; no increment on register select

  ld a, 00101000b
  out ($00),a ; border

  ld a, $A6   ; psram size retrieval
  out ($30), a

;  ld a, 00101010b
;  out ($00),a ; grey border
;  call wait_some

  in a, ($31) ; is it 8MB psram?
  cp 8
  jp nz, no_psram ; no... 

 ; ld a, 10100000b
 ; out ($00),a ; green border
 ; call wait_some

  ld a, $A5
  out ($30), a ; psram to page3 high bit selected
  ld a, 0
  out ($31), a ; set to 0 (0-255 can be selected)
  ld a, $A4
  out ($30), a ; psram to page3 low 8 bits selected
  ld b, 0
  ld c, 0
  ld hl, 0

;  ld a, 00100010b
;  out ($00),a ; cyan border
;  call wait_some

  ld a, 5
  out ($31), a  ; 5th bank to map in to page3

  ld a, 00101000b
  out ($00),a ; brown border

psram_loop:
  inc hl
  ld a, l
  out ($00), a
  in a, ($31)
  cp 5
  jr nz, psram_loop
  
  push hl

;  ld a, 00000010b
;  out ($00),a ; dark green border
;  call wait_some

;  ld a, 10100010b
;  out ($00), a
;  call wait_some

  ld hl, $0100
  ld ($bf80), hl
;  ld a, 001010101b
;  out ($00), a
  ld a, $B0
  out ($30), a ; Function library call
;  ld a, 00000010b
;  out ($00), a
;  call wait_some
  
  ld a, SET_XY
  call call_function ; GOTOXY selected
;  ld a, $08
;  out ($00), a
  pop hl
  ld ($bf80), hl
  ld a, PRINT_HEX_WORD
  call call_function ; print hex byte called
;  ld a, $82
;  out ($00),a ; blue border
;  call wait_some
  ld a, $a2
  out ($00), a
  jp kilep


no_psram:
  ld a, $88  ; i0g0r0b0
  out ($00),a
.no_psram_loop:
  jr .no_psram_loop

wait_some:
  push bc
  push hl
  push af
  ld b, 1
  ld hl, $0000
wait_cycle_test:
  dec hl
  ld a, h
  or l
  jr nz, wait_cycle_test
  djnz wait_cycle_test
  pop af
  pop hl
  pop bc
  ret

call_function:
;  call wait_some
  out ($31), a
.wait_for_finish:  
;  call wait_some
  in a, ($31)
  cp $FF
  jr nz, .wait_for_finish
  ret 

kilep:
  ld a, $a0
  out ($30), a
  ld a, PRINT_HEX_WORD
  out ($31), a
  ld a,$d0 ; U0-U1-VID-EXT
  out ($02), a
  ret

mem_test:
  phase $3000
  di
  ld a, $a0
  ld (.border_color), a
  out ($00), a
  ld a, $B0   ; U0-U1-U2-U3
  out ($02),a
  ld a, $A0   ; p2
  out ($30),a
  in a, ($31) ; by def it should be $04
  ld (.original_page), a
  call .page_in_b6
  ld b, $00
  ld de, 0
  ld hl, 0
  add hl, sp
  ld (.original_sp), hl
  ld sp, $4000
.mainloop_read
  ld hl, $8000
.loop_read
  ld c, (hl)
  ld a, $55
  ld (hl), a
  cp (hl)
  jr z, .skip_2nd_test
  call  .check_failed
  cp (hl)
  call nz, .check_failed_again
.skip_2nd_test
  ld (hl), c
  ld a, c
  cp (hl)
  call nz, .check_failed_again
  inc hl
  ld a, h
  cp $00
  jr nz, .loop_read
  ld a, (.border_color)
  xor $80
  ld (.border_color), a
  out ($00), a
  djnz .mainloop_read
  ld a, ($0003)
  out ($02),a
  ld a, $A0
  out ($30),a
  ld a, (.original_page)
  out ($31),a
  ld hl, (.original_sp)
  ld sp, hl
  ex de, hl
  ei
  ret
.check_failed:
  push af
  ld a, (.border_color)
  or 00001000b
  ld (.border_color), a
  out ($00), a
  inc de
  pop af
  ret
.check_failed_again:
  ld a, (.border_color)
  or 00000010b
  ld (.border_color), a
  out ($00), a
  inc de
  ret
.original_page
  db 00
.original_sp
  dw 0000

  di
  xor a
  out ($32), a
  ld de, 0000
  ld a, 10100000b  ; i0g0r0b0
  out ($00), a
  ld (.border_color), a
  ld a, $B0 ; U0-U1-U2-U3
  out ($02), a
  call .clr_screen
  call .set_xy
  ld b, $60
.start_test_loop:
  ld hl, $8000
.test_loop:
  ld c, (hl)
  ld a, $aa
  ld (hl), a
  cp (hl)
  call nz, .mem_test_fail
  ld a, $55
  ld (hl), a
  cp (hl)
  call nz, .mem_test_fail
  ld (hl), c
  inc hl
  ld a, h
  cp $00
  jr nz, .test_loop
  call .print_dot
  ld a, (.border_color)
  xor $80
  ld (.border_color), a
  out ($00), a
  djnz .start_test_loop
  ld a, ($0003)
  out ($02), a
  ei
  ex de, hl
  ret
.mem_test_fail:
  ld a, 10001000b ; red border on fail i0g0r0b0
  out ($00), a
  ld (.border_color), a
  call .page_in_b6
  ld a, $b0
  out ($30), a
  ld a, 1100b
  ld ($bf80), a
  ld a, SET_TEXT_COLOR
  out ($31), a
  call .check_cmd_finished
  inc de
  call .page_in_b4
  ret

.clr_screen:
  call .page_in_b6
  ld a, $b0
  out ($30), a
  xor a
  out ($31), a
  call .check_cmd_finished
  call .page_in_b4
  ret
.set_xy:
  call .page_in_b6
  ld hl, $0200
  ld ($bf80), hl
  ld a, $b0
  out ($30), a
  ld a, SET_XY
  out ($31), a
  call .check_cmd_finished
  call .page_in_b4
  ret

.print_dot:
  call .page_in_b6
  ld a, '.'
  ld ($bf80), a
  ld a, $b0
  out ($30), a
  ld a, $02
  out ($31), a
  call .check_cmd_finished
  ld a, $b0
  out ($30), a
  ld a, 1111b
  ld ($bf80), a
  ld a, SET_TEXT_COLOR
  out ($31), a
  call .check_cmd_finished
  call .page_in_b4
  ret

.print_hex_word
  call .page_in_b6
  ld ($BF80), hl
  ld a, $b0
  out ($30), a
  ld a, PRINT_HEX_WORD
  out ($31), a
  call .check_cmd_finished
  ld a, $b0
  call .page_in_b4
  ret

.page_in_b4
  ld a, $a0
  out ($30), a
  ld a, $04
  out ($31), a
  ret

.page_in_b6
  ld a, $a0
  out ($30), a
  ld a, $06
  out ($31), a
  ret

.check_cmd_finished
  in a, ($31)
  cp $ff
  jr nz, .check_cmd_finished
  ret

.border_color
  db $a0;
  dephase
mem_test_end:

mem_test_in_extram:
  phase $a000
  di
  ld a, $82
  ld (.border_color), a
  out ($00), a
  ld a, $B0   ; U0-U1-U2-U3
  out ($02),a
  ld a, $A1   ; p3
  out ($30),a
  in a, ($31) ; by def it should be $06
  ld (.original_page), a
  call .page_in_b6
  ld b, $00
  ld de, 0
  ld hl, 0
  add hl, sp
  ld (.original_sp), hl
  ld sp, $4000
.mainloop_read
  ld hl, $C000
.loop_read
  ld c, (hl)
  ld a, $55
  ld (hl), a
  cp (hl)
  call nz, .check_failed
  ld (hl), c
  ld a, c
  cp (hl)
  call nz, .check_failed
  inc hl
  ld a, h
  or l
  jr nz, .loop_read
  ld a, (.border_color)
  xor $80
  ld (.border_color), a
  out ($00), a
  djnz .mainloop_read
  ld a, ($0003)
  out ($02),a
  ld a, $A1
  out ($30),a
  ld a, (.original_page)
  out ($31),a
  ld hl, (.original_sp)
  ld sp, hl
  ex de, hl
  ei
  ret

.page_in_b6
  ld a, $a1
  out ($30), a
  ld a, $06
  out ($31), a
  ret

.check_failed:
  push af
  ld a, (.border_color)
  or 00001000b
  ld (.border_color), a
  out ($00), a
  inc de
  pop af
  ret
.border_color
  db $00
.original_page
  db 00
.original_sp


  dephase
mem_test_in_extram_end:

load_bmp:
  phase $8000
  ld a, $00
  out ($32), a
  call .switch_to_bitmap
  ld a, $b1
  out ($30),a
  ld a, $04
  out ($31),a
  inc hl
  ld c,(hl)
  inc c
  ld b, 0
  ld de, $8201
  ldir
  ld a, 1
  ld ($8200),a
  call .open_file
  jp nz, .switch_to_text
  
  ld hl, 118
  ld ($8204), hl
  ld hl, 0
  ld ($8206), hl
  call .seek_file
  jp nz, .switch_to_text
  
  ld b, 240
  ld hl, 32768 + 239*128
  ld de, 128
.loop_read:
  ld a, 128
  ld ($8204), a
  xor a
  ld ($8205), a
  ld ($8206), a
  ld ($8207), hl
  ld ($8209), a
  call .read_file_dest
  jp nz, .switch_to_text
  xor a
  sbc hl, de
  djnz .loop_read
  call .close_file

.loop_kbd
  rst $30
  db $93
  ld a, c
  cp $00
  jr z, .loop_kbd  
  ld hl, 0
  jp .switch_to_text



.open_file:
  ld a, $b0
  out ($30),a
  ld a, $80 + 1 ; openfile
  out ($31),a
  call .wait_till_done
  ld a, $B2
  out ($30), a
  in a, ($31)
  cp $00
  ret z
  ld hl, 1
  ret

.seek_file
  ld a, $b0
  out ($30),a
  ld a, $80 + 10 ; openfile
  out ($31),a
  call .wait_till_done
  ld a, $B2
  out ($30), a
  in a, ($31)
  cp $00
  ret z
  ld hl, 2
  ret

.read_file_dest:
  ld a, $b0
  out ($30),a
  ld a, $80+9
  out ($31),a
  call .wait_till_done
  ld a, $B2
  out ($30), a
  in a, ($31)
  cp $00
  ret z
  ld l, a
  ld h, 0
  ret

.close_file:
  ld a, $B0
  out ($30), a
  ld a, $80+2
  out ($31), a
  call .wait_till_done
  ret

.wait_till_done:
  in a, ($31)
  cp $FF
  jr nz, .wait_till_done
  ret

.switch_to_bitmap:
  ld a, $90
  out ($30),a
  ld a, 3
  out ($31),a
  ret

.switch_to_text:
  ld a, $90
  out ($30),a
  ld a, 1
  out ($31),a
  ret
  dephase
load_bmp_end: