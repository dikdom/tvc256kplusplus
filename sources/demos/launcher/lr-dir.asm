
NUM_OF_ENTRIES:
	db 0
POS_OF_NEXT_ENTRY:
	dw 0
SUB_DIR
	db 0

get_current_path:
	ld de, CURRENT_PATH
	rst $30
	db TVC_FUNC_GET_PWD
	or a
	ret nz
	ld hl, CURRENT_PATH
	ld a, (hl)	; length of path
	inc hl
	ld e, a
	ld d, 0
	add hl, de
	xor a
	ld (hl), a
	ret
	

init_dirs:
    call get_current_path
    ret
	
close_dir_and_exit_with_error:
	rst $30
	db TVC_FUNC_CLOSE_DIR
	xor a
	inc a
	ret

close_dir_and_exit
	rst $30
	db TVC_FUNC_CLOSE_DIR
	
	call clear_de_index

	xor a
	ret

load_dir_entries
    rst $30
	db TVC_FUNC_OPEN_DIR
	or a
	ret nz
	
	xor a
    ld (NUM_OF_ENTRIES), a
	ld (SELECTED_LINE), a
	ld (WINDOW_POS), a
	ld (SUB_DIR), a
	ld hl, DIR_ENTRIES
	ld (POS_OF_NEXT_ENTRY), hl
	
	ld a, (CURRENT_PATH)
	cp 1
	jr z, .load_dir_loop
	
	ld de, DIR_ENTRIES
	ld hl, DIR_ENTRY_POIS
	ld (hl), e
	inc hl
	ld (hl), d
	ex de, hl
	ld (hl), $10
	ld de, 5
	add hl, de
	ex de, hl
	ld hl, .parent_dir_str
	ld bc, 4
	ldir
	ex de, hl
	ld (POS_OF_NEXT_ENTRY), hl
	ld a, 1
	ld (NUM_OF_ENTRIES), a
	ld (SUB_DIR), a
	
	
.load_dir_loop
	call print_de_index
	
	ld de, WORK_AREA
	
	rst $30
	db TVC_FUNC_READ_DIR
	
	or a
	jr nz, close_dir_and_exit_with_error
	
	ld a, (WORK_AREA)
	or a
	jr z, close_dir_and_exit
	
	ld a, (WORK_AREA)
	cp 1
	jr nz, .skip_current_dir
	ld a, (WORK_AREA + 1)
	cp '.'
	jr z, .load_dir_loop
.skip_current_dir:	
	call store_dir_entry
	
	ld hl, NUM_OF_ENTRIES
	ld a, (hl)
	cp $FF
	jr z, close_dir_and_exit
	
	jr .load_dir_loop
.parent_dir_str
  db 2
  dz ".."

print_de_index
	call di_and_page
	ld hl, PARAM_BASE_ADDR
	
	ld (hl), FUNC_SET_XY
	inc hl
	
	ld a, (BOX_X)
	inc a
	ld (hl), a
	inc hl
	ld a, (BOX_Y)
	inc a
	ld (hl), a
	inc hl
	
	ld (hl), FUNC_PRINT_HEX_BYTE
	inc hl
	ld a, (NUM_OF_ENTRIES)
	ld (hl), a
	
	ld a, (BASE_PORT)
	ld c, a
	
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	
	inc c
	ld a, 2
	out (c), a
	call wait_for_func
	
	call ei_and_page
	ret
	
clear_de_index
	call di_and_page
	ld hl, PARAM_BASE_ADDR
	
	ld (hl), FUNC_SET_XY
	inc hl
	
	ld a, (BOX_X)
	inc a
	ld (hl), a
	inc hl
	ld a, (BOX_Y)
	inc a
	ld (hl), a
	inc hl
	
	ld (hl), FUNC_PRINT_STRING_ASCII
	inc hl
	ld (hl), 32
	inc hl
	ld (hl), 32
	inc hl
	ld (hl), 0
	
	ld a, (BASE_PORT)
	ld c, a
	
	ld a, REG_FUNCTION_MULTI_EXECUTE
	out (c), a
	
	inc c
	ld a, 2
	out (c), a
	call wait_for_func
	call ei_and_page
	ret

store_dir_entry
	call di_and_page
	ld h, 0
	ld a, (NUM_OF_ENTRIES)
	ld l, a
	add hl, hl
	ld de, DIR_ENTRY_POIS
	add hl, de
	
	ld de, (POS_OF_NEXT_ENTRY)
	ld (VAR_NEWEL), de
	ld (hl), e
	inc hl
	ld (hl), d
	
	ld a, (WORK_AREA + 256) ; attrib
	ld (de), a
	inc de
	ld bc, 4
	ld hl, WORK_AREA + 257	; size of file
	ldir
	ld a, (WORK_AREA)
	ld c, a
	inc bc
	ld hl, WORK_AREA ; full name of file
	ldir
	xor a
	ld (de), a
	inc de
	ld (POS_OF_NEXT_ENTRY), de
	ld hl, NUM_OF_ENTRIES
	inc (hl)
	call ei_and_page
	ld a, (SUB_DIR)
	or a
	ld a, (hl)
	jr z, .root_dir
	cp 3
	ret c
