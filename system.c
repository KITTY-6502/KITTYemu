#include <stdio.h>
#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>
#include <termios.h>
#include <unistd.h>
#include <time.h>
#include <stdlib.h>

#include "w6502.c"
#include "psg.c"

/* SDL */

/* must be a power of two, decrease to allow for a lower latency, increase to reduce risk of underrun. */
static Uint16 buffer_size = 4096;

static SDL_AudioDeviceID audio_device;
static SDL_AudioSpec audio_spec;
static int sample_rate = 44100;


const int screen_width = 256; const int screen_height = 256;
const uint8_t* os_keyboard;

const uint32_t tick_interval = 1000/50.1;
uint32_t next_time = 0;

uint8_t system_ram[0x7000];
uint8_t *system_rom;
int     system_rom_size;
uint8_t bank_reg;
PSG     system_psg;

const int system_psg_buff_size = 2000000;
float system_psg_samples[2000000];
int system_psg_sample_index = 0;

int cur_cycle = 7;

int font[256][8][8];


uint32_t palette[16] = {
    0x000000,
    0x630000,
    0x916300,
    0xFF6300,
    
    0x009100,
    0x639100,
    0x91FF00,
    0xFFFF00,
    
    0x0000FF,
    0x6300FF,
    0x9163FF,
    0xFF63FF,
    
    0x0091FF,
    0x6391FF,
    0x91FFFF,
    0xF2FFFF,
};

uint32_t time_left(void)
{
    uint32_t now;

    now = SDL_GetTicks();
    if(next_time <= now)
        return 0;
    else
        return next_time - now;
}

int mygetch ( void ) 
{
  int ch;
  struct termios oldt, newt;
  
  tcgetattr ( STDIN_FILENO, &oldt );
  newt = oldt;
  newt.c_lflag &= ~( ICANON | ECHO );
  tcsetattr ( STDIN_FILENO, TCSANOW, &newt );
  ch = getchar();
  tcsetattr ( STDIN_FILENO, TCSANOW, &oldt );
  
  return ch;
}

int cpu_state(CPU* cpu) {
    //printf("CYCLE: %x | PC: %x INSTRUCTION: %x A: %x X: %x Y: %x STACK POINTER: %x FLAGS: %x", cpu->C, cpu->PC, cpu->I, cpu->A, cpu->X, cpu->Y, cpu->S, cpu->P);
    if (cpu->C == 1)
    printf("A:%X X:%X Y:%X P:%X SP:%X I:%X C:%X | PC:%4X \n", cpu->A, cpu->X, cpu->Y, cpu->P, cpu->S, cpu->I, cpu->C, cpu->PC);
}

static void audio_callback(void *unused, Uint8 *byte_stream, int byte_stream_length);
static int setup_sdl_audio(void) {

    SDL_AudioSpec want;

    SDL_Init(SDL_INIT_AUDIO | SDL_INIT_TIMER);

    SDL_zero(want);
    SDL_zero(audio_spec);

    want.freq = sample_rate;
    /* request 16bit signed little-endian sample format */
    want.format = AUDIO_S16LSB;
    /* request 2 channels (stereo) */
    want.channels = 2;
    want.samples = buffer_size;

    /*
     Tell SDL to call this function (audio_callback) that we have defined whenever there is an audiobuffer ready to be filled.
     */
    want.callback = audio_callback;

    if(1) {
        printf("\naudioSpec want\n");
        printf("----------------\n");
        printf("sample rate:%d\n", want.freq);
        printf("channels:%d\n", want.channels);
        printf("samples:%d\n", want.samples);
        printf("----------------\n\n");
    }

    audio_device = SDL_OpenAudioDevice(NULL, 0, &want, &audio_spec, 0);

    if(1) {
        printf("\naudioSpec get\n");
        printf("----------------\n");
        printf("sample rate:%d\n", audio_spec.freq);
        printf("channels:%d\n", audio_spec.channels);
        printf("samples:%d\n", audio_spec.samples);
        printf("size:%d\n", audio_spec.size);
        printf("----------------\n");
    }

    if (audio_device == 0) {
        if(1) {
            printf("\nFailed to open audio: %s\n", SDL_GetError());
        }
        return 1;
    }

    if (audio_spec.format != want.format) {
        if(1) {
            printf("\nCouldn't get requested audio format.\n");
        }
        return 2;
    }

    buffer_size = audio_spec.samples;
    SDL_PauseAudioDevice(audio_device, 0); /* unpause audio */
    return 0;
}

