#include <stdio.h>
#include "pico/stdlib.h"
#include <stdint.h>
#include "hardware/pio.h"
#include "hardware/clocks.h"
#include "pico/sync.h"
#include "hardware/watchdog.h"
#include <hardware/dma.h>
#include <string.h>
#include <math.h>

#include "tvc-overlay.pio.h"
#include "sprite.h"
#include "tvc-colors.h"
#include "videoton_sprites.h"
#include "TVC-IO-main-sys.h"
#include "TVC-IO-main-gfx.h"
#include "tvc-hat.h"
#include "tvc-usb.h"

sprite_t sprites[SPRITES_NUM];
extern uint8_t TVC_RAM[];
uint16_t scan_line;
absolute_time_t lastStart = 0;
// mutex_t irq_mutex;

/**
 * videoMode=0 : no (empty screen, only sprites)
 * videoMode=1 : 2x text
 * videoMode=2 : 16c text
 * videoMode=3 : 16c bitmap
 */
volatile int8_t videoMode = 0;
volatile bool stayInGfxCycle = true;
uint overlay_offset = 33;

const uint8_t baloon[] = {0, 127,   0,  1, 255, 192,  3, 255, 224,    3, 231, 224,
                    7, 217, 240,  7, 223, 240,  7, 217, 240,    3, 231, 224,
                    3, 255, 224,  3, 255, 224,  2, 255, 160,    1, 127,  64,
                    1,  62,  64,  0, 156, 128,  0, 156, 128,    0,  73,  0, 
                    0,  73,  0,   0, 62,    0,  0,  62,   0,    0,  62,  0, 
                    0,  28, 0};
const uint8_t rectangle[] = {255, 255, 255,  160, 0, 1,  240, 0, 1,    0, 0, 1,  224, 0, 1,    0, 0, 1,
                       192,   0,   1,  128, 0, 1,  128, 0, 1,  128, 0, 1,  128, 0, 1,  128, 0, 1,
                       128,   0,   1,  128, 0, 1,  128, 0, 1,  128, 0, 1,  128, 0, 1,  128, 0, 1,
                       128,   0,   1,  128, 0, 1,  255, 255, 255};

const PIO pio = pio0;
uint64_t  bitmap_mask_buffer[256];
uint64_t  color_table[16];
uint16_t background_mask_buffer[256];
uint16_t background_color_buffer[256];
uint64_t  collision_sprite_idx_buffer[SPRITES_NUM];
uint64_t  collision_2c_sprite_mask_buffer[16];
uint32_t collision_16c_sprite_mask_buffer[256];
uint8_t __aligned(4) screenScrollXreg = 0;
uint8_t __aligned(4) screenScrollYreg = 0;

extern uint16_t registerSpSpCollision;
extern uint16_t registerSpBgCollision;
extern uint16_t registerSpSpIRQMask;
extern uint16_t registerSpBgIRQMask;
extern uint16_t registerSpriteEnabledRead;

// bool registerRasterInterruptEnabled = false;
uint16_t __aligned(2) registerIRQOnRasterLine = 0;
uint64_t  tempRegisterSpriteCollision;
sprite_t tempSprites[SPRITES_NUM];
volatile uint8_t __aligned(4) registerBorderColor;

uint16_t y = 21;
volatile uint16_t maxY = 240+21;
int x = 0;
uint32_t bitmapBaseAddr;
uint32_t spriteBaseAddr;
uint32_t screenBaseAddr;
uint32_t sColorBaseAddr;
uint32_t fontBaseAddr;
extern volatile uint8_t registerBitmapBaseAddr;
extern uint8_t registerSpriteBaseAddress;
extern uint8_t registerScreenBaseAddr;
extern uint8_t registerScreenColorBaseAddr;
extern uint8_t registerFontBaseAddr;
__aligned(4)
uint8_t extc_bits_line[2][256+48];
uint8_t sprite_background_line_mask[256+48];

uint16_t collision_line_buffer[256+48];
uint16_t background_sprite_collision_line_buffer[256+48];

