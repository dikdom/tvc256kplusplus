;-------------------------------------------------------------------------------
; GoatTracker V2.73 playroutine
;
; NOTE: This playroutine source code does not fall under the GPL license!
; Use it, or song binaries created from it freely for any purpose, commercial
; or noncommercial.
;
; NOTE 2: This code is in the format of Magnus Lind's assembler from Exomizer.
; Does not directly compile on DASM etc.
;-------------------------------------------------------------------------------
TVC256k equ 1

debug   equ     00h

        ;Defines for the music data
        ;Patterndata notes

ENDPATT         = $00
INS             = $00
FX              = $40
FXONLY          = $50
NOTE            = $60
REST            = $bd
KEYOFF          = $be
KEYON           = $bf
FIRSTPACKEDREST = $c0
PACKEDREST      = $00

        ;Effects

DONOTHING       = $00
PORTAUP         = $01
PORTADOWN       = $02
TONEPORTA       = $03
VIBRATO         = $04
SETAD           = $05
SETSR           = $06
SETWAVE         = $07
SETWAVEPTR      = $08
SETPULSEPTR     = $09
SETFILTPTR      = $0a
SETFILTCTRL     = $0b
SETFILTCUTOFF   = $0c
SETMASTERVOL    = $0d
SETFUNKTEMPO    = $0e
SETTEMPO        = $0f

        ;Orderlist commands

PLAYERREPEAT          = $d0
TRANSDOWN       = $e0
TRANS           = $f0
TRANSUP         = $f0
LOOPSONG        = $ff

        ;Wave,pulse,filttable comands

LOOPWAVE        = $ff
LOOPPULSE       = $ff
LOOPFILT        = $ff
SETPULSE        = $80
SETFILTER       = $80
SETCUTOFF       = $00

;        ORG     base
 defs    low -$
        ;Jump table

        jp      mt_init
        jp      mt_play
    if TVC256k = 1
        jp      init_TVC256k
    endif
    IF (SOUNDSUPPORT != 0)
        jp      mt_playsfx      ;'C' channel, 'HL' note
    ENDIF
    IF (VOLSUPPORT != 0)
        jp      mt_setmastervol
    ENDIF

              IF (ZPGHOSTREGS == 0)
mt_temp1        db      00h
mt_temp2        db      00h
              ELSE
ghostfreqlo     db      00h
ghostfreqhi     db      00h
ghostpulselo    db      00h
ghostpulsehi    db      00h
ghostwave       db      00h
ghostad         db      00h
ghostsr         db      00h
ghostfiltcutlow db      00h
ghostfiltcutoff db      00h
ghostfiltctrl   db      00h
ghostfilttype   db      00h
mt_temp1        db      00h
mt_temp2        db      00h
              ENDIF

    if  TVC256k = 1
write_SID_
        push    af
        ld      a,b
        jr      wrtcont

write_SID
        push    af
        ld      a,b
        add     a,c
      if debug = 1
        ld      b,a
      endif
wrtcont add     a,0e0h
REGptc2 out     (00h),a
        pop     af
REGptc3 out     (00h),a
      if debug = 1
        push    hl
        ld      l,b
        ld      h,0d4h
        ld      (hl),a
        pop     hl
      endif
        ld      b,d
        ret

    else

write_SID
        push    af
        ld      a,b
        add     a,c
      if debug = 1
        ld      b,a
      endif
        out     (0eh),a
        pop     af
        out     (0fh),a
      if debug = 1
        push    hl
        ld      l,b
        ld      h,0d4h
        ld      (hl),a
        pop     hl
      endif
        ld      b,d
        ret

write_SID_
        push    af
        ld      a,b
        out     (0eh),a
        pop     af
        out     (0fh),a
      if debug = 1
        push    hl
        ld      l,b
        ld      h,0d4h
        ld      (hl),a
        pop     hl
      endif
        ld      b,d
        ret
    endif

    ;Author info

    IF (NOAUTHORINFO == 0)

authorinfopos   = $ + 20h
checkpos1:
      IF ((authorinfopos - checkpos1) > 15)
      define    authinfo
mt_tick0jumptbl:
        db      (mt_tick0_0 % 256)
        db      (mt_tick0_12 % 256)
        db      (mt_tick0_12 % 256)
        db      (mt_tick0_34 % 256)
        db      (mt_tick0_34 % 256)
        db      (mt_tick0_5 % 256)
        db      (mt_tick0_6 % 256)
        db      (mt_tick0_7 % 256)
        db      (mt_tick0_8 % 256)
        db      (mt_tick0_9 % 256)
        db      (mt_tick0_a % 256)
        db      (mt_tick0_b % 256)
        db      (mt_tick0_c % 256)
        db      (mt_tick0_d % 256)
        db      (mt_tick0_e % 256)
        db      (mt_tick0_f % 256)
      ENDIF

checkpos2:
      IF ((authorinfopos - checkpos2) > 4)
      define    effectjptbl
mt_effectjumptbl:
        db      (mt_effect_0 % 256)
        db      (mt_effect_12 % 256)
        db      (mt_effect_12 % 256)
        db      (mt_effect_3 % 256)
        db      (mt_effect_4 % 256)
      ENDIF

checkpos3:
      IF ((authorinfopos - checkpos3) > 1)
      define funktemptbl
mt_funktempotbl:
        db      08h,05h             ;.byte (8,5)
      ENDIF

        ;This is pretty stupid way of filling left-out space, but .ORG
        ;seemed to bug

checkpos4:
      IF ((authorinfopos - checkpos4) > 0) 
        db      00h                 ;.BYTE (0)
      ENDIF
checkpos5:
      IF ((authorinfopos - checkpos5) > 0)
        db      00h                 ;.BYTE (0)
      ENDIF
checkpos6:
      IF ((authorinfopos - checkpos6) > 0)
        db      00h                 ;.BYTE (0)
      ENDIF

mt_author:
        db      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        db      0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    ENDIF

        ;0 Instrument vibrato

mt_tick0_0:
    IF (NOEFFECTS == 0)
      IF (NOINSTRVIB == 0)
        ld      hl,mt_insvibparam-1
        add     hl,de
        ld      a,(hl)
        jr      mt_tick0_34
      ELSE
        IF (NOVIB == 0)
        xor     a
        jr      mt_tick0_34
        ENDIF
      ENDIF
    ENDIF

        ;1,2 Portamentos

mt_tick0_12:
    IF (NOVIB == 0)
                                        ;tay
                                        ;lda #$00
                                        ;sta mt_chnvibtime,x
        ld      (ix+mt_chnvibtime-dlt),00h;tya
    ENDIF

        ;3,4 Toneportamento, Vibrato

mt_tick0_34:
    IF (NOEFFECTS == 0)
      IF ((NOTONEPORTA == 0) || (NOPORTAMENTO == 0) || (NOVIB == 0))
        ld      (ix+mt_chnparam-dlt),a  ;sta mt_chnparam,x
        ld      a,(ix+mt_chnnewfx-dlt)  ;lda mt_chnnewfx,x
        ld      (ix+mt_chnfx-dlt),a     ;sta mt_chnfx,x
      ENDIF
        ret                             ;rts
    ENDIF

        ;5 Set AD

mt_tick0_5:
    IF (NOSETAD == 0)
      IF (BUFFEREDWRITES == 0)
        ld      b,05h
        call    write_SID               ;sta SIDBASE+$05,x
      ELSE
        IF (GHOSTREGS == 0)
        ld      (ix+mt_chnad-dlt),a     ;sta mt_chnad,x
        ELSE
        ld      (ix+ghostad-dlt),a      ;sta <ghostad,x
        ENDIF
      ENDIF
        ret                             ;rts
    ENDIF

        ;6 Set Sustain/Release

mt_tick0_6:
    IF (NOSETSR == 0)
      IF (BUFFEREDWRITES == 0)
        ld      b,06h
        call    write_SID               ;sta SIDBASE+$06,x
      ELSE
        IF (GHOSTREGS == 0)
        ld      (ix+mt_chnsr-dlt),a     ;sta mt_chnsr,x
        ELSE
        ld      (ix+ghostsr-dlt),a      ;sta <ghostsr,x
        ENDIF
      ENDIF
        ret                             ;rts
    ENDIF

        ;7 Set waveform

mt_tick0_7:
    IF (NOSETWAVE == 0)
        ld      (ix+mt_chnwave-dlt),a   ;sta mt_chnwave,x
        ret                             ;rts
    ENDIF

        ;8 Set wavepointer

mt_tick0_8:
    IF (NOSETWAVEPTR == 0)
        ld      (ix+mt_chnwaveptr-dlt),a;sta mt_chnwaveptr,x
      IF (NOWAVEDELAY == 0)
        xor     a                       ;lda #$00                        ;Make sure possible delayed
        ld      (ix+mt_chnwavetime-dlt),a;sta mt_chnwavetime,x            ;waveform execution goes
      ENDIF                             ;correctly
        ret                             ;rts
    ENDIF

        ;9 Set pulsepointer

mt_tick0_9:
    IF (NOSETPULSEPTR == 0)
        ld      (ix+mt_chnpulseptr-dlt),a;sta mt_chnpulseptr,x
        xor     a                       ;lda #$00                        ;Reset pulse step duration
        ld      (ix+mt_chnpulsetime-dlt),a;sta mt_chnpulsetime,x
        ret                             ;rts
    ENDIF

        ;a Set filtpointer

mt_tick0_a:
    IF (NOSETFILTPTR == 0)
      IF (NOFILTERMOD == 0)
        ld      e,00h                   ;ldy #$00
        ld      hl,mt_filttime+1
        ld      (hl),e                  ;sty mt_filttime+1
      ENDIF
mt_tick0_a_step:
        ld      (mt_filtstep+1),a       ;sta mt_filtstep+1
        ret                             ;rts
    ENDIF

        ;b Set filtcontrol (channels & resonance)

mt_tick0_b:
    IF (NOSETFILTCTRL == 0)
        ld      (mt_filtctrl+1),a       ;sta mt_filtctrl+1
    IF (NOSETFILTPTR == 0)
        or      a
        jr      z,mt_tick0_a_step       ;beq mt_tick0_a_step          ;If 0, stop also step-programming
    ELSE
        or      a
        jr      nz,mt_tick0_b_noset     ;bne mt_tick0_b_noset
        ld      (mt_filtstep+1),a       ;sta mt_filtstep+1
mt_tick0_b_noset:
              ENDIF
        ret                         ;   rts
              ENDIF

        ;c Set cutoff

mt_tick0_c:
    IF (NOSETFILTCUTOFF == 0)
        ld      (mt_filtcutoff+1),a     ;sta mt_filtcutoff+1
        ret                             ;rts
    ENDIF

        ;d Set mastervolume / timing mark

mt_tick0_d:
    IF (NOSETMASTERVOL == 0)
      IF (NOAUTHORINFO == 0)
        cp      10h                     ;cmp #$10
        jr      nc,mt_tick0_d_timing    ;bcs mt_tick0_d_timing
      ENDIF
mt_setmastervol:
        ld      (mt_masterfader+1),a    ;sta mt_masterfader+1
        ret                             ;rts
      IF (NOAUTHORINFO == 0)
mt_tick0_d_timing:
        ld      (mt_author+31),a        ;sta mt_author+31
        ret                             ;rts
      ENDIF
    ENDIF

        ;e Funktempo

