.cpu 65c02

.val char_timer $10
.val line_buffer   $0200
.val char_cur      $11
.val line_buffer_i $12
.val line_buffer_l $13


.val keyboard_cache $14
.val line_cur       $20
.val serial_active  $30

.org [$1000]
_nmi

_start
#-----------------------------------------
# Serial Cart Detection and 16c550 init
#-----------------------------------------

# ------------------------------------------------------
# CPU speed calc

wai
stz <0>; stz <1>; stz <2>
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
  lda <0>; adc 1; sta <0>   # 3+2+3 (8)
  lda <1>; adc 0; sta <1>   # 3+2+3 (8)
  cli                         # 2
lda <2>; beq (calcloop)      # 3+3   (6)
cld
lda <1>; and $F0; lsr A; lsr A; lsr A; lsr A; clc; adc $30
  sta [CHR+$47]
lda <1>; and $0F; clc; adc $30;
  sta [CHR+$48]
lda <0>; and $F0; lsr A; lsr A; lsr A; lsr A; clc; adc $30
  sta [CHR+$4A]
lda <0>; and $0F; clc; adc $30;
  sta [CHR+$4B]

stz <serial_active>

_serialcheck
    # change to cart bank
    lda $40; sta [$70D0]
    # check if MCR works as expected
    # MCR should store a value but set the top 3 bits to 0
    lda $ff; sta [$8004]
    lda $1f; cmp [$8004]; bne (noserial)
    stz [$8004]; lda [$8004]; bne (noserial)
    
    __yesserial
    # we assume we have a serial cart
    lda $ff; sta <serial_active>
    # setting baudrate and word length
    lda $80; sta [$8003]                # enable divisor latch
    lda $0D; sta [$8000]; stz [$8001]   # set divisor
    lda %0_0_000_0_11; sta [$8003]      # disable divisor latch and set word length to 8, 1 stop bit

    # Clear and enable Enable FIFOs
    lda %00_00_0_11_1; sta [$8002]
    
    # Serial Enabled Icon
    lda $F8; sta [$6C1F]
    lda 's'; sta [$681F]
    
    __noserial
    # return to bank 0
    stz [$70D0]
_irq
bra (noserial)
lda <serial_active>; beq (noserial)
    lda $40; sta [$70D0]
    lda [$8005]
    cmp 1; bne (noserial)
    lda [$8000]; cmp $01; bne (noserial)
    lda $01; sta [$8000]
    
    __wait
    ldx $00
    lda $01
    ldy $02
    __waitloop
        cmp [$8005]; beq (yesserial)
    inc X; bne (waitloop)
    bra (break)
    __yesserial
    lda [$8000]; sta [$0000+Y]; dec Y; bpl (waitloop)
    
    ldx $00
    __receiveloop
        lda $01
        ___wait
        cmp [$8005]; bne (wait)
        
        lda [$8000]; sta [$5000+X]
    inc X; bne (receiveloop)
    
    #lda <$02>; sta [$70D0]
    #lda [$5000+X]; sta [<$00>+X]
    lda $40; sta [$70D0]
    
    bra (wait)
__break
stz [$70D0]
__noserial

lda <line_buffer_i>
lda $E0; sta <line_cur>
lda $6B; sta <line_cur+1>

