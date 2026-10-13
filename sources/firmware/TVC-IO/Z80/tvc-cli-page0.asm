command_recs:        
            DW      cmd_mkauto 
            DB      6, "MKAUTO"
            DW      cmd_mkdir 
            DB      5, "MKDIR"
            DW      cmd_lcdsr
            DB      5, "LCDSR"
            DW      cmd_umdsk 
            DB      5, "UMDSK"
            DW      cmd_help 
            DB      4, "HELP"
            DW      cmd_exit 
            DB      4, "EXIT"
            DW      cmd_mdsk 
            DB      4, "MDSK"
            dw      cmd_pwd
            db      3, "PWD"
            dw      cmd_del
            db      3, "DEL"
            dw      cmd_ren
            db      3, "REN"
            dw      cmd_cls
            db      3, "CLS"
            DW      cmd_dir
            db      3, "DIR"
            DW      cmd_ver
            db      3, "VER"
            dw      cmd_cd
            db      2, "CD"
            dw      cmd_ds
            db      2, "DS"
            DW      cmd_exit 
            DB      1, "X"
            DW      cmd_help 
            DB      1, "H"

            DW      0

cli_parser:
    ld hl, .cli_header_str
    call print_cstring
    LD  a, (CAS_IN_HW_REDIRECT_ADDR)
    LD  (TVC256_CAS_IN_REDIRECT_SAVE), a
    LD  a, (CAS_OUT_HW_REDIRECT_ADDR)
    LD  (TVC256_CAS_OUT_REDIRECT_SAVE), a
    LD  a, (TVC256_CAS_REDIRECT)
    LD  (CAS_IN_HW_REDIRECT_ADDR), a
    LD  (CAS_OUT_HW_REDIRECT_ADDR),A 

.cli_loop:
    ld hl, .cli_prompt
    call print_cstring
    
    rst $30
    db $24 ; ed-cfix
.char_read:
    rst $30
    db $a1 ; ed-chin
    LD      A,C 
    CP      $0D 
    JR      z,.cli_loop
    CP      $20 
    JR      z,.char_read
    CP      $1B ; Exit on ESC
    JP      z,cmd_exit
    LD      HL,TVC256_INPUT_AREA
    LD      (HL),A 
    INC     HL
.line_read_loop:      
    RST     $30 
    DB      $A1 
    LD      a,c 
    CP      $0D 
    JR      z,.line_done
    LD      (hl),a 
    INC     hl 
    LD      a,l 
    CP      $40 ; 64 chars should be enough
    JR      nz,.line_read_loop
.line_done:
    XOR     a 
    LD      (hl),a 
    LD      hl, command_recs 
    LD      de, TVC256_INPUT_AREA
    PUSH    hl
    INC     hl 
    INC     hl
    ld      b, (hl)
    inc     hl
.cmd_check_loop:
    ld a, (de)
    or a
    jr z, .check_next_cmd
    CP      $60 
;    JR      c,.upper_case
    AND     11011111B 
.upper_case:          
    cp (hl)
    jr nz, .check_next_cmd
    inc de
    inc hl
    djnz .cmd_check_loop
    jr .command_found
.check_next_cmd:      
    POP     hl
    inc hl
    inc hl
    ld a, (hl)
    inc a
    ld e, a
    ld d, 0
    add hl, de

    PUSH    hl 
    LD      a,(hl) 
    INC     hl 
    OR      (hl) 
    JR      z, .command_not_found
    INC     hl
    ld b,   (hl)
    inc     hl 
    LD      de, TVC256_INPUT_AREA
    JR      .cmd_check_loop 
.command_found:       
    POP     hl 
    PUSH    DE 
    LD      e,(hl) 
    INC     hl 
    LD      d,(hl) 
    EX      de,hl 
    POP     DE 
    JP      (hl) 
.command_not_found:   
    POP     hl 
    LD      hl,.cli_cmd_not_found_str
    CALL    print_cstring 
    JP      .cli_loop
.cli_header_str:
    db "** TVC256k++ IO Card - CLI **\r\n", 0