void create_helper_tables() {
	uint8_t *p_bitmap_mask_buffer = (uint8_t *)&bitmap_mask_buffer;
	for (int i = 0; i < 256; i++) {
		uint8_t bm = i;
		for (int b = 0; b < 8; b++) {
			*p_bitmap_mask_buffer = (bm & 0x80) ? 0xff : 0x00;
			p_bitmap_mask_buffer++;
			bm <<= 1;
		}
	}

    uint8_t* p_color_table = (uint8_t*)&color_table;
	for (int i = 0; i < 16; i++) {
		for (int j = 0; j < 8; j++) {
#if BOARD_WAVESHARE_RP2350B_PROTOTYPE_V0
            *p_color_table = i;
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV2
        // e 0 3 2 1  -> e 0 1 2 3
			*p_color_table = i;
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV1
        // e 0 3 2 1  -> e 0 1 2 3
            uint8_t cc = ((i & 1)<<2) | (i & 2) | ((i & 4) >> 2) | (i & 8);
			*p_color_table = cc;
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV0
            uint8_t cc = ((i & 1)<<2) | (i & 2) | ((i & 4) >> 2);
			*p_color_table = (((cc<<2) & (16+8+4)) | (i>7?2:0));
#endif
            p_color_table++;
		}
	}

    for(int i=0; i<256; i++) {
#if BOARD_WAVESHARE_RP2350B_PROTOTYPE_V0
        uint8_t ccl = i & 7;
        uint8_t cch = (i >> 4) & 7;
        
        uint8_t cl = (i & 0x0f) == 0x08 ? 0x10 : i & 0x0f;
        uint8_t ch = (i & 0xf0) == 0x80 ? 0x10 : (i & 0xf0) >> 4;
        background_mask_buffer[i] = ((ch == 0x10) ? 0x00 : 0xff ) | (((cl == 0x10) ? 0x00 : 0xff) << 8);
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV2
        // e 0 1 2 3  -> e 3 0 1 2

        uint8_t cl = (i & 0x0f) == 0x08 ? 0x10 : i & 0x0f;
        uint8_t ch = (i & 0xf0) == 0x80 ? 0x10 : i >> 4;
        background_mask_buffer[i] = ((ch == 0x10) ? 0x00 : 0xff ) | (((cl == 0x10) ? 0x00 : 0xff) << 8);
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV1
        // e 0 3 2 1  -> e 3 0 1 2
        uint8_t ccl = ( (i     & 1) << 2) | ( i     & 2) | (( i     & 4) >> 2) | ( i     & 8);
        uint8_t cch = (((i>>4) & 1) << 2) | ((i>>4) & 2) | (((i>>4) & 4) >> 2) | ((i>>4) & 8);

        uint8_t cl = (i & 0x0f) == 0x08 ? 0x10 : ccl & 0x0f;
        uint8_t ch = (i & 0xf0) == 0x80 ? 0x10 : cch & 0x0f;
        background_mask_buffer[i] = ((ch == 0x10) ? 0x00 : 0xff ) | (((cl == 0x10) ? 0x00 : 0xff) << 8);
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV0
        uint8_t ccl = ((i&1)<<2) | (i&2) | ((i&4)>>2);
        uint8_t cch = (((i>>4) & 1)<<2) | ((i>>4) & 2) | (((i>>4) & 4)>>2);
        
        uint8_t cl = (i & 0x0f) == 0x08 ? 0x01 : ((ccl<<2) & 0x1c) + ((i&8)?0x02:0x00);
        uint8_t ch = (i & 0xf0) == 0x80 ? 0x01 : ((cch<<2) & 0x1c) + ((i&128)?0x02:0x00);
        background_mask_buffer[i] = ((ch == 0x01)?0x00:0xff) | (((cl == 0x01)?0x00:0xff)<<8);
#endif
        background_color_buffer[i] = (((uint16_t)ch)) + (((uint16_t)cl)<<8);
        // printf("%02X. cl: %02X, ch: %02X, bmb: %04X, bcb: %04X\n", i, cl, ch, background_mask_buffer[i], background_color_buffer[i]);
    }

    for(int i=0; i<16; i++) {
        collision_sprite_idx_buffer[i] = (1LL<<i) | ((1LL<<i)<<16) | ((1LL<<i)<<32) | ((1LL<<i)<<48);
    }

	for (int i = 0; i < 16; i++) {
        uint16_t *p_buff = (uint16_t *)(&collision_2c_sprite_mask_buffer[i]);
        uint8_t b = i;
        for(int j=0; j<4; j++) {
            *p_buff = b & 0x8 ? 0xffff : 0x0000;
            b <<=1;
            p_buff++;
        }

        // printf("%d. %016llx\n", i, collision_2c_sprite_mask_buffer[i]);
	}
    
    for (int i = 0; i < 256; i++) {
        uint32_t value = 0xffffffff;
        // uint16_t *p = (uint16_t *)&collision_16c_sprite_mask_buffer[i];
        
        if(( i >> 4) == 0x08) {
            value &= 0xffff0000;
        }
        if((i & 0x0f) == 0x08) {
            value &= 0x0000ffff;
        }
        collision_16c_sprite_mask_buffer[i] = value;
	}
}

void render_bitmap_data(uint8_t* output_buffer, uint8_t bitmap_data, uint8_t color) {
	uint64_t bitmap_mask = bitmap_mask_buffer[bitmap_data];
	*((uint64_t *)output_buffer) = (*((uint64_t *)output_buffer) & ~bitmap_mask) | (color_table[color & 0x0f] & bitmap_mask);
}

void copy_bitmap_line_01(uint8_t *line_buffer, uint8_t *background_buffer, uint16_t yToUse) {
// void copy_bitmap_line_01(uint8_t *line_buffer) {
    if(yToUse < 21) {
        return;
    }
    uint32_t startPos = bitmapBaseAddr + (yToUse-21)*128;
    uint32_t maxPos = startPos + 128;
    uint16_t *pos = (uint16_t *)line_buffer;
    uint16_t *maskBufPos = (uint16_t *)background_buffer;
    
    for(uint32_t i=startPos; i<maxPos; i++) {
        *pos = (*pos & ~background_mask_buffer[TVC_RAM[i]]) | (background_color_buffer[TVC_RAM[i]] & background_mask_buffer[TVC_RAM[i]]); 
        pos++;
        
        *maskBufPos = background_color_buffer[TVC_RAM[i]];
        maskBufPos++;
    }
}

