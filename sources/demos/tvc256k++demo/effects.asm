SCROLL_POSY EQU  28
STARTLINE EQU    21 + SCROLL_POSY * 8 - 1
BORDER_COLOR EQU $0B4F

DEMO:
	di
	
	ld hl, set_sprite_positions.DX
	ld d, 237
	call set_sprite_positions.fill_d
	ld hl, set_sprite_positions.DY
	ld d, 207
	call set_sprite_positions.fill_d
	
	ld hl, .text
	ld (.current_pos), hl

	ld a, (BASE_PORT)
	ld c, a
	
	ld a, PPREG_SPRITE_COLORMODE_LOW
	out (c), a
	ld a, $0F
	inc c
	out (c), a
	dec c
	
	ld a, PPREG_SPRITE_COLORMODE_HIGH
	out (c), a
	ld a, $F0
	inc c
	out (c), a
	dec c
	
	
	ld e, PPREG_SPRITE_COLOR + 4
	ld d, 15
	ld b, 8
.color_loop:
	out (c), e
	inc c
	out (c), d
	dec c
	inc d
	ld a, d
	cp $10
	jr nz, .skip_color_fix
	ld d, 9
.skip_color_fix
	inc e
	djnz .color_loop
	
		; port increment set to 0
	inc c
	inc c
	ld a, 1
	out (c), a
	dec c
	dec c
	
	ld a, PPREG_SPRITE_PHASE
	ld b, 16
	out (c), a
	inc c
	ld a, 64
.phase_loop0:
	out (c), a
	djnz .phase_loop0
	
	dec c
	
	inc c
	inc c
	xor a
	out (c), a
	dec c
	dec c
	
	
	ld e, PPREG_SPRITE_PHASE + 4
	ld d, 9
	ld b, 8
.phase_loop:
	out (c), e
	inc c
	out (c), d
	dec c
	dec d
	inc e
	djnz .phase_loop
	
	
	ld a, PPREG_SPRITE_ENABLE_LOW
	out (c), a
	inc c
	ld a, $FF
	out (c), a
	dec c
	
	ld a, PPREG_SPRITE_ENABLE_HIGH
	out (c), a
	inc c
	ld a, $FF
	out (c), a
	dec c
	

	; map in page 0
	ld a, PPREG_MEMORY_P2     ; map in page 0
	out (c),a
	xor a
	inc c
	out (c),a
	dec c

	ld hl, $8400 + (SCROLL_POSY) * 32
	ld de, $8400 + (SCROLL_POSY) * 32 + 1
	ld bc, $1F
	ld a, $20
	ld (hl), a
	ldir

	inc hl
	ld de, $20
	add hl, de

	xor a

	ld a, (BASE_PORT)
	ld c, a

.main_loop

	; read y
	ld a, PPREG_SCREEN_Y
	out (c), a
	inc c
.loop_till_no:
	in a, (c)
	cp STARTLINE
	jr nz, .loop_till_no
	dec c

	; 2c text mode
	ld a, PPREG_SCREEN_VIDEOMODE
	out (c),a
	inc c
	ld a, 1
	out (c), a
	dec c

	ld a, $82     ; dark blue border
	out ($00), a
	ld hl, .current_scroll
	ld a, PPREG_SCREEN_SCROLL_X
	out (c), a
	inc c
	ld a, (hl)
	out (c), a
	dec c

	; read y
	ld a, PPREG_SCREEN_Y
	out (c), a
	inc c
.loop_till_yes:
	in a, (c)
	cp STARTLINE + 8
	jr nz, .loop_till_yes
	dec c

	ld a, PPREG_SCREEN_VIDEOMODE
	out (c),a
	inc c
	ld a, 3
	out (c), a
	dec c

	ld a, $A0     ; light green border
	out ($00),a

	dec (hl)
	ld a, (hl)
	cp $80
	jr nc, .byte_scroll_done

	ld a, $87
	ld (hl), a
	ld hl, $8400 + SCROLL_POSY * 32 + 1
	ld de, $8400 + SCROLL_POSY * 32 + 0
	ld bc, 31
	ldir

	ld hl, (.current_pos)
	inc hl
	ld a, (hl)
	or a
	jr nz, .pos_ok
	ld hl, .text
	ld a, (hl)
.pos_ok
	ld (.current_pos), hl

	ld ($8400 + SCROLL_POSY * 32 + 31), a

.byte_scroll_done
	ld a, $88	; light red
	out ($00),a
	ld a, (BASE_PORT)
	ld c, a

	ld a, PPREG_SCREEN_SCROLL_X
	out (c), a
	xor a
	inc c
	out (c), a
	dec c
	
	call set_sprite_positions
	ld a, (BORDER_COLOR)
	out ($00),a

	jp .main_loop