.cli_prompt:
    db "> ", 0
.cli_cmd_not_found_str:  
            db   "Command not found\r\n", 0 

cmd_help:
    ld hl, cmd_help_page1
    ld b, 1
    call SET_C_SAVE_INC
    jp TVC256_PAGE_ROM
cmd_help_exit:
    call RESTORE_INC_FROM_SAVE
    JP      cli_parser.cli_loop 

cmd_esc:
    XOR     A 
    LD      ($0B16),A 
    LD      ($0BE5),A 
    call    print_newline
cmd_exit:
    ld hl, .exit_str
    call print_cstring
    LD  a, (TVC256_CAS_IN_REDIRECT_SAVE)
    LD  (CAS_IN_HW_REDIRECT_ADDR), a
    LD  a, (TVC256_CAS_OUT_REDIRECT_SAVE)
    LD (CAS_OUT_HW_REDIRECT_ADDR), a
    RET
.exit_str:
    db "TVC256k++ CLI Exit. Bye!\r\n", 0

cmd_pwd:
    ld de, $DB00
    rst $30
    db $D6      ; PWD system call, bit 7 is set
    or a
    jp nz, io_failed
    ld hl, $DB00
    call print_pstring
.exit_pwd
    call print_newline
    jp cli_parser.cli_loop

cmd_cd:
    ld a, (de)
    or A
    jr z, cmd_pwd
    cp $20
    jr nz, .trailing_spcs_done
    inc de
    jr cmd_cd
.trailing_spcs_done:
    ex de, hl
    ld de, $DB01
    ld b, 0
.copy_loop
    ld a, (hl)
    or a
    jr z, .done_copying
    ld (de), a
    inc hl
    inc de
    inc b
    jr nz, .copy_loop
.done_copying:
    ld hl, $DB00
    ld (hl), b
    ex de, hl
    rst $30
    db $56      ; CD system call, bit 7 is clear
    or a
    jp nz, io_failed
    ld hl, .cd_ok_str
    call print_cstring
    jp cli_parser.cli_loop
.cd_ok_str:
    db "CD OK\r\n", 0

cmd_cls:
    RST     $30 
    DB      $05 
    ; LD      BC,$0101 
    ; RST     $30 
    ; DB      F_EDCPOS 
    jp cli_parser.cli_loop

cmd_dirw:
    ld de, $DB00
    rst $30
    db $D6
    or a
    jp nz, io_failed
    ld a, ($DB00)
    cp $01
    jr z, .skip_double_dot
    ld hl, .double_dot_str
    call print_cstring
.skip_double_dot:
    rst $30
    db $57
    or a
    jp nz, io_failed
.shortdir_read_loop:
    ld de, $DC00
    rst $30
    db $D8
    or a
    jp nz, io_failed
    ld a, ($DC00)
    or a
    jr z, .dirlist_end
    ld a, ($DD00)
    and $10
    jr z, .print_short_filename
    ld a, '['
    call print_char
.print_short_filename
    ld a, ($DC00)
    cp 13
    jr c, .print_fname
    ld hl, $DD05
    ld d, (hl)
    jr .print_fileName
.print_fname:
    ld hl, $DC00
    ld d, (hl)
.print_fileName:
    push de
    call print_pstring
    ld a, ($DD00)
    and $10
    jr z, .finished_fileName
    ld a, ']'
    call print_char
    pop de
    ld a, 2
    add d
    ld d, a
    push de
.finished_fileName:
    ld a, 9
    call print_char
    pop de
    ld a, d
    cp 8
    jr nc, .skip_extra_tab
    ld a, 9
    call print_char
.skip_extra_tab
    ld a, ($0b16)   ; check CTRL-ESC
    cp $FF
    jr nz, .check_simple_ctrl
    rst $30
    db $58
    or A
    jp nz, io_failed
    ld hl, break_str
    call print_cstring
    XOR     A 
    LD      ($0B16),A 
    LD      ($0BE5),A 
    jp cli_parser.cli_loop
.check_simple_ctrl
    ld a, ($0BE8)   ; check CTRL is down
    cp $04
    jr nz, .read_on
    ld hl, 5000