.root_dir
	cp 2
	ret c
	ld a, (selected_sort_plan)
	or a
	ret z
	call INSERT_SORTED
	
	ret
	

; -----------------------------------------------------------------------------
; LOGARITMIKUS BESZÚRÁS RENDEZETT POINTER LISTÁBA (Max 255 elem)
; Bemenet:
;   HL : A pointer lista kezdőcíme
;   A  : A listában lévő elemek száma (N, kezdetben 1, max 254 az új elem előtt)
;   DE : Az új struktúrára mutató pointer
; 
; Feltételezett külső függvény:
;   COMPARE_PTR: Összehasonlítja a HL és DE regiszterben lévő pointereket.
;                Kimenet: CARRY flag beállítva (C), ha (HL) < (DE)
;                AF kivételével minden regisztert megőriz.
; -----------------------------------------------------------------------------

INSERT_SORTED:
    ; 1. Bemenetek elmentése a RAM változókba
	ld hl, DIR_ENTRY_POIS
	ld a, (SUB_DIR)
	or a
	jr z, .root_dir
	inc hl
	inc hl
	ld (VAR_BASE), HL
	ld a, (NUM_OF_ENTRIES)
	sub 2
    LD (VAR_N), A
	jr .params_ok
.root_dir:
    LD (VAR_BASE), HL
	
	ld a, (NUM_OF_ENTRIES)
	dec a
    LD (VAR_N), A
.params_ok
	ld de, (VAR_NEWEL)
    
    ; 2. Bináris keresés inicializálása
    LD B, 0                 ; Low index (B = 0)
    LD C, A                 ; High index (C = N)

.BSEARCH_LOOP:
    ; Ciklusfeltétel: amíg Low < High
    LD A, B
    CP C
    JR NC, .BSEARCH_DONE    ; Ha Low >= High, megvan a hely, kilépünk

    ; Mid = (Low + High) / 2
    ADD A, C                ; A = Low + High
    RRA                     ; A = (Low + High) / 2
    LD (VAR_MID), A         ; Mid index elmentése

    ; Memóriacím számítása a te PUSH BC / POP BC módszereddel (sokkal jobb!)
    PUSH BC                 ; Mentjük a Low (B) és High (C) indexeket
    
    LD L, A                 ; L = Mid
    LD H, 0                 ; H = 0
    ADD HL, HL              ; HL = Mid * 2
    LD BC, (VAR_BASE)       ; BC = Lista kezdőcíme
    ADD HL, BC              ; HL = &Array[Mid]
    
    ; Pointer kiolvasása HL-be (Little Endian)
    LD A, (HL)
    INC HL
    LD H, (HL)
    LD L, A                 ; HL = Array[Mid] pointer értéke
    
    POP BC                  ; Visszatöltjük a Low és High indexeket a kereséshez
    
    ; Összehasonlítás: Array[Mid] (HL) vs Új Pointer (DE)
    CALL COMPARE_PTR        
    
    LD A, (VAR_MID)         ; Mid index visszatöltése A-ba a döntéshez
    JR C, .IS_LESS

.IS_GREATER_OR_EQUAL:
    ; Ha Array[Mid] >= NewPtr, akkor High = Mid
    LD C, A                 ; C (High) = Mid
    JR .BSEARCH_LOOP

.IS_LESS:
    ; Ha Array[Mid] < NewPtr, akkor Low = Mid + 1
    INC A                   ; A = Mid + 1
    LD B, A                 ; B (Low) = Mid + 1
    JR .BSEARCH_LOOP

.BSEARCH_DONE:
    ; Itt a B regiszter tartalmazza a beszúrási indexet (I).
    ; EL KELL MENTENI, mert az LDDR meg fogja semmisíteni a BC regiszterpárt!
    LD A, B
    LD (VAR_I), A           ; Beszúrási index (I) biztonságba helyezése
    
    PUSH DE                 ; Új pointer (DE) megmentése a mozgatás idejére

    ; 3. A lista eltolása, hogy helyet csináljunk (ha szükséges)
    ; Eltolandó elemek száma = N - I
    LD A, (VAR_N)
    LD C, A                 ; C ideiglenesen N
    LD A, (VAR_I)
    LD B, A                 ; B ideiglenesen I
    
    LD A, C
    SUB B                   ; A = N - I
    JR Z, .DO_INSERT        ; Ha a végére szúrunk (N == I), nem kell tolni

    ; Mozgatandó bájtok száma: BC = (N - I) * 2
    LD L, A                 
    LD H, 0
    ADD HL, HL
    LD B, H
    LD C, L                 ; BC most a mozgatandó bájtok száma (Kész az LDDR-hez)

    ; Számoljuk ki az első szabad helyet a tömb végén: BaseAddr + N * 2
    LD A, (VAR_N)
    LD L, A
    LD H, 0
    ADD HL, HL              ; HL = N * 2
    LD DE, (VAR_BASE)
    ADD HL, DE              ; HL = &Array[N] (A cél blokk legvége utáni bájt)

    ; Az LDDR visszafelé másol, a cél és forrás blokk UTOLSÓ bájtjaira kell mutatni
    EX DE, HL               ; DE = &Array[N]
    INC DE                  ; DE = Cél utolsó bájtja (&Array[N] + 1)
    
    LD H, D
    LD L, E
    DEC HL
    DEC HL                  ; HL = Forrás utolsó bájtja (&Array[N] - 1)
    
    LDDR                    ; Memória feljebb tolása. FIGYELEM: Itt BC nullává válik!

