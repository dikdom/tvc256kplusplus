; CAS_CHIN D1               0b11010001
; CAS_CHOUT 51              0b01010001
; CAS_BKIN D2               0b11010010
; CAS_BKOUT 52              0b01010010
; CAS_OPEN D3               0b11010011
; CAS_CRTE 53               0b01010011
; CAS_CLOSE D4 (for read)   0b11010100
; CAS_CLOSE 54 (for write)  0b01010100
; CAS_VERIFY D5             0b11010101

CAS_IN_HW_REDIRECT_ADDR  EQU $0B05 
CAS_OUT_HW_REDIRECT_ADDR EQU $0B0D 

OPEN_FOR_READ_FILE_TYPE EQU $0BF3 ; 0x00 no open file, 0x01 buffered, 0x11 unbuffered
OPEN_FOR_WRITE_FILE_TYPE EQU $0D14 ; 0x00 no open file, 0x01 buffered, 0x11 unbuffered

VERIFY_ONGOING EQU  $0BF1   ;
AVAILABLE_FOR_GET EQU $0BF4 
REMAINING_BYTES EQU $0D05 ; in memory buffer
ERROR_CODE      EQU $0D0B
BUFFER      EQU     $0B6B ; 00: non-buffered, otherwise: buffered
END_OF_FILE EQU     $0B6E ; 00: file readable, otherwise: EOF reached
BORDER_COLOR EQU    $0B4F 
INK_COLOR   EQU     $0B4D 
PAPER_COLOR EQU     $0B4E 
PORT02_SHADOW EQU   $0003 
PORT03_SHADOW EQU   $0B11
WARM_FLAG EQU       $0B21 ; $ff means -> warm reset is being done
COLD_FLAG EQU       $0B22 ; $FF means -> cold reset needed
PICTURE     EQU     $0B51 

TVC256_PAGE_ROM EQU      $D7F0
TVC256_IOPORT EQU        $D800
TVC256_MEMSHADOW EQU     $D801  ; used in EXT
TVC256_FILEHANDLE EQU    $D802
TVC256_BLKIO_DEST EQU    $D806
TVC256_BLKIO_TOREAD EQU  $D808
TVC256_BORDER_SAVE EQU   $D80A
TVC256_BORDER_RED  EQU   $D80B
TVC256_BLKIO_SOURCE EQU  $D80C
TVC256_BLKIO_TOWRITE EQU $D80E
TVC256_CLOSE_TYPE    EQU $D80F ; 0 for read, 1 for write
TVC256_SELECTED_DRIVE  EQU $D810 ; 0 for no cache, 1 for cached -> 0: USB, 1: PSRAM, 2: Flash drive, 3: dsk drive
TVC256_INCREMENT_SAVE EQU $D811 ; for saving the current addr increment value, to restore it later
TVC256_DIRHANDLE EQU     $D812
TVC256_DIRNEXT_FLAG EQU  $D814   ; filled by dirnext_handler, 0 if 
TVC256_JUMP_CODE_ADDR EQU $D815  ; (2)
TVC256_EXT_VECTOR_ADDR EQU $D817 ; (2)
TVC256_ORIG_ISR EQU      $d819  ; (3)
TVC256_DIV_BY_10_QUO EQU $D81C ; (4)
TVC256_DIV_BY_10_CNT EQU $D820 ; (1)
TVC256_CARD_RAM_AREA EQU $D821 ; (1) one of these: $40, $70, $A0, $D0
TVC256_CAS_REDIRECT  EQU ($D822) ; (1)
TVC256_CAS_IN_REDIRECT_SAVE EQU ($D823) ; (1)
TVC256_CAS_OUT_REDIRECT_SAVE EQU ($D823) ; (1)
TVC256_PSRAM_FS_VALID EQU $D824 ; (1) 0: no fs copied to PSRAM, 1: fs copied to PSRAM
TVC256_DSK_FS_VALID EQU $D825 ; (1) 0: no valid DSK drive, 1: DSK drive is valid

TVC256_CARD_FREE     EQU $D880 ; ($80)

TVC256_INPUT_AREA  EQU   $D900
TVC256_OUTPUT_AREA EQU   $DA00

TVC256_OPEN_IN_MODE     EQU TVC256_INPUT_AREA
TVC256_OPEN_IN_TYPE     EQU TVC256_INPUT_AREA + 1
TVC256_OPEN_IN_FN_LEN   EQU TVC256_INPUT_AREA + 2
TVC256_OPEN_IN_FNAME    EQU TVC256_INPUT_AREA + 3
TVC256_OPEN_OUT_FHANDLE EQU TVC256_OUTPUT_AREA
TVC256_OPEN_OUT_FSIZE   EQU TVC256_OUTPUT_AREA + 4
TVC256_OPEN_OUT_FN_LEN  EQU TVC256_OUTPUT_AREA + 8
TVC256_OPEN_OUT_FNAME   EQU TVC256_OUTPUT_AREA + 9
TVC256_BLKIO_IN_FHANDLE EQU TVC256_INPUT_AREA
TVC256_BLKIO_IN_SIZE    EQU TVC256_INPUT_AREA + 4
TVC256_BLKIO_IN_DATA    EQU TVC256_INPUT_AREA + 6
TVC256_BLKIO_OUT_SIZE   EQU TVC256_OUTPUT_AREA