.current_scroll:
	db $88
.current_pos:
	dw .text
	ascmap 'A'..'Z', => 0x01
	ascmap 'a'..'z', => 0x81
	ascmap '@', 0x00

	ascmap $e1, $f0	; á
	ascmap $e9, $ec ; é
	ascmap $ed, $e1 ; í
	ascmap $f3, $f6 ; ó
	ascmap $f6, $f4 ; ö
	ascmap $f5, $e5 ; õ
	ascmap $fa, $f5 ; ú
	ascmap $fc, $ee ; ü
	ascmap $fb, $fb ; û
;	asc "áéíóû'
; will not work sjasm 0.42c: ö, õ, ú, ü

	ascmap $c1, $EB	;Á
	ascmap $c9, $f1 ;É
	ascmap $cd, $e2 ;Í
	ascmap $d3, $f9 ;Ó
	ascmap $d6, $F7 ;Ö
	ascmap $d5, $E3 ;Õ
	ascmap $da, $f8 ;Ú
	ascmap $dc, $F3 ;Ü
	ascmap $db, $f2 ;Û
		
	
.text:
  asc " Helló! Ez egy egyszerû scroll-teszt demó a TVC256k++ kártyához!! Ahogy láthatod nincs gond az egyenletes scroll-élménnyel"
  asc " a jó ", $f4, "reg TVC-n. Ajánlom figyelmedbe a sprite-ok mozgását a háttérhez képest! Nagy helló Debrecennek, mindenkit "
  asc $ee, "dv", $f4, "zl", $f4, "k a Cívis Mikroklub el", $e5, "adásain! 2026.03.07., Sanyi    ***  " 
  asc " Hello! This is a simple scroll test of the TVC256k++ !! You can see that there is no problem with smooth scrolling on the TVC"
  asc " computers anymore. Greetings to Debrecen, to Cívis Mikroklub!  2026-03-07, by Sanyi    ***  "
  asc " (Ezt a programot a Launcher miatt javítani kellett, mert t", $f4, "nkretette a kártya által beállított sprite-okat. Bp., 2026-07-20, Sanyi)    ***  "
  db 0
  
  

set_sprite_positions:
	ld a, (.counter)
	dec a
	ld (.counter), a
	ret nz
	ld a, 1
	ld (.counter), a

	inc c
	inc c
	ld a, 2
	out (c), a
	dec c
	dec c
	
	ld a, PPREG_SPRITE_X
	out (c), a
	inc c
	
	ld b, $00
	ld d, 0
.loop_set_pos_x
	
	ld e, b
	
	ld hl, .DX
	add hl, de
	ld e, (hl)
	inc (hl)
	ld hl, .POS_X
	add hl, de
	ld a, (hl)
	or a
	jr nz, .dx_ok
	
	ld e, b
	ld hl, .DX
	add hl, de
	xor a
	ld (hl), a
	ld hl, .POS_X
	ld a, (hl)
.dx_ok
	out (c), a
	
	inc b
	ld a, 16
	cp b
	jr nz, .loop_set_pos_x
	dec c

; from now, let's set the Y of each sprites. 
	
	ld a, PPREG_SPRITE_Y
	out (c), a
	inc c

	ld b, $00
.loop_set_pos_y
	
	ld e, b
	
	ld hl, .DY
	add hl, de
	ld e, (hl)
	inc (hl)
	ld hl, .POS_Y
	add hl, de
	ld a, (hl)
	or a
	jr nz, .dy_ok
	
	ld e, b
	ld hl, .DY
	add hl, de
	xor a
	ld (hl), a
	
	ld a, c
	add 3
	ld c, a
	
	ld e, b
	ld hl, .DFG
	add hl, de
	ld a, (hl)
	xor $01
	ld (hl), a
	push af
	ld a, $60
	add b
	out (c), a
	inc c
	pop af
	out (c), a
	dec c
	
	ld a, c
	sub 3
	ld c, a
	
	ld hl, .POS_Y
	ld a, (hl)
.dy_ok
	out (c), a
	
	inc b
	ld a, $10
	cp b
	jr nz, .loop_set_pos_y
	
	
	; let's clear the auto port increment. C is now <base port>+1
	inc c
	xor a
	out (c), a
	dec c
	dec c
	
	ret

.fill_d:
	ld b, 00
	ld c, 0
.fill_d_loop
	ld (hl), c
	ld a, 9
	add c
	cp d
	jr c, .set_properly
	sub d
.set_properly
	ld c, a

	inc hl
	inc b
	ld a, $10
	cp b
	jr nz, .fill_d_loop
	ret

