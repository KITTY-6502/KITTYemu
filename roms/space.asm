.cpu 65c02
.org [$8000]
_reset
lda 0
ldx 8
__mute
    sta [$70F0+X]
dec X; bpl (mute)

ldx $00
__backgroundclear
    lda $f0
    sta [$6800+X]; sta [$6900+X]; sta [$6A00+X]; sta [$6B00+X]
    lda ' '
    sta [$6C00+X]; sta [$6D00+X]; sta [$6E00+X]; sta [$6F00+X]
inc X; bne (backgroundclear)

.var shipX $10
.var shipY $11
.var shipMoveTimer $12
.var shipMoveDelay $02
lda 8; sta <shipX>; lda 20; sta <shipY>
.var shipShootTimer $13
.var shipShootDelay $02

.var bulletsX $20
.var bulletsY $30

_bullets
ldx $0F
lda $FF
__loop
    sta <bulletsX+X>
    sta <bulletsY+X>
dec X; bpl (loop)

_main
wai
    lda '.'; sta [$6D10]; lda $E0; sta [$6910]
    
    ldx <shipY>
    lda [yTableHi+X]; sta <$01>
    lda [yTableLo+X]; ora <shipX>; sta <$00>
    lda ' '; sta [<$00>]
    
    ldx $0F
    _bulletsClear
    __loop
        lda <bulletsY+X>; bmi (break); tay
        lda [yTableHi+Y]; sta <$01>
        lda [yTableLo+Y]; ora <bulletsX+X>; sta <$00>
        
        lda ' '; sta [<$00>]
        dec <bulletsY+X>
        __break
    dec X; bpl (loop)
    
    _movement
        lda <shipX>; sta <$00>
        lda <shipY>; sta <$01>
        
        dec <shipMoveTimer>; bpl (break)
        stz <shipMoveTimer>
        lda [$7040]; beq (break)
        ldx shipMoveDelay; stx <shipMoveTimer>
        __right
        asl A; bcc (down)
        inc <$00>
        __down
        asl A; bcc (left)
        inc <$01>
        __left
        asl A; bcc (up)
        dec <$00>
        __up
        asl A; bcc (break)
        dec <$01>
    __break
    _coordclamp
    lda <$00>; bmi (noX); cmp 32; bpl (noX); sta <shipX>
    __noX
    lda <$01>; bmi (noY); cmp 32; bpl (noY); sta <shipY>
    __noY
    
    _shooting
    dec <shipShootTimer>; bpl (break)
    stz <shipShootTimer>
        
    lda [$7030]; lsr A; lsr A; bcc (break)
    ldx shipShootDelay; stx <shipShootTimer>
    
    ldx $0F
    __loop
        lda <bulletsY+X>; bpl (next)
        lda <shipY>; sta <bulletsY+X>
        lda <shipX>; sta <bulletsX+X>
        bra (break)
        __next
    dec X; bpl (loop)
    __break
    
    #lda <shipX>; and %00011111; sta <shipX>
    #lda <shipY>; and %00011111; sta <shipY>
    
    ldx <shipY>
    lda [yTableHi+X]; sta <$01>
    lda [yTableLo+X]; ora <shipX>; sta <$00>
    lda $F8; sta [<$00>]
    lda [yTableHiCo+X]; sta <$01>
    lda $F0; sta [<$00>]
    
    ldx $0F
    _bulletsDraw
    __loop
        lda <bulletsY+X>; bmi (break); tay
        lda [yTableHi+Y]; sta <$01>
        lda [yTableLo+Y]; ora <bulletsX+X>; sta <$00>
        
        lda '!'; sta [<$00>]
        lda [yTableHiCo+Y]; sta <$01>
        lda $D0; sta [<$00>]
        __break
    dec X; bpl (loop)

jmp [main]

# 32byte Tables to speed up translating y values to character and color ram
_yTableLo
.byte $00
.byte $20
.byte $40
.byte $60
.byte $80
.byte $A0
.byte $C0
.byte $E0
.byte $00
.byte $20
.byte $40
.byte $60
.byte $80
.byte $A0
.byte $C0
.byte $E0
.byte $00
.byte $20
.byte $40
.byte $60
.byte $80
.byte $A0
.byte $C0
.byte $E0
.byte $00
.byte $20
.byte $40
.byte $60
.byte $80
.byte $A0
.byte $C0
.byte $E0

_yTableHi
.byte $6C
.byte $6C
.byte $6C
.byte $6C
.byte $6C
.byte $6C
.byte $6C
.byte $6C
.byte $6D
.byte $6D
.byte $6D
.byte $6D
.byte $6D
.byte $6D
.byte $6D
.byte $6D
.byte $6E
.byte $6E
.byte $6E
.byte $6E
.byte $6E
.byte $6E
.byte $6E
.byte $6E
.byte $6F
.byte $6F
.byte $6F
.byte $6F
.byte $6F
.byte $6F
.byte $6F
.byte $6F

_yTableHiCo
.byte $68
.byte $68
.byte $68
.byte $68
.byte $68
.byte $68
.byte $68
.byte $68
.byte $69
.byte $69
.byte $69
.byte $69
.byte $69
.byte $69
.byte $69
.byte $69
.byte $6A
.byte $6A
.byte $6A
.byte $6A
.byte $6A
.byte $6A
.byte $6A
.byte $6A
.byte $6B
.byte $6B
.byte $6B
.byte $6B
.byte $6B
.byte $6B
.byte $6B
.byte $6B

.pad [VECTORS]
.word reset
.word reset
.word reset