mt_tick0_e:
    IF (NOFUNKTEMPO == 0)
        ld      e,a                     ;tay
        ld      hl,mt_speedlefttbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_speedlefttbl-1,y
        ld      (mt_funktempotbl),a     ;sta mt_funktempotbl
        ld      hl,mt_speedrighttbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_speedrighttbl-1,y
        ld      (mt_funktempotbl+1),a   ;sta mt_funktempotbl+1
        xor     a                       ;lda #$00
      IF (NOCHANNELTEMPO == 0)
        jr      mt_tick0_f_setglobaltempo;beq mt_tick0_f_setglobaltempo
      ENDIF
    ENDIF

        ;f Set Tempo

mt_tick0_f:
    IF ((NOCHANNELTEMPO == 0) && (NOGLOBALTEMPO == 0))
        or      a
        jp      m,mt_tick0_f_setchantempo;bmi mt_tick0_f_setchantempo     ;Channel or global tempo?
    ENDIF
mt_tick0_f_setglobaltempo:
    IF (NOGLOBALTEMPO == 0)
        ld      (mt_chntempo),a         ;sta mt_chntempo
      IF (NUMCHANNELS > 1)
        ld      (mt_chntempo+7),a       ;sta mt_chntempo+7
      ENDIF
      IF (NUMCHANNELS > 2)
        ld      (mt_chntempo+14),a      ;sta mt_chntempo+14
      ENDIF
        ret                             ;rts
    ENDIF
mt_tick0_f_setchantempo:
    IF (NOCHANNELTEMPO == 0)
        and     7fh                     ;and #$7f
        ld      (ix+mt_chntempo-dlt),a  ;sta mt_chntempo,x
        ret                             ;rts
    ENDIF

        ;Continuous effect code

        ;0 Instrument vibrato

    IF (NOINSTRVIB == 0)
mt_effect_0_delay:
        dec     (ix+mt_chnvibdelay-dlt) ;dec mt_chnvibdelay,x
mt_effect_0_donothing:
        jp      mt_done                 ;jmp mt_done
mt_effect_0:    
        or      a
        jr      z,mt_effect_0_donothing ;beq mt_effect_0_donothing         ;Speed 0 = no vibrato at all
        ld      a,(ix+mt_chnvibdelay-dlt);lda mt_chnvibdelay,x
        or      a
        jr      nz,mt_effect_0_delay    ;bne mt_effect_0_delay
    ELSE
mt_effect_0:
mt_effect_0_donothing:
        jp      mt_done                 ;jmp mt_done
    ENDIF

        ;4 Vibrato

mt_effect_4:
    IF (NOVIB == 0)
      IF (NOCALCULATEDSPEED == 0)
        ld      hl,mt_speedlefttbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_speedlefttbl-1,y
        IF (NONORMALSPEED == 0)
        or      a
        jp      m,mt_effect_4_nohibyteclear;bmi mt_effect_4_nohibyteclear
        ld      e,00h                   ;ldy #$00                        ;Clear speed highbyte
        ld      hl,mt_temp2
        ld      (hl),e                  ;sty <mt_temp2
        ENDIF
mt_effect_4_nohibyteclear:
        and     7fh                     ;and #$7f
        ld      (mt_effect_4_speedcmp+1),a;sta mt_effect_4_speedcmp+1
        ELSE
        xor     a                       ;lda #$00                        ;Clear speed highbyte
        ld      (mt_temp2),a            ;sta <mt_temp2
        ENDIF
        ld      a,(ix+mt_chnvibtime-dlt);lda mt_chnvibtime,x
        or      a
        jp      m,mt_effect_4_nodir     ;bmi mt_effect_4_nodir
      IF (NOCALCULATEDSPEED != 0)
        ld      hl,mt_speedlefttbl-1
        add     hl,de
        cp      (hl)                    ;cmp mt_speedlefttbl-1,y
      ELSE
mt_effect_4_speedcmp:
        cp      00h                     ;cmp #$00
      ENDIF
        jr      c,mt_effect_4_nodir2    ;bcc mt_effect_4_nodir2
        jr      z,mt_effect_4_nodir     ;beq mt_effect_4_nodir
        cpl                             ;eor #$ff
mt_effect_4_nodir:
                                        ;clc
mt_effect_4_nodir2:
        add     02h                     ;adc #$02
mt_vibdone:
        ld      (ix+mt_chnvibtime-dlt),a;sta mt_chnvibtime,x
        rra                             ;lsr
        jr      nc,mt_freqadd           ;bcc mt_freqadd
        jr      mt_freqsub              ;bcs mt_freqsub
    ENDIF

        ;1,2,3 Portamentos

mt_effect_3:
    IF (NOTONEPORTA == 0)
        ld      a,e                     ;tya
        or      a
        jr      z,mt_effect_3_found     ;beq mt_effect_3_found           ;Speed $00 = tie note
    ENDIF
mt_effect_12:
    IF ((NOTONEPORTA == 0) || (NOPORTAMENTO == 0))
      IF (NOCALCULATEDSPEED != 0)
        ld      hl,mt_speedlefttbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_speedlefttbl-1,y
        ld      (mt_temp2),a            ;sta <mt_temp2
      ENDIF
    ENDIF
    IF (NOPORTAMENTO == 0)

      IF (NOWAVECMD != 0)
        ld      a,(ix+mt_chnfx-dlt)     ;lda mt_chnfx,x
      ELSE
mt_effectnum:
        ld      a,00h                   ;lda #$00
      ENDIF
        cp      02h                     ;cmp #$02
        jr      c,mt_freqadd            ;bcc mt_freqadd
        jr      z,mt_freqsub            ;beq mt_freqsub
    ELSE
      IF (NOTONEPORTA == 0)
                                        ;sec
      ENDIF
    ENDIF
    IF (NOTONEPORTA == 0)
        ld      e,(ix+mt_chnnote-dlt)   ;ldy mt_chnnote,x
      IF (GHOSTREGS == 0)
        ld      a,(ix+mt_chnfreqlo-dlt) ;lda mt_chnfreqlo,x              ;Calculate offset to the
        ld      hl,mt_freqtbllo-FIRSTNOTE*2
        add     hl,de
        add     hl,de
        sub     (hl)                    ;sbc mt_freqtbllo-FIRSTNOTE,y    ;right frequency
        ld      b,a                     ;pha
        ld      a,(ix+mt_chnfreqhi-dlt) ;lda mt_chnfreqhi,x
      ELSE
        ld      a,(ix+ghostfreqlo-dlt)  ;lda <ghostfreqlo,x              ;Calculate offset to the
        ld      hl,mt_freqtbllo-FIRSTNOTE*2
        add     hl,de
        add     hl,de
        sub     (hl)                    ;sbc mt_freqtbllo-FIRSTNOTE,y    ;right frequency
        ld      b,a                     ;pha
        ld      a,(ix+ghostfreqhi-dlt)  ;lda <ghostfreqhi,x
      ENDIF
        inc     hl                      ;           mt_freqtblhi-FIRSTNOTE*2
        sbc     (hl)                    ;sbc mt_freqtblhi-FIRSTNOTE,y
        ld      e,a                     ;tay
        ld      a,b                     ;pla
        ld      b,d
        jr      nc,mt_effect_3_down     ;bcs mt_effect_3_down            ;If positive, have to go down

mt_effect_3_up:
        ld      hl,(mt_temp1)           ;adc <mt_temp1                   ;Add speed to offset
        add     a,l
        ld      a,e                     ;tya                             ;If changes sign, we're done
        adc     a,h                     ;adc <mt_temp2
        jp      p,mt_effect_3_found     ;bpl mt_effect_3_found
    ENDIF


    IF ((NOTONEPORTA == 0) || (NOPORTAMENTO == 0) || (NOVIB == 0))
mt_freqadd:
        ld      hl,(mt_temp1)
      IF (GHOSTREGS == 0)
        ld      a,l                     ;lda mt_chnfreqlo,x
        add     a,(ix+mt_chnfreqlo-dlt) ;adc <mt_temp1
        ld      (ix+mt_chnfreqlo-dlt),a ;sta mt_chnfreqlo,x
        ld      a,h                     ;lda mt_chnfreqhi,x
        adc     a,(ix+mt_chnfreqhi-dlt) ;adc <mt_temp2
      ELSE
        ld      a,l                     ;lda <ghostfreqlo,x
        add     a,(ix+ghostfreqlo-dlt)  ;adc <mt_temp1
        ld      (ix+ghostfreqlo-dlt),a  ;sta <ghostfreqlo,x
        ld      a,h                     ;lda <ghostfreqhi,x
        adc     a,(ix+ghostfreqhi-dlt)  ;adc <mt_temp2
      ENDIF
        jp      mt_storefreqhi          ;jmp mt_storefreqhi
    ENDIF

    IF (NOTONEPORTA == 0)
mt_effect_3_down:
        ld      hl,(mt_temp1)
        sub     l                       ;sbc <mt_temp1                   ;Subtract speed from offset
        ld      a,e                     ;tya                             ;If changes sign, we're done
        sbc     h                       ;sbc <mt_temp2
        jp      m,mt_effect_3_found     ;bmi mt_effect_3_found
    ENDIF

    IF ((NOTONEPORTA == 0) || (NOPORTAMENTO == 0) || (NOVIB == 0))
mt_freqsub:
        ld      hl,(mt_temp1)
      IF (GHOSTREGS == 0)
        ld      a,(ix+mt_chnfreqlo-dlt) ;lda mt_chnfreqlo,x
        sub     l                       ;sbc <mt_temp1
        ld      (ix+mt_chnfreqlo-dlt),a ;sta mt_chnfreqlo,x
        ld      a,(ix+mt_chnfreqhi-dlt) ;lda mt_chnfreqhi,x
      ELSE
        ld      a,(ix+ghostfreqlo-dlt)  ;lda <ghostfreqlo,x
        sub     l                       ;sbc <mt_temp1
        ld      (ix+ghostfreqlo-dlt),a  ;sta <ghostfreqlo,x
        ld      a,(ix+ghostfreqhi-dlt)  ;lda <ghostfreqhi,x
      ENDIF
        sbc     h                       ;sbc <mt_temp2
        jp      mt_storefreqhi          ;jmp mt_storefreqhi
    ENDIF

mt_effect_3_found:
    IF (NOTONEPORTA == 0)
      IF (NOCALCULATEDSPEED == 0)
        ld      a,(ix+mt_chnnote-dlt)   ;lda mt_chnnote,x
        jp      mt_wavenoteabs          ;jmp mt_wavenoteabs
      ELSE
        ld      e,(ix+mt_chnnote-dlt)   ;ldy mt_chnnote,x
        jp      mt_wavenote             ;jmp mt_wavenote
      ENDIF
    ENDIF

        ;Init routine

mt_init:
    IF (NUMSONGS > 1)
        ld      l,a                     ;sta mt_init+5
        add     a,a                     ;asl
        add     a,l                     ;adc #$00
    ENDIF
        ld      (mt_initsongnum+1),a    ;sta mt_initsongnum+1
        ret                             ;rts

        ;Play soundeffect -routine

    IF (SOUNDSUPPORT != 0)
        ;Sound FX init routine

mt_playsfx:
        ld      ix,dlt
        add     ix,bc
;        ld      l,a
;        ld      h,e                     ;sta mt_playsfxlo+1
        ;ld      (mt_playsfxlo+1),hl    ;sty mt_playsfxhi+1
        ld      a,(ix+mt_chnsfx-dlt)    ;lda mt_chnsfx,x                   ;Need a priority check?
        or      a
        jr      z,mt_playsfxok          ;beq mt_playsfxok
        ld      a,h                     ;tya                               ;Check address highbyte
        cp      (ix+mt_chnsfxhi-dlt)    ;cmp mt_chnsfxhi,x
        ret     c                       ;bcc mt_playsfxskip                ;Lower than current -> skip
        jr      nz,mt_playsfxok         ;bne mt_playsfxok                  ;Higher than current -> OK
        ld      a,l                     ;lda mt_playsfxlo+1                ;Check address lowbyte
        cp      (ix+mt_chnsfxlo-dlt)    ;cmp mt_chnsfxlo,x
        ret     c                       ;bcc mt_playsfxskip                ;Lower than current -> skip
