if [ ! -d build/ ]; then
    mkdir build
fi
if [ ! -d build/roms/ ]; then
    mkdir build/roms
fi

if gcc system.c -Llib -lSDL2 -lSDL2_image; then
    mv a.out build/kittyemu
    cp font.png build/font.png
    
    cp roms/test.65x build/roms/test.65x
    cp roms/test.asm build/roms/test.asm
    
    cp roms/snake.65x build/roms/snake.65x
    cp roms/snake.asm build/roms/snake.asm
    
    cp roms/foxmon.65x build/roms/foxmon.65x
    cp roms/foxmon.asm build/roms/foxmon.asm
    
    cp roms/hello.65x build/roms/hello.65x
    cp roms/hello.asm build/roms/hello.asm
    
    cp roms/music.65x build/roms/music.65x
    cp roms/music.asm build/roms/music.asm
    
    cp roms/frequencies.asm build/roms/frequencies.asm
    
    cp -r CapyASM build/CapyASM
    
    ./build/kittyemu
fi