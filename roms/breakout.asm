.cpu kitty
.org [$0000]
.var r0 2
.var r1 2

.var paddle_chr_ptr 2
.var paddle_pal_ptr 2

.var paddle_chr_ptr 2
.var paddle_pal_ptr 2

.var ball_prev  2
.var ball_pos_x 2
.var ball_pos_y 2
.var ball_vel_x 2
.var ball_vel_y 2

.var ball_ppos 6

.var xpos

.org [$8000]
_IRQ
_NMI
_RESET
    sei; cld; ldx $FF; txs
    stz [VOL1]; stz [VOL2]; stz [VOL3]; stz [VOL4]
    
    ldx 0
    __clrloop
        lda ' '
        sta [CHR+$000+X]; sta [CHR+$100+X]; sta [CHR+$200+X]; sta [CHR+$300+X]
        
        lda $F0
        sta [PAL+$000+X]; sta [PAL+$100+X]; sta [PAL+$200+X]; sta [PAL+$300+X]
        
        lda 0
        sta <$00+X>
    inc X; bne (clrloop)
_GameLoop
    # Ball
    __BallMove
    ldy 0; lda 0; sta [<ball_prev>+Y]
    
    lda 3; sta <ball_vel_x>
    lda 4; sta <ball_vel_y>
    clc
    lda <ball_pos_y>; adc <ball_vel_y>; sta <ball_pos_y>
    clc
    lda <ball_pos_x>; adc <ball_vel_x>; sta <ball_pos_x>
    
    lda <ball_pos_y>; and %1111_1000
    asl A; asl A
    sta <r0+0>
    lda <ball_pos_y>
    lsr A; lsr A; lsr A; lsr A; lsr A; lsr A
    sta <r0+1>
    
    lda <ball_pos_x>; lsr A; lsr A; lsr A
    clc
    adc <r0+0>; sta <r0+0>
    lda <r0+1>; adc 0; sta <r0+1> 
    
    
    ldy 0
    
    clc; lda CHR.hi; adc <r0+1>; sta <r0+1>
    lda $8C; sta [<r0>+Y]
    
    clc; lda 4; adc <r0+1>; sta <r0+1>
    lda $F0; sta [<r0>+Y]
    
    lda <r0+0>; sta <ball_prev+0>
    lda <r0+1>; sta <ball_prev+1> 
    
    # Paddle
    
    ldy 0
    __ErasePaddle
        lda ' '; sta [<paddle_chr_ptr>+Y]
        lda $00; sta [<paddle_pal_ptr>+Y]
    inc Y; cpy 5; bne (ErasePaddle)
    
    lda <xpos>; lsr A; lsr A
    clc
    adc $E0; sta <paddle_chr_ptr+0>; sta <paddle_pal_ptr+0>
    lda CHR.hi+$03; sta <paddle_chr_ptr+1>
    lda PAL.hi+$03; sta <paddle_pal_ptr+1>
    
    lda <xpos>; and %0000_0011; tax
    lda 0
    __XCalc
        cpx 0; beq (break)
        clc; adc 5
    dec X; bra (XCalc)
    ___break
    tax; ldy 0
    __DrawPaddle
        lda [PaddleChar+X]; sta [<paddle_chr_ptr>+Y]
        lda [PaddleColor+X]; sta [<paddle_pal_ptr>+Y]
    inc X; inc Y; cpy 5; bne (DrawPaddle)
    
    __MovePaddle
    lda 1; sta <r1>
    lda [KEY1]; sta <r0>
    
    lda %1000_0000; bit [KEY3]; beq (normalspeed)
        lda 3; sta <r1>
    ___normalspeed
    lda %0000_0001; bit <r0>; bne (right)
    lda %0000_0100; bit <r0>; bne (left)
    bra (nomove)
    ___left
        lda <xpos>; sec; sbc <r1>; bpl (next)
            lda 0
        ____next
        sta <xpos>
    bra (nomove)
    ___right
        lda <xpos>; clc; adc <r1>; cmp 128-16; bcc (next)
            lda 128-17
        ____next
        sta <xpos>
    #bra (nomove)
    ___nomove
wai; jmp [GameLoop]

_PaddleChar
.byte $0F, $0F, $0F, $0F, $00
.byte $8B, $8B, $0F, $8B, $8B
.byte $09, $09, $0F, $09, $09
.byte $9A, $9A, $0F, $9A, $9A
_PaddleColor
.byte $AA, $BB, $BB, $AA, $00
.byte $0A, $AB, $BB, $BA, $A0
.byte $0A, $AB, $BB, $BA, $A0
.byte $A0, $BA, $BB, $AB, $0A

.pad [VECTORS]
.word NMI
.word RESET
.word IRQ