mt_playsfxok:
                                        ;lda #$01
        ld      (ix+mt_chnsfx-dlt),01h  ;sta mt_chnsfx,x
;mt_playsfxlo:
        ;ld      hl,0000h                ;lda #$00
                                        ;sta mt_chnsfxlo,x
                                        ;mt_playsfxhi:
        ld      (ix+mt_chnsfxlo-dlt),l  ;lda #$00
        ld      (ix+mt_chnsfxhi-dlt),h  ;sta mt_chnsfxhi,x
;mt_playsfxskip:
        ret                             ;rts
    ENDIF

        ;Set mastervolume -routine

    IF ((VOLSUPPORT != 0) && (NOSETMASTERVOL != 0))
mt_setmastervol:
        ld      (mt_masterfader+1),a    ;sta mt_masterfader+1
        ret                             ;rts
    ENDIF

        ;Playroutine

mt_play:
    IF ((ZPGHOSTREGS == 0) && (GHOSTREGS != 0))
      if  TVC256k = 1
;        ld      a,(IOreg)
;        inc     a
;        ld      c,a
;        ld      a,0e0h
;        ld      hl,ghostregs
;        ld      b,19h
;mt_copyregs:
;        dec     c
;        out     (c),a
;        inc     a
;        inc     c
;        outi
;        jr      nz,mt_copyregs
        ld      a,0e0h
REGptc1 ld      bc,1900h
        out     (c),a
        ld      hl,ghostregs
        inc     c
        otir
      else

        ld      bc,0190fh               ;ldx #24                         ;In full ghosting mode copy
        ld      hl,ghostregs
        xor     a
mt_copyregs:
        out     (0eh),a                 ;lda ghostregs,x                 ;previous frame's SID values in one step
        inc     a                       ;sta SIDBASE,x
        outi                            ;dex
        jr      nz,mt_copyregs          ;bpl mt_copyregs
      endif
    ENDIF

        ld      c,b                     ;ldx #$00                        ;Channel index

        ;Song initialization

mt_initsongnum:
        ld      e,00h                   ;ldy #$00
        inc     e
        dec     e
        jp      m,mt_filtstep           ;bmi mt_filtstep
        ld      a,c                     ;txa
        ld      b,NUMCHANNELS*14        ;ldx #NUMCHANNELS * 14 - 1
        ld      hl,mt_chnsongptr
mt_resetloop:
        ld      (hl),a                  ;sta mt_chnsongptr,x             ;Reset sequencer + voice
        inc     hl                      ;dex                             ;variables on all channels
        djnz    mt_resetloop            ;bpl mt_resetloop
    IF (GHOSTREGS == 0)
      IF (NUMCHANNELS == 2)
        ld      b,12h
        call    write_SID_              ;sta SIDBASE+$12
      ENDIF
      IF (NUMCHANNELS == 1)
        ld      b,0bh
        call    write_SID_              ;sta SIDBASE+$0b
        ld      b,12h
        call    write_SID_              ;sta SIDBASE+$12
      ENDIF
        ld      b,15h
        call    write_SID_              ;sta SIDBASE+$15                ;Reset filter cutoff lowbyte
    ELSE
        ld      (ghostfiltcutlow),a     ;sta <ghostfiltcutlow
    ENDIF
        ld      (mt_filtctrl+1),a       ;sta mt_filtctrl+1             ;Switch filter off & reset
    IF (NOFILTER == 0)
        ld      (mt_filtstep+1),a       ;sta mt_filtstep+1             ;step-programming
    ENDIF
        dec     a
        ld      (mt_initsongnum+1),a    ;stx mt_initsongnum+1          ;Reset initflag
                                        ;tax
    IF (NUMCHANNELS == 3)
        call    mt_initchn              ;jsr mt_initchn
        ld      c,07h                   ;ldx #$07
        call    mt_initchn              ;jsr mt_initchn
        ld      c,0eh                   ;ldx #$0e
    ENDIF
    IF (NUMCHANNELS == 2)
        call    mt_initchn              ;jsr mt_initchn
        ld      c,07h                   ;ldx #$07
    ENDIF
mt_initchn:
        ld      ix,dlt
        add     ix,bc
    IF (NUMSONGS > 1)
        ld      a,e                     ;tya
        inc     e                       ;iny
        ld      (ix+mt_chnsongnum-dlt),a;sta mt_chnsongnum,x             ;Store index to songtable
    ENDIF
mt_defaulttempo:
                                        ;lda #DEFAULTTEMPO               ;Set default tempo
        ld      (ix+mt_chntempo-dlt),DEFAULTTEMPO   ;sta mt_chntempo,x
        ld      a,01h                   ;lda #$01
        ld      (ix+mt_chncounter-dlt),a;sta mt_chncounter,x             ;Reset counter
        ld      (ix+mt_chninstr-dlt),a  ;sta mt_chninstr,x               ;Reset instrument
        jp      mt_loadregswaveonly     ;jmp mt_loadregswaveonly          ;Load waveform

        ;Filter execution

mt_filtstep:
    IF (NOFILTER == 0)
        ld      e,00h                   ;ldy #$00                        ;See if filter stopped
        inc     e
        dec     e
        jr      z,mt_filtdone           ;beq mt_filtdone
      IF (NOFILTERMOD == 0)
mt_filttime:
        ld      a,00h                   ;lda #$00                        ;See if time left for mod.
        or      a
        jr      nz,mt_filtmod           ;bne mt_filtmod                  ;step
      ENDIF
mt_newfiltstep:
        ld      hl,mt_filttimetbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_filttimetbl-1,y          ;$80-> = set filt parameters
        or      a
        jr      z,mt_setcutoff          ;beq mt_setcutoff                ;$00 = set cutoff
      IF (NOFILTERMOD == 0)
        jp      p,mt_newfiltmod         ;bpl mt_newfiltmod
      ENDIF
mt_setfilt:
        add     a,a                     ;asl                             ;Set passband
        ld      (mt_filttype+1),a       ;sta mt_filttype+1
        ld      hl,mt_filtspdtbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_filtspdtbl-1,y           ;Set resonance/channel
        ld      (mt_filtctrl+1),a       ;sta mt_filtctrl+1
        ld      hl,mt_filttimetbl
        add     hl,de
        ld      a,(hl)                  ;lda mt_filttimetbl,y            ;Check for cutoff setting
        or      a
        jr      nz,mt_nextfiltstep2     ;bne mt_nextfiltstep2            ;following immediately
mt_setcutoff2:
        inc     e                       ;iny
mt_setcutoff:
        ld      hl,mt_filtspdtbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_filtspdtbl-1,y           ;Take cutoff value
        ld      (mt_filtcutoff+1),a     ;sta mt_filtcutoff+1
      IF (NOFILTERMOD == 0)
        jr      mt_nextfiltstep         ;jmp mt_nextfiltstep
mt_newfiltmod:
        ld      (mt_filttime+1),a       ;sta mt_filttime+1               ;$01-$7f = new modulation step
mt_filtmod:
        ld      hl,mt_filtspdtbl-1
        add     hl,de                   ;lda mt_filtspdtbl-1,y           ;Take filt speed
        ld      a,(hl)                  ;clc
        ld      hl,mt_filtcutoff+1
        add     a,(hl)                  ;adc mt_filtcutoff+1
        ld      (hl),a                  ;sta mt_filtcutoff+1
        ld      hl,mt_filttime+1
        dec     (hl)                    ;dec mt_filttime+1
        jr      nz,mt_storecutoff       ;bne mt_storecutoff
      ENDIF
mt_nextfiltstep:
        ld      hl,mt_filttimetbl
        add     hl,de
        ld      a,(hl)                  ;lda mt_filttimetbl,y           ;Jump in filttable?
mt_nextfiltstep2:
        cp      LOOPFILT                ;cmp #LOOPFILT
        inc     e                       ;iny
        ld      a,e                     ;tya
        jr      c,mt_nofiltjump         ;bcc mt_nofiltjump
        ld      hl,mt_filtspdtbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_filtspdtbl-1,y          ;Take jump point
mt_nofiltjump:
        ld      (mt_filtstep+1),a       ;sta mt_filtstep+1
mt_filtdone:
mt_filtcutoff:
        ld      a,00h                   ;lda #$00
mt_storecutoff:
      IF (GHOSTREGS == 0)
        ld      b,16h
        call    write_SID_              ;sta SIDBASE+$16
      ELSE
        ld      (ghostfiltcutoff),a     ;sta <ghostfiltcutoff
      ENDIF
    ENDIF
mt_filtctrl:
        ld      a,00h                   ;lda #$00
    IF (GHOSTREGS == 0)
        ld      b,17h
        call    write_SID_              ;sta SIDBASE+$17
    ELSE
        ld      (ghostfiltctrl),a       ;sta <ghostfiltctrl
    ENDIF
mt_filttype:
        ld      a,00h                   ;lda #$00
mt_masterfader:
        or      0fh                     ;ora #$0f                        ;Master volume fader
    IF (GHOSTREGS == 0)
        ld      b,18h
        call    write_SID_
;        ld      (SIDBASE+18h),a        ;sta SIDBASE+$18
    ELSE
        ld      (ghostfilttype),a       ;sta <ghostfilttype
    ENDIF

;        ld      c,00h
    IF (NUMCHANNELS == 3)
        call    mt_execchn              ;jsr mt_execchn
        ld      c,07h                   ;ldx #$07
        call    mt_execchn              ;jsr mt_execchn
        ld      c,0eh                   ;ldx #$0e
    ENDIF
    IF (NUMCHANNELS == 2)
        call    mt_execchn              ;jsr mt_execchn
        ld      c,07h                   ;ldx #$07
    ENDIF

        ;Channel execution

mt_execchn:
        ld      ix,dlt
        add     ix,bc
        dec     (ix+mt_chncounter-dlt)  ;dec mt_chncounter,x               ;See if tick 0
        jr      z,mt_tick0              ;beq mt_tick0

        ;Ticks 1-n

mt_notick0:
        jp      p,mt_effects            ;bpl mt_effects
        ld      a,(ix+mt_chntempo-dlt)  ;lda mt_chntempo,x               ;Reload tempo if negative

    IF (NOFUNKTEMPO == 0)
        cp      02h                     ;cmp #$02
        jr      nc,mt_nofunktempo       ;bcs mt_nofunktempo              ;Funktempo: bounce between
        ld      e,a                     ;tay                             ;funktable indexes 0,1
        xor     01h                     ;eor #$01
        ld      (ix+mt_chntempo-dlt),a  ;sta mt_chntempo,x
        ld      hl,mt_funktempotbl
        add     hl,de
        ld      a,(hl)                  ;lda mt_funktempotbl,y
        dec     a                       ;sbc #$00
    ENDIF

mt_nofunktempo:
        ld      (ix+mt_chncounter-dlt),a;sta mt_chncounter,x
mt_effects:
        jp      mt_waveexec             ;jmp mt_waveexec

        ;Sequencer repeat