.wait_400ms_loop
    call wait_100us
    dec hl
    ld a, h
    or l
    jr nz, .wait_400ms_loop
.read_on
    jp .shortdir_read_loop
.dirlist_end:
    rst $30
    db $58
    or a
    jp nz, io_failed
    call print_newline
    ld hl, cmd_dir.dir_ok_str
    call print_cstring
    jp cli_parser.cli_loop

.double_dot_str:
    db "[..]", 9, 9, 0

cmd_dir:
    ld a, (de)
    or a
    jr z, .set_no_filter
    inc de
    cp $20
    jr z, cmd_dir
    cp '/'
    jr nz, .read_filter
    ld a, (de)
    cp 'w'
    jp z, cmd_dirw
    cp 'W'
    jp z, cmd_dirw
    jr .set_no_filter
.read_filter
    ld hl, $DF00
    ld (hl), 0
    ld hl, $DF02
    cp '*'
    jr nz,.read_filter_loop
    ld a, 1 ; ends-with
    ld ($DF00), a
    ld a, (de)
    inc de
    or a
    jr z, .set_no_filter
.read_filter_loop
    call .make_it_lowercase
    ld (hl), a
    ld a, (de)
    inc de
    inc hl
    or a
    jr nz, .read_filter_loop
    ld (hl), a
    ld a, l
    sub 2
    ld ($DF01), a ; len of filter string
    dec hl
    ld a, (hl)
    cp '*'
    jr nz, .full_fit
    ld (hl), 0
    ld hl, $DF00
    ld (hl), 2
    inc hl
    dec (hl)
    jr .scan_dir
.full_fit
    ld hl, $DF00
    xor a
    cp (hl)
    jr nz, .scan_dir
    ld (hl), 3
    jr .scan_dir
.set_no_filter:
    xor a
    ld ($DF00), a
    ld ($DF01), a
    ld ($DF02), a
.scan_dir:
    ld de, $DB00
    rst $30
    db $D6
    or a
    jp nz, io_failed
    ld a, ($DB00)
    cp $01
    jr z, .skip_double_dot
    ld hl, .dir_marker_str
    call print_cstring
    ld hl, .double_dot_str
    call print_cstring
.skip_double_dot:
    ld hl, TVC256_CARD_FREE
    ld de, TVC256_CARD_FREE+1
    xor a
    ld (hl), a
    ld bc, 4
    ldir
    rst $30
    db $57
    or a
    jp nz, io_failed
.dir_read_loop:
    ld de, $DC00
    rst $30
    db $D8
    or a
    jp nz, io_failed
    ld a, ($DC00)
    or a
    jp z, .dir_read_finished
    call .check_filter
    jr nz, .dir_read_loop
    ld a, ($DD00)
    and $10
    jr nz, .directory_entry
.file_entry
    ld hl, TVC256_CARD_FREE
    inc (hl)
    ld a, $20
    ld hl, $D980
    ld de, $D981
    ld (hl), a
    ld bc, 10
    ldir
    xor a
    ld (de), a
    dec hl
    push hl
    ld hl, ($DD01)
    ex de,hl
    ld hl, ($DD03)
.loop_sprintf
    push bc
    call DIV32b_BY_10
    pop bc
    pop hl
    add a, '0'
    ld (hl),A
    dec hl
    push hl
    ld hl, (TVC256_DIV_BY_10_QUO+2) ; cheating...
    ld a, d
    or e
    jr nz, .loop_sprintf
    ld a, l
    or h
    jr nz, .loop_sprintf
    pop hl
    ld hl, ($DD03)
    ld a, h
    or l
    ld hl, $D985
    jr z, .digitpos_set
    ld b, 5
.digitpos_find_loop
    ld a,(hl)
    cp $20
    jr z, .digitpos_set
    dec hl
    djnz .digitpos_find_loop
