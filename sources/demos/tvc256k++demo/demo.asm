PPREG_SPRITE_X equ $00
PPREG_SPRITE_Y equ $20
PPREG_SPRITE_COLOR equ $40
PPREG_SPRITE_PHASE equ $50

PPREG_SPRITE_ENABLE_LOW equ $90
PPREG_SPRITE_ENABLE_HIGH equ $91
PPREG_SPRITE_COLORMODE_LOW equ $94
PPREG_SPRITE_COLORMODE_HIGH equ $95

PPREG_SCREEN_VIDEOMODE equ $A0
PPREG_SCREEN_SCROLL_X equ $A5
PPREG_SCREEN_Y equ $A8
PPREG_MEMORY_P2 equ $B0
PPREG_FUNCTION_EXEC equ $C0
PPREG_FUNCTION_PARAM_START equ $C1
PPREG_FUNCTION_RESULT equ $C2

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
  
	ld hl, opening_file_str
	call print_cstring
	call print_newline
  
	call open_file
	ld hl, 1
	jp nz, quit_with_error

	ld hl, reading_file_str
	call print_cstring
	call print_newline
  
	call read_bitmap
	ld hl, 2
	jp nz, quit_with_error

	call close_file
	ld hl, 3
	jp nz, quit_with_error
	
	rst $30
	db $05
	
	jp DEMO

	ld hl, 0
	ret

base_port_addr_str:
	dz "Base IO addr: "
opening_file_str:
	dz "Opening file ..."
reading_file_str:
	dz "Reading file ..."

quit_with_error:
	ld a, (BASE_PORT)
	ld c, a
	ld a, PPREG_SCREEN_VIDEOMODE
	out (c), a
	inc c
	xor a
	out (c), a
	ld hl, -1
	ret

setup:
    ld a, (BASE_PORT)
	ld c, a
	
	inc c
	inc c
	xor a
	out (c), a
	dec c
	dec c

	
	; parameter is read from $8000
	ld a, PPREG_FUNCTION_PARAM_START
	out (c), a
	xor a
	inc c
	out (c), a
	dec c
	
	; memory mapping set to page 4 -> 8000-bfff
	ld a, PPREG_MEMORY_P2
	out (c), a
	inc c
	ld a, 4
	out (c), a
	dec c
	
	; set screen to gfx
	ld a, PPREG_SCREEN_VIDEOMODE
	out (c), a
	ld a, 3
	inc c
	out (c), a
	dec c
	
	; hide sprites
	ld a, PPREG_SPRITE_ENABLE_LOW
	out (c), a
	xor a
	inc c
	out (c), a
	dec c
	
	ld a, PPREG_SPRITE_ENABLE_LOW
	out (c), a
	xor a
	inc c
	out (c), a
	dec c
	
	ld a, PPREG_MEMORY_P2
	out (c), a
	inc c
	xor a
	out (c), a
	
	ld hl, VIDEOTON
	ld de, $8000 + 2*64
	ld bc, 8*64
	ldir
	
	ld hl, SANTAS_HAT
	ld de, $8000 + 256*64
	ld bc, 252
	ldir

	ret

	include "load-bitmap.asm"
	include "effects.asm"

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
	AND     $C0 ; $00, $40, $80, $c0
	RRCA     
	RRCA     ; $00, $10, $20, $30
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

			
BASE_PORT:
  db 00

VIDEOTON:
	; V
     db $00,$00,$00,$3c,$00,$0c,$46,$03
     db $fc,$43,$03,$0c,$61,$86,$0c,$30
     db $cc,$18,$30,$68,$30,$18,$38,$30
     db $0c,$30,$60,$06,$00,$c0,$06,$00
     db $80,$03,$01,$80,$01,$83,$00,$01
     db $83,$00,$00,$c6,$00,$00,$cc,$00
     db $00,$68,$00,$00,$78,$00,$00,$00
     db $00,$00,$00,$00,$00,$00,$00,$01

// sprite 1 / singlecolor / color: $01
// sprite1:
	; I
     db $00,$00,$00,$01,$f8,$00,$03,$18
     db $00,$03,$18,$00,$03,$18,$00,$03
     db $18,$00,$03,$18,$00,$03,$18,$00
     db $03,$18,$00,$01,$8c,$00,$01,$8c
     db $00,$00,$c6,$00,$00,$c6,$00,$00
     db $c6,$00,$00,$c6,$00,$00,$7c,$00
     db $00,$00,$00,$00,$00,$00,$00,$00
     db $00,$00,$00,$00,$00,$00,$00,$01

// sprite 2 / singlecolor / color: $01
// sprite2:
	; D
     db $00,$00,$00,$1f,$f8,$00,$18,$0e
     db $00,$30,$03,$00,$30,$01,$80,$33
     db $c1,$80,$33,$60,$c0,$33,$30,$c0
     db $33,$18,$c0,$33,$18,$c0,$33,$30
     db $c0,$31,$e1,$80,$31,$81,$80,$30
     db $03,$00,$30,$06,$00,$30,$1c,$00
     db $60,$f0,$00,$7f,$c0,$00,$00,$00
     db $00,$00,$00,$00,$00,$00,$00,$01