void copy_2color_text_line(uint8_t *line_buffer, uint8_t *background_buffer, uint16_t yToUse) {
    uint32_t screenAddrStart = ((yToUse-21) / 8 ) * 32 + screenBaseAddr;
    uint32_t screenAddrEnd = screenAddrStart + 32;
    uint64_t* pos = (uint64_t *)(line_buffer);
    uint32_t* pos_of_background = (uint32_t *)background_buffer;
    uint8_t midLine = (yToUse-21) % 8;
    int diff = sColorBaseAddr -  screenBaseAddr;
    for(uint32_t screenAddr=screenAddrStart; screenAddr<screenAddrEnd; screenAddr++) {
        uint8_t screenCode = TVC_RAM[screenAddr];
        render_bitmap_data((uint8_t *)pos, TVC_RAM[fontBaseAddr + screenCode*8 + midLine], TVC_RAM[screenAddr + diff]);
        pos++;
        
        /**
         * background-sprite buffer
         */
        uint64_t bitmap_mask = bitmap_mask_buffer[TVC_RAM[fontBaseAddr + screenCode*8 + midLine]];
        *pos_of_background = (bitmap_mask>>32);
        pos_of_background++;
        asm("nop");
        *pos_of_background = bitmap_mask & 0xffffffff;
        pos_of_background++;
    }
}

void copy_fullcolor_text_line(uint8_t *line_buffer, uint8_t *background_buffer, uint16_t yToUse) {
    uint32_t screenAddrStart = ((yToUse-21) / 8 ) * 32 + screenBaseAddr;
    uint32_t screenAddrEnd = screenAddrStart + 32;
    uint8_t midLine = (yToUse-21) % 8;
    uint16_t* pos = (uint16_t *)line_buffer;
    uint32_t fcFontBaseAddress = fontBaseAddr & 0x1E000;
    uint16_t *maskBufPos = (uint16_t *)background_buffer;
    for(uint32_t screenAddr=screenAddrStart; screenAddr<screenAddrEnd; screenAddr++) {
        uint8_t screenCode = TVC_RAM[screenAddr];
        uint32_t fontSourceAddr = fcFontBaseAddress + screenCode * 32 + midLine * 4;
        *pos = (*pos & ~background_mask_buffer[TVC_RAM[fontSourceAddr]]) | (background_color_buffer[TVC_RAM[fontSourceAddr]] & background_mask_buffer[TVC_RAM[fontSourceAddr]]); 
        *maskBufPos = background_mask_buffer[TVC_RAM[fontSourceAddr]];
        fontSourceAddr++;
        pos++;
        maskBufPos++;
        *pos = (*pos & ~background_mask_buffer[TVC_RAM[fontSourceAddr]]) | (background_color_buffer[TVC_RAM[fontSourceAddr]] & background_mask_buffer[TVC_RAM[fontSourceAddr]]); 
        *maskBufPos = background_mask_buffer[TVC_RAM[fontSourceAddr]];
        fontSourceAddr++;
        pos++;
        maskBufPos++;
        *pos = (*pos & ~background_mask_buffer[TVC_RAM[fontSourceAddr]]) | (background_color_buffer[TVC_RAM[fontSourceAddr]] & background_mask_buffer[TVC_RAM[fontSourceAddr]]); 
        *maskBufPos = background_mask_buffer[TVC_RAM[fontSourceAddr]];
        fontSourceAddr++;
        pos++;
        maskBufPos++;
        *pos = (*pos & ~background_mask_buffer[TVC_RAM[fontSourceAddr]]) | (background_color_buffer[TVC_RAM[fontSourceAddr]] & background_mask_buffer[TVC_RAM[fontSourceAddr]]); 
        *maskBufPos = background_mask_buffer[TVC_RAM[fontSourceAddr]];
        pos++;
        maskBufPos++;
    }
}

void mark_collision_2c(uint8_t *collision_pixels, uint8_t pixelData, uint8_t spriteIdx) {
    uint64_t currentSprite;
    uint64_t previousSprites;

    currentSprite = collision_2c_sprite_mask_buffer[pixelData >> 4] & collision_sprite_idx_buffer[spriteIdx];
    previousSprites = *((uint64_t *)collision_pixels) & collision_2c_sprite_mask_buffer[pixelData >> 4];

    if((currentSprite!=0) && (previousSprites!=0)) {
        tempRegisterSpriteCollision |= (currentSprite | previousSprites);
    }

    collision_pixels+=8;

    currentSprite = collision_2c_sprite_mask_buffer[pixelData & 0x0f] & collision_sprite_idx_buffer[spriteIdx];
    previousSprites = *((uint64_t *)collision_pixels) & collision_2c_sprite_mask_buffer[pixelData & 0x0f];

    if((previousSprites!=0) && (currentSprite!=0)) {
        tempRegisterSpriteCollision |= (currentSprite | previousSprites);
    }
    *((uint64_t *)collision_pixels) |= currentSprite;
}