.digitpos_set
    call print_cstring
    ld hl, ($DD01)
    ex de, hl
    ld hl, (TVC256_CARD_FREE+1)
    add hl, de
    ld (TVC256_CARD_FREE+1), hl
    ld hl, ($DD03)
    ex de, hl
    ld hl, (TVC256_CARD_FREE+3)
    adc hl, de
    ld (TVC256_CARD_FREE+3), hl
    jr .direntry_name
.directory_entry:
    ld hl, .dir_marker_str
    call print_cstring
.direntry_name:
    ld hl, $DC00
    call print_pstring
    call print_newline
    ld a, ($0b16)   ; check CTRL-ESC
    cp $FF
    jr nz, .check_simple_ctrl
    rst $30
    db $58
    or A
    jp nz, io_failed
    ld hl, break_str
    call print_cstring
    XOR     A 
    LD      ($0B16),A 
    LD      ($0BE5),A 
    jp cli_parser.cli_loop
.check_simple_ctrl
    ld a, ($0BE8)   ; check CTRL is down
    cp $04
    jr nz, .read_on
    ld hl, 5000
.wait_400ms_loop
    call wait_100us
    dec hl
    ld a, h
    or l
    jr nz, .wait_400ms_loop
.read_on
    jp .dir_read_loop
.dir_marker_str:
    db "<DIR> ", 0
.dir_read_finished:
    ld a, (TVC256_CARD_FREE)
    ld l, a
    ld h, 0
    call PRINT_16BIT_DECIMAL_NUMBER
    ld hl, .files_str
    call print_cstring
    ld hl, TVC256_CARD_FREE+1
    ld de, TVC256_CARD_FREE+16
    call sprint_32b_int
    call print_cstring
    ld hl, .bytes_str
    call print_cstring
    rst $30
    db $58
    or A
    jp nz, io_failed
    ld hl, .dir_ok_str
    call print_cstring
    jp cli_parser.cli_loop
.make_it_lowercase
    cp 'A'
    ret c
    cp 'Z' + 1
    ret nc
    or 00100000B
    ret
.check_filter
    ld a, ($DF00)
    or a
    ret z
.check_rest_of_filters
    cp 3
    jr z, .check_full_fit
    cp 2
    jr z, .check_start_with
.check_ends_with
    ld hl, $DF00+1
    ld a, ($DC00)
    cp (hl)
    jr c, .no_filter_result    ; filename is smaller than filter string
    sub (hl)
    add 1
    ld l, a
    ld h, $DC
    ld de, $DF00+2
.check_ends_with_loop
    ld a, (de)
    or a
    ret z
    ld c, (hl)
    push af
    ld a, c
    call .make_it_lowercase
    ld c, a
    pop af
    cp c
    inc de
    inc hl
    jr z, .check_ends_with_loop
    ret
.no_filter_result
    xor a
    inc a
    ret
.check_start_with
    ld hl, $DF01
    ld a, ($DC00)
    cp (hl)
    jr c, .no_filter_result    ; filename is smaller than filter string
    ld hl, $DC01
    ld de, $DF02
.check_start_with_loop
    ld a, (de)
    or a
    ret z
    push af
    ld a, (hl)
    call .make_it_lowercase
    ld c, a
    ; push bc
    ; rst $30
    ; DB $21
    ; pop bc
    pop af
    cp c
    inc hl
    inc de
    jr z, .check_start_with_loop
    ret
.check_full_fit
    ld hl, $DF01
    ld a, ($DC00)
    cp (hl)
    ret nz
    ld hl, $DC01
    ld de, $DF02
    jr .check_start_with_loop

.dir_ok_str:
    db "DIR OK\r\n", 0
.files_str:
    db " file(s),", 0
.bytes_str:
    db " bytes\r\n", 0
.double_dot_str:
    db "..\r\n", 0
break_str
    db "Break\r\n", 0

; Prints a 32bit number's digit into a 12 bytes long, $00 terminated (included) string
; INPUT
;  HL - points to the 32bit number
;  DE - points to the 12 bytes free area, this is where the digits will be printed
; OUTPUT
;  HL - points into the 12 bytes area where the numbers starts. String ends with $00
;  AF, BC is remains intact
sprint_32b_int:
    push bc
    push af
    push hl
    push de
    pop hl
    inc de
    ld a, $20
    ld (hl), a
    ld bc, 10
    ldir
    pop hl
    xor a
    ld (de), a
    dec de
    push de
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a

