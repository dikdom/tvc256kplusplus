/**
 * TVC++ Card. 
 * This is the core0 source. All the sources included in this file are
 * executed on core0.
 * The task of this core is to draw the overlay on TVC's screen:
 * - sprites (mono- and multicolor)
 * - text (mono- and multicolor)
 * - graphics
 * The core0
 * - start the system at 200MHz (5ns clock cycle)
 * - initializes core1
 * - initializes tvc-overlay in PIO0
 * and in its main cycle simply
 * - on border opening calculates a new line
 * - feeds the PIO overlay routine with the calculated data
 */

// #define PICO_VTABLE_PER_CORE 1
#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "hardware/irq.h"
#include "hardware/clocks.h"
#include "hardware/exception.h"
#include "pico/multicore.h"

#include "TVC-IO-main-gfx.h"
#include "TVC-IO-main-sys.h"
#include "tvc-graphics.h"
#include "tvc-usb.h"
#include "tvc-routines.h"

#include <string.h>


extern volatile  uint8_t queueHead;
extern volatile uint8_t queueTail;
extern message_t messageQueue[16];
extern volatile uint32_t counter;
extern uint8_t message_id;


repeating_timer_t rt_out;
extern uint8_t TVC_RAM[];
// extern uint16_t fontBaseAddr;
extern uint8_t registerFontBaseAddr;
// extern uint16_t bitmapBaseAddr;
extern uint8_t registerBitmapBaseAddr;

void preinit_core_gfx() {
    uint32_t fontBaseAddr = (registerFontBaseAddr & 0x3f) * 0x0800;
    memcpy(&TVC_RAM[fontBaseAddr], &font_bin, font_len);
    uint32_t bitmapBaseAddr = (registerBitmapBaseAddr & 0x03) * 0x8000;
    for(int i=0; i<240; i++) {
        for(int j=0; j<128; j++) {
            // TVC_RAM[bitmapBaseAddr + i*128 + j] = tvc_16cimage_data[(239-i)*128 + j];
            TVC_RAM[bitmapBaseAddr + i*128 + j] = bkgimg_bin[(239-i)*128 + j + 118];
        }
    }
}

void init_bushandler_gpios();
void init_bushandler_pios();
void initRegisterPointers();


extern absolute_time_t lastStart;
void blink_slow(int n);

void main_graphics() {
    init_graphics_subsystem();
    initRegisterPointers();
    init_routines();
    init_bushandler_pios();
    init_bushandler_gpios();

    // set_raw_exception_handler(HARDFAULT_EXCEPTION, &hardfault_handler, save);

    while(gpio_get(PIN_RESET) == 0) {}


    lastStart = get_absolute_time();
    pio_sm_set_enabled(pio0, 1, true);

    // wait_for_valid_vsync();
    while(true) {
        prepareForStartGfxPIO();

        draw_screen_cycle();
        
        while(gpio_get(PIN_RESET) == 0) {}
    }
}

