# This test ROM was written for the CapyAsm assembler (smal's weird wip thing)
# But you can use any assembler you want for your own programs
.cpu 65c02

.val CHR $6C00
.val PAL $6800

.val KEY_1    $7000
.val KEY_2    $7010
.val KEY_3    $7020
.val KEY_4    $7030
.val KEY_5    $7040

.val OSC_0    $70E0
.val OSC_1    $70E1
.val OSC_2    $70E2
.val OSC_CTRL $70E3

.val zColorCur       $00
.val zColorTimer     $01
.val zVolumeCounter  $10

.org [$8000]
_reset

cld
sei

# Mute Audio
stz [$70F0]
stz [$70F1]
stz [$70F2]
stz [$70F3]

# Set the frequency for the melodic channels
ldx 72 #C5
lda %00_11_010_0; sta [OSC_CTRL]; lda [note_lo+X]; sta [OSC_0]; lda [note_hi+X]; sta [OSC_0];

ldx 76 #E5
lda %01_11_010_0; sta [OSC_CTRL]; lda [note_lo+X]; sta [OSC_1]; lda [note_hi+X]; sta [OSC_1];

ldx 79 #G5
lda %10_11_010_0; sta [OSC_CTRL]; lda [note_lo+X]; sta [OSC_2]; lda [note_hi+X]; sta [OSC_2];

# Set the waveform for erach channel
lda $F0; sta [$70F4]; sta [$70F5]; sta [$70F6]; stz [$70F7]


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

stz <zVolumeCounter>

lda $F8; sta <zColorCur>; lda 50; sta <zColorTimer>

_test1
ldx 0
__loop
    lda [textSpecs+X]; beq (end)
    sta [CHR+64+X]
    inc X
    bra (loop)
__end
_test2
ldx 0
__loop
    lda [textLoad+X]; beq (end)
    sta [CHR+320+2+X]
    inc X
    bra (loop)
__end

# 89AB CDEF

# Print Palette to Screen
lda $00; sta [$6AA8]
lda $11; sta [$6AA9]
lda $22; sta [$6AAA]
lda $33; sta [$6AAB]
lda $44; sta [$6AAC]
lda $55; sta [$6AAD]
lda $66; sta [$6AAE]
lda $77; sta [$6AAF]

lda $88; sta [$6AB0]
lda $99; sta [$6AB1]
lda $AA; sta [$6AB2]
lda $BB; sta [$6AB3]
lda $CC; sta [$6AB4]
lda $DD; sta [$6AB5]
lda $EE; sta [$6AB6]
lda $FF; sta [$6AB7]

ldx $00
__display_font
# Character Memory
txa; sta [$6F00+X]
inx; bne (display_font)

__fim
cli
bra (fim)

#---------------------------------------------------------
# INTERUPT REQUEST
_irq
sei

dec <zColorTimer>; bne (next)
    inc <zColorCur>
    lda 50; sta <zColorTimer>
__next

ldx 0
__loop
    lda [textWelcome+X]; beq (end)
    sta [$6C00+X]
    lda <zColorCur>; sta [$6800+X]
    inc X
    bra (loop)
__end

    # Printing Keyboard to the screen
    lda <$6E>; sta <$21>

    lda $0C; sta <$20>
    lda [KEY_1]
    jsr [keyprint]

    lda $2C; sta <$20>
    lda [KEY_2]
    jsr [keyprint]

    lda $4C; sta <$20>
    lda [KEY_3]
    jsr [keyprint]

    lda $6C; sta <$20>
    lda [KEY_4]
    jsr [keyprint]

    lda $8C; sta <$20>
    lda [KEY_5]
    jsr [keyprint]

    # set the channel volume to the counter value
    inc <zVolumeCounter>; lda <zVolumeCounter>; 
    sta [$70F0]
    sta [$70F1]
    sta [$70F2]
cli
rti

#----------------------------
# Subroutines and data

_keyprint
    ldy 8
    __loop
        ldx $FD;
        asl A; bcc (nopress); ldx $FC
        __nopress
        psh A
        txa; ldx <$20>; sta [$6E00+X]; inc <$20>
        pul A
    dey; bne (loop)
rts

# zero-terminated strings
_textWelcome
.byte " Hello! Welcome to my Computer! "
_textSpecs
.byte "Running @3Mhz with custom video + sound! "
_textLoad
.byte "Drag & Drop a ROM to run!"

.asm frequencies

#
#   END OF CODE
#
.pad [VECTORS]
.word reset
.word reset
.word irq