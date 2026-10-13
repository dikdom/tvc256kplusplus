; fileType - $01 buffered, $11 non-buffered
  db $11

; copyprotect - $00 no protection
  db $00

; number of blocks, lo-hi order. Program size in $80 sized blocks
  dw ((PROGRAM_END - PROGRAM_START - 1) / $80 ) + 1

; lastblock bytes (0-$7f)
  db (PROGRAM_END - PROGRAM_START) % $80

; filled with zeroes
  ds ($80-$05)

; always $00
  db $00

; type of file: 01h program file, $00 data file
  db $01

; program size in bytes lo/hi order
  dw (PROGRAM_END - PROGRAM_START)

; autorun if $ff
  db $00

; always $00
  ds ($90-$85)