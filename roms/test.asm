# This test ROM was written for the CapyAsm assembler (smal's weird wip thing)
# But you can use any assembler you want for your own programs
.cpu 65c02

.val CHR $6800
.val PAL $6C00

.val KEY_1    $7000
.val KEY_2    $7010
.val KEY_3    $7020
.val KEY_4    $7030
.val KEY_5    $7040

.val OSC_0    $70E0
.val OSC_1    $70E1
.val OSC_2    $70E2
.val OSC_CTRL $70E3

.org [$0000]
.var r0
.var r1
.var r2

.var zADDRText 2
.var zADDRScreen 2
.var zColorCur
.var zColorTimer
.var zVolumeCounter
.var zPosition

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
    sta [CHR+$C0+2+X]
    lda $0F
    sta [PAL+$A0+2+X]
    sta [PAL+$C0+2+X]
    sta [PAL+$E0+2+X]
    inc X
    bra (loop)
__end
lda $AA; sta [CHR+$A0+2]
lda $AB; sta [CHR+$A0+29]
lda $BA; sta [CHR+$E0+2]
lda $BB; sta [CHR+$E0+29]

lda $F0; sta [PAL+$A0+2]
lda $F0; sta [PAL+$A0+29]
lda $F0; sta [PAL+$E0+2]
lda $F0; sta [PAL+$E0+29]

# 89AB CDEF

# Print Palette to Screen
lda $00; sta [PAL+$0288]
lda $11; sta [PAL+$0289]
lda $22; sta [PAL+$028A]
lda $33; sta [PAL+$028B]
lda $44; sta [PAL+$028C]
lda $55; sta [PAL+$028D]
lda $66; sta [PAL+$028E]
lda $77; sta [PAL+$028F]

lda $88; sta [PAL+$0290]
lda $99; sta [PAL+$0291]
lda $AA; sta [PAL+$0292]
lda $BB; sta [PAL+$0293]
lda $CC; sta [PAL+$0294]
lda $DD; sta [PAL+$0295]
lda $EE; sta [PAL+$0296]
lda $FF; sta [PAL+$0297]

ldx $00
__display_font
# Character Memory
txa; sta [CHR+$0300+X]
inx; bne (display_font)

# ------------------------------------------------------
# CPU speed calc

wai
stz <r0>; stz <r1>; stz <r2>
clc
sed
wai

# Should take 200 cycles per loop
# 26+loops*5-1

__calcloop
  ldx 35                     # 2
  ___delay
  dec X; bne (delay)          # loops*(2+3)-1
  # Calculation (24)
  lda <r0>; adc 1; sta <r0>   # 3+2+3 (8)
  lda <r1>; adc 0; sta <r1>   # 3+2+3 (8)
  cli                         # 2
lda <r2>; beq (calcloop)      # 3+3   (6)
cld
lda <r1>; and $F0; lsr A; lsr A; lsr A; lsr A; clc; adc $30
  sta [CHR+$47]
lda <r1>; and $0F; clc; adc $30;
  sta [CHR+$48]
lda <r0>; and $F0; lsr A; lsr A; lsr A; lsr A; clc; adc $30
  sta [CHR+$4A]
lda <r0>; and $0F; clc; adc $30;
  sta [CHR+$4B]

__fim
cli
bra (fim)

#---------------------------------------------------------
# INTERUPT REQUEST
_irq
pha; phx
sei
lda 1; sta <r2>

dec <zColorTimer>; bne (next)
    inc <zColorCur>
    lda 50; sta <zColorTimer>
__next

__hellotext
    ldx 0
    ___loop
        lda [textWelcome+X]; beq (end)
        sta [CHR+X]
        lda <zColorCur>; sta [PAL+X]
        inc X
    bra (loop)
    ___end
    
__keytext
    lda textKeyboard.hi; sta <zADDRText+1>
    lda textKeyboard.lo; sta <zADDRText+0>
    lda CHR.hi+$01; sta <zADDRScreen+1>
    lda $40+8; sta <zADDRScreen+0>
    jsr [textprint]
    
    # Printing Keyboard to the screen
    lda $0C; sta <zPosition>
    lda [KEY_1]
    jsr [keyprint]

    lda $2C; sta <zPosition>
    lda [KEY_2]
    jsr [keyprint]

    lda $4C; sta <zPosition>
    lda [KEY_3]
    jsr [keyprint]

    lda $6C; sta <zPosition>
    lda [KEY_4]
    jsr [keyprint]

    lda $8C; sta <zPosition>
    lda [KEY_5]
    jsr [keyprint]
    
__colortext
    lda textPalette.hi; sta <zADDRText+1>
    lda textPalette.lo; sta <zADDRText+0>
    lda CHR.hi+$02; sta <zADDRScreen+1>
    lda $40+13; sta <zADDRScreen+0>
    jsr [textprint]
    
__fonttext
    lda textFont.hi; sta <zADDRText+1>
    lda textFont.lo; sta <zADDRText+0>
    lda CHR.hi+$02; sta <zADDRScreen+1>
    lda $C0+14; sta <zADDRScreen+0>
    jsr [textprint]
    
    
    # set the channel volume to the counter value
    inc <zVolumeCounter>; lda <zVolumeCounter>; 
    #sta [$70F0]
    #sta [$70F1]
    #sta [$70F2]
cli
plx; pla
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
        txa; ldx <zPosition>; sta [CHR+$180+X]; inc <zPosition>
        pul A
    dey; bne (loop)
rts

_textprint
    ldy 0
    __loop
        lda [<zADDRText>+Y]; beq (break)
        sta [<zADDRScreen>+Y]
        inc Y
    bra (loop)
__break
rts

# zero-terminated strings
_textWelcome
.byte " Hello! Welcome to my Computer! "
_textSpecs
.byte "65c02 @  .  Mhz, 28K RAM, Custom video + sound! "
_textLoad
.byte " Drag & Drop a ROM to run!  "
_textPalette
.byte "Palette"
_textKeyboard
.byte "Keyboard Matrix"
_textFont
.byte "Font"

.asm frequencies
#
#   END OF CODE
#
.pad [VECTORS]
.word reset
.word reset
.word irq

.pad $8000*15
