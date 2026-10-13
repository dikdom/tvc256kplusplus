#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/pio.h"
#include "hardware/irq.h"
#include "hardware/clocks.h"
#include "hardware/vreg.h"
#include "hardware/watchdog.h"
#include "pico/multicore.h"
#include "hardware/exception.h"


#include "TVC-IO-main-sys.h"
#include "TVC-IO-main-gfx.h"
#include "tvc-graphics.h"
#include "tvc-routines.h"

extern volatile  uint8_t queueHead;
extern volatile uint8_t queueTail;
extern message_t messageQueue[16];
extern volatile uint32_t counter;
extern uint8_t message_id;
extern uint8_t videoMode;

#define USB_ON_CORE0 1

void pre_init() {
    preinit_core_gfx();
    preinit_core_sys();
}

extern uint8_t videoMode;
extern uint16_t savedSkippedClocks;
extern uint8_t savedAdsrStage_1_1;
extern uint8_t savedAdsrStage_1_2;
extern uint32_t savedLFSR15_1;
extern uint32_t savedLFSR5_1;
extern uint32_t savedDLFSR15_1;
extern uint32_t savedDLFSR5_1;
extern uint32_t savedAdsrVolume_1_1;
extern uint32_t savedAdsrVolume_1_2;

/**
 * This works only if the hf occures in core#0, the USB
 */
void my_fault_handler_c(sContextStateFrame *frame) {
    clear_text_screen(NULL);  // Clear the screen to provide a clean slate for fault information
    videoMode = 1;  // set text mode to ensure we can print the fault information
    set_text_color((uint8_t[]){15}); // Set text color to white for better visibility of fault information

    print_string_ascii((uint8_t *)"A hard fault has occurred!\r\n");
    print_string_ascii((uint8_t *)"sp: ");
    uint32_t p = *(uint32_t*)&frame;
    print_hex_word((uint8_t*)&p + 2);
    print_hex_word((uint8_t*)&p);
    print_string_ascii((uint8_t *)"\r\n");

    print_string_ascii((uint8_t *)"r0: ");
    print_hex_word(((uint8_t *)&frame->r0)+2);
    print_hex_word((uint8_t *)&frame->r0);
    print_string_ascii((uint8_t *)"  r1: ");
    print_hex_word(((uint8_t *)&frame->r1)+2);
    print_hex_word((uint8_t *)&frame->r1);
    print_string_ascii((uint8_t *)"\r\n");
    print_string_ascii((uint8_t *)"r2: ");
    print_hex_word(((uint8_t *)&frame->r2)+2);
    print_hex_word((uint8_t *)&frame->r2);
    print_string_ascii((uint8_t *)"  r3: ");
    print_hex_word(((uint8_t *)&frame->r3)+2);
    print_hex_word((uint8_t *)&frame->r3);
    print_string_ascii((uint8_t *)"\r\n");
    print_string_ascii((uint8_t *)"r12:");
    print_hex_word(((uint8_t *)&frame->r12)+2);
    print_hex_word((uint8_t *)&frame->r12);
    print_string_ascii((uint8_t *)"  lr: ");
    print_hex_word(((uint8_t *)&frame->lr)+2);
    print_hex_word((uint8_t *)&frame->lr);
    print_string_ascii((uint8_t *)"\r\n");
    
    print_string_ascii((uint8_t *)"return addr: ");
    print_hex_word(((uint8_t *)&frame->return_address)+2);
    print_hex_word((uint8_t *)&frame->return_address);
    print_string_ascii((uint8_t *)"\r\n");

    print_string_ascii((uint8_t *)"xpsr: ");
    print_hex_word(((uint8_t *)&frame->xpsr)+2);
    print_hex_word((uint8_t *)&frame->xpsr);
    print_string_ascii((uint8_t *)"\r\n");

    print_string_ascii((uint8_t *)"extra reg: ");
    print_hex_word(((uint8_t *)&frame->xpsr)+6);
    print_hex_word(((uint8_t *)&frame->xpsr)+4);
    print_string_ascii((uint8_t *)"\r\n");

    volatile unsigned int cfsr  = *(volatile unsigned int *)0xE000ED28;
    volatile unsigned int hfsr  = *(volatile unsigned int *)0xE000ED2C;
    volatile unsigned int bfar  = *(volatile unsigned int *)0xE000ED38;
    
    print_string_ascii((uint8_t *)"cfsr:");
    print_hex_word(((uint8_t *)&cfsr)+2);
    print_hex_word(((uint8_t *)&cfsr)+0);
    print_string_ascii((uint8_t *)" ");

    print_string_ascii((uint8_t *)"hfsr:");
    print_hex_word(((uint8_t *)&hfsr)+2);
    print_hex_word(((uint8_t *)&hfsr)+0);
    print_string_ascii((uint8_t *)"\r\n");

    print_string_ascii((uint8_t *)"bfar:");
    print_hex_word(((uint8_t *)&bfar)+2);
    print_hex_word(((uint8_t *)&bfar)+0);
    print_string_ascii((uint8_t *)" ");

    while (1) {
        gpio_xor_mask(1u << 25); // Toggle an LED connected to GPIO 25
        sleep_ms(50);
    }


  // If and only if a debugger is attached, execute a breakpoint
  // instruction so we can take a look at what triggered the fault
//   HALT_IF_DEBUGGING();

  // Logic for dealing with the exception. Typically:
  //  - log the fault which occurred for postmortem analysis
  //  - If the fault is recoverable,
  //    - clear errors and return back to Thread Mode
  //  - else
  //    - reboot system
}