.loop_sprintf
    call DIV32b_BY_10
    pop hl
    add a, '0'
    ld (hl),A
    dec hl
    push hl
    ld hl, (TVC256_DIV_BY_10_QUO+2)
    ld a, d
    or e
    jr nz, .loop_sprintf
    ld a, l
    or h
    jr nz, .loop_sprintf
    pop hl
    pop af
    pop bc
    ret


cmd_mkdir:
    call skip_spaces
.leading_spcs_done:
    ex de, hl
    ld de, $DB01
    ld b, 0
.copy_loop
    ld a, (hl)
    or a
    jr z, .done_copying
    cp $20
    jr z, .done_copying
    ld (de), a
    inc hl
    inc de
    inc b
    jr nz, .copy_loop
.done_copying:
    ld hl, $DB00
    ld (hl), b
    ex de, hl

    rst $30
    db $59      ; mkdir, independently to bit 7
    or a
    jp nz, io_failed
    ld hl, .mkdir_ok_str
    call print_cstring
    jp cli_parser.cli_loop
.mkdir_ok_str:
    db "MKDIR OK\r\n", 0

cmd_del:
    call skip_spaces
.leading_spcs_done:
    ex de, hl
    ld de, $DB01
    ld b, 0
.copy_loop
    ld a, (hl)
    or a
    jr z, .done_copying
    cp $20
    jr z, .done_copying
    ld (de), a
    inc hl
    inc de
    inc b
    jr nz, .copy_loop
.done_copying:
    ld hl, $DB00
    ld (hl), b
    ex de, hl
    rst $30
    db $5a      ; delete, independently to bit 7
    or a
    jp nz, io_failed
    ld hl, .delete_ok_str
    call print_cstring
    jp cli_parser.cli_loop
.delete_ok_str:
    db "DEL OK\r\n", 0

cmd_lcdsr:
    ld a, (TVC256_SELECTED_DRIVE)   ; exit if not USB is selected
    or a
    ld hl, no_valid_drive
    jr nz, .print_msg_and_exit

    ld de, $8000                ; getting current directory
    rst $30
    db $D6
    or a
    jp nz, io_failed

    ld hl, TVC256_IOPORT
    ld c, (hl)
    inc c
    inc c
    in a, (c)
    ld (TVC256_INCREMENT_SAVE), a
    xor a
    out (c), a
    dec c
    dec c

    ld a, REG_FUNCTON_PARAM_SELECT
    out (c), a
    inc c
    xor a
    out (c), a      ; set TVC ADDR $8000 as param input
    dec c

    ld hl, .caching_directory_str
    call print_cstring

    ld hl, $8000
    ld a, (hl)  ; len of current path
    ld e, a
    ld d, 0
    add hl, de
    inc hl      ; hl points right after the path
    ld a, 1
    ld (hl), a  ; set progress display enabled

    ld a, REG_FUNCTON_EXECUTE
    out (c), a
    inc c
    ld a, 15    ; copy-dir-to-psram
    out (c), a
.loop_forever:
    ld hl, 1000
.loop_wait
    dec hl
    ld a, h
    or l
    jr nz, .loop_wait
    in a, (c)
    cp $FF
    jr nz, .loop_forever
    dec c
    ld a, REG_FUNCTON_RESULT
    out (c), a
    inc c
    in a, (c)
    or a
    jr z, .function_ok
    ld hl, .caching_directory_failed
.print_msg_and_exit
    call print_cstring
    call .revert_reg_increment
    jp cli_parser.cli_loop
.function_ok
    ld hl, .caching_directory_done
    call print_cstring
    call .revert_reg_increment
    jp cli_parser.cli_loop
.revert_reg_increment
    ld a, (TVC256_IOPORT)
    add a, 2
    ld c, a
    ld a, (TVC256_INCREMENT_SAVE)
    out (c), a
    ret