void mark_collision_2c_w(uint8_t *collision_pixels, uint8_t pixelData, uint8_t spriteIdx) {
    for(int i=0; i<2; i++) {
        // uint64_t bob = (*((uint32_t *)collision_pixels)) | (((uint64_t)*( ( ( (uint32_t *)collision_pixels) + 1 ) ) ) << 32);
        uint8_t idx_4_cmb = (i==0) ? pixelData >> 4 : pixelData & 0x0f;
        
        uint32_t cpl = *((uint32_t *)collision_pixels);
        asm("nop");
        uint32_t cph = *((uint32_t *)(collision_pixels + 4));
        
        uint32_t psl = cpl & (uint32_t)(collision_2c_sprite_mask_buffer[idx_4_cmb]);
        uint32_t psh = cph & (uint32_t)(collision_2c_sprite_mask_buffer[idx_4_cmb] >> 32);

        uint32_t csl = (uint32_t)collision_2c_sprite_mask_buffer[idx_4_cmb] & (uint32_t)collision_sprite_idx_buffer[spriteIdx];
        uint32_t csh = (uint32_t)(collision_2c_sprite_mask_buffer[idx_4_cmb]>>32) & (uint32_t)(collision_sprite_idx_buffer[spriteIdx]>>32);
        
        // currentSprite = collision_2c_sprite_mask_buffer[pixelData >> 4] & collision_sprite_idx_buffer[spriteIdx];
        // previousSprites = *((uint64_t *)collision_pixels) & collision_2c_sprite_mask_buffer[pixelData >> 4];
        
        if( ( (csl | csh) !=0 ) && ( (psl | psh) !=0) ) {
            tempRegisterSpriteCollision |= ((csl + ((uint64_t)csh << 32)) | (psl + ( (uint64_t)psh << 32) ) );
        }
        *(uint32_t *) collision_pixels |= csl;
        asm("nop"); // this is needed because 64 bit, non-aligned access causes Fault
        *(uint32_t *) (collision_pixels+4) |= csh;
        
        collision_pixels+=8;
    }
}

void mark_collision_16c(uint32_t *collision_pixels, uint8_t pixelData, uint8_t spriteIdx) {
    // *(uint32_t *)collision_pixels |= collision_16c_sprite_mask_buffer[(pixelData)] | (collision_sprite_idx_buffer[spriteIdx] & 0xffffffff);
    uint32_t currentSprite;
    uint32_t previousSprites;
    currentSprite   = collision_16c_sprite_mask_buffer[pixelData] & (collision_sprite_idx_buffer[spriteIdx] & 0xffff);
    previousSprites = collision_16c_sprite_mask_buffer[pixelData] & *collision_pixels;
    // if(y==STOP_AT_Y)
    //     printf("sIdx: %d, cs: %08x, ps: %08x, tmp: %08x\n", spriteIdx, currentSprite, previousSprites, tempRegisterSpriteCollision);
    if((currentSprite!=0) && (previousSprites!=0)) {
        tempRegisterSpriteCollision |= (currentSprite | previousSprites);
    }
    *collision_pixels |= currentSprite;
}

// 3.36us
// 3.45us
// 1.19us - RAM
void calc_one_sprite_line(uint8_t *line_buffer, bool foreground) {
    sprite_t *sprite = &tempSprites[0];
    const bool isFg = foreground;
    for(int i=0; i<SPRITES_NUM; i++, sprite++) {
        
        if(__builtin_expect(!sprite->enabled, 1)) {
            continue;
        }
        if(__builtin_expect(sprite->foreground != isFg, 1)) {
            continue;
        }

        int rowofsprite = y - sprite->y;
        if((rowofsprite < 0) || 
                (rowofsprite > 20) || 
                (sprite->x >= 256+24)) {
            continue;
        }
        if(!sprite->fullColor) {
            uint32_t baseAddr = spriteBaseAddr + sprite->phase * 64 + rowofsprite * 3;
            uint8_t *spriteData = &TVC_RAM[baseAddr];
            color_t sprite_color = sprite->color;
            render_bitmap_data(&line_buffer[sprite->x], *spriteData, sprite_color);
            mark_collision_2c_w((uint8_t *)&collision_line_buffer[sprite->x], *spriteData, i);
            spriteData++;
            render_bitmap_data(&line_buffer[sprite->x+8], *spriteData, sprite_color);
            mark_collision_2c_w((uint8_t *)&collision_line_buffer[sprite->x+8], *spriteData, i);
            spriteData++;
            render_bitmap_data(&line_buffer[sprite->x+16], *spriteData, sprite_color);
            mark_collision_2c_w((uint8_t *)&collision_line_buffer[sprite->x+16], *spriteData, i);
        } else {
            uint32_t baseAddr = spriteBaseAddr + sprite->phase * 256 + rowofsprite * 12;
            uint8_t *spriteData = &TVC_RAM[baseAddr];
            uint16_t *pos = (uint16_t *)&line_buffer[sprite->x];
            uint32_t *clbPos = (uint32_t *)&collision_line_buffer[sprite->x];
            for(int j=0;j<24; j+=2) {
                *pos = (*pos & ~background_mask_buffer[*spriteData]) | (background_color_buffer[*spriteData] & background_mask_buffer[*spriteData]); 
                mark_collision_16c(clbPos, *spriteData, i);
                spriteData++;
                pos++;
                clbPos++;
            }
        }
    }
}