uint8_t system_access(CPU *cpu,ACCESS *result) {
    uint8_t operand = result->value;
    
    if (result->address < 0x7000) {
        if (result->type == READ) {
            operand = system_ram[result->address];
        } else {
            system_ram[result->address] = operand;
        }
    } else if (result->address < 0x8000) {
        // Keyboard Reading
        if (!(result->address & 0x80)) {
            operand = 0x00;
            int row = (result->address & 0xF0) >> 4;
            uint8_t alt = os_keyboard[SDL_SCANCODE_LALT] || os_keyboard[SDL_SCANCODE_RALT];
            
            int alt_list[21] = {
                SDL_SCANCODE_0,
                SDL_SCANCODE_1,
                SDL_SCANCODE_2,
                SDL_SCANCODE_3,
                SDL_SCANCODE_4,
                SDL_SCANCODE_5,
                SDL_SCANCODE_6,
                SDL_SCANCODE_7,
                SDL_SCANCODE_8,
                SDL_SCANCODE_9,
                
                SDL_SCANCODE_KP_0,
                SDL_SCANCODE_KP_1,
                SDL_SCANCODE_KP_2,
                SDL_SCANCODE_KP_3,
                SDL_SCANCODE_KP_4,
                SDL_SCANCODE_KP_5,
                SDL_SCANCODE_KP_6,
                SDL_SCANCODE_KP_7,
                SDL_SCANCODE_KP_8,
                SDL_SCANCODE_KP_9,
                
                SDL_SCANCODE_DELETE,
            };
            
            for (int i = 0; i < 21; i++) {
                if (os_keyboard[alt_list[i]]) {
                    alt = 1;
                }
            }
            
            uint8_t shift = os_keyboard[SDL_SCANCODE_LSHIFT] || os_keyboard[SDL_SCANCODE_RSHIFT];
            
            int shift_list[1] = {
                SDL_SCANCODE_DELETE,
            };
            
            for (int i = 0; i < 1; i++) {
                if (os_keyboard[shift_list[i]]) {
                    shift = 1;
                }
            }
            
            switch (row) {
                case 4:
                    if (os_keyboard[SDL_SCANCODE_ESCAPE]) operand   |= 0x80;
                    if (os_keyboard[SDL_SCANCODE_W]) operand        |= 0x40;
                    if (os_keyboard[SDL_SCANCODE_E]) operand        |= 0x20;
                    if (os_keyboard[SDL_SCANCODE_R]) operand        |= 0x10;
                    if (os_keyboard[SDL_SCANCODE_T]) operand        |= 0x08;
                    if (os_keyboard[SDL_SCANCODE_U]) operand        |= 0x04;
                    if (os_keyboard[SDL_SCANCODE_I]) operand        |= 0x02;
                    if (os_keyboard[SDL_SCANCODE_O]) operand        |= 0x01;
                    
                    // numbers
                    if (os_keyboard[SDL_SCANCODE_2] | os_keyboard[SDL_SCANCODE_KP_2]) operand        |= 0x40;
                    if (os_keyboard[SDL_SCANCODE_3] | os_keyboard[SDL_SCANCODE_KP_3]) operand        |= 0x20;
                    if (os_keyboard[SDL_SCANCODE_4] | os_keyboard[SDL_SCANCODE_KP_4]) operand        |= 0x10;
                    if (os_keyboard[SDL_SCANCODE_5] | os_keyboard[SDL_SCANCODE_KP_5]) operand        |= 0x08;
                    if (os_keyboard[SDL_SCANCODE_7] | os_keyboard[SDL_SCANCODE_KP_7]) operand        |= 0x04;
                    if (os_keyboard[SDL_SCANCODE_8] | os_keyboard[SDL_SCANCODE_KP_8]) operand        |= 0x02;
                    if (os_keyboard[SDL_SCANCODE_9] | os_keyboard[SDL_SCANCODE_KP_9]) operand        |= 0x01;
                    
                    break;
                case 3:
                    if (alt) operand                                |= 0x80;
                    if (os_keyboard[SDL_SCANCODE_Q]) operand        |= 0x40;
                    if (os_keyboard[SDL_SCANCODE_S]) operand        |= 0x20;
                    if (os_keyboard[SDL_SCANCODE_G]) operand        |= 0x10;
                    if (os_keyboard[SDL_SCANCODE_Y]) operand        |= 0x08;
                    if (os_keyboard[SDL_SCANCODE_J]) operand        |= 0x04;
                    if (os_keyboard[SDL_SCANCODE_K]) operand        |= 0x02;
                    if (os_keyboard[SDL_SCANCODE_P]) operand        |= 0x01;
                    
                    // numbers
                    if (os_keyboard[SDL_SCANCODE_1] | os_keyboard[SDL_SCANCODE_KP_1]) operand        |= 0x40;
                    if (os_keyboard[SDL_SCANCODE_6] | os_keyboard[SDL_SCANCODE_KP_6]) operand        |= 0x08;
                    if (os_keyboard[SDL_SCANCODE_0] | os_keyboard[SDL_SCANCODE_KP_0]) operand        |= 0x01;
                    
                    break;
                case 2:
                    if (shift) operand   |= 0x80;
                    if (os_keyboard[SDL_SCANCODE_A]) operand        |= 0x40;
                    if (os_keyboard[SDL_SCANCODE_D]) operand        |= 0x20;
                    if (os_keyboard[SDL_SCANCODE_V]) operand        |= 0x10;
                    if (os_keyboard[SDL_SCANCODE_H]) operand        |= 0x08;
                    if (os_keyboard[SDL_SCANCODE_M]) operand        |= 0x04;
                    if (os_keyboard[SDL_SCANCODE_L]) operand        |= 0x02;
                    if (os_keyboard[SDL_SCANCODE_BACKSPACE] |
                        os_keyboard[SDL_SCANCODE_DELETE]) operand|= 0x01;
                    
                    break;
                case 1:
                    if (os_keyboard[SDL_SCANCODE_TAB]) operand      |= 0x80;
                    if (os_keyboard[SDL_SCANCODE_Z]) operand        |= 0x40;
                    if (os_keyboard[SDL_SCANCODE_F]) operand        |= 0x20;
                    if (os_keyboard[SDL_SCANCODE_B]) operand        |= 0x10;
                    if (os_keyboard[SDL_SCANCODE_N]) operand        |= 0x08;
                    if (os_keyboard[SDL_SCANCODE_COMMA]) operand    |= 0x04;
                    if (os_keyboard[SDL_SCANCODE_PERIOD]) operand   |= 0x02;
                    if (os_keyboard[SDL_SCANCODE_RETURN] |
                        os_keyboard[SDL_SCANCODE_KP_ENTER]) operand   |= 0x01;
                    break;
                case 0:
                    if (os_keyboard[SDL_SCANCODE_LCTRL]) operand    |= 0x80;
                    if (os_keyboard[SDL_SCANCODE_X]) operand        |= 0x40;
                    if (os_keyboard[SDL_SCANCODE_C]) operand        |= 0x20;
                    if (os_keyboard[SDL_SCANCODE_SPACE]) operand    |= 0x10;
                    if (os_keyboard[SDL_SCANCODE_UP]) operand       |= 0x08;
                    if (os_keyboard[SDL_SCANCODE_LEFT]) operand     |= 0x04;
                    if (os_keyboard[SDL_SCANCODE_DOWN]) operand     |= 0x02;
                    if (os_keyboard[SDL_SCANCODE_RIGHT]) operand    |= 0x01;
                    break;
                default:
                    break;
            }
        } else if ( (result->address & 0xF0) >= 0xE0) {
            operand = psg_access(&system_psg, result);
        } else if ( (result->address & 0xF0) == 0xD0) {
            if (result->type == WRITE) {
                bank_reg = operand;
            }
        }
    } else { // ROM ACCESS
        if (result->type == READ) {
            if (bank_reg >= 128) {
                operand = 0;
            } else {
                int local_address = result->address - 0x8000;
                int rom_address = (local_address + 0x8000*bank_reg) % system_rom_size;
                operand = system_rom[rom_address];
            }
        }
    }
    
    return operand;
}