REG_MEMORY_ROM_PAGE       EQU $B7

REG_FUNCTON_EXECUTE       EQU $C0
REG_FUNCTON_PARAM_SELECT  EQU $C1
REG_FUNCTON_RESULT        EQU $C2
REG_FW_VERSION_MAJOR      EQU $C3
REG_FW_VERSION_MINOR      EQU $C4

REG_USB_DETECTED          EQU $D0
REG_USB_MSC_CMD           EQU $D6

TVC256_MSCMD_OPEN      EQU $01
TVC256_MSCMD_CLOSE     EQU $02
TVC256_MSCMD_READ      EQU $03
TVC256_MSCMD_WRITE     EQU $04
TVC256_MSCMD_OPENDIR   EQU $05
TVC256_MSCMD_CLOSEDIR  EQU $06
TVC256_MSCMD_READDIR   EQU $07
TVC256_MSCMD_WRITE_SRC EQU $08
TVC256_MSCMD_READ_DST  EQU $09
TVC256_MSCMD_SEEK      EQU $0a
TVC256_MSCMD_GETCWD    EQU $0b
TVC256_MSCMD_CHDIR     EQU $0c
TVC256_MSCMD_MKDIR     EQU $0d
TVC256_MSCMD_DELETE    EQU $0e
TVC256_MSCMD_RENAME    EQU $0f
TVC256_MSCMD_FSTAT     EQU $10
TVC256_MSCMD_FSYNC     EQU $11
TVC256_MSCMD_MOUNTDSK  EQU $12
TVC256_MSCMD_UNMOUNTDSK EQU $13
; TVC256_GET_IOBASE      EQU $12
; TVC256_GET_MEMBASE     EQU $13
; TVC256_MSCMD_MOUNTDSK  EQU $14


NUM_OF_FUNCTIONS EQU 16 ; 14

F_VIDMODE   EQU     $04 
F_EDCHOUT   EQU     $21 
F_EDBLKOUT  EQU     $22 
F_EDCPOS    EQU     $23

  DEFPAGE 0..1, $C000, $1800

  PAGE 0
;  CODE @ $C000

            DB      "MOPS" 
CARD_SHORT_NAME_LENGTH:  
            DB      6 
CARD_SHORT_NAME:     
            DB      "256k++" 
            ; .ORG    $C00B
  CODE @ $C00B 
            DW      init
            DB      NUM_OF_FUNCTIONS 
            DW      void_ret                ;  0 
            DW      chario_handler          ;  1
            DW      blockio_handler         ;  2
            DW      open_handler            ;  3
            DW      close_handler           ;  4 
            DW      verify_handler          ;  5
            DW      pwd_handler             ;  6
            DW      opendir_handler         ;  7
            DW      readdir_handler         ;  8
            DW      mkdir_handler           ;  9
            DW      delete_handler          ; 10
            DW      rename_handler          ; 11
            DW      seek_handler            ; 12
            DW      iobase_handler          ; 13
            DW      membase_handler         ; 14
            DW      mount_dsk_handler       ; 15
            ; .ORG    $C040 

  include "tvc-init.asm"
  include "tvc-tools.asm"
  include "tvc-func-chario.asm"
  include "tvc-func-open.asm"
  include "tvc-func-blkio.asm"
  include "tvc-func-close.asm"
  include "tvc-func-verify.asm"
  include "tvc-func-pwd.asm"
  include "tvc-func-dir.asm"
  include "tvc-func-mkdir.asm"
  include "tvc-func-delete.asm"
  include "tvc-func-rename.asm"
  include "tvc-func-seek.asm"
  include "tvc-cli-page0.asm"
  include "tvc-func-getbase.asm"
  include "tvc-func-mntdsk.asm"


macro MYJUMP
  ld a, REG_MEMORY_ROM_PAGE
  out (c), a
  inc c
  ld a, b
  out (c), a
.rom_page_check_loop:
  in a, (c)
  cp b
  jr nz, .rom_page_check_loop
  jp (hl)
endmacro

void_ret:
    ret
  
  ds TVC256_PAGE_ROM - $, $75
  code @ TVC256_PAGE_ROM
  MYJUMP
;  ds 75, $d800 - $
  
  PAGE 1
  include "tvc-cli-page1.asm"
  ds TVC256_PAGE_ROM - $, $75
  code @ TVC256_PAGE_ROM
  MYJUMP
;  ds 75, $d800 - $
    ret
  PAGE 0
  code ! $d7c0
  ret
  