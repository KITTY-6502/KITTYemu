.cpu kitty

.org [$0000]
.var zADDRText 2
.var zADDRScreen 2
.var zColorCur
.var zColorTimer
.var zVolumeCounter
.var zPosition

.org [$8000]
_RESET

cld
sei

# Mute Audio
stz [$70F0]
stz [$70F1]
stz [$70F2]
stz [$70F3]

# Fill up the screen with empty data
lda ' ' # character
ldx 0
__fill_chr
    # Character Memory
    sta [CHR+$0000+X]
    sta [CHR+$0100+X]
    sta [CHR+$0200+X]
    sta [CHR+$0300+X]
inx; bne (fill_chr)

lda $F0
ldx 0
__fill_pal
    # Palette Memory
    sta [PAL+$0000+X]
    sta [PAL+$0100+X]
    sta [PAL+$0200+X]
    sta [PAL+$0300+X]
inx; bne (fill_pal)

_FontDisplay
    lda CHR.hi+1; sta <$01>
    lda CHR.lo+8; sta <$00>
    ldx $00; ldy $00
    __loop
        txa; sta [<$00>+Y]
        inc Y; cpy $10; bne (next)
            ldy $00
            clc
            lda <$00>; adc $20; sta <$00>
            lda <$01>; adc $00; sta <$01>
        __next
    inc X; bne (loop)
    
    __numberl
    ldx 16
    ___loop
        dec X; bmi (break)
            lda [HEX+X]; sta [CHR+$E8+X]
            lda $F8; sta [PAL+$E8+X]
    bra (loop)
    ___break
    
    __numberh
    lda CHR.hi+1; sta <$01>
    lda CHR.lo+7; sta <$00>
    lda PAL.hi+1; sta <$03>
    lda PAL.lo+7; sta <$02>
    ldx 0; ldy 0
    ___loop
        lda [HEX+X]; sta [<$00>+Y]
        lda $F8; sta [<$02>+Y]
        
        lda <$00>; adc $20; sta <$00>
        lda <$01>; adc $00; sta <$01>
        
        lda <$02>; adc $20; sta <$02>
        lda <$03>; adc $00; sta <$03>
    inc X; cpx 16; bne (loop)
    
    lda $8F; sta [CHR+$E7]
    lda $F8; sta [PAL+$E7]
    
_main
bra (main)

_HEX
.byte '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'

.pad [VECTORS]
.word RESET
.word RESET
.word RESET