/*
void testTiming(void) {
// void testTiming() {

    memcpy((uint8_t *)(&TVC_RAM[64]), (uint8_t *)(&baloon), 63);
    for(int i=0; i<8; i++) {
        sprites[i].enabled = true;
        sprites[i].y = 21;
        sprites[i].x = 40+x*4;
        sprites[i].color = 15;
        sprites[i].foreground = (i%2) == 1;
        sprites[i].phase = 1;
    }
    y = 21;
    videoMode = 1;
    while(true) {
        absolute_time_t start_time = get_absolute_time();
        printf("drawOneLine\n");
        for(int i = 0; i<1000; i++) {
            calc_one_sprite_line((uint8_t *)&extc_bits_line[0], false);
            calc_one_sprite_line((uint8_t *)&extc_bits_line[0], true);
            // copy_bitmap_line_01(&extc_bits_line[0]);
            // copy_text_line_01(&extc_bits_line[0]);
            // drawOneLine(&extc_bits_line[0]);
        }
        absolute_time_t end_time = get_absolute_time();
        int64_t write_time_us = absolute_time_diff_us(start_time, end_time);
        printf("duration: %lldus\n", write_time_us);
        sleep_ms(3000);
    }
}
*/

void transferToPIObyDMA(uint8_t *line_buffer) {
    while(dma_channel_is_busy(0)) {}
    pio_sm_put_blocking(pio, 0, 255);
    dma_channel_set_read_addr(0, (uint32_t *)&line_buffer[24], true);
}

/*
void transferToPIObyCPU(uint32_t *line_buffer) {
    pio_sm_put_blocking(pio, 0, 255);
    for(int i=0; i<64; i++) {
        pio_sm_put_blocking(pio, 0, line_buffer[i]);
    }
}
*/

/*
int bounceIdx = 0;
int bcnt = 0;
uint16_t bounceY[100];
void bounceSprites() {
    for(int i=0; i<SPRITES_NUM; i++) {
        sprites[i].y = bounceY[(bounceIdx + i * 0) % 100] + 21;
    }
    if(bcnt++ >= 0) {
        bounceIdx++;
        bcnt = 0;
    }
}
*/

uint16_t build_background_sprite_collision_bitvector() {
    sprite_t *s = &tempSprites[0];
    uint16_t backgroundSpriteCollision = 0;
    for(int spriteIdx=0; spriteIdx<SPRITES_NUM; spriteIdx++, s++) {
        if(! s->enabled)
            continue;
        if((s->y > y) || ((s->y + 20) < y) ) 
            continue;
        if(s->fullColor) {
            uint8_t *spriteData = &TVC_RAM[spriteBaseAddr + s->phase * 256 + (y - s->y) * 12];
            for(int i=0; i<12; i++, spriteData++) {
                uint16_t bkMask = *(uint16_t *)&sprite_background_line_mask[s->x + i*2];
                uint16_t mask = bkMask & background_mask_buffer[*spriteData];
                if(mask!=0) {
                    backgroundSpriteCollision |= (1<<spriteIdx);
                    break;
                }
            }
        } else {
            uint8_t *spriteData = &TVC_RAM[spriteBaseAddr + s->phase * 64 + (y - s->y) * 3];
            for(int i=0; i<3; i++, spriteData++) {
                uint64_t mask = *(uint64_t *)&sprite_background_line_mask[s->x + i*8] & bitmap_mask_buffer[*spriteData];
                if(mask != 0l) {
                    backgroundSpriteCollision |= (1<<spriteIdx);
                    break;
                }
            }
        }
    }
    return backgroundSpriteCollision;
}