mt_repeat:
    IF (NOREPEAT == 0)
        sub     PLAYERREPEAT                  ;sbc #REPEAT
        inc     (ix+mt_chnrepeat-dlt)   ;inc mt_chnrepeat,x
        cp      (ix+mt_chnrepeat-dlt)   ;cmp mt_chnrepeat,x
        jr      nz,mt_nonewpatt         ;bne mt_nonewpatt
mt_repeatdone:
        ld      (ix+mt_chnrepeat-dlt),00h;lda #$00
                                        ;sta mt_chnrepeat,x
        jr      mt_repeatdone2          ;beq mt_repeatdone2
    ENDIF

        ;Tick 0

mt_tick0:
    IF (NOEFFECTS == 0)
        ld      e,(ix+mt_chnnewfx-dlt)  ;ldy mt_chnnewfx,x               ;Setup tick 0 FX jumps
        ld      hl,mt_tick0jumptbl
        add     hl,de
        ld      a,(hl)                  ;lda mt_tick0jumptbl,y
        ld      (mt_tick0jump1+1),a     ;sta mt_tick0jump1+1
        ld      (mt_tick0jump2+1),a     ;sta mt_tick0jump2+1
    ENDIF

        ;Sequencer advance

mt_checknewpatt:
        ld      a,(ix+mt_chnpattptr-dlt);lda mt_chnpattptr,x             ;Fetch next pattern?
        or      a
        jr      nz,mt_nonewpatt         ;bne mt_nonewpatt
mt_sequencer:
        ld      e,(ix+mt_chnsongnum-dlt);ldy mt_chnsongnum,x
        ld      hl,mt_songtbllo
        add     hl,de
        add     hl,de
        ld      a,(hl)                  ;lda mt_songtbllo,y              ;Get address of sequence
        inc     hl                      ;sta <mt_temp1
        ld      h,(hl)                  ;lda mt_songtblhi,y
        ld      l,a
        ld      (mt_temp1),hl           ;sta <mt_temp2
        ld      e,(ix+mt_chnsongptr-dlt);ldy mt_chnsongptr,x
;        ld      hl,(mt_temp1)
        add     hl,de
        ld      a,(hl)                  ;lda (mt_temp1),y                ;Get pattern from sequence
        cp      LOOPSONG                ;cmp #LOOPSONG                   ;Check for loop
        jr      c,mt_noloop             ;bcc mt_noloop
        inc     hl                      ;iny
        ld      e,(hl)                  ;lda (mt_temp1),y
        ld      hl,(mt_temp1)           ;tay
        add     hl,de
        ld      a,(hl)                  ;lda (mt_temp1),y
mt_noloop:
    IF (NOTRANS == 0)
        cp      TRANSDOWN               ;cmp #TRANSDOWN                  ;Check for transpose
        jr      c,mt_notrans            ;bcc mt_notrans
        sub     TRANS                   ;sbc #TRANS
        ld      (ix+mt_chntrans-dlt),a  ;sta mt_chntrans,x
        inc     e                       ;iny
        inc     hl
        ld      a,(hl)                  ;lda (mt_temp1),y
    ENDIF
mt_notrans:
    IF (NOREPEAT == 0)
        cp      PLAYERREPEAT                  ;cmp #REPEAT                     ;Check for repeat
        jr      nc,mt_repeat            ;bcs mt_repeat
    ENDIF
        ld      (ix+mt_chnpattnum-dlt),a;sta mt_chnpattnum,x             ;Store pattern number
mt_repeatdone2:
        inc     e                       ;iny
                                        ;tya
        ld      (ix+mt_chnsongptr-dlt),e;sta mt_chnsongptr,x             ;Store songposition

        ;New note start

mt_nonewpatt:
        ld      e,(ix+mt_chninstr-dlt)  ;ldy mt_chninstr,x
    IF (FIXEDPARAMS == 0)
        ld      hl,mt_insgatetimer-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_insgatetimer-1,y
        ld      (ix+mt_chngatetimer-dlt),a;sta mt_chngatetimer,x
    ENDIF
        ld      a,(ix+mt_chnnewnote-dlt);lda mt_chnnewnote,x             ;Test new note init flag
        or      a
        jp      z,mt_nonewnoteinit      ;beq mt_nonewnoteinit
mt_newnoteinit:
                                        ;sec
        sub     NOTE                    ;sbc #NOTE
        ld      (ix+mt_chnnote-dlt),a   ;sta mt_chnnote,x
        xor     a                       ;lda #$00
    IF (NOEFFECTS == 0)
      IF ((NOTONEPORTA == 0) || (NOPORTAMENTO == 0) || (NOVIB == 0))
        ld      (ix+mt_chnfx-dlt),a     ;sta mt_chnfx,x                  ;Reset effect
      ENDIF
    ENDIF
        ld      (ix+mt_chnnewnote-dlt),a;sta mt_chnnewnote,x             ;Reset newnote action
    IF (NOINSTRVIB == 0)
        ld      hl,mt_insvibdelay-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_insvibdelay-1,y          ;Load instrument vibrato
        ld      (ix+mt_chnvibdelay-dlt),a;sta mt_chnvibdelay,x
      IF (NOEFFECTS == 0)
        ld      hl,mt_insvibparam-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_insvibparam-1,y
        ld      (ix+mt_chnparam-dlt),a  ;sta mt_chnparam,x
      ENDIF
    ENDIF
    IF (NOTONEPORTA == 0)
        ld      a,(ix+mt_chnnewfx-dlt)  ;lda mt_chnnewfx,x               ;If toneportamento, skip
        cp      TONEPORTA               ;cmp #TONEPORTA                  ;most of note init
        jr      z,mt_nonewnoteinit      ;beq mt_nonewnoteinit
    ENDIF

    IF (FIXEDPARAMS == 0)
        ld      hl,mt_insfirstwave-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_insfirstwave-1,y         ;Load first frame waveform
      IF (NOFIRSTWAVECMD == 0)
        or      a
        jr      z,mt_skipwave           ;beq mt_skipwave
        cp      0feh                    ;cmp #$fe
        jr      nc,mt_skipwave2         ;bcs mt_skipwave2                ;Skip waveform but load gate
      ENDIF
    ELSE
        ld      a,FIRSTWAVEPARAM        ;lda #FIRSTWAVEPARAM
    ENDIF
        ld      (ix+mt_chnwave-dlt),a   ;sta mt_chnwave,x
    IF ((NUMLEGATOINSTR > 0) || (NOFIRSTWAVECMD == 0))
        ld      a,0ffh                  ;lda #$ff
mt_skipwave2:
        ld      (ix+mt_chngate-dlt),a   ; sta mt_chngate,x                ;Reset gateflag
    ELSE
        inc     (ix+mt_chngate-dlt)     ;inc mt_chngate,x
    ENDIF
mt_skipwave:   

    IF (NOPULSE == 0)
        ld      hl,mt_inspulseptr-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_inspulseptr-1,y          ;Load pulseptr (if nonzero)
        or      a
        jr      z,mt_skippulse          ;beq mt_skippulse
        ld      (ix+mt_chnpulseptr-dlt),a;sta mt_chnpulseptr,x
      IF (NOPULSEMOD == 0)
                                        ;lda #$00                        ;Reset pulse step duration
        ld      (ix+mt_chnpulsetime-dlt),00h;sta mt_chnpulsetime,x
      ENDIF
    ENDIF
mt_skippulse:
    IF (NOFILTER == 0)
        ld      hl,mt_insfiltptr-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_insfiltptr-1,y           ;Load filtptr (if nonzero)
        or      a
        jr      z,mt_skipfilt           ;beq mt_skipfilt
        ld      (mt_filtstep+1),a       ;sta mt_filtstep+1
      IF (NOFILTERMOD == 0)
        xor     a                       ;lda #$00
        ld      (mt_filttime+1),a       ;sta mt_filttime+1
      ENDIF
    ENDIF
mt_skipfilt:
        ld      hl,mt_inswaveptr-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_inswaveptr-1,y           ;Load waveptr
        ld      (ix+mt_chnwaveptr-dlt),a;sta mt_chnwaveptr,x

        ld      hl,mt_inssr-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_inssr-1,y                ;Load Sustain/Release
    IF (BUFFEREDWRITES == 0)
        ld      b,06h
        call    write_SID               ;sta SIDBASE+$06,x
    ELSE
      IF (GHOSTREGS == 0)
        ld      (ix+mt_chnsr-dlt),a     ;sta mt_chnsr,x
      ELSE
        ld      (ix+ghostsr-dlt),a      ;sta <ghostsr,x
      ENDIF
    ENDIF
        ld      hl,mt_insad-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_insad-1,y                ;Load Attack/Decay
    IF (BUFFEREDWRITES == 0)
        ld      b,05h
        call    write_SID               ;sta SIDBASE+$05,x
    ELSE
      IF (GHOSTREGS == 0)
        ld      (ix+mt_chnad-dlt),a     ;sta mt_chnad,x
      ELSE
        ld      (ix+ghostad-dlt),a      ;sta <ghostad,x
      ENDIF
    ENDIF

    IF (NOEFFECTS == 0)
        ld      a,(ix+mt_chnnewparam-dlt);lda mt_chnnewparam,x            ;Execute tick 0 FX after
mt_tick0jump1:                          ;newnote init
        call    mt_tick0_0              ;jsr mt_tick0_0
    ENDIF
    IF (BUFFEREDWRITES == 0)
        jp      mt_loadregswaveonly     ;jmp mt_loadregswaveonly
    ELSE
        jp      mt_loadregs             ;jmp mt_loadregs
    ENDIF

    IF (NOWAVECMD == 0)
mt_wavecmd:
        jp      mt_execwavecmd          ;jmp mt_execwavecmd
    ENDIF

        ;Tick 0 effect execution

mt_nonewnoteinit:
    IF (NOEFFECTS == 0)
        ld      a,(ix+mt_chnnewparam-dlt);lda mt_chnnewparam,x            ;No new note init: exec tick 0
mt_tick0jump2:
        call    mt_tick0_0              ;jsr mt_tick0_0                  ;FX, and wavetable afterwards
    ENDIF

        ;Wavetable execution

mt_waveexec:
        ld      e,(ix+mt_chnwaveptr-dlt);ldy mt_chnwaveptr,x
        inc     e
        dec     e
        jr      z,mt_wavedone           ;beq mt_wavedone
        ld      hl,mt_wavetbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_wavetbl-1,y
    IF (NOWAVEDELAY == 0)
        cp      10h                     ;cmp #$10                        ;0-15 used as delay
        jr      nc,mt_nowavedelay       ;bcs mt_nowavedelay              ;+ no wave change
        cp      (ix+mt_chnwavetime-dlt) ;cmp mt_chnwavetime,x
        jr      z,mt_nowavechange       ;beq mt_nowavechange
        inc     (ix+mt_chnwavetime-dlt) ;inc mt_chnwavetime,x
        jr      nz,mt_wavedone          ;bne mt_wavedone
mt_nowavedelay:
        sub     10h                     ;sbc #$10
    ELSE
        jr      z,mt_nowavechange       ;beq mt_nowavechange
    ENDIF
    IF (NOWAVECMD == 0)
        cp      0e0h                    ;cmp #$e0
        jr      nc,mt_nowavechange      ;bcs mt_nowavechange
    ENDIF
        ld      (ix+mt_chnwave-dlt),a   ;sta mt_chnwave,x
mt_nowavechange:
        ld      hl,mt_wavetbl
        add     hl,de
        ld      a,(hl)                  ;lda mt_wavetbl,y
        cp      LOOPWAVE                ;cmp #LOOPWAVE                  ;Check for wavetable jump
        inc     e                       ;iny
        ld      a,e                     ;tya
        ccf
        jr      nc,mt_nowavejump        ;bcc mt_nowavejump
    IF (NOWAVECMD != 0)
                                        ;clc
    ENDIF
        ld      hl,mt_notetbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_notetbl-1,y
