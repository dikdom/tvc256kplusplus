help_str_page1:
;                    0        1         2         3         4         5         6   4    
            DB      "Available commands:\r\n"
            DB      " - HELP: prints the available commands (shortcut: H)\r\n" 
            DB      " - CD [dir]: prints the current directory or changes into\r\n" 
            DB      "   the given 'dir' directory\r\n" 
            DB      " - CLS: clears screen\r\n" 
            DB      " - DEL <file or directory>: deletes a file or an empty\r\n" 
            DB      "   directory\r\n"
            DB      " - DIR [/W]|[<flt>]: lists the directories and files in the\r\n" 
            DB      "   current directory. DIR /W prints condensed directory list\r\n"
            DB      "   <flt> can be any of *x or a* or simply a filename.\r\n"
            DB      " - DS <U|S|F|D> selects drive: Usb, Slowram, Flash or Dsk\r\n"
            DB      " - EXIT: exits from the CLI of the TVC256k++ IO card\r\n" 
            db      "   (shortcut: X, or press ESC)\r\n"
            DB      " - LCDSR: loads current USB directory content into slow RAM of\r\n"
            DB      "   TVC256k++ card. This will act as a readonly RAM filesystem.\r\n"
            DB      " - MKAUTO: makes an auto load file with the current directory, \r\n"
            DB      "   so next boot TVC256k++ will load this directory to slow RAM\r\n"
            DB      " - MDSK <dsk file>: mounts a .dsk file into the DSK Drive\r\n"
            DB      " - MKDIR <dir>: creates a new directory\r\n" 
            DB      " - PWD: prints the current directory (shortcut: CD)\r\n"
            DB      " - REN: <fileFrom> <fileTo> renames a file or a directory\r\n"
            DB      " - UMDSK: un-mounts the DSK Drive\r\n"
            DB      " - VER: prints the version of the firmware\r\n" 
            DB      0


; yes, this is a duplicate, but I didn't want to page in and out for just printing out 
; a C string...
print_cstring_page1:
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

cmd_help_page1
    LD      HL, help_str_page1
    CALL    print_cstring_page1
    ld hl,  cmd_help_exit
    ld b, 0
    ld a, (TVC256_IOPORT)
    ld c, a
    jp TVC256_PAGE_ROM