void calculate_one_line(uint8_t *line_buffer) {
    uint16_t yToUse = y - (screenScrollYreg & 0x07);
    if((screenScrollYreg & 128) && ((y<21+8) || (y>(maxY)-8))) {
        memset((void *)&line_buffer[24], color_table[registerBorderColor & 0x0f], 256);
    } else {
        int startXPos = 24 + (screenScrollXreg & 0x07);
        memcpy(tempSprites, sprites, sizeof(sprites));
        spriteBaseAddr = (registerSpriteBaseAddress & 0x07) * 0x4000;
        bitmapBaseAddr = (registerBitmapBaseAddr & 0x03) * 0x8000;
        screenBaseAddr = (registerScreenBaseAddr & 0x7F) * 0x0400;
        sColorBaseAddr = (registerScreenColorBaseAddr & 0x7F) * 0x0400;
        fontBaseAddr = (registerFontBaseAddr & 0x3F) * 0x0800;

#if BOARD_WAVESHARE_RP2350B_PROTOTYPE_V0 || BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV1 || BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV2
        memset((void *)&line_buffer[24], 0b00010000, 256);
        memset((void *)&sprite_background_line_mask[24], 0x00, 7); // only the first 7 pixels
        
#else
        memset((void *)&line_buffer[24], 0b00000001, 256);
#endif
        memset(&collision_line_buffer[0], 0x00, sizeof(collision_line_buffer));
        memset(&background_sprite_collision_line_buffer, 0x00, sizeof(background_sprite_collision_line_buffer));
        tempRegisterSpriteCollision = 0;

        calc_one_sprite_line(line_buffer, false);
        if(videoMode == 1) {
            copy_2color_text_line(&line_buffer[startXPos], &sprite_background_line_mask[startXPos], yToUse);
        } else if (videoMode == 2) {
            copy_fullcolor_text_line(&line_buffer[startXPos], &sprite_background_line_mask[startXPos], yToUse);
        } else if (videoMode == 3) {
            copy_bitmap_line_01(&line_buffer[startXPos], &sprite_background_line_mask[startXPos], yToUse);
        } else {
            registerSpBgCollision = 0;
        }
        calc_one_sprite_line(line_buffer, true);

        uint16_t sumOfCollisions = 0;
        if(tempRegisterSpriteCollision!=0) {
            for(int i=0; i<4; i++) {
                sumOfCollisions |= *(((uint16_t *)&tempRegisterSpriteCollision) + i);
            }
        }

        if(screenScrollXreg & 128) {
            uint8_t border_color = color_table[registerBorderColor & 0x0f];
            for(int i=0; i<8; i++) {
                line_buffer[24+i] = border_color;
                line_buffer[24+248+i] = border_color;
                sprite_background_line_mask[24+i] = 0;
                sprite_background_line_mask[24+248+i] = 0;
            }
        }
        uint16_t tempCollision;
        do {
            tempCollision = registerSpSpCollision;
            registerSpSpCollision |= sumOfCollisions;
        } while ((tempCollision | sumOfCollisions) != registerSpSpCollision);

        // uint32_t save = save_and_disable_interrupts();
        // registerSpSpCollision |= sumOfCollisions;
        // restore_interrupts(save);

        if(videoMode != 0) {
            uint16_t tempSpBgC = build_background_sprite_collision_bitvector();
            do {
                tempCollision = registerSpBgCollision;
                registerSpBgCollision |= tempSpBgC;
            } while((tempCollision | tempSpBgC) != registerSpBgCollision);

            // save = save_and_disable_interrupts();
            // registerSpBgCollision |= tempSpBgC;
            // restore_interrupts(save);
        }

        // mutex_exit(&irq_mutex);
    }
}

void printSpSpCollision() {
    uint16_t rsc = registerSpSpCollision;
    registerSpSpCollision = 0;
    for(int i=0; i<16; i++) {
        if((rsc & 0x8000) !=0)
            TVC_RAM[screenBaseAddr+i] = 49;
        else {
            TVC_RAM[screenBaseAddr+i] = 48;
        }
        rsc <<= 1;
    }
}

void printSpBgCollision() {
    uint16_t rsc = registerSpBgCollision;
    registerSpBgCollision = 0;
    for(int i=0; i<16; i++) {
        if((rsc & 0x8000) !=0)
            TVC_RAM[screenBaseAddr+32+i] = 49;
        else {
            TVC_RAM[screenBaseAddr+32+i] = 48;
        }
        rsc <<= 1;
    }
}

void printStartLine(uint16_t startLine) {
    TVC_RAM[screenBaseAddr + 48+10] = startLine%256;
    TVC_RAM[screenBaseAddr + 48+11] = startLine/256;
    
    uint16_t b[] = {10000, 1000, 100, 10, 1};
    uint16_t pos = screenBaseAddr + 1*32 + 2;
    uint16_t d = startLine;
    uint8_t idx = 0;
    while(idx<5) {
        if(d>b[idx]) {
            uint8_t digit = d/b[idx];
            TVC_RAM[pos] = 48 + digit;
            d = d % b[idx];
        }
        pos++;
        idx++;
    }
}

void init_graphics();