mt_nowavejump:
        ld      (ix+mt_chnwaveptr-dlt),a;sta mt_chnwaveptr,x
    IF (NOWAVEDELAY == 0)
                                        ;lda #$00
        ld      (ix+mt_chnwavetime-dlt),00h;sta mt_chnwavetime,x
    ENDIF

    IF (NOWAVECMD == 0)
        ld      hl,mt_wavetbl-2
        add     hl,de
        ld      a,(hl)                  ;lda mt_wavetbl-2,y
        cp      0e0h                    ;cmp #$e0
        jr      nc,mt_wavecmd           ;bcs mt_wavecmd
    ENDIF
        ld      hl,mt_notetbl-2
        add     hl,de
        ld      a,(hl)                  ;lda mt_notetbl-2,y

    IF ((NOTONEPORTA == 0) || (NOPORTAMENTO == 0) || (NOVIB == 0))
        inc     a
        dec     a
        jr      nz,mt_wavefreq          ;bne mt_wavefreq                 ;No frequency-change?

        ;No frequency-change / continuous effect execution

mt_wavedone:
      IF (REALTIMEOPTIMIZATION != 0)
        ld      a,(ix+mt_chncounter-dlt);lda mt_chncounter,x             ;No continuous effects on tick0
        or      a
        IF (PULSEOPTIMIZATION != 0)
        jr      z,mt_gatetimer          ;beq mt_gatetimer
        ELSE
        jr      z,mt_done               ;beq mt_done
        ENDIF
      ENDIF
      IF (NOEFFECTS == 0)
        ld      e,(ix+mt_chnfx-dlt)     ;ldy mt_chnfx,x
        IF (NOWAVECMD == 0)
          IFDEF mt_effectnum
        ld      hl,mt_effectnum+1
        ld      (hl),e                  ;sty mt_effectnum+1
          ENDIF
        ENDIF
        ld      hl,mt_effectjumptbl
        add     hl,de
        ld      a,(hl)                  ;lda mt_effectjumptbl,y
        ld      (mt_effectjump+1),a     ;sta mt_effectjump+1
        ld      e,(ix+mt_chnparam-dlt)  ;ldy mt_chnparam,x
      ELSE
        ld      e,(ix+mt_chninstr-dlt)  ;ldy mt_chninstr,x
        ld      hl,mt_insvibparam-1
        add     hl,de
        ld      e,(hl)                  ;lda mt_insvibparam-1,y
                                        ;tay
      ENDIF
mt_setspeedparam:
    IF (NOCALCULATEDSPEED != 0)
        ld      hl,mt_speedrighttbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_speedrighttbl-1,y
        ld      (mt_temp1),a            ;sta <mt_temp1
    ELSE
      IF (NONORMALSPEED == 0)
        ld      hl,mt_speedlefttbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_speedlefttbl-1,y
        or      a
        jp      m,mt_calculatedspeed    ;bmi mt_calculatedspeed
mt_normalspeed:
        ld      (mt_temp2),a            ;sta <mt_temp2
        ld      hl,mt_speedrighttbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_speedrighttbl-1,y
        ld      (mt_temp1),a            ;sta <mt_temp1
        jr      mt_effectjump           ;jmp mt_effectjump
      ELSE
        IF (NOZEROSPEED == 0)
        or      a
        jr      nz,mt_calculatedspeed   ;bne mt_calculatedspeed
mt_zerospeed:
        ld      hl,mt_temp1
        ld      (hl),e                  ;sty <mt_temp1
        inc     hl
        ld      (hl),e                  ;sty <mt_temp2
        jr      mt_effectjump           ;beq mt_effectjump
        ENDIF
      ENDIF
mt_calculatedspeed:
        ld      hl,mt_speedrighttbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_speedrighttbl-1,y
        ld      (mt_cscount+1),a        ;sta mt_cscount+1
        push    de                      ;sty mt_csresty+1
        ld      e,(ix+mt_chnlastnote-dlt);ldy mt_chnlastnote,x
        ld      hl,mt_freqtbllo-FIRSTNOTE*2
        add     hl,de                   ;lda mt_freqtbllo+1-FIRSTNOTE,y
        add     hl,de                   ;sec
        ld      e,(hl)                  ;sbc mt_freqtbllo-FIRSTNOTE,y
        inc     hl                      ;sta <mt_temp1
        ld      d,(hl)                  ;lda mt_freqtblhi+1-FIRSTNOTE,y
        inc     hl                      ;sbc mt_freqtblhi-FIRSTNOTE,y
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        sbc     hl,de
mt_cscount:
        ld      b,00h                   ;ldy #$00
        inc     b
        dec     b
        jr      z,mt_csresty            ;beq mt_csresty
mt_csloop:
        srl     h                       ;lsr
        rr      l                       ;ror <mt_temp1
                                        ;dey
        djnz    mt_csloop               ;bne mt_csloop
mt_csresty:
        pop     de                     ;ldy #$00
        ld      (mt_temp2),hl           ;sta <mt_temp2
    ENDIF
mt_effectjump:
        jp      mt_effect_0             ;jmp mt_effect_0
    ELSE
        jr      z,mt_wavedone           ;beq mt_wavedone
    ENDIF

        ;Setting note frequency

mt_wavefreq:
        jp      p,mt_wavenoteabs        ;bpl mt_wavenoteabs
        adc     a,(ix+mt_chnnote-dlt)   ;adc mt_chnnote,x
        and     7fh                     ;and #$7f
mt_wavenoteabs:
    IF (NOCALCULATEDSPEED == 0)
        ld      (ix+mt_chnlastnote-dlt),a;sta mt_chnlastnote,x
    ENDIF
        ld      e,a                     ;tay
mt_wavenote:
    IF (NOVIB == 0)
                                        ;lda #$00                        ;Reset vibrato phase
        ld      (ix+mt_chnvibtime-dlt),00h;sta mt_chnvibtime,x
    ENDIF
        ld      hl,mt_freqtbllo-FIRSTNOTE*2
        add     hl,de
        add     hl,de
        ld      a,(hl)                  ;lda mt_freqtbllo-FIRSTNOTE,y
    IF (GHOSTREGS == 0)
        ld      (ix+mt_chnfreqlo-dlt),a ;sta mt_chnfreqlo,x
        inc     hl                      ;       hl,mt_freqtblhi-FIRSTNOTE
        ld      a,(hl)                  ;lda mt_freqtblhi-FIRSTNOTE,y
mt_storefreqhi:
        ld      (ix+mt_chnfreqhi-dlt),a ;sta mt_chnfreqhi,x
    ELSE
        ld      (ix+ghostfreqlo-dlt),a  ;sta <ghostfreqlo,x
        inc     hl                      ;       hl,mt_freqtblhi-FIRSTNOTE
        ld      a,(hl)                  ;lda mt_freqtblhi-FIRSTNOTE,y
mt_storefreqhi:
        ld      (ix+ghostfreqhi-dlt),a  ;sta <ghostfreqhi,x
    ENDIF

        ;Check for new note fetch

    IF ((NOTONEPORTA != 0) && (NOPORTAMENTO != 0) && (NOVIB != 0))
mt_wavedone:
    ENDIF
mt_done:
    IF (PULSEOPTIMIZATION != 0)
        ld      a,(ix+mt_chncounter-dlt);lda mt_chncounter,x             ;Check for gateoff timer
mt_gatetimer:
      IF (FIXEDPARAMS == 0)
        cp      (ix+mt_chngatetimer-dlt);cmp mt_chngatetimer,x
      ELSE
        cp      GATETIMERPARAM          ;cmp #GATETIMERPARAM
      ENDIF
        jr      z,mt_getnewnote         ;beq mt_getnewnote               ;Fetch new notes if equal
    ENDIF

        ;Pulse execution
    IF (NOPULSE == 0)
mt_pulseexec:
        ld      e,(ix+mt_chnpulseptr-dlt);ldy mt_chnpulseptr,x            ;See if pulse stopped
        inc     e
        dec     e
        jr      z,mt_pulseskip          ;beq mt_pulseskip
      IF (PULSEOPTIMIZATION != 0)
        or      (ix+mt_chnpattptr-dlt)  ;ora mt_chnpattptr,x             ;Skip when sequencer executed
        jr      z,mt_pulseskip          ;beq mt_pulseskip
      ENDIF
      IF (NOPULSEMOD == 0)
        ld      a,(ix+mt_chnpulsetime-dlt);lda mt_chnpulsetime,x           ;Pulse step counter time left?
        or      a
        jr      nz,mt_pulsemod          ;bne mt_pulsemod
      ENDIF
mt_newpulsestep:
        ld      hl,mt_pulsetimetbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_pulsetimetbl-1,y         ;Set pulse, or new modulation
      IF (NOPULSEMOD == 0)
        or      a
        jp      p,mt_newpulsemod        ;bpl mt_newpulsemod              ;step?
      ENDIF
mt_setpulse:
      IF (SIMPLEPULSE == 0)
        IF (GHOSTREGS == 0)
        ld      (ix+mt_chnpulsehi-dlt),a;sta mt_chnpulsehi,x             ;Highbyte
        ELSE
        ld      (ix+ghostpulsehi-dlt),a ;sta <ghostpulsehi,x
        ENDIF
      ENDIF
        ld      hl,mt_pulsespdtbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_pulsespdtbl-1,y          ;Lowbyte
      IF (GHOSTREGS == 0)
        ld      (ix+mt_chnpulselo-dlt),a;sta mt_chnpulselo,x
      ELSE
        ld      (ix+ghostpulselo-dlt),a ;sta <ghostpulselo,x
        IF (SIMPLEPULSE != 0)
        ld      (ix+ghostpulsehi-dlt),a ;sta <ghostpulsehi,x
        ENDIF
      ENDIF
      IF (NOPULSEMOD == 0)
        jr      mt_nextpulsestep        ;jmp mt_nextpulsestep
mt_newpulsemod:
        ld      (ix+mt_chnpulsetime-dlt),a;sta mt_chnpulsetime,x
mt_pulsemod:
        IF (SIMPLEPULSE == 0)
        ld      hl,mt_pulsespdtbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_pulsespdtbl-1,y          ;Take pulse speed
        or      a                       ;clc
        jp      p,mt_pulseup            ;bpl mt_pulseup
          IF (GHOSTREGS == 0)
        dec     (ix+mt_chnpulsehi-dlt)  ;dec mt_chnpulsehi,x
mt_pulseup:
        add     a,(ix+mt_chnpulselo-dlt);adc mt_chnpulselo,x             ;Add pulse lowbyte
        ld      (ix+mt_chnpulselo-dlt),a;sta mt_chnpulselo,x
        jr      nc,mt_pulsenotover      ;bcc mt_pulsenotover
        inc     (ix+mt_chnpulsehi-dlt)  ;inc mt_chnpulsehi,x
          ELSE
        dec     (ix+ghostpulsehi-dlt)   ;dec <ghostpulsehi,x
mt_pulseup:
        add     a,(ix+ghostpulselo-dlt) ;adc <ghostpulselo,x             ;Add pulse lowbyte
        ld      (ix+ghostpulselo-dlt),a ;sta <ghostpulselo,x
        jr      nc,mt_pulsenotover      ;bcc mt_pulsenotover
        inc     (ix+ghostpulsehi-dlt)   ;inc <ghostpulsehi,x
          ENDIF