sei
stz [char_cur]
lda <line_buffer_i>; sta <line_buffer_l>
ldx 4
_keyloop
    psh X
    txa; asl A; asl A; asl A; asl A; tax
    lda [$7000+X]
    pul X
    
    psh A           # PUSH 01
    cmp [keyboard_cache+X]; bne (change)
    jmp [nochange]
    _change
    
    __bit0
    lsr [keyboard_cache+X]; bcs (bit1)
    bit %0000_0001; beq (bit1)
    psh A; lda [kKeys0+X]; sta [char_cur]; pul A
    __bit1
    lsr [keyboard_cache+X]; bcs (bit2)
    bit %0000_0010; beq (bit2)
    psh A; lda [kKeys1+X]; sta [char_cur]; pul A
    __bit2
    lsr [keyboard_cache+X]; bcs (bit3)
    bit %0000_0100; beq (bit3)
    psh A; lda [kKeys2+X]; sta [char_cur]; pul A
    __bit3
    lsr [keyboard_cache+X]; bcs (bit4)
    bit %0000_1000; beq (bit4)
    psh A; lda [kKeys3+X]; sta [char_cur]; pul A
    __bit4
    lsr [keyboard_cache+X]; bcs (bit5)
    bit %0001_0000; beq (bit5)
    psh A; lda [kKeys4+X]; sta [char_cur]; pul A
    __bit5
    lsr [keyboard_cache+X]; bcs (bit6)
    bit %0010_0000; beq (bit6)
    psh A; lda [kKeys5+X]; sta [char_cur]; pul A
    __bit6
    lsr [keyboard_cache+X]; bcs (bit7)
    bit %0100_0000; beq (bit7)
    psh A; lda [kKeys6+X]; sta [char_cur]; pul A
    __bit7
    lsr [keyboard_cache+X]; bcs (bitend)
    bit %1000_0000; beq (bitend)
    psh A; lda [kKeys7+X]; sta [char_cur]; pul A
    
    __bitend
    
    _nochange
    pul A # PULL 01
    sta [keyboard_cache+X]
dec X; bmi (keyend); jmp [keyloop]
__keyend


_write
lda <char_cur>; bne (writing); jmp [break]
__writing
bmi (specialchar)


sta <$00>   # char to write
sec; sbc 32; tax
__normalchar
lda $80; bit <keyboard_cache+2>; beq (noshift)
lda [kShift+X]; sta <$00>
bra (modend)
___noshift
lda $80; bit <keyboard_cache+3>; beq (modend)
lda [kAlt+X]; sta <$00>
bra (modend)

__modend
lda 30; cmp <line_buffer_i>; bpl (next)
jmp [break]
___next
lda <$00>
ldx <line_buffer_i>; sta [line_buffer+X]; psh X; pul Y; sta [<line_cur>+Y]
inc <line_buffer_i>
bra (break)

__specialchar
___testback
cmp $80; bne (testenter); lda <line_buffer_i>; beq (testenter)

ldx <line_buffer_i>
lda ' '; psh X; pul Y; sta [<line_cur>+Y]
stz [line_buffer+X];
dec X; stx <line_buffer_i>
stz [line_buffer+X]; lda ' '; psh X; pul Y; sta [<line_cur>+Y]
bra (break)
___testenter
cmp $81; bne (testescape)
jsr [Run]; bra (break)
___testescape
cmp $82; bne (testarrow)
jsr [Clear]; bra (break)

___testarrow
cmp $F0; bmi (break)
____nobreak
tax; lda $80; bit <keyboard_cache+3>; beq (arrowmove)
txa; sta <$00>
jmp [modend]
____arrowmove
txa
____left
cmp $F0; bne (up)
ldy <line_buffer_i>; beq (break)
dec <line_buffer_i>; bra (break)
____up
cmp $F1; bne (right)
stz <line_buffer_i>; bra (break)
____right
cmp $F2; bne (bottom)
ldy <line_buffer_i>
lda [line_buffer+Y]; beq (break)
inc <line_buffer_i>; bra (break)
____bottom
#ldy <line_buffer_i>; lda [line_buffer+Y]; sta [<line_cur>+Y]
_____loop
    lda [line_buffer+Y]; beq (over)
    inc Y; bra (loop)
_____over
sty <line_buffer_i>
__break

# Blinking: first return last cursor pos to normal color
# $00/01 → pointer to color of cursor
ldy <line_buffer_l>
lda <line_cur>; sta <$00>
lda <line_cur+1>; clc; adc $04; sta <$01>
lda $F0; sta [<$00>+Y]

# Blinking: clear timer if a char was input
lda <char_cur>; beq (blink)
stz <char_timer>
_blink
ldx $0F
lda <char_timer>; bit %0001_0000; beq (next)
ldx $F0
__next
ldy <line_buffer_i>
lda <line_cur>; sta <$00>
lda <line_cur+1>; clc; adc $04; sta <$01>
txa; sta [<$00>+Y]

inc <char_timer>

#rti
wai
jmp [irq]

