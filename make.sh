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
    ./build/kittyemu
fi