.caching_directory_str:
    db "Loading current directory into slow RAM...\r\n", 0
.caching_directory_done:
    db "LCDSR OK\r\n",0
.caching_directory_failed:
    db "LCDSR FAILED\r\n",0

cmd_ren:
    call skip_spaces
.leading_spcs_done:
    ex de, hl
    ld de, $DB01
    call copy_string    
    push hl
    ld hl, $DB00
    ld (hl), b

    pop hl
    ex de, hl
    call skip_spaces
    ex de, hl
    push de
    inc de
    call copy_string
    pop hl
    ld (hl), b

    ld de, $DB00

    rst $30
    db $5B
    or a
    jp nz, io_failed
    ld hl, .rename_done_str
    call print_cstring
    jp cli_parser.cli_loop
.rename_done_str:
    db "REN OK\r\n", 0

cmd_mkauto:
    ld a, (TVC256_SELECTED_DRIVE)
    or a
    ld hl, no_valid_drive
    jr nz, .print_msg_and_exit
    ld de, $DF00
    rst $30
    db $D6      ; PWD system call, bit 7 is set
    or a
    jp nz, io_failed
    ld de, .autoload_filename
    rst $30
    db $53
    or a
    jp nz, io_failed
    ld hl, $DF00
    ld b, (hl)
    inc hl
.path_write_loop
    ld c, (hl)
    push bc
    rst $30
    db $51
    pop bc
    or a
    jp nz, io_failed
    inc hl
    djnz .path_write_loop
.done_with_path:
    rst $30
    DB $54
    or a
    jp nz, io_failed
    ld hl, .autoload_ok
.print_msg_and_exit
    call print_cstring
    jp cli_parser.cli_loop
.autoload_filename:
    db 14, "@/auto256k.tvc"
.autoload_ok
    db "MKAUTO OK\r\n", 0
.op_ok
    dz "ook\r\n";
.wr_ok
    dz "wok";
.cl_ok
    dz "cok\r\n";
.pw_ok
    dz "pok\r\n";
no_valid_drive
    db "Invalid source drive!\r\n", 0


skip_spaces:
    ld a, (de)
    or A
    jp z, missing_parameter
    cp $20
    ret nz
    inc de
    jr skip_spaces

cmd_ds:
    ld a, (de)
    or A
    jp z, .print_ds
    cp $20
    jr nz, .found_param
    inc de
    jr cmd_ds
.found_param
    cp 'u'
    jr z, .select_usb
    cp 'U'
    jr z, .select_usb
    cp 's'
    jr z, .select_slowram
    cp 'S'
    jr z, .select_slowram
    cp 'f'
    jr z, .select_flash
    cp 'F'
    jr z, .select_flash
    cp 'd'
    jr z, .select_dsk
    cp 'D'
    jr z, .select_dsk
    ld hl, .invalid_param_str
    jr .printhl_and_exit
.select_usb:
    xor a
    ld (TVC256_SELECTED_DRIVE), a
    jr .ds_done
.select_slowram:
    ld a, (TVC256_PSRAM_FS_VALID)
    or a
    ld hl, .no_valid_slowram_str
    jr z, .printhl_and_exit
    ld a, 1
    ld (TVC256_SELECTED_DRIVE), a
    jr .ds_done
.select_flash:
    ld a, 2
    ld (TVC256_SELECTED_DRIVE), a
    jr .ds_done
.select_dsk:
    ld a, (TVC256_DSK_FS_VALID)
    or a
    ld hl, .no_valid_dsk_str
    jr z, .printhl_and_exit
    ld a, 3
    ld (TVC256_SELECTED_DRIVE), a
    jr .ds_done
.ds_done:
    ld hl, .ds_ok_str
.printhl_and_exit
    call print_cstring
    jp cli_parser.cli_loop    
.no_valid_slowram_str:
    db "No valid filesystem in SlowRAM. Use LCDSR first!\r\n", 0
.no_valid_dsk_str:
    db "No valid filesystem in DSK Drive. Use MDSK first!\r\n", 0
.invalid_param_str:
    db "Unexpected parameter!\r\n", 0
