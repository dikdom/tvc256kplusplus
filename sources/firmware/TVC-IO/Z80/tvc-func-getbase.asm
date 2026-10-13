iobase_handler:
    ld a, (TVC256_IOPORT)
    ld c, a
    xor a
    ret

membase_handler:
    ld a, (TVC256_IOPORT)
    ld c, $40
    cp $10
    jr z, .done
    ld c, $70
    cp $20
    jr z, .done
    ld c, $A0
    cp $30
    jr z, .done
    ld c, $C0
.done
    xor a
    ret