mt_pulsenotover:
        ELSE
          IF (GHOSTREGS == 0)
        ld      a,(ix+mt_chnpulselo-dlt);lda mt_chnpulselo,x
                                        ;clc
        ld      hl,mt_pulsespdtbl
        add     hl,de
        add     a,(hl)                  ;adc mt_pulsespdtbl-1,y
        adc     b                       ;adc #$00
        ld      (ix+mt_chnpulselo-dlt),a;sta mt_chnpulselo,x
          ELSE
        ld      a,(ix+ghostpulselo-dlt) ;lda <ghostpulselo,x
                                        ;clc
        ld      hl,mt_pulsespdtbl-1
        add     hl,de
        add     a,(hl)                  ;adc mt_pulsespdtbl-1,y
        adc     b                       ;adc #$00
        ld      (ix+ghostpulselo-dlt),a ;sta <ghostpulselo,x
        ld      (ix+ghostpulsehi-dlt),a ;sta <ghostpulsehi,x
          ENDIF
        ENDIF
        dec     (ix+mt_chnpulsetime-dlt);dec mt_chnpulsetime,x
        jr      nz,mt_pulsedone2        ;bne mt_pulsedone2
      ENDIF

mt_nextpulsestep:
        ld      hl,mt_pulsetimetbl
        add     hl,de
        ld      a,(hl)                  ;lda mt_pulsetimetbl,y           ;Jump in pulsetable?
        cp      LOOPPULSE               ;cmp #LOOPPULSE
        inc     e                       ;iny
        ld      a,e                     ;tya
        jr      c,mt_nopulsejump        ;bcc mt_nopulsejump
        ld      hl,mt_pulsespdtbl-1
        add     hl,de
        ld      a,(hl)                  ;lda mt_pulsespdtbl-1,y          ;Take jump point
mt_nopulsejump:
        ld      (ix+mt_chnpulseptr-dlt),a;sta mt_chnpulseptr,x
mt_pulsedone:
      IF (BUFFEREDWRITES == 0)
        ld      a,(ix+mt_chnpulselo-dlt);lda mt_chnpulselo,x
      ENDIF
mt_pulsedone2:
      IF (BUFFEREDWRITES == 0)
        ld      b,02h
        call    write_SID               ;sta SIDBASE+$02,x
        IF (SIMPLEPULSE == 0)
        ld      a,(ix+mt_chnpulsehi-dlt);lda mt_chnpulsehi,x
        ENDIF
        ld      b,03h
        call    write_SID               ;sta SIDBASE+$03,x
      ENDIF
mt_pulseskip:
    ENDIF

    IF (PULSEOPTIMIZATION == 0)
        ld      a,(ix+mt_chncounter-dlt);lda mt_chncounter,x             ;Check for gateoff timer
mt_gatetimer:
      IF (FIXEDPARAMS == 0)
        cp      (ix+mt_chngatetimer-dlt);cmp mt_chngatetimer,x
      ELSE
        cp      GATETIMERPARAM          ;cmp #GATETIMERPARAM
      ENDIF
;        jr      z,mt_getnewnote        ;beq mt_getnewnote               ;Fetch new notes if equal
        jp      nz, mt_loadregs         ;jmp mt_loadregs
    ELSE
        jp      mt_loadregs             ;jmp mt_loadregs
    ENDIF
        ;New note fetch

mt_getnewnote:
        ld      e,(ix+mt_chnpattnum-dlt);ldy mt_chnpattnum,x
        ld      hl,mt_patttbllo
        add     hl,de
        add     hl,de
        ld      a,(hl)                  ;lda mt_patttbllo,y
        inc     hl                      ;sta <mt_temp1
        ld      h,(hl)                  ;lda mt_patttblhi,y
        ld      l,a
        ld      (mt_temp1),hl           ;sta <mt_temp2
        ld      e,(ix+mt_chnpattptr-dlt);ldy mt_chnpattptr,x
        add     hl,de
        ld      a,(hl)                  ;lda (mt_temp1),y
        cp      FX                      ;cmp #FX
        jr      c,mt_instr              ;bcc mt_instr                    ;Instr. change
    IF (NOEFFECTS == 0)
        cp      NOTE                    ;cmp #NOTE
        jr      c,mt_fx                 ;bcc mt_fx                       ;FX
    ENDIF
        cp      FIRSTPACKEDREST         ;cmp #FIRSTPACKEDREST
        jr      c,mt_note               ;bcc mt_note                     ;Note only

        ;Packed rest handling

mt_packedrest:
        ld      a,(ix+mt_chnpackedrest-dlt);lda mt_chnpackedrest,x
        or      a
        jr      nz,mt_packedrestnonew   ;bne mt_packedrestnonew
        ;ld      hl,(mt_temp1)
        ld      a,(hl)                  ;lda (mt_temp1),y
mt_packedrestnonew:
        inc     a                       ;adc #$00
        ld      (ix+mt_chnpackedrest-dlt),a;sta mt_chnpackedrest,x
        jr      z,mt_rest               ;beq mt_rest
        jr      mt_loadregs             ;bne mt_loadregs

        ;Instrument change

mt_instr:
        ld      (ix+mt_chninstr-dlt),a  ;sta mt_chninstr,x               ;Instrument change, followed
        inc     e                       ;iny
        inc     hl                      ;           ld      hl,(mt_temp1)
        ld      a,(hl)                  ;lda (mt_temp1),y                ;by either FX or note
    
    IF (NOEFFECTS == 0)
        cp      NOTE                    ;cmp #NOTE
        jr      nc,mt_note              ;bcs mt_note

        ;Effect change

mt_fx:
        cp      FXONLY                  ;cmp #FXONLY                     ;Note follows?
        push    af
        and     0fh                     ;and #$0f
        ld      (ix+mt_chnnewfx-dlt),a  ;sta mt_chnnewfx,x
        or      a
        jr      z,mt_fx_noparam         ;beq mt_fx_noparam               ;Effect 0 - no param.
        inc     e                       ;iny
        inc     hl                      ;           ld      hl,(mt_temp1)
        ld      a,(hl)                  ;lda (mt_temp1),y
        ld      (ix+mt_chnnewparam-dlt),a;sta mt_chnnewparam,x
mt_fx_noparam:
        pop     af
        jr      nc,mt_rest              ;bcs mt_rest
mt_fx_getnote:
        inc     e                       ;iny
        inc     hl                      ;           ld      hl,(mt_temp1)
        ld      a,(hl)                  ;lda (mt_temp1),y
    ENDIF

        ;Note handling

mt_note:
        cp      REST                    ;cmp #REST                   ;Rest or gateoff/on?
    IF (NOGATE == 0)
        jr      c,mt_normalnote         ;bcc mt_normalnote
    ENDIF
        jr      z,mt_rest               ;beq mt_rest
mt_gate:
    IF (NOGATE == 0)
        or      0f0h                    ;ora #$f0
        jr      mt_setgate              ;bne mt_setgate
    ENDIF

        ;Prepare for note start; perform hardrestart

mt_normalnote:
    IF (NOTRANS == 0)
        add     a,(ix+mt_chntrans-dlt)  ;adc mt_chntrans,x
    ENDIF
        ld      (ix+mt_chnnewnote-dlt),a;sta mt_chnnewnote,x
    IF (NOTONEPORTA == 0)
        ld      a,(ix+mt_chnnewfx-dlt)  ;lda mt_chnnewfx,x           ;If toneportamento, no gateoff
        cp      TONEPORTA               ;cmp #TONEPORTA
        jr      z,mt_rest               ;beq mt_rest
    ENDIF
    IF (((NUMHRINSTR > 0) && (NUMNOHRINSTR > 0)) || (NUMLEGATOINSTR > 0))
        ld      a,(ix+mt_chninstr-dlt)  ;lda mt_chninstr,x
        cp      FIRSTNOHRINSTR          ;cmp #FIRSTNOHRINSTR         ;Instrument order:
      IF (NUMLEGATOINSTR > 0)
        jr      nc,mt_nohr_legato       ;bcs mt_nohr_legato          ;With HR - no HR - legato
      ELSE
        jr      nc,mt_skiphr            ;bcs mt_skiphr
      ENDIF
    ENDIF
    IF (NUMHRINSTR > 0)
        ld      a,SRPARAM               ;lda #SRPARAM                ;Hard restart 
      IF (BUFFEREDWRITES == 0)
        ld      b,06h
        call    write_SID               ;sta SIDBASE+$06,x
      ELSE
        IF (GHOSTREGS == 0)
        ld      (ix+mt_chnsr-dlt),a     ;sta mt_chnsr,x
        ELSE
        ld      (ix+ghostsr-dlt),a      ;sta <ghostsr,x
        ENDIF
      ENDIF
        ld      a,ADPARAM               ;lda #ADPARAM
      IF (BUFFEREDWRITES == 0)
        ld      b,05h
        call    write_SID               ;sta SIDBASE+$05,x
      ELSE
        IF (GHOSTREGS == 0)
        ld      (ix+mt_chnad-dlt),a     ;sta mt_chnad,x
        ELSE
        ld      (ix+ghostad-dlt),a      ;sta <ghostad,x
        ENDIF
      ENDIF
  
    ENDIF
mt_skiphr:
        ld      a,0feh                  ;lda #$fe
mt_setgate:
        ld      (ix+mt_chngate-dlt),a   ;sta mt_chngate,x

        ;Check for end of pattern

mt_rest:
        inc     e                       ;iny
        ld      hl,(mt_temp1)
        add     hl,de
        ld      a,(hl)                  ;lda (mt_temp1),y
        or      a
        jr      z,mt_endpatt            ;beq mt_endpatt
        ld      a,e                     ;tya
mt_endpatt:
        ld      (ix+mt_chnpattptr-dlt),a;sta mt_chnpattptr,x

        ;Load voice registers

mt_loadregs:
    IF (BUFFEREDWRITES == 0)
        ld      a,(ix+mt_chnfreqlo-dlt) ;lda mt_chnfreqlo,x
;        ld      b,d                     ;ld      b,00h
        call    write_SID               ;sta SIDBASE+$00,x
        ld      a,(ix+mt_chnfreqhi-dlt) ;lda mt_chnfreqhi,x
        ld      b,01h
        call    write_SID               ;sta SIDBASE+$01,x
mt_loadregswaveonly:
        ld      a,(ix+mt_chnwave-dlt)   ;lda mt_chnwave,x
        and     (ix+mt_chngate-dlt)     ;and mt_chngate,x
        ld      b,04h
        call    write_SID               ;sta SIDBASE+$04,x
    ELSE
      IF (SOUNDSUPPORT != 0)
        ld      e,(ix+mt_chnsfx-dlt)    ;ldy mt_chnsfx,x
        inc     e
        dec     e
        jr      nz,mt_sfxexec           ;bne mt_sfxexec
      ENDIF
      IF (GHOSTREGS == 0)
        ld      a,(ix+mt_chnad-dlt)     ;lda mt_chnad,x
        ld      b,05h
        call    write_SID               ;sta SIDBASE+$05,x
        ld      a,(ix+mt_chnsr-dlt)     ;lda mt_chnsr,x
        ld      b,06h
        call    write_SID               ;sta SIDBASE+$06,x
        ld      a,(ix+mt_chnpulselo-dlt);lda mt_chnpulselo,x
        IF (SIMPLEPULSE == 0)
        ld      b,02h
        call    write_SID               ;sta SIDBASE+$02,x
        ld      a,(ix+mt_chnpulsehi-dlt);lda mt_chnpulsehi,x
        ld      b,03h
        call    write_SID               ;sta SIDBASE+$03,x
        ELSE
        ld      b,02h
        call    write_SID               ;sta SIDBASE+$02,x
        ld      b,03h
        call    write_SID               ;sta SIDBASE+$03,x
        ENDIF