int render_screen(SDL_Texture* texture) {
    int *pixels = NULL;
    int pitch;

    
    SDL_LockTexture(texture, NULL, (void **) &pixels,&pitch);

    for (int i = 0; i < screen_width*screen_height; i++) {
        int x = i%screen_width;
        int y = i/screen_width;
        
        int p = 0;
        
        int index = (x/8) + (y/8)*32;
        
        uint8_t character = system_ram[0x6800 + index];
        uint32_t pal[2] = {
            palette[system_ram[0x6C00 + index] & 0x0F],
            palette[system_ram[0x6C00 + index] >> 4]
        };
        
        p = font[character][x%8][y%8];
        
        pixels[x + y*(pitch/4)] = pal[p];
    }
    SDL_UnlockTexture(texture);

}
int initram()
{
    for (int i = 0; i < 0x7000; i++) {
        system_ram[i] = rand();
    }
}

int loadrom(char* filename, CPU* cpu) 
{
    FILE *fp;
    fp = fopen(filename, "rb");
    
    // get rom size
    fseek(fp, 0L, SEEK_END);
    system_rom_size = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    if (system_rom_size > 128*32*1024) system_rom_size = 128*32*1024;
    
    // load the file into the rom
    system_rom = realloc(system_rom, system_rom_size * sizeof(int));
    fread(system_rom, sizeof(uint8_t), system_rom_size, fp);
    fclose(fp);
    
    bank_reg = 0;
    cpu->C = 0; cpu->IRQ = 0; cpu->NMI = 0; cpu->RESET = 1;
    cpu->P  = 0x24;
    cpu->S  = 0xFD;
}