.ds_ok_str:
    db "DS OK\r\n", 0
.print_ds:
    ld a, (TVC256_SELECTED_DRIVE)
    add a
    ld e, a
    ld d, 0
    ld hl, .drives
    add hl, de
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a
.print_ds_done
    push hl
    ld hl, .current_drive_str
    call print_cstring
    pop hl
    call print_cstring
    jp cli_parser.cli_loop
.current_drive_str:
    db "Current drive: ", 0
.drives
    dw .usb_ds_str
    dw .slowram_ds_str
    dw .flash_ds_str
    dw .dsk_ds_str
.usb_ds_str:
    db "USB\r\n", 0
.slowram_ds_str:
    db "SlowRAM\r\n", 0
.flash_ds_str:
    db "Flash\r\n", 0
.dsk_ds_str:
    db "DSK\r\n", 0

cmd_mdsk:
    ld a, (de)
    or A
    jp z, missing_parameter
    cp $20
    jr nz, .trailing_spcs_done
    inc de
    jr cmd_mdsk
.trailing_spcs_done:
    ex de, hl
    ld de, $DB01
    ld b, 0
.copy_loop
    ld a, (hl)
    or a
    jr z, .done_copying
    ld (de), a
    inc hl
    inc de
    inc b
    jr nz, .copy_loop
.done_copying:
    ld hl, $DB00
    ld (hl), b
    ex de, hl
    rst $30
    db $DF  ; mount
    or a
    jp nz, io_failed
    ld a, 3
    ld (TVC256_SELECTED_DRIVE), a
    ld hl, mdsk_ok_str
    call print_cstring
    jp cli_parser.cli_loop
.missing_parameter_str
    dz "Missing parameter"

umdsk_ok_str:
    dz "UNMOUNT DSK OK\r\n"
mdsk_ok_str equ umdsk_ok_str + 2

cmd_umdsk:
    rst $30
    db $5F
    or a
    jr nz, io_failed
    ld hl, umdsk_ok_str
    call print_cstring
    jp cli_parser.cli_loop

cmd_ver:
    ld hl, .version_str
    call print_cstring
    rst $30
    db $5D      ; get iobase
    ld a, REG_FW_VERSION_MAJOR
    out (C), a
    inc c
    in a, (c)
    dec c
    push bc
    
    call print_dec_byte
    ld a, '.'
    call print_char

    pop bc
    ld a, REG_FW_VERSION_MINOR
    out (C), a
    inc c
    in a, (c)
    push af
    cp 10
    jr nc, .zero_prefix_done
    ld a, '0'
    call print_char
.zero_prefix_done
    pop af
    call print_dec_byte

    call print_newline

    jp cli_parser.cli_loop
.version_str:
    db "TVC256k++ Firmware: v", 0

;
; copies bytes from HL to DE unctil (HL) is 0 or $20
copy_string:
    ld b, 0
.copy_string_loop:
    ld a, (hl)
    or a
    ret z
    cp $20
    ret z
    ld (de), a
    inc hl
    inc de
    inc b
    jr nz, .copy_string_loop
    ret

io_failed:
    ld hl, .io_failed_str
    push af
    call print_cstring
    pop af
    call print_hex_byte
    ld a, ':'
    call print_char
    ld hl, TVC256_CARD_RAM_AREA
    ld a, (hl)
    add a, 9
    ld l, a
    ld h, 0
    ld a, (hl)
    call print_hex_byte
    ld hl, .io_failed_str_closure
    call print_cstring
    jp cli_parser.cli_loop
.io_failed_str:
    db "IO operation failed (", 0
.io_failed_str_closure:
    db ")\r\n", 0
missing_parameter:
    ld hl, .missing_parameter_str
    call print_cstring
    jp cli_parser.cli_loop
.missing_parameter_str:
    db "Missing parameter!\r\n", 0

cli_header_str:
    db "** TVC256k++ IO Card - CLI **\r\n", 0
cli_prompt:
    db "> ", 0
cli_cmd_not_found_str:  
            db   "Command not found\r\n", 0 