__attribute__((naked)) void hardfault_handler() {
    // Infinite loop to halt the program when a hard fault occurs

    __asm volatile(                              
      "tst lr, #4 \n"                            
      "ite eq \n"                                
      "mrseq r0, msp \n"                         
      "mrsne r0, psp \n"                         
      "b my_fault_handler_c \n");

    while (1) {
        gpio_xor_mask(1u << 25); // Toggle an LED connected to GPIO 25
        sleep_ms(100);
    }
}

void blink(int n, int delay) {
    for(int i=0; i<n; i++) {
        gpio_put(PIN_LED, true);
        sleep_ms(delay);
        gpio_put(PIN_LED, false);
        sleep_ms(2*delay);
    }
}

void blink_slow(int n) {
    blink(n, 100);
    sleep_ms(300);
}

void blink_fast(int n) {
    blink(n, 100);
}


/**
 * ARM tasks:
 * core1
 * - graphics
 * - Z80 bushandling interrupts
 * core0
 * - USB
 * - IO port write handling: composite bitverctors, commands
 * PIO tasks:
 * - graphics overlay (PIO0, SM0)
 * - reset line IRQ (PIO0, SM1, irq0)
 * - PIO USB (PIO1)
 * - Z80 bus handler
 *   - U2/U3: SM0, SM1 (irq 0)
 *   - Z80 port0 write: SM2 (irq 1)
 */

int main() {
    gpio_init(PIN_LED);
    gpio_set_dir(PIN_LED, true);
    gpio_init(PIN_RESET);

    blink_slow(1);

    vreg_set_voltage(VREG_VOLTAGE_1_25);
    sleep_ms(100);

    if(!set_sys_clock_khz(336000, true)) {
        while(true)
            blink_fast(500);
    } // Set system clock in kHz

    pre_init();

    #if USB_ON_CORE0    // irq on core0
    *(uint32_t *)BUSCTRL_BASE = 1<<4;
    // *(uint32_t *)BUSCTRL_BASE = (1<<4) | (1<<8);

    uint32_t save = save_and_disable_interrupts();
    ((exception_handler_t *) scb_hw->vtor)[HARDFAULT_EXCEPTION] = hardfault_handler;
    __dmb();
    restore_interrupts_from_disabled(save);

    blink_slow(1);
    
    multicore_launch_core1(main_graphics);

    main_system();
    #else               // irq on core1, gfx on core0
    *(uint32_t *)BUSCTRL_BASE = 1<<0;
    multicore_launch_core1(main_system);
    main_graphics();
    #endif
}