int quit = 0;


static void audio_callback(void *unused, Uint8 *byte_stream, int byte_stream_length) {

    /*
     This function is called whenever the audio buffer needs to be filled to allow
     for a continuous stream of audio.
     Write samples to byteStream according to byteStreamLength.
     The audio buffer is interleaved, meaning that both left and right channels exist in the same
     buffer.
     */

    int i;
    int16_t *s_byte_stream;
    int remain;
    static int prev_index = 0;
    static int wait = 2;
    
    if (wait) {
        wait--; return;
    }

    /* zero the buffer */
    memset(byte_stream, 0, byte_stream_length);

    if(quit) {
        return;
    }

    /* cast buffer as 16bit signed int */
    s_byte_stream = (int16_t*)byte_stream;

    /* buffer is interleaved, so get the length of 1 channel */
    remain = byte_stream_length / 2;
    
    /* write random samples to buffer to generate noise */
    int u = 0;
    //float ratio = ((float)3000000 / (float)sample_rate/2);
    float ratio = 1.0f;

    for (i = 0; i < remain; i += 2) {
        float average_l = 0;
        float average_r = 0;

        average_l += system_psg_samples[(prev_index + u) % system_psg_buff_size];
        average_r += system_psg_samples[(prev_index + u+1) % system_psg_buff_size];
        u+=2;

        average_l = average_l*100 / ratio; 
        average_r = average_r*100 / ratio;
        
        s_byte_stream[i] = (uint16_t)average_l;
        s_byte_stream[i+1] = (uint16_t)average_r;
    }
    
    prev_index = (remain+prev_index)%system_psg_buff_size;
    if (system_psg_sample_index-prev_index > remain) {
        prev_index = system_psg_sample_index - remain;
    }
}