void draw_screen_cycle(void) {
    pio_sm_clear_fifos(pio, 0);
    // screen start!
    // int i=0;
    // uint16_t startLine;
#if BOARD_WAVESHARE_RP2350B_PROTOTYPE_V0
    while( (gpioc_hi_in_get() & (1<<(PIN_VSYNC-32) ) ) !=0) {}
    while( (gpioc_hi_in_get() & (1<<(PIN_VSYNC-32) ) ) ==0) {}  //
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV0 || BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV1 || BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV2
    int cnt = 0;
    while (cnt<3) {
        if((gpio_get_all() & (1<<PIN_VSYNC)) == 0) {
            cnt++;
        } else {
            cnt = 0;
        }
    }
    while((gpio_get_all() & (1<<PIN_VSYNC)) == 0) {}
    cnt = 0;
    while (cnt<3) {
        if((gpio_get_all() & (1<<PIN_VSYNC)) != 0) {
            cnt++;
        } else {
            cnt = 0;
        }
    }
    while((gpio_get_all() & (1<<PIN_VSYNC)) !=0) {}
#endif
    pio_sm_put(pio, 0, 0x19750605);
    while(stayInGfxCycle) {
#if BOARD_WAVESHARE_RP2350B_PROTOTYPE_V0
        while( (gpioc_hi_in_get() & (1<<(PIN_VSYNC-32) ) ) ==0) {}
        while( (gpioc_hi_in_get() & (1<<(PIN_VSYNC-32) ) ) !=0) {}  // Wait for one complete line
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV0 || BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV1 || BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV2
        while((gpio_get_all() & (1<<PIN_VSYNC)) !=0) {}
        while((gpio_get_all() & (1<<PIN_VSYNC)) ==0) {}
#endif
        scan_line = 0;
        y=21;
        calculate_one_line((uint8_t *)&extc_bits_line[y & 1]);
        transferToPIObyDMA((uint8_t *)&extc_bits_line[y & 1]);
        // transferToPIObyCPU((uint32_t *)(&extc_bits_line[y & 1][24]));
        // while(dma_channel_is_busy(0)) {}
#if BOARD_WAVESHARE_RP2350B_PROTOTYPE_V0
        while( (gpioc_hi_in_get() & (1<<(PIN_BORDER-32) ) ) == 0) {}
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV0 || BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV1 || BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV2
        while((gpio_get_all() & (1<<PIN_BORDER)) == 0) {}
#endif
        y++;
        // startLine = scan_line;

        while(y < maxY) {
            calculate_one_line((uint8_t *)&extc_bits_line[y & 1]);
            transferToPIObyDMA((uint8_t *)&extc_bits_line[y & 1]);

            // while(dma_channel_is_busy(0)) {}
            // transferToPIObyCPU((uint32_t *)(&extc_bits_line[y & 1][24]));
            // switch_buffer()
#if BOARD_WAVESHARE_RP2350B_PROTOTYPE_V0
            while( (gpioc_hi_in_get() & (1<<(PIN_BORDER-32) ) ) !=0) {}
            while( (gpioc_hi_in_get() & (1<<(PIN_BORDER-32) ) ) ==0) {}
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV0 || BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV1 || BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV2
            while((gpio_get_all() & (1<<PIN_BORDER)) != 0) {}
            // disable_interrupts();
            while((gpio_get_all() & (1<<PIN_BORDER)) == 0) {}
#endif
            y++;
        }
        // uint32_t save = save_and_disable_interrupts();
        if(((registerSpSpCollision & registerSpSpIRQMask) != 0) ||
           ((registerSpBgCollision & registerSpBgIRQMask) != 0)) {
            gpioc_lo_oe_set(1 << PIN_INTn);
        }
        // restore_interrupts(save);
        // bounceSprites();
        // printSpSpCollision();
        // printSpBgCollision();
    }
    stayInGfxCycle = true;
    for(int i=0; i<16; i++)
        sprites[i].enabled = false;
    registerSpriteEnabledRead = 0x0000;
}

/**
 * Initialize the graphics peripherals:
 *   data structures
 *   PIO
 */

uint8_t clear_text_screen(uint8_t *);

void init_graphics() {
    // mutex_init(&irq_mutex);

    for (int i = 0; i < SPRITES_NUM; i++) {
        sprites[i].x = i*12 + 24; // (int)((double)(256-24)/(SPRITES_NUM - 1) * i) + 24;
        sprites[i].y = 21;
        sprites[i].color = 15;// (i==0?15:i+8);
        sprites[i].enabled = false;
        sprites[i].phase = 0x40;// 0x40; //2+i;
        sprites[i].foreground = true;
        sprites[i].fullColor = true; // true;
    }
    memcpy(&TVC_RAM, &baloon[0], sizeof(baloon));
    memcpy(&TVC_RAM[64], &rectangle, sizeof(rectangle));
    memcpy(&TVC_RAM[128], &videoton_sprites, sizeof(videoton_sprites));
    // memcpy(&TVC_RAM[fontBaseAddr], &font_bin, font_len);
    // for(int i=0; i<8; i++)
    //     *(uint32_t *)&TVC_RAM[fontBaseAddr + 32*8*4 + i] = 0x08080808;  // clearing the space as if this font was 16c
    // memcpy(&TVC_RAM[spriteBaseAddr + 0x40 * 256], &tvc_16csprite_data[0], sizeof(tvc_16csprite_data));
    for(int i=0; i<21; i++) {
        for(int j=0; j<12; j++) {
            TVC_RAM[(registerSpriteBaseAddress * 0x4000) + 0x40 * 256 + i*12 + j] = tvc_16csprite_data[(20-i) * 12 + j];
        }
    }
    
    for(int i=0; i<1024; i++) {
        if((i>256) && (i<512))
            TVC_RAM[(registerScreenBaseAddr * 0x0400) + i] = i & 0xff;
        else
            TVC_RAM[(registerScreenBaseAddr * 0x0400) + i] = 0x20;
        TVC_RAM[(registerScreenColorBaseAddr * 0x0400) + i] = i & 0x0f;
    }
    for(int i=0; i<16; i++)
        TVC_RAM[(registerScreenColorBaseAddr * 0x0400) + i] = 0x0f;

    // memset(&TVC_RAM[bitmapBaseAddr], 0x88, 0x8000);
    // memcpy(&TVC_RAM[bitmapBaseAddr], &tvc_16cimage_data[0], sizeof(tvc_16cimage_data));
    // for(int i=0; i<240; i++) {
    //     for(int j=0; j<128; j++) {
    //         TVC_RAM[bitmapBaseAddr + i*128 + j] = tvc_16cimage_data[(239-i)*128 + j];
    //     }
    // }
    // scrollXreg = 128 + 3;
    // scrollYreg = 128 + 7;
    videoMode = 0;
    clear_text_screen(NULL);

    // for(int i=0; i<100; i++) {
    //     bounceY[i] = 220 - sin(M_PI / 100.0 * i) * 220;
    // }
    // bounceSprites();
}