mt_loadregswavefreq:
        ld      a,(ix+mt_chnfreqlo-dlt) ;lda mt_chnfreqlo,x
;        ld      b,d                     ;       ld      b,00h
        call    write_SID               ;sta SIDBASE+$00,x
        ld      a,(ix+mt_chnfreqhi-dlt) ;lda mt_chnfreqhi,x
        ld      b,01h
        call    write_SID               ;sta SIDBASE+$01,x
mt_loadregswaveonly:
        ld      a,(ix+mt_chnwave-dlt)   ;lda mt_chnwave,x
        and     (ix+mt_chngate-dlt)     ;and mt_chngate,x
        ld      b,04h
        call    write_SID               ;sta SIDBASE+$04,x
      ELSE
mt_loadregswaveonly:
        ld      a,(ix+mt_chnwave-dlt)   ;lda mt_chnwave,x
        and     (ix+mt_chngate-dlt)     ;and mt_chngate,x
        ld      (ix+ghostwave-dlt),a    ;sta <ghostwave,x
      ENDIF
    ENDIF
        ret                             ;rts

    IF (NUMLEGATOINSTR > 0)
mt_nohr_legato:
        cp      FIRSTLEGATOINSTR        ;cmp #FIRSTLEGATOINSTR
        jr      c,mt_skiphr             ;bcc mt_skiphr
        jr      mt_rest                 ;bcs mt_rest
    ENDIF

        ;Sound FX code

    IF (SOUNDSUPPORT != 0)
      IF (GHOSTREGS == 0)

        ;Sound FX code without ghostregs

mt_sfxexec:
        ld      l,(ix+mt_chnsfxlo-dlt)  ;lda mt_chnsfxlo,x
                                        ;sta <mt_temp1
        ld      h,(ix+mt_chnsfxhi-dlt)  ;lda mt_chnsfxhi,x
        ld      (mt_temp1),hl           ;sta <mt_temp2
                                        ;lda #$fe
        ld      (ix+mt_chngate-dlt),0feh;sta mt_chngate,x
        xor     a                       ;lda #$00
        ld      (ix+mt_chnwaveptr-dlt),a;sta mt_chnwaveptr,x
        inc     (ix+mt_chnsfx-dlt)      ;inc mt_chnsfx,x
        ld      d,a
        ld      a,e
        cp      02h                     ;cpy #$02
        ld      a,d
        ld      d,b
        jr      z,mt_sfxexec_frame0     ;beq mt_sfxexec_frame0
        jr      nc,mt_sfxexec_framen    ;bcs mt_sfxexec_framen
        ld      b,06h
        call    write_SID               ;sta SIDBASE+$06,x                ;Hardrestart before sound FX
        ld      b,05h
        call    write_SID               ;sta SIDBASE+$05,x                ;begins
        jr      mt_loadregswavefreq     ;bcc mt_loadregswavefreq
mt_sfxexec_frame0:
        ld      e,a                     ;tay
;        ld      hl,(mt_temp1)
        add     hl,de
        ld      a,(hl)                  ;lda (mt_temp1),y           ;Load ADSR
        ld      b,05h
        call    write_SID               ;sta SIDBASE+$05,x
;        inc     e                       ;iny
        inc     hl                      ;       ld      hl,(mt_temp1)
        ld      a,(hl)                  ;lda (mt_temp1),y
        ld      b,06h
        call    write_SID               ;sta SIDBASE+$06,x
;        inc     e                       ;iny
        inc     hl                      ;       ld      hl,(mt_temp1)
        ld      a,(hl)                  ;lda (mt_temp1),y           ;Load pulse
        ld      b,02h
        call    write_SID               ;sta SIDBASE+$02,x
        ld      b,03h
        call    write_SID               ;sta SIDBASE+$03,x
        ld      a,09h                   ;lda #$09                   ;Testbit
mt_sfxexec_wavechg:
        ld      (ix+mt_chnwave-dlt),a   ;sta mt_chnwave,x
        ld      b,04h
        jp      write_SID               ;sta SIDBASE+$04,x
;mt_sfxexec_done:
;                                       ;rts
mt_sfxexec_framen:
        ld      hl,(mt_temp1)
        add     hl,de
        ld      a,(hl)                  ;lda (mt_temp1),y
        or      a
        jr      nz,mt_sfxexec_noend     ;bne mt_sfxexec_noend
mt_sfxexec_end:
        ld      (ix+mt_chnsfx-dlt),a    ;sta mt_chnsfx,x
        jr      mt_sfxexec_wavechg      ;beq mt_sfxexec_wavechg
mt_sfxexec_noend:
        ld      e,a                     ;tay
        ld      hl,mt_freqtbllo-$80*2
        add     hl,de
        add     hl,de
        ld      a,(hl)                  ;lda mt_freqtbllo-$80,y        ;Get frequency
;        ld      b,d                     ;       ld      b,00h
        call    write_SID               ;sta SIDBASE+$00,x
        inc     hl                      ;       hl,mt_freqtblhi-$80*2
        ld      a,(hl)                  ;lda mt_freqtblhi-$80,y
        ld      b,01h
        call    write_SID               ;sta SIDBASE+$01,x
        ld      e,(ix+mt_chnsfx-dlt)    ;ldy mt_chnsfx,x
        ld      hl,(mt_temp1)
        add     hl,de
        ld      a,(hl)                  ;lda (mt_temp1),y              ;Then take a look at the next
        or      a
        ret     z                       ;beq mt_sfxexec_done           ;byte
        cp      82h                     ;cmp #$82                      ;Is it a waveform or a note?
        ret     nc                      ;bcs mt_sfxexec_done
        inc     (ix+mt_chnsfx-dlt)      ;inc mt_chnsfx,x
        jr      mt_sfxexec_wavechg      ;bcc mt_sfxexec_wavechg
      ELSE

        ;Sound FX code with ghostregs

mt_sfxexec:
        ld      l,(ix+mt_chnsfxlo-dlt)  ;lda mt_chnsfxlo,x
                                        ;sta <mt_temp1
        ld      h,(ix+mt_chnsfxhi-dlt)  ;lda mt_chnsfxhi,x
        ld      (mt_temp1),hl           ;sta <mt_temp2
                                        ;lda #$fe
        ld      (ix+mt_chngate-dlt),0feh;sta mt_chngate,x
        xor     a                       ;lda #$00
        ld      (ix+mt_chnwaveptr-dlt),a;sta mt_chnwaveptr,x
        inc     (ix+mt_chnsfx-dlt)      ;inc mt_chnsfx,x
        ld      d,a
        ld      a,e
        cp      02h                     ;cpy #$02
        ld      a,d
        ld      d,b
        jr      c,mt_sfxexec_fr1        ;bcc mt_sfxexec_fr1                  ;Hardrestart frame?
        jr      z,mt_sfxexec_fr2        ;beq mt_sfxexec_fr2                  ;First or nth frame?
mt_sfxexec_fr3:
;        ld      hl,(mt_temp1)
        add     hl,de
        ld      a,(hl)                  ;lda (mt_temp1),y
        or      a
        jr      nz,mt_sfxexec_noend     ;bne mt_sfxexec_noend
mt_sfxexec_end:
        ld      (ix+mt_chnsfx-dlt),a    ;sta mt_chnsfx,x
        jr      mt_sfxexec_wavechg      ;beq mt_sfxexec_wavechg
mt_sfxexec_noend:
        ld      e,a                     ;tay
        ld      hl,mt_freqtbllo-$80*2
        add     hl,de
        add     hl,de
        ld      a,(hl)                  ;lda mt_freqtbllo-$80,y        ;Get frequency
        ld      (ix+ghostfreqlo-dlt),a  ;sta <ghostfreqlo,x
        inc     hl                      ;       hl,mt_freqtblhi-$80*2
        ld      a,(hl)                  ;lda mt_freqtblhi-$80,y
        ld      (ix+ghostfreqhi-dlt),a  ;sta <ghostfreqhi,x
        ld      e,(ix+mt_chnsfx-dlt)    ;ldy mt_chnsfx,x
        ld      hl,(mt_temp1)
        add     hl,de
        ld      a,(hl)                  ;lda (mt_temp1),y              ;Then take a look at the next
        or      a
        jr      z,mt_sfxexec_done       ;beq mt_sfxexec_done           ;byte
        cp      82h                     ;cmp #$82                      ;Is it a waveform or a note?
        jr      nc,mt_sfxexec_done      ;bcs mt_sfxexec_done
        inc     (ix+mt_chnsfx-dlt)      ;inc mt_chnsfx,x
mt_sfxexec_wavechg:
        ld      (ix+mt_chnwave-dlt),a   ;sta mt_chnwave,x
        ld      (ix+ghostwave-dlt),a    ;sta <ghostwave,x
mt_sfxexec_done:
        ld      e,00h                   ;ldy #$00
        ld      hl,(mt_temp1)
        add     hl,de
        ld      a,(hl)                  ;lda (mt_temp1),y             ;Load ADSR
        ld      (ix+ghostad-dlt),a      ;sta <ghostad,x
;        inc     e                       ;iny
        inc     hl
        ld      a,(hl)                  ;lda (mt_temp1),y
        ld      (ix+ghostsr-dlt),a      ;sta <ghostsr,x
;        inc     e                       ;iny
        inc     hl
        ld      a,(hl)                  ;lda (mt_temp1),y             ;Load pulse
        ld      (ix+ghostpulselo-dlt),a ;sta <ghostpulselo,x
        ld      (ix+ghostpulsehi-dlt),a ;sta <ghostpulsehi,x
        ret                             ;rts

mt_sfxexec_fr1:
        ld      (ix+ghostad-dlt),a      ;sta <ghostad,x               ;Hardrestart before sound FX
        ld      (ix+ghostsr-dlt),a      ;sta <ghostsr,x               ;begins
        jp      mt_loadregswaveonly     ;bcc mt_loadregswaveonly

mt_sfxexec_fr2:
        ld      a,09h                   ;lda #$09
        jr      mt_sfxexec_wavechg      ;bne mt_sfxexec_wavechg

      ENDIF
    ENDIF

        ;Wavetable command exec

    IF (NOWAVECMD == 0)
mt_execwavecmd:
        and     0fh                     ;and #$0f
        ld      (mt_temp1),a            ;sta <mt_temp1
        ld      b,a
        ld      hl,mt_notetbl-2
        add     hl,de
        ld      a,(hl)                  ;lda mt_notetbl-2,y
        ld      (mt_temp2),a            ;sta <mt_temp2
        ld      e,b                     ;ldy <mt_temp1
        ld      b,d
      IF ((NOTONEPORTA == 0) || (NOPORTAMENTO == 0) || (NOVIB == 0))
        ld      l,a
        ld      a,e
        cp      05h
        ld      a,l
        cp      05h                     ;cpy #$05
        jr      nc,mt_execwavetick0     ;bcs mt_execwavetick0
mt_execwavetickn:
        IFDEF mt_effectnum
        ld      a,e
        ld      (mt_effectnum+1),a      ;sty mt_effectnum+1
        ENDIF
        ld      hl,mt_effectjumptbl
        add     hl,de
        ld      a,(hl)                  ;lda mt_effectjumptbl,y
        ld      (mt_effectjump+1),a     ;sta mt_effectjump+1
        ld      a,(mt_temp2)
        ld      e,a                     ;ldy <mt_temp2
        jp      mt_setspeedparam        ;jmp mt_setspeedparam
      ENDIF