int main(int argc, char *argv[])
{   
    srand(time(NULL));
    SDL_Init(SDL_INIT_VIDEO);
    
    SDL_Window* window = SDL_CreateWindow(
        "KITTY Emu",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        screen_width * 2, screen_height* 2,
        SDL_WINDOW_SHOWN
    );
    SDL_Renderer* renderer = SDL_CreateRenderer(
        window,
        -1,
        0
    );
    SDL_Texture* system_screen = SDL_CreateTexture(
        renderer,
        SDL_PIXELFORMAT_RGBA32,
        SDL_TEXTUREACCESS_STREAMING,
        256,256
    ); 
    
    SDL_Surface* font_texture = IMG_Load("font.png");
    SDL_Surface* font_texture_rgb = SDL_ConvertSurfaceFormat(font_texture, SDL_PIXELFORMAT_RGBA32, 0);
    
    SDL_EventState(SDL_DROPFILE, SDL_ENABLE);
    
    uint32_t* pixels = (uint32_t*)font_texture_rgb->pixels;
    //printf("\n%X  ", font_texture_rgb->pitch);
    
    for (int character = 0; character < 256; character++) {
        for (int x = 0; x < 8; x++) {
            for (int y = 0; y < 8; y++) {
                font[character][x][y] = pixels[
                    x + y*(font_texture_rgb->pitch/4) + (character%16)*8 + (character/16)*(font_texture_rgb->pitch/4)*8
                ] == 0xFFFFFFFF;
            }
        }
    }
    
    SDL_FreeSurface(font_texture);
    SDL_FreeSurface(font_texture_rgb);
    
    setup_sdl_audio();
    
    w6502_setup();
    CPU cpu;
    cpu.C = 0; cpu.IRQ = 0; cpu.NMI = 0; cpu.RESET = 1;
    cpu.P  = 0x24;
    cpu.S  = 0xFD;
    initram();
    
    loadrom("roms/test.65x",&cpu);
    
    ACCESS result;
    
    int wait = 0;
    int int_count = 0;
    int cycle_count = -1;
    
    double sbuff_wait = 0;
    double sbuff_reload = 67;
    
    SDL_Event event;
    while (!quit) {
        if (cycle_count >= (384/2)*312 || cycle_count == -1) {
            if (!time_left()) {
            render_screen(system_screen);
            
            SDL_RenderClear(renderer);
            SDL_RenderCopy(renderer, system_screen, NULL, NULL);
            SDL_RenderPresent(renderer);
            SDL_UpdateWindowSurface(window);
            
            next_time = SDL_GetTicks() + tick_interval;
            
            if (cycle_count > 0) cpu.IRQ = 1;
            cycle_count = 0;
            
            while(SDL_PollEvent(&event)){
               switch (event.type) {
                case SDL_QUIT:
                    quit = 1; break;
                // Drag and Drop
                case SDL_DROPFILE:
                    char* filename = event.drop.file;
                    initram();
                    loadrom(filename, &cpu);
                    SDL_free(filename);
                    break;
               }
            }
            SDL_PumpEvents();
            os_keyboard = SDL_GetKeyboardState(NULL);
            }

        }
        else {
        if (cycle_count > 8) cpu.IRQ = 0;
        //printf("\n\nø2 - %d\n", cur_cycle++);
        psg_tick_82c54(&system_psg);
        if (cycle_count%(39*192) == 0 ) {
            psg_tick_noise(&system_psg);
        }
        
        if (sbuff_wait<= 0) {
            //left
            system_psg_sample_index = (system_psg_sample_index+1) % system_psg_buff_size;
            system_psg_samples[system_psg_sample_index] = psg_getsample(&system_psg,1);
            // right
            system_psg_sample_index = (system_psg_sample_index+1) % system_psg_buff_size;
            system_psg_samples[system_psg_sample_index] = psg_getsample(&system_psg,0);
            
            sbuff_wait += sbuff_reload;
        }
        sbuff_wait -= 1.0;
        
        cpu_tick1(&cpu, &result);
        
        uint8_t operand = system_access(&cpu, &result);
        
        //printf(" , %xm %x @%x", result.type, operand, result.address);
        
        cpu_tick2(&cpu, operand);
        
        if (0) {
            cpu_state(&cpu);
            if (result.type == WRITE) {
            printf("Wrote %X(%c) to %4X \n", operand, operand, result.address);
            }
            else {
            printf("Read %X(%c) from %4X \n", operand, operand, result.address);
            }
        }
        
        cycle_count += 1;
        }
    }
    SDL_DestroyWindow(window);
    SDL_Quit();
    
    return 0;
}