.DO_INSERT:
    ; 4. Az új pointer (DE) beírása
    POP DE                  ; Új pointer visszatöltése a veremből

    ; Beszúrási cím: HL = BaseAddr + I * 2
    LD A, (VAR_I)           ; Visszavesszük a lementett I indexet!
    LD L, A
    LD H, 0
    ADD HL, HL              ; HL = I * 2
    
    LD BC, (VAR_BASE)
    ADD HL, BC              ; HL = BaseAddr + I * 2
    
    ; Pointer mentése (Little Endian formátumban)
    LD (HL), E
    INC HL
    LD (HL), D

    RET

; -----------------------------------------------------------------------------
; VÁLTOZÓK (RAM-ban)
; -----------------------------------------------------------------------------
VAR_BASE:   DW 0            ; 16-bites: A lista alapcíme
VAR_N:      DB 0            ; 8-bites: A listaelemek száma
VAR_MID:    DB 0            ; 8-bites: Temp változó a Mid indexnek
VAR_I:      DB 0            ; 8-bites: A megtalált beszúrási index (I)
VAR_NEWEL:  DW 0

COMPARE_PTR:
	call di_and_page
	push bc
	ld a, (hl)
	and $10
	ld b, a
	ld a, (de)
	and $10
	sub b
	jr z, .sameType
	push af
	call ei_and_page
	pop af
	pop bc
	ret
.sameType
	push de
	push hl
	
	inc hl	; 2x36clk compared to 85
	inc hl
	inc hl
	inc hl
	inc hl
	
	
	inc de
	inc de
	inc de
	inc de
	inc de
	
	ld a, (selected_sort_plan)
	cp 1	; no CAS selected for sort
	jr nz, .no_cas_first
	ld a, $10
	cp b
	jr z, .no_cas_first
	

	call ends_with_cas
	ld b, a
	push bc
	
	ex de, hl
	call ends_with_cas
	ex de, hl
	pop bc
	
	sub b
	jr z, .check_done
	jr .done
	
.check_done
.no_cas_first
	inc hl
	inc de
	ld a, (selected_sort_plan)
	cp 3
	jr z, .compare_loop_2
	
	
.compare_loop_1
	ld a, (de)
	cp 'A'
	jr c, .case_ok_asc1
	cp 'Z'+1
	jr nc, .case_ok_asc1
	add 'a' - 'A'
.case_ok_asc1
	ld b, a
	ld a, (hl)
	cp 'A'
	jr c, .case_ok_asc2
	cp 'Z'+1
	jr nc, .case_ok_asc2
	add 'a' - 'A'
.case_ok_asc2
	cp b
	inc hl
	inc de
	jr nz, .done
	ld a, (de)
	or a
	scf
	jr z, .done
	ld a, (hl)
	or a
	jr nz, .compare_loop_1
	jr .done

.compare_loop_2
	ld a, (hl)
	cp 'A'
	jr c, .case_ok_desc1
	cp 'Z'+1
	jr nc, .case_ok_desc1
	add 'a' - 'A'
.case_ok_desc1
	ld b, a
	ld a, (de)
	cp 'A'
	jr c, .case_ok_desc2
	cp 'Z'+1
	jr nc, .case_ok_desc2
	add 'a' - 'A'
.case_ok_desc2
	cp b
	inc hl
	inc de
	jr nz, .done
	ld a, (de)
	or a
	jr z, .done
	ld a, (hl)
	or a
	scf
	jr nz, .compare_loop_2

.done
	push af
	call ei_and_page
	pop af
	
	pop hl
	pop de
	pop bc
	
	ret

ends_with_cas
	push hl
	push de
	ld a, (de)
	cp 5
	jr c, .no_cas
	sub 3
	ld l, a
	ld h, 0
	add hl, de
	ex de, hl
	ld hl, .cas_ext
	ld b, 4
.check_cas_loop
	ld a, (de)
	cp 'a'
	jr c, .small_caps
	sub 'a'-'A'
.small_caps
	cp (hl)
	jr nz, .no_cas
	inc hl
	inc de
	djnz .check_cas_loop
.cas
	pop de
	pop hl
	xor a
	ret
.no_cas
	pop de
	pop hl
	ld a, 1
	ret
.cas_ext:
	db ".CAS"