void init_dma() {
    dma_channel_config_t dma_ch_config = dma_channel_get_default_config(0);
    channel_config_set_read_increment(&dma_ch_config, true);
    channel_config_set_write_increment(&dma_ch_config, false);
    channel_config_set_dreq(&dma_ch_config, pio_get_dreq(pio, 0, true));
    channel_config_set_transfer_data_size(&dma_ch_config, DMA_SIZE_32);

    dma_channel_configure(0, 
                          &dma_ch_config,
                          &pio->txf[0],        // Destination pointer
                          &extc_bits_line[0][24],       // Source pointer
                          64, // Number of transfers
                          false                // Start immediately
    );
}

extern uint8_t SID[32];

void reset_handler() {
    // currentP2 = 0x04;
    // currentP3 = 0x05;
    uint64_t diff = absolute_time_diff_us(lastStart, get_absolute_time());
    if( diff > 1000000) {    // more than a sec
        lastStart = get_absolute_time();
        videoMode = 0;
        y=maxY;
        screenScrollXreg = 0;
        screenScrollYreg = 0;
        for(int i=0; i<15; i++) {
            sprites[i].enabled = false;
        }
        SID[24] = 0;
        stayInGfxCycle = false;
    } else {
        watchdog_reboot(0, 0, 0);
    }
    pio_interrupt_clear(pio0, 0);
}

void init_overlay_pio() {
    pio_set_gpio_base(pio, 16);
    // printf("set base: %d\n", pio_set_gpio_base(pio, 16));
    
    uint gfx_offset = pio_add_program(pio, &draw_overlay_new_program);
    // printf("Loaded draw_overlay PIO program at %d\n", offset);
#if BOARD_WAVESHARE_RP2350B_PROTOTYPE_V0
    printf("draw_overlay PIO init: %d\n", draw_overlay_program_init(pio, 0, offset, PIN_6M25, PIN_EC3));
    // pio_sm_set_pins64(pio, 0, 1ll<<PIN_EC3);
    // pio_sm_set_pins64(pio, 0, 1ll<<PIN_EC2);
    // pio_sm_set_pins64(pio, 0, 1ll<<PIN_EC1);
    // pio_sm_set_pins64(pio, 0, 1ll<<PIN_EC0);
    pio_sm_set_pins64(pio, 1, 1ll<<PIN_EXTC);
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV0
    printf("draw_overlay PIO init: %d\n", draw_overlay_new_program_init(pio, 0, offset, PIN_6M25, PIN_EXTC));
    pio_sm_set_pins64(pio, 0, 1ll<<PIN_EXTC);
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV1
    printf("draw_overlay PIO init: %d\n", draw_overlay_new_program_init(pio, 0, gfx_offset, PIN_6M25, PIN_EC1));
    pio_sm_set_pins64(pio, 0, 1ll<<PIN_EXTC);
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV2
    draw_overlay_new_program_init(pio, 0, gfx_offset, PIN_6M25, PIN_EC3);
    // printf("draw_overlay PIO init: %d\n", draw_overlay_new_program_init(pio, 0, gfx_offset, PIN_6M25, PIN_EC3));
    pio_sm_set_pins64(pio, 0, 1ll<<PIN_EXTC);
#endif
    pio_sm_set_enabled(pio, 0, true);

    uint reset_offset = pio_add_program(pio, &reset_rp2350_program);
    reset_rp2350_program_init(pio, 1, reset_offset, PIN_RESET);
    pio_sm_set_pins(pio, 1, PIN_RESET);

    pio_set_irq0_source_enabled(pio, pis_interrupt0, true);
    irq_set_exclusive_handler(PIO0_IRQ_0, &reset_handler);

    irq_set_enabled(PIO0_IRQ_0, true);
    overlay_offset = gfx_offset;
}

void wait_for_valid_vsync() {
    int count = 0; 
    while(count<5) {
        while( (gpio_get_all() & (1 << PIN_VSYNC ) ) !=0) {}
        sleep_ms(10);
        if( (gpio_get_all() & (1 << PIN_VSYNC ) ) ==0) {
            count = 0;
            while( (gpio_get_all() & (1 << PIN_VSYNC) ) ==0) {}
            continue;
        }  // valid vsync
        sleep_ms(10);
        if( (gpio_get_all() & (1 << PIN_VSYNC ) ) !=0) {
            count = 0;
            continue;
        }
        count++;
    }
}

void prepareForStartGfxPIO() {
    if(overlay_offset!=33) {
        pio_sm_set_enabled(pio, 0, false);
        if(dma_channel_is_busy(0))
        dma_channel_abort(0);
        while(dma_channel_is_busy(0)) {}
        pio_sm_clear_fifos(pio, 0);
        pio_sm_restart(pio, 0);
        pio_sm_exec(pio, 0, pio_encode_jmp(overlay_offset));
        pio_sm_set_enabled(pio, 0, true);
    }
}

void init_graphics_subsystem() {
    create_helper_tables();
    init_graphics();
    init_overlay_pio();
    init_dma();
    gpio_init(PIN_RESET);
}