mt_execwavetick0:
        ld      hl,mt_tick0jumptbl
        add     hl,de
        ld      a,(hl)                  ;lda mt_tick0jumptbl,y
        ld      (mt_execwavetick0jump+1),a;sta mt_execwavetick0jump+1
        ld      a,(mt_temp2)            ;lda <mt_temp2
mt_execwavetick0jump:
        call    mt_tick0_0              ;jsr mt_tick0_0
        jp      mt_done                 ;jmp mt_done
    ENDIF

    if TVC256k = 1
init_TVC256k
        ld      hl,0041h
        ld      bc,0410h
@msdetl push    bc
        ld      b,06h
        ld      de,tvc256c
@mschkl ld      a,(de)
        cp      (hl)
        inc     de
        inc     hl
        jr      nz,@msnodt
        djnz    @mschkl
        pop     bc
        ld      a,c
        add     a,04h
    IF ((ZPGHOSTREGS == 0) && (GHOSTREGS != 0))
        ld      (REGptc1+01h),a
    endif
        ld      (REGptc2+01h),a
        inc     a
        ld      (REGptc3+01h),a
        ld      c,a
        inc     c
        ld      a,01h           ;step rate
        out     (c),a           ;IOBase+06h
        ret

@msnodt pop     bc
        ld      a,l
        and     0f0h
        add     a,31h
        ld      l,a
        ld      a,c
        add     a,10h
        ld      c,a
        djnz    @msdetl
        pop     af
        ret

tvc256c db      "256k++"
   endif

    IF (NOEFFECTS == 0)
      ifndef authinfo
mt_tick0jumptbl:
        db      (mt_tick0_0 % 256)
        db      (mt_tick0_12 % 256)
        db      (mt_tick0_12 % 256)
        db      (mt_tick0_34 % 256)
        db      (mt_tick0_34 % 256)
        db      (mt_tick0_5 % 256)
        db      (mt_tick0_6 % 256)
        db      (mt_tick0_7 % 256)
        db      (mt_tick0_8 % 256)
        db      (mt_tick0_9 % 256)
        db      (mt_tick0_a % 256)
        db      (mt_tick0_b % 256)
        db      (mt_tick0_c % 256)
        db      (mt_tick0_d % 256)
        db      (mt_tick0_e % 256)
        db      (mt_tick0_f % 256)
      ENDIF
    ENDIF

    IF (NOEFFECTS == 0)
      ifndef effectjptbl
        IF ((NOTONEPORTA == 0) || (NOPORTAMENTO == 0) || (NOVIB == 0))
mt_effectjumptbl:
        db      (mt_effect_0 % 256)
        db      (mt_effect_12 % 256)
        db      (mt_effect_12 % 256)
        db      (mt_effect_3 % 256)
        db      (mt_effect_4 % 256)
        ENDIF
      ENDIF
    ENDIF

    ifndef funktemptbl
      IF (NOFUNKTEMPO == 0)
mt_funktempotbl:
        db      08h,05h             ;.BYTE (8,5)
      ENDIF
    ENDIF

    IF ((NOEFFECTS == 0) || (NOWAVEDELAY == 0) || (NOTRANS == 0) || (NOREPEAT == 0) || (FIXEDPARAMS == 0) || (GHOSTREGS != 0) || (BUFFEREDWRITES != 0) || (NOCALCULATEDSPEED == 0))
              ;Normal channel variables

mt_chnsongptr:
        db      00h                 ;.BYTE (0)
mt_chntrans:
        db      00h                 ;.BYTE (0)
mt_chnrepeat:
        db      00h                 ;.BYTE (0)
mt_chnpattptr:
        db      00h                 ;.BYTE (0)
mt_chnpackedrest:
        db      00h                 ;.BYTE (0)
mt_chnnewfx:
        db      00h                 ;.BYTE (0)
mt_chnnewparam:
        db      00h                 ;.BYTE (0)

      IF (NUMCHANNELS > 1)
        defs    07h
      ENDIF
      IF (NUMCHANNELS > 2)
        defs    07h
      ENDIF

dlt

mt_chnfx:
        db      00h                 ;.BYTE (0)
mt_chnparam:
        db      00h                 ;.BYTE (0)
mt_chnnewnote:
        db      00h                 ;.BYTE (0)
mt_chnwaveptr:
        db      00h                 ;.BYTE (0)
mt_chnwave:
        db      00h                 ;.BYTE (0)
mt_chnpulseptr:
        db      00h                 ;.BYTE (0)
mt_chnpulsetime:
        db      00h                 ;.BYTE (0)

      IF (NUMCHANNELS > 1)
        defs    07h                ;.BYTE (0,0,0,0,0,0,0)
      ENDIF
      IF (NUMCHANNELS > 2)
        defs    07h                ;.BYTE (0,0,0,0,0,0,0)
      ENDIF

mt_chnsongnum:
        db      00h                 ;.BYTE (0)
mt_chnpattnum:
        db      00h                 ;.BYTE (0)
mt_chntempo:
        db      00h                 ;.BYTE (0)
mt_chncounter:
        db      00h                 ;.BYTE (0)
mt_chnnote:
        db      00h                 ;.BYTE (0)
mt_chninstr:
        db      01h                 ;.BYTE (1)
mt_chngate:
        db      0feh                ;.BYTE ($fe)

      IF (NUMCHANNELS > 1)
        db      01h,00h,00h,00h,00h,01h,0feh    ;.BYTE (1,0,0,0,0,1,$fe)
      ENDIF
      IF (NUMCHANNELS > 2)
        db      02h,00h,00h,00h,00h,01h,0feh    ;.BYTE (2,0,0,0,0,1,$fe)
      ENDIF

      IF ((GHOSTREGS == 0) || (NOCALCULATEDSPEED == 0))

mt_chnvibtime:
        db      00h                 ;.BYTE (0)
mt_chnvibdelay:
        db      00h                 ;.BYTE (0)
mt_chnwavetime:
        db      00h                 ;.BYTE (0)
mt_chnfreqlo:
        db      00h                 ;.BYTE (0)
mt_chnfreqhi:
        db      00h                 ;.BYTE (0)
mt_chnpulselo:
        db      00h                 ;.BYTE (0)
mt_chnpulsehi:
        db      00h                 ;.BYTE (0)

        IF (NUMCHANNELS > 1)
          defs    07h                 ;.BYTE (0,0,0,0,0,0,0)
        ENDIF
        IF (NUMCHANNELS > 2)
          defs    07h                 ;.BYTE (0,0,0,0,0,0,0)
        ENDIF

        IF ((BUFFEREDWRITES != 0) || (FIXEDPARAMS == 0) || (NOCALCULATEDSPEED == 0))
mt_chnad:
        db      00h                 ;.BYTE (0)
mt_chnsr:
        db      00h                 ;.BYTE (0)
mt_chnsfx:
        db      00h                 ;.BYTE (0)
mt_chnsfxlo:
        db      00h                 ;.BYTE (0)
mt_chnsfxhi:
        db      00h                 ;.BYTE (0)
mt_chngatetimer:
        db      00h                 ;.BYTE (0)
mt_chnlastnote:
        db      00h                 ;.BYTE (0)

        IF (NUMCHANNELS > 1)
          defs    07h                 ;.BYTE (0,0,0,0,0,0,0)
        ENDIF
        IF (NUMCHANNELS > 2)
          defs    07h                 ;.BYTE (0,0,0,0,0,0,0)
        ENDIF

      ENDIF

    ELSE

mt_chnvibtime:
        db      00h                 ;.BYTE (0)
mt_chnvibdelay:
        db      00h                 ;.BYTE (0)
mt_chnwavetime:
        db      00h                 ;.BYTE (0)
mt_chnsfx:
        db      00h                 ;.BYTE (0)
mt_chnsfxlo:
        db      00h                 ;.BYTE (0)
mt_chnsfxhi:
        db      00h                 ;.BYTE (0)
mt_chngatetimer:
        db      00h                 ;.BYTE (0)

      IF (NUMCHANNELS > 1)
        defs    07h                 ;.BYTE (0,0,0,0,0,0,0)
      ENDIF
      IF (NUMCHANNELS > 2)
        defs    07h                 ;.BYTE (0,0,0,0,0,0,0)
      ENDIF
      
    ENDIF
      
    ELSE

              ;Optimized channel variables

mt_chnsongptr:
        db      00h                 ;.BYTE (0)
mt_chnpattptr:
        db      00h                 ;.BYTE (0)
mt_chnpackedrest:
        db      00h                 ;.BYTE (0)
mt_chnnewnote:
        db      00h                 ;.BYTE (0)
mt_chnwaveptr:
        db      00h                 ;.BYTE (0)
mt_chnwave:
        db      00h                 ;.BYTE (0)
mt_chnpulseptr:
        db      00h                 ;.BYTE (0)

      IF (NUMCHANNELS > 1)
        defs    07h                 ;.BYTE (0,0,0,0,0,0,0)
      ENDIF
      IF (NUMCHANNELS > 2)
        defs    07h                 ;.BYTE (0,0,0,0,0,0,0)
      ENDIF

dlt

mt_chnpulsetime:
        db      00h                 ;.BYTE (0)
mt_chnpulselo:
        db      00h                 ;.BYTE (0)
mt_chnpulsehi:
        db      00h                 ;.BYTE (0)
mt_chnvibtime:
        db      00h                 ;.BYTE (0)
mt_chnvibdelay:
        db      00h                 ;.BYTE (0)
mt_chnfreqlo:
        db      00h                 ;.BYTE (0)
mt_chnfreqhi:
        db      00h                 ;.BYTE (0)

      IF (NUMCHANNELS > 1)
        defs    07h                 ;.BYTE (0,0,0,0,0,0,0)
      ENDIF
      IF (NUMCHANNELS > 2)
        defs    07h                 ;.BYTE (0,0,0,0,0,0,0)
      ENDIF

mt_chnsongnum:
        db      00h                 ;.BYTE (0)
mt_chnpattnum:
        db      00h                 ;.BYTE (0)
mt_chntempo:
        db      00h                 ;.BYTE (0)
mt_chncounter:
        db      00h                 ;.BYTE (0)
mt_chnnote:
        db      00h                 ;.BYTE (0)
mt_chninstr:
        db      01h                 ;.BYTE (1)
mt_chngate:
        db      0feh                ;.BYTE ($fe)

      IF (NUMCHANNELS > 1)
        db      01h,00h,00h,00h,00h,01h,0feh    ;.BYTE (1,0,0,0,0,1,$fe)
      ENDIF
      IF (NUMCHANNELS > 2)
        db      02h,00h,00h,00h,00h,01h,0feh    ;.BYTE (2,0,0,0,0,1,$fe)
      ENDIF

    ENDIF

    IF ((GHOSTREGS != 0) && (ZPGHOSTREGS == 0))
ghostregs:
        defs    3*7+04h             ;.BYTE (0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0,0,0,0,0,0,0, 0,0,0,0)
ghostfreqlo     = ghostregs+0
ghostfreqhi     = ghostregs+1
ghostpulselo    = ghostregs+2
ghostpulsehi    = ghostregs+3
ghostwave       = ghostregs+4
ghostad         = ghostregs+5
ghostsr         = ghostregs+6
ghostfiltcutlow = ghostregs+21
ghostfiltcutoff = ghostregs+22
ghostfiltctrl   = ghostregs+23
ghostfilttype   = ghostregs+24
    ENDIF

        ;Songdata & frequencytable will be inserted by the relocator here