// sprite 3 / singlecolor / color: $01
// sprite3:
	; E
     db $00,$00,$00,$07,$fe,$00,$7c,$07
     db $80,$60,$01,$80,$60,$01,$80,$30
     db $7f,$00,$33,$e0,$00,$33,$00,$00
     db $31,$c0,$00,$30,$60,$00,$30,$60
     db $00,$31,$c0,$00,$73,$00,$00,$63
     db $80,$00,$61,$ff,$c0,$60,$00,$60
     db $60,$00,$60,$60,$00,$c0,$7f,$ff
     db $80,$00,$00,$00,$00,$00,$00,$01

// sprite 4 / singlecolor / color: $01
// sprite4:
	; O
     db $00,$00,$00,$00,$ff,$00,$01,$81
     db $c0,$03,$00,$60,$06,$00,$30,$0c
     db $00,$38,$18,$00,$18,$18,$7e,$18
     db $18,$63,$0c,$30,$c3,$0c,$30,$c1
     db $98,$30,$c1,$90,$30,$7f,$90,$18
     db $06,$30,$18,$00,$30,$0e,$00,$60
     db $03,$80,$c0,$00,$f9,$c0,$00,$0f
     db $00,$00,$00,$00,$00,$00,$00,$01

// sprite 5 / singlecolor / color: $01
// sprite5:
	; T
     db $00,$00,$00,$00,$00,$00,$07,$8f
     db $e0,$1f,$ff,$e0,$1f,$ff,$e0,$1f
     db $ff,$c0,$1f,$fe,$00,$00,$7c,$00
     db $00,$7c,$00,$00,$7c,$00,$00,$7c
     db $00,$00,$7c,$00,$00,$7c,$00,$00
     db $7c,$00,$00,$7c,$00,$00,$78,$00
     db $00,$78,$00,$00,$78,$00,$00,$30
     db $00,$00,$00,$00,$00,$00,$00,$01

// sprite 6 / singlecolor / color: $01
// sprite4:
	; O
     db $00,$00,$00,$00,$7f,$00,$01,$ff
     db $80,$03,$ff,$e0,$07,$ff,$e0,$07
     db $ff,$f0,$0f,$ff,$f0,$1f,$ff,$f0
     db $1f,$c1,$f8,$3f,$81,$f8,$3f,$81
     db $f0,$3f,$c0,$f0,$3f,$ff,$f0,$1f
     db $ff,$f0,$1f,$ff,$e0,$0f,$ff,$e0
     db $03,$ff,$c0,$00,$ff,$c0,$00,$0e
     db $00,$00,$00,$00,$00,$00,$00,$01

// sprite 7 / singlecolor / color: $01
// sprite7:
	; N
     db $00,$00,$00,$00,$00,$78,$03,$c0
     db $fc,$0f,$e0,$fc,$0f,$f0,$fc,$0f
     db $f8,$f8,$0f,$fc,$f8,$0f,$ff,$f8
     db $0f,$ff,$f8,$0f,$ff,$f8,$0f,$9f
     db $f8,$0f,$9f,$f8,$1f,$8f,$f8,$1f
     db $8f,$f8,$1f,$8f,$f8,$1f,$87,$f8
     db $1f,$03,$f0,$1f,$03,$f0,$0e,$00
     db $f0,$00,$00,$00,$00,$00,$00,$01

SANTAS_HAT:
	db $88, $88, $88, $88, $77, $77, $77, $88, $88, $88, $88, $88, $88, $88, $87, $77
    db $77, $77, $77, $77, $77, $88, $88, $88, $88, $87, $77, $7F, $FF, $FF, $FF, $FF
    db $F7, $77, $77, $88, $88, $77, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $F7, $77, $88
    db $88, $7F, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $F7, $77, $78, $88, $FF, $FF, $F4
    db $44, $44, $44, $44, $FF, $F7, $77, $78, $88, $FF, $44, $44, $CC, $CC, $C4, $44
    db $44, $44, $77, $88, $88, $84, $4C, $CC, $CC, $CC, $CC, $CC, $CC, $44, $44, $88
    db $88, $8C, $CC, $CC, $CC, $CC, $CC, $CC, $CC, $C4, $48, $88, $88, $8C, $CC, $CC
    db $CC, $CC, $CC, $CC, $CC, $C4, $48, $88, $88, $88, $CC, $CC, $CC, $CC, $CC, $CC
    db $CC, $44, $88, $88, $88, $88, $8C, $CC, $CC, $CC, $CC, $CC, $C4, $48, $88, $88
    db $88, $88, $88, $CC, $CC, $CC, $CC, $CC, $C4, $48, $77, $78, $88, $88, $88, $CC
    db $CC, $CC, $CC, $CC, $44, $87, $7F, $F8, $88, $88, $88, $8C, $CC, $CC, $CC, $C4
    db $48, $87, $FF, $F7, $88, $88, $88, $88, $CC, $CC, $CC, $C4, $48, $84, $4F, $78
    db $88, $88, $88, $88, $8C, $CC, $CC, $CC, $44, $44, $CC, $88, $88, $88, $88, $88
    db $88, $CC, $CC, $CC, $CC, $CC, $CC, $88, $88, $88, $88, $88, $88, $8C, $CC, $CC
    db $CC, $CC, $C8, $88, $88, $88, $88, $88, $88, $88, $8C, $CC, $CC, $C8, $88, $88
    db $88, $88, $88, $88, $88, $88, $88, $88, $88, $88, $88, $88
	
PROGRAM_END:  