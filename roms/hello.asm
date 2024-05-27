# A very Simple Hello World Example
.cpu 65c02
.org [$8000]
_NMI
_IRQ
_RESET
    # Disable IRQ and Decimal Mode
    sei; cld
    
    # Set stack pointer
    ldx $FF; txs
    
    # Mute Audio Channels
    stz [$70F0]; stz [$70F1]; stz [$70F2]; stz [$70F3]
    
    # Reset Screen
    ldx $00
    __clearloop
        # White Foreground, Black Background
        lda $F0
        sta [$6800+X]; sta [$6900+X]; sta [$6A00+X]; sta [$6B00+X]
        # Space Character
        lda ' '
        sta [$6C00+X]; sta [$6D00+X]; sta [$6E00+X]; sta [$6F00+X]
    inc X; bne (clearloop)
    
    # We are now done with the initial system cleanup, print hello world
    ldx $00
    __printloop
        lda [HelloText+X]; beq (break)
        sta [$6C00+X]
        inc X
    bra (printloop)
    ___break
    
_FIM
    # We are done, now loop forever
    jmp [FIM]

_HelloText
.byte 'Hello '   # Text String
.byte "World!"   # Text String using "" is zero terminated

# Interrupt Vectors
.pad [VECTORS]
.word NMI
.word RESET
.word IRQ