sprites_init
	ld a, (BASE_PORT)
	ld c, a
	push bc
	ld a, REG_MEMORY_P2
	out (c), a
	inc c
	xor a
	out (c), a
	ld hl, sprite1
	ld de, $8000
	ld bc, sprites_end - sprite1
	ldir
	ld b, 64
	ld a, $ff
.sprite_fill_loop
	ld (de), a
	inc de
	djnz .sprite_fill_loop
	pop bc
	ld a, REG_MEMORY_P2
	out (c), a
	inc c
	ld a, 14
	out (c), a
 	dec c

 	inc c
	inc c
	ld a, 1
	out (c), a
	dec c
	dec c
	
	ld a, REG_SPRITE0_X
	out (c), a
	inc c
	ld a, 196	; sprite #0
	out (c), a
	xor a
	out (c), a
	ld a, 196	; sprite #1
	out (c), a
	xor a
	out (c), a
	ld a, 4
	out (c), a	; sprite #2
	xor a
	out (c), a
	dec c
	
	ld a, REG_SPRITE0_Y
	out (c), a
	inc c
	ld a, 235
	out (c), a ; sprite #0
	xor a
	out (c), a
	ld a, 240
	out (c), a ; sprite #1
	xor a
	out (c), a
	ld a, 240
	out (c), a ; sprite #2
	xor a
	out (c), a
	dec c
	
	ld a, REG_SPRITE0_COLOR
	out (c), a
	inc c
	ld a, 3
	out (c), a
	ld a, 9
	out (c), a
	ld a, 9
	out (c), a
	dec c
	
	ld a, REG_SPRITE0_PHASE
	out (c), a
	inc c
	xor a
	out (c), a
	ld a, 5
	out (c), a
	out (c), a
	dec c
	
	ld a, REG_SPRITE_ENABLE_LOW
	out (c), a
	inc c
	ld a, 7
	out (c), a
	dec c
	
	ld a, REG_SPRITE_FOREGROUND_LOW
	out (c), a
	inc c
	xor a
	out (c), a
	dec c
	
	ld a, REG_SPRITE_COLORMODE_LOW
	out (c), a
	inc c
	xor a
	out (c), a
	dec c
	
	
	inc c
	inc c
	xor a
	out (c), a
	dec c
	dec c
	
	ret
	
	
	


; sprite 1 / singlecolor / color: $01
sprite1:
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$40,$00
	db $00,$a0,$00,$00,$7f,$ff,$ff,$01

; sprite 2 / singlecolor / color: $01
sprite2:
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$0c,$00,$00,$33,$00,$10,$c0
	db $c0,$2b,$00,$30,$1c,$00,$0c,$01

; sprite 3 / singlecolor / color: $01
sprite3:
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$0c,$00,$00,$1e,$00
	db $00,$33,$00,$00,$61,$80,$04,$c0
	db $c0,$0b,$80,$60,$07,$00,$30,$01

; sprite 4 / singlecolor / color: $01
sprite4:
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$08,$00,$00,$08,$00,$00
	db $1c,$00,$00,$14,$00,$00,$36,$00
	db $00,$22,$00,$00,$63,$00,$01,$41
	db $00,$02,$c1,$80,$01,$00,$c0,$01

; sprite 5 / singlecolor / color: $01
sprite5:
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$00,$00,$00,$00
	db $00,$00,$00,$00,$0c,$00,$00,$0c
	db $00,$00,$0c,$00,$00,$0c,$00,$00
	db $0c,$00,$00,$0c,$00,$00,$0c,$00
	db $00,$1c,$00,$00,$1c,$00,$00,$7c
	db $00,$00,$a6,$00,$00,$43,$00,$01
sprites_end