.POS_X:	; 237
	db 140 , 143 , 146 , 149 , 152 , 155 , 158 , 161 , 164 , 167 , 170 , 173 , 176 , 179 , 182 , 185
	db 187 , 190 , 193 , 196 , 198 , 201 , 203 , 206 , 208 , 211 , 213 , 215 , 218 , 220 , 222 , 224
	db 226 , 228 , 230 , 232 , 234 , 236 , 237 , 239 , 240 , 242 , 243 , 244 , 246 , 247 , 248 , 249
	db 250 , 251 , 252 , 252 , 253 , 253 , 254 , 254 , 255 , 255 , 255 , 255 , 255 , 255 , 255 , 254
	db 254 , 254 , 253 , 253 , 252 , 251 , 250 , 249 , 248 , 247 , 246 , 245 , 244 , 243 , 241 , 240
	db 238 , 236 , 235 , 233 , 231 , 229 , 227 , 225 , 223 , 221 , 219 , 217 , 214 , 212 , 210 , 207
	db 205 , 202 , 199 , 197 , 194 , 191 , 189 , 186 , 183 , 180 , 177 , 175 , 172 , 169 , 166 , 163
	db 160 , 157 , 154 , 151 , 148 , 145 , 142 , 138 , 135 , 132 , 129 , 126 , 123 , 120 , 117 , 114
	db 111 , 108 , 105 , 103 , 100 , 97 , 94 , 91 , 89 , 86 , 83 , 81 , 78 , 75 , 73 , 70
	db 68 , 66 , 63 , 61 , 59 , 57 , 55 , 53 , 51 , 49 , 47 , 45 , 44 , 42 , 40 , 39
	db 37 , 36 , 35 , 34 , 33 , 32 , 31 , 30 , 29 , 28 , 27 , 27 , 26 , 26 , 26 , 25
	db 25 , 25 , 25 , 25 , 25 , 25 , 26 , 26 , 27 , 27 , 28 , 28 , 29 , 30 , 31 , 32
	db 33 , 34 , 36 , 37 , 38 , 40 , 41 , 43 , 44 , 46 , 48 , 50 , 52 , 54 , 56 , 58
	db 60 , 62 , 65 , 67 , 69 , 72 , 74 , 77 , 79 , 82 , 84 , 87 , 90 , 93 , 95 , 98
	db 101 , 104 , 107 , 110 , 113 , 116 , 119 , 122 , 125 , 128 , 131 , 134 , 137
	db 0

.POS_Y: ; $C8 = 207
	db 21 , 21 , 21 , 21 , 21 , 22 , 22 , 22 , 23 , 23 , 23 , 24 , 24 , 25 , 26 , 26
	db 27 , 28 , 29 , 30 , 31 , 32 , 33 , 34 , 35 , 36 , 37 , 38 , 40 , 41 , 42 , 44
	db 45 , 47 , 48 , 50 , 52 , 53 , 55 , 57 , 59 , 61 , 62 , 64 , 66 , 68 , 70 , 72
	db 75 , 77 , 79 , 81 , 83 , 86 , 88 , 90 , 93 , 95 , 98 , 100 , 103 , 105 , 108 , 110
	db 113 , 116 , 118 , 121 , 124 , 126 , 129 , 132 , 135 , 138 , 141 , 144 , 146 , 149 , 152 , 155
	db 158 , 161 , 164 , 167 , 170 , 174 , 177 , 180 , 183 , 186 , 189 , 192 , 195 , 199 , 202 , 205
	db 208 , 211 , 214 , 218 , 221 , 224 , 227 , 230 , 234 , 230 , 227 , 224 , 221 , 218 , 214 , 211
	db 208 , 205 , 202 , 199 , 195 , 192 , 189 , 186 , 183 , 180 , 177 , 174 , 170 , 167 , 164 , 161
	db 158 , 155 , 152 , 149 , 146 , 144 , 141 , 138 , 135 , 132 , 129 , 126 , 124 , 121 , 118 , 116
	db 113 , 110 , 108 , 105 , 103 , 100 , 98 , 95 , 93 , 90 , 88 , 86 , 83 , 81 , 79 , 77
	db 75 , 72 , 70 , 68 , 66 , 64 , 62 , 61 , 59 , 57 , 55 , 53 , 52 , 50 , 48 , 47
	db 45 , 44 , 42 , 41 , 40 , 38 , 37 , 36 , 35 , 34 , 33 , 32 , 31 , 30 , 29 , 28
	db 27 , 26 , 26 , 25 , 24 , 24 , 23 , 23 , 23 , 22 , 22 , 22 , 21 , 21 , 21
	db 0

.DX:
	db 32, 30, 28, 26, 24, 22, 20, 18, 16, 14, 12, 10, 8, 6, 4, 2
.DY:
	db 32, 30, 28, 26, 24, 22, 20, 18, 16, 14, 12, 10, 8, 6, 4, 2
.DFG
	ds 16
.counter
    db 3