_Run
    ldy $00
    jsr [read]
    
    __interpret
    # The Vector goes into <$08,$09>
    lda <$80>; cmp $F2; bne (nojump)
    jmp [jump]
    __nojump
    lda <$80>; jsr [TextToHex]; bmi (BAD)
    asl A; asl A; asl A; asl A
    sta <$09>
    lda <$81>; jsr [TextToHex]; bmi (BAD)
    ora <$09>; sta <$09>
    
    lda <$82>; cmp $F2; beq (poke); jsr [TextToHex]; bmi (BAD)
    asl A; asl A; asl A; asl A
    sta <$08>
    lda <$83>; jsr [TextToHex]; bmi (BAD)
    ora <$08>; sta <$08>
    
    lda <$84>; cmp $F2; bne (BAD)
    jsr [peek]; jmp [cmdend]
    
    __poke
    lda <$09>; sta <$10>
    ldy 3; jsr [read]
    
    lda <$80>; jsr [TextToHex]; bmi (BAD)
    asl A; asl A; asl A; asl A
    sta <$09>
    lda <$81>; jsr [TextToHex]; bmi (BAD)
    ora <$09>; sta <$09>
    
    lda <$82>; jsr [TextToHex]; bmi (BAD)
    asl A; asl A; asl A; asl A
    sta <$08>
    lda <$83>; jsr [TextToHex]; bmi (BAD)
    ora <$08>; sta <$08>
    
    lda <$10>; sta [<$08>]
    jmp [cmdend]
    
    __BAD
    #jsr [Clear]
rts
    __read
        ldx $00
        ___loop
            lda [line_buffer+Y]; beq (break)
            sta <$80+X>; inc X

            cmp $80; bpl (break)
            inc Y
        bra (loop)
        ___break
        stz <$80+X>
    rts
    __jump
        ldy 1; jsr [read]
        
        lda <$80>; jsr [TextToHex]; bmi (BAD)
        asl A; asl A; asl A; asl A
        sta <$09>
        lda <$81>; jsr [TextToHex]; bmi (BAD)
        ora <$09>; sta <$09>
        
        lda <$82>; jsr [TextToHex]; bmi (BAD)
        asl A; asl A; asl A; asl A
        sta <$08>
        lda <$83>; jsr [TextToHex]; bmi (BAD)
        ora <$08>; sta <$08>
        
        lda <$84>; beq (samejump)
        
        lda <$84>; jsr [HexToText]; bmi (BAD)
        asl A; asl A; asl A; asl A
        sta <$07>
        lda <$85>; jsr [HexToText]; bmi (BAD)
        ora <$07>
        sta <$07>
        ___bankjump
        lda <$09>; sta [$70D0]
        jmp [[$0007]]
        
        ___samejump
        jmp [[$0008]]
    rts
    __peek
        lda [<$08>]; jsr [HexToText]
        lda <$00>; sta [$6BFE]
        lda <$01>; sta [$6BFF]
    rts
    __cmdend
    lda $00; sta <$00>
    lda $68; sta <$01>
    
    lda $E0; sta <$02>
    lda $67; sta <$03>
    
    ldx 4
    ldy $40
    ___moveloop
        lda [<$00>+Y]
        sta [<$02>+Y]
    inc Y; bne (moveloop)
    ldy $00
    inc <$03>; inc <$01>; lda <$01>; dec X; bne (moveloop)
    
    ldx $E0
    lda ' '
    ___spaceloop
        sta [$6B00+X]
    inc X; bne (spaceloop)
    jsr [Clear]
    rts
_HexToText
# Converts a value in A into a Hex String at <$00-$01>
    sta <$10>
    and $F0; lsr A; lsr A; lsr A; lsr A
    tax; lda [tHex+X]; sta <$00>
    lda <$10>
    and $0F
    tax; lda [tHex+X]; sta <$01>
    
    lda <$10>; rts
    
_TextToHex
# Converts a character in A into a number, outputs 80 if invalid
    sec; sbc $30; bmi (invalid)
    cmp $0A; bpl (letter)
    # Is A value from 0-9
    clc; adc 0
    rts
    __letter
    and %1101_1111
    sec; sbc 7; bmi (invalid)
    cmp $10; bpl (invalid)
    clc; adc 0
    rts
__invalid
    lda $80; rts 

_Clear
    ldy $1f
    __loop
        lda 0; sta [line_buffer+Y]
        lda ' '; sta [<line_cur>+Y]
    dec Y; bpl (loop)
    ___break
    stz <line_buffer_i>
rts

_tHex
.byte '0123456789abcdef'

#--------------------------
# Keyboard Layout
_kKeys7
.byte $00,$00,$00,$00,$82
_kKeys6
.byte 'x','z','a','q','w'
_kKeys5
.byte 'c','f','d','s','e'
_kKeys4
.byte ' ','b','v','g','r'

_kKeys3
.byte $F1,'n','h','y','t'
_kKeys2
.byte $F0,'|','m','j','u'
_kKeys1
.byte $F3,'.','l','k','i'
_kKeys0
.byte $F2,$81,$80,'p','o'

_kShift
.byte $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,',',$2F
.byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$3F
.byte $40,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4A,$4B,$4C,$4D,$4E,$4F
.byte $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5A,$5B,$5C,$5D,$5E,$5F
.byte $60,'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O'
.byte 'P','Q','R','S','T','U','V','W','X','Y','Z',$7B,$7C,$7D,$7E,$7F
_kAlt
.byte $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F
.byte $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$3F
.byte $40,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4A,$4B,$4C,$4D,$4E,$4F
.byte $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5A,$5B,$5C,$5D,$5E,$5F
.byte $60,'@',';',$63,$64,'3',$66,$67,$68,'8',$6A,$6B,$6C,$6D,$6E,'9'
.byte '0','1','4',$73,'5','7',$76,'2',$78,'6',$7A,$7B,$7C,$7D,$7E,$7F

.pad [$2000]
.org [$9000]

_reset
# Mute Audio
ldx 7
_muteloop
    stz [$70F0+X]
dec X; bpl (muteloop)

ldx $00
__clrscreen
    stz [$0200+X]
    lda $F0
    sta [$6C00+X]; sta [$6D00+X]; sta [$6E00+X]; sta [$6F00+X]
    lda ' '
    sta [$6800+X]; sta [$6900+X]; sta [$6A00+X]; sta [$6B00+X]
inc X; bne (clrscreen)

ldx $00
__printheader
    lda [tHeader+X]; beq (break)
    sta [$6800+X]
    
    lda [tHeaderColor+X]
    sta [$6C00+X]
    
    inc X; bra (printheader)
___break

stz <line_buffer_i>
ldx 4
__keyzero
    stz <keyboard_cache+X>
dec X; bpl (keyzero)

ldx $00
_copyloop
    lda [$8000+X]; sta [$1000+X]
    lda [$8100+X]; sta [$1100+X]
    lda [$8200+X]; sta [$1200+X]
    lda [$8300+X]; sta [$1300+X]
    lda [$8400+X]; sta [$1400+X]
    lda [$8500+X]; sta [$1500+X]
    lda [$8600+X]; sta [$1600+X]
    lda [$8700+X]; sta [$1700+X]
    lda [$8800+X]; sta [$1800+X]
    lda [$8900+X]; sta [$1900+X]
    lda [$8A00+X]; sta [$1A00+X]
    lda [$8B00+X]; sta [$1B00+X]
    lda [$8C00+X]; sta [$1C00+X]
    lda [$8D00+X]; sta [$1D00+X]
    lda [$8E00+X]; sta [$1E00+X]
    lda [$8F00+X]; sta [$1F00+X]
inc X; bne (copyloop)

jmp [start]

# Text
_tHeader
.byte $A1
.byte 'foxmon'
.byte $A1,$A1,$A1,$A1,$A1,$A1,$A1,$A1,$00

_tHeaderColor
.byte $0F
.byte $0F,$0F,$0F,$0F,$0F,$0F
.byte $F8,$8C,$CE,$E4,$43,$39,$9B,$B0

.pad [VECTORS]
.word reset
.word reset
.word reset
# Other banks
.pad $8000*15