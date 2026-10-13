/**
 * TVC 256k++ Card. 
 */

#define PICO_VTABLE_PER_CORE 1
#include "TVC-IO-main-gfx.h"
#include <stdio.h>
#include <string.h>
#include "pico/stdlib.h"
#include "pico/time.h"
#include "hardware/pio.h"
#include "hardware/irq.h"
#include <hardware/dma.h>
#include <hardware/pwm.h>
#include <hardware/ticks.h>
#include "hardware/xip_cache.h"
#include "hardware/flash.h"
#include "hardware/sync.h"
#include "pico/multicore.h"
#include "tvc-system.pio.h"
#include "tvc-dbushandler.pio.h"
#include "TVC-IO-main-sys.h"
#include "sprite.h"
#include "psram.h"
#include "tvc-routines.h"
#include "tvc-usb.h"
#include "tusb.h"
#include "hardware/structs/xip_ctrl.h"
#include "hardware/structs/qmi.h"
#include "tvc-sound.h"
#include "hardware/structs/busctrl.h"
#include "tvc-lfs-flash.h"
#include "tvc-lfs-psram.h"


#include "ff.h"
#include "tvc-fatfs.h"
#include "tvc-fatfs-pendrive.h"
#include "tvc-fatfs-dskdrive.h"

#define DEBUG 0 // Set to 1 to enable debug prints
#define PIO_MEM pio2
#define PIO_SM_READ 0
#define PIO_SM_WRITE 1

#define MSG_TYPE_READRAM_P2  1
#define MSG_TYPE_WRITERAM_P2 2
#define MSG_TYPE_READRAM_P3  3
#define MSG_TYPE_WRITERAM_P3 4
#define MSG_TYPE_EXPN_READ   5
#define MSG_TYPE_EXPN_WRITE  6
#define MSG_TYPE_SLOTN_READ  7
#define MSG_TYPE_SLOTN_WRITE 8
#define MSG_TYPE_HEARTBEAT  16

#define MEMORY_RAM_SIZE 256
#define MEMORY_ROM_SIZE 8

#define MOUSE_SPEED_STORAGE_ADDR 0x00040000

uint8_t TVC_RAM[(MEMORY_RAM_SIZE+32) * 1024];
uint8_t TVC_ROM[MEMORY_ROM_SIZE * 1024];
volatile uint8_t *psram_array;
uint8_t __aligned(4) currentP2 = 0x04;
uint8_t __aligned(4) currentP3 = 0x05;
uint16_t  registerTempTarget8MP2 = 0xffff;
volatile uint16_t  registerTarget8MP2 = 0xffff;
uint16_t  registerTempTarget8MP3 = 0xffff;
volatile uint16_t  registerTarget8MP3 = 0xffff;
uint16_t  registerMapped8MP2 = 0xffff;
uint16_t  registerMapped8MP3 = 0xffff;

uint8_t *register_pointer_storage_read[256] = {NULL};
uint8_t *register_pointer_storage_write[256] = {NULL};
uint8_t register_select[2] = {0, 0};
uint8_t register_increment[2] = {1, 1};

uint16_t registerSpriteEnabledRead;
uint16_t registerSpriteEnabledWrite;

uint16_t  registerSpriteForegroundRead;
uint16_t  registerSpriteForegroundWrite;

uint16_t  registerSpriteColorModeRead;
uint16_t  registerSpriteColorModeWrite;

volatile uint16_t registerSpSpCollision = 0;
volatile uint16_t registerSpBgCollision = 0;
volatile uint16_t registerSpSpIRQMask = 0;
volatile uint16_t registerSpBgIRQMask = 0;

// bool registerSpriteInterruptEnabled = false;

uint8_t registerSpriteBaseAddress = 0;  // default sprites at 0x0000
uint8_t registerScreenBaseAddr = 1;  // default screen at 0x0400
uint8_t registerScreenColorBaseAddr = 2;  // default screen color at 0x0800
uint8_t registerFontBaseAddr = 2;  // default font at 0x1000
volatile uint8_t registerBitmapBaseAddr = 1;  // default to bitmap at 0x8000
uint8_t registerPSRAMSize;
uint8_t registerROMPageRead = 0;
uint8_t registerROMPageWrite = 0;

volatile uint8_t registerFunctionSelect = 0;
uint8_t registerFunctionParamStart = 0;
volatile uint8_t registerFunctionResult = 0;
uint8_t registerFunctionMultiSelect = 0;

volatile uint8_t registerUSBMSCCommand = 0;

uint8_t registerUSBDebug = 0x00;


volatile uint32_t counter = 0;

volatile uint8_t queueHead = 0;
volatile uint8_t queueTail = 0;
message_t messageQueue[256];
uint8_t message_id = 0;

extern sprite_t sprites[];
extern uint8_t videoMode;
// extern uint16_t spriteBaseAddr;
// extern uint16_t bitmapBaseAddr;
// extern uint16_t screenBaseAddr;
// extern uint16_t sColorBaseAddr;
// extern uint16_t fontBaseAddr;
extern uint8_t screenScrollXreg;
extern uint8_t screenScrollYreg;
extern uint16_t spriteCollision;
extern uint8_t registerBorderColor;

uint8_t registerFirmwareVersionMajor = FW_VERSION_MAJOR;
uint8_t registerFirmwareVersionMinor = FW_VERSION_MINOR;

// extern mutex_t sprite_access_mutex;
extern mutex_t irq_mutex;

// extern tvc_function_t        tvc256k_function_array[];
extern tvc_function_struct_t tvc256k_funct_struct_array[];
// extern tvc_function_struct_t tvc256k_funct_struct_array_source[];
// extern uint64_t              tvc256k_funct_param_size_array[];

extern uint8_t registerInitializedUSBDevices;
extern uint8_t registerUSBMouseButtons;
// extern int8_t  registerUSBMouseDX;
// extern int8_t  registerUSBMouseDY;
extern int8_t  registerUSBMouseDWheel;
extern uint8_t registerUSBMouseSpeedRead;
extern uint8_t registerUSBMouseSpeedWrite;
extern volatile uint32_t mouseUpdateXID;
extern volatile uint32_t mouseUpdateYID;
extern mouse_move_t mouseMove;
extern uint8_t mouseRetrievedPort;
uint16_t nextMouseSpeedPos;
uint8_t flash_data_buffer[FLASH_SECTOR_SIZE] __aligned(4);

extern uint16_t y;
extern uint16_t maxY;
extern uint16_t screenMaxY;

extern uint8_t SID[32];
uint8_t dummySIDWriteRegister;
extern uint8_t sidQueueWritePos;
// extern uint32_t sidTimeStampQueue[256];
// extern uint16_t sidAddrValueQueue[256];
extern sid_write_queue_t sid_write_queue[256];

// uint8_t multiParamBuffer[256];

uint8_t registerFunctionBitmapBase = 0xff;

extern uint8_t dsk_file_type;

extern bool flash_drive_initialized;

/**
 * This IRQ handler catches the write to PORT 0x00 (TVC Border color)
 */
void irq_handler_border_io() {
    uint8_t data = gpioc_hi_in_get() & 0xff;
#if BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV1
    registerBorderColor =   // grb -> rgb
        ((data >> 1 ) & 0x01) | // 00000010 , b , >> 1
        ((data >> 1 ) & 0x04) | // 00001000 , r , >> 1 
        ((data >> 4 ) & 0x02) | // 00100000 , g , 
        ((data >> 4 ) & 0x08);  // 10000000 , i
#elif BOARD_PCB_WEACT_RP2350B_PROTOTYPE_REV2
    registerBorderColor =   // grb -> rgb
        ((data >> 1 ) & 0x01) | // 00000010 , b , >> 1
        ((data >> 1 ) & 0x04) | // 00001000 , r , >> 1 
        ((data >> 4 ) & 0x02) | // 00100000 , g , 
        ((data >> 4 ) & 0x08);  // 10000000 , i
#else
    registerBorderColor =   // grb -> rgb
        ((data >> 1 ) & 0x01) | // 00000010 , b , >> 1
        ((data >> 1 ) & 0x04) | // 00001000 , r , >> 1 
        ((data >> 4 ) & 0x02) | // 00100000 , g , 
        ((data >> 4 ) & 0x08);  // 10000000 , i
#endif

    pio_interrupt_clear(PIO_MEM, 1);
}

/**
 * These z80 bushandler related functions are executed on 
 * core 1 - gfx core.
 */

// typedef struct {
//     uint32_t ts;
//     uint32_t address;
//     uint8_t data;
//     bool isWrite;
// } data_queue_t;

// uint8_t dqPos = 0;
// data_queue_t data_queue[256];

void irq_handler_mreq_p() {
    uint32_t gpios = gpio_get_all();
    uint8_t *currentP = (gpios & (1<<PIN_P2)) ? &currentP3 : &currentP2;
    if( *currentP != 0xff)  {
        // uint32_t t = timer1_hw->timelr;
        gpioc_hi_oe_set(1<<(PIN_PHANTOM-32));
        // gpioc_hi_out_clr(1<<(PIN_PHANTOM-32));
        uint32_t shift = (uint32_t)(*currentP) * 16 * 1024;
        uint16_t addr = ( gpios >> PIN_A0 ) & ADDRESS_MASK;  // page address
        if((gpios & (1<<PIN_RD)) == 0) {
            // read
            uint8_t data = TVC_RAM[shift + addr];
            gpioc_hi_out_put((uint32_t)data);
            gpioc_hi_oe_set((1<<(PIN_PHANTOM-32)) | (0xff<<(PIN_D0 - 32)));
            // data_queue[dqPos].address = shift + addr;
            // data_queue[dqPos].data = data;
            // data_queue[dqPos++].isWrite = false;
        } else {
            // write
            TVC_RAM[shift + addr] = gpioc_hi_in_get() & 0xff;
            // data_queue[dqPos].address = shift + addr;
            // data_queue[dqPos].data = TVC_RAM[shift + addr];
            // data_queue[dqPos++].isWrite = true;
            // __isb();
        }
        pio_interrupt_clear(PIO_MEM, 0);
        while((gpio_get_all() & (1<<PIN_MREQ)) == 0) {}
        gpioc_hi_out_set(1<<(PIN_PHANTOM-32));
        __nop();
        gpioc_hi_oe_clr((1<<(PIN_PHANTOM-32)) | (0xff<<(PIN_D0 - 32)));
        gpioc_hi_out_clr(1<<(PIN_PHANTOM-32));
        // gpioc_hi_out_clr(0xff<<(PIN_D0 - 32));
        // gpioc_hi_oe_clr(1<<(PIN_PHANTOM-32));
    } else {
        pio_interrupt_clear(PIO_MEM, 0);
    }
}

void irq_handler_slotn() {
    uint32_t gpios = gpio_get_all();
    if((gpios & (1<<PIN_EXPn)) == 0) {
        uint16_t addr = ( gpios >> PIN_A0 ) & 0x1FFF;  // in EXT it is C000-DFFF
        if((gpios & (1<<PIN_RD))==0) {
            uint8_t data = TVC_ROM[addr];
            gpioc_hi_out_put((uint32_t)data);
            gpioc_hi_oe_set(0xff<<(PIN_D0 - 32));
            gpio_acknowledge_irq(PIN_EXPn, GPIO_IRQ_EDGE_FALL);
            while ((gpioc_lo_in_get() & (1<<PIN_RD)) == 0) {}
            gpioc_hi_oe_clr(0xff<<(PIN_D0 - 32));
            // messageQueue[queueHead++] = (message_t){.id=message_id++, .msgType = MSG_TYPE_EXPN_READ, .address = addr, .data = data };
        } else if(addr >= 0x1800) {
            TVC_ROM[addr] = gpioc_hi_in_get() & 0xff;
            gpio_acknowledge_irq(PIN_EXPn, GPIO_IRQ_EDGE_FALL);
        } else {
            gpio_acknowledge_irq(PIN_EXPn, GPIO_IRQ_EDGE_FALL);
        }
        return;
    } else if( ( gpios & (1<<PIN_RD) ) == 0) {
        // SLOT READ
        uint8_t addr = ( gpios >> PIN_A0 ) & 0x07;
        uint8_t data = 0;
        uint8_t prev_register_selected = 0xff;
        uint8_t *port_p;
        if((addr & 0x03) == 0) {  // port select
            data = register_select[addr>>2];
        } else if((addr & 0x03) == 1) { // data select
            prev_register_selected = register_select[addr >> 2]; // Primary or Secondary register select
            port_p = register_pointer_storage_read[prev_register_selected];
            if(port_p != NULL) {
                data = *port_p;
            }
        } else if((addr & 0x03) == 2) {
            data = register_increment[addr >> 2];
        }
        gpioc_hi_out_put((uint32_t)data);
        gpioc_hi_oe_set(0xff << (PIN_D0 - 32));

        if((addr & 0x03) == 1) {
            register_select[addr >> 2] += register_increment[addr >> 2];
            if(prev_register_selected == REG_USB_MOUSE_DX) {
                mouseUpdateXID++;
                *port_p = 0;
                // mouseRetrievedPort = prev_register_selected - REG_USB_MOUSE_DX;
            } else if(prev_register_selected == REG_USB_MOUSE_DY) {
                mouseUpdateYID++;
                *port_p = 0;
                // mouseRetrievedPort = prev_register_selected - REG_USB_MOUSE_DX;
            } else if(prev_register_selected == REG_SPRITE_SP_COLLISION_LOW) {
                // mutex_enter_blocking(&irq_mutex);
                registerSpSpCollision = 0;
                gpioc_lo_oe_clr( 1 << PIN_INTn );
                // mutex_exit(&irq_mutex);
            } if(prev_register_selected == REG_SPRITE_BG_COLLISION_LOW) {
                registerSpBgCollision = 0;
                gpioc_lo_oe_clr( 1 << PIN_INTn );
            }
        }

        gpio_acknowledge_irq(PIN_SLOTn, GPIO_IRQ_EDGE_FALL);
        while((gpioc_lo_in_get() & (1<<PIN_RD)) == 0) {}
        gpioc_hi_oe_clr(0xff<<(PIN_D0 - 32));
    } else {
        // SLOT WRITE
        uint16_t addr = ( gpios >> PIN_A0 ) & 0x07;
        uint8_t prev_register_selected = 0xff;
        // while(gpio_get_all() & (1<<PIN_WR)) {}
        uint8_t data = gpioc_hi_in_get() & 0xff;

        if((addr & 0x03) == 0) {  // port select
            register_select[addr>>2] = data;
        } else if ((addr & 0x03) == 1) { // data select
            prev_register_selected = register_select[addr >> 2];
            uint8_t *regdata_p = register_pointer_storage_write[prev_register_selected];
            if(regdata_p != NULL) {
                *regdata_p = data;
            }
            register_select[ addr >> 2 ] += register_increment[ addr >> 2 ];
            // if( (prev_register_selected == REG_FUNCTION_EXECUTE ) ) {
            //     registerUSBDebug++;
            // }
        } else if((addr & 0x03) == 2) {
            register_increment[ addr >> 2 ] = data;
        }
        
        gpio_acknowledge_irq(PIN_SLOTn, GPIO_IRQ_EDGE_FALL);
        gpio_xor_mask(1<<PIN_LED);

        if((addr & 0x03) == 1) {
            if(prev_register_selected>=REG_VSID_BASE ) {
                uint64_t t1_64 = timer_time_us_64(timer1_hw);
                uint32_t sid_clk = t1_64 / 341;
                sid_write_queue[sidQueueWritePos].ts = sid_clk; 
                sid_write_queue[sidQueueWritePos].address_value = data + ((prev_register_selected - REG_VSID_BASE) << 8);
                sidQueueWritePos++;
            } else if(prev_register_selected>=REG_SPRITE_ENABLE_LOW ) {
                messageQueue[queueHead++] = (message_t) {
                                                        // .id=message_id++, 
                                                        .msgType = MSG_TYPE_SLOTN_WRITE, 
                                                        // .address = addr, 
                                                        .registerSelect = prev_register_selected,
                                                        .data = data };
            } else if(prev_register_selected>=REG_SPRITE_FOREGROUND ) {
                messageQueue[queueHead++] = (message_t){
                                                        // .id=message_id++, 
                                                        .msgType = MSG_TYPE_SLOTN_WRITE, 
                                                        // .address = addr, 
                                                        .registerSelect = prev_register_selected & 0xf0,
                                                        .data = data };
            }
        }
    }
}


void init_bushandler_pios() {
    // Initialize PIOs for TVC-IO operations

    uint offset_memreq_p2 = pio_add_program(PIO_MEM, &memreq_ram_p2_program);
    // printf("Loaded memreq_p2 program at %d\n", offset_memreq_p2);
    memreq_ram_p2_program_init(PIO_MEM, 0, offset_memreq_p2, PIN_MREQ);

    uint offset_memreq_p3 = pio_add_program(PIO_MEM, &memreq_ram_p3_program);
    // printf("Loaded memreq_p3 program at %d\n", offset_memreq_p3);
    memreq_ram_p3_program_init(PIO_MEM, 1, offset_memreq_p3, PIN_MREQ);

    uint offset_border_io = pio_add_program(PIO_MEM, &border_io_program);
    // printf("Loaded memreq_p3 program at %d\n", offset_memreq_p3);
    border_io_program_init(PIO_MEM, 2, offset_border_io, PIN_RD);


    pio_set_irq0_source_enabled(PIO_MEM, pis_interrupt0, true);
    irq_set_exclusive_handler(PIO2_IRQ_0, &irq_handler_mreq_p);
    // irq_set_exclusive_handler(PIO2_IRQ_0, &irq_handler_mreq_p2);

    pio_set_irq1_source_enabled(PIO_MEM, pis_interrupt1, true);
    irq_set_exclusive_handler(PIO2_IRQ_1, &irq_handler_border_io);
    // irq_set_exclusive_handler(PIO2_IRQ_1, &irq_handler_mreq_p3);

    irq_set_priority(PIO2_IRQ_0, 0x00);
    irq_set_priority(PIO2_IRQ_1, 0x00);

    irq_set_enabled(PIO2_IRQ_0, true);
    irq_set_enabled(PIO2_IRQ_1, true);

#if BOARD_WAVESHARE_RP2350B_PROTOTYPE_V0
    for(int i=0; i<PIN_INTn ; i++) 
        pio_gpio_init(PIO_MEM, i); // Initialize pins to function PIO
    
  #ifdef PIO_DBUS_HANDLER
    for(int i=PIN_D0; i<=PIN_PHANTOM; i++) 
        pio_gpio_init(PIO_MEM, i); // Initialize pins to function PIO
        
    uint offset_dbus_mreq_handler = pio_add_program(PIO_MEM, &dbus_handler_program);
    printf("Loaded dbus handler program at %d\n", offset_dbus_mreq_handler);
    dbus_handler_program_init(PIO_MEM, 2, offset_dbus_mreq_handler, PIN_MREQ, PIN_D0);
    
    uint offset_dbus_iorq_handler = pio_add_program(PIO_MEM, &dbus_handler_program);
    printf("Loaded dbus handler program at %d\n", offset_dbus_iorq_handler);
    dbus_handler_program_init(PIO_MEM, 3, offset_dbus_iorq_handler, PIN_SLOTn, PIN_D0);
    pio_sm_set_enabled(PIO_MEM, 2, true);
    pio_sm_set_enabled(PIO_MEM, 3, true);
  #endif
    
#else
    for(int i=1; i<PIN_A0; i++) 
        pio_gpio_init(PIO_MEM, i); // Initialize pins to function PIO
#endif

    pio_sm_set_enabled(PIO_MEM, 0, true);
    pio_sm_set_enabled(PIO_MEM, 1, true);
    pio_sm_set_enabled(PIO_MEM, 2, true);
}

void init_bushandler_gpios() {
    // printf("gpio init ...\n");
#if BOARD_WAVESHARE_RP2350B_PROTOTYPE_V0
    for(int i=0; i<=PIN_PHANTOM; i++) {
        gpio_init(i);
    }
    gpio_init(PIN_LED);
    gpio_set_dir_masked64((1ll<<PICO_DEFAULT_LED_PIN), 1ll<<PICO_DEFAULT_LED_PIN);
    gpio_put(PIN_PHANTOM, 0); // Set /PHANTOM low
    printf("put 0 to PIN_PHANTOM done\n");
    gpio_put(PIN_INTn, 0);
    printf("put 0 to PIN_INTn done\n");
    for(int i=0; i<8; i++) {
        gpio_set_drive_strength(i, GPIO_DRIVE_STRENGTH_12MA);
        gpio_set_slew_rate(i, GPIO_SLEW_RATE_FAST);
    }
    gpio_set_drive_strength(PIN_PHANTOM, GPIO_DRIVE_STRENGTH_12MA);
    gpio_set_slew_rate(PIN_PHANTOM, GPIO_SLEW_RATE_FAST);

#else
    gpio_init(PIN_PHANTOM);
    gpio_init(PIN_INTn);
    for(int i=PIN_PSRAM_CS+1; i<=PIN_RESET; i++) {
        gpio_init(i);
    }
    gpio_init(PIN_LED);

    for(int i=0; i<8; i++)
        gpio_init(PIN_D0 + i);
    gpio_set_dir_masked( (1l<<PICO_DEFAULT_LED_PIN), 
                (1l<<PICO_DEFAULT_LED_PIN));
    
                
    gpio_put(PIN_PHANTOM, 0); // Set /PHANTOM high
    gpio_set_dir(PIN_PHANTOM, false);
    // gpioc_hi_oe_set(1<<(PIN_PHANTOM - 32));
    // gpioc_hi_out_set(1<<(PIN_PHANTOM - 32));
    
    // printf("put 0 to PIN_PHANTOM done\n");
    gpio_put(PIN_INTn, 0);
    // printf("put 0 to PIN_INTn done\n");
#endif

    // irq_set_exclusive_handler(IO_IRQ_BANK0, gpio_irq_handler);
    irq_set_exclusive_handler(IO_IRQ_BANK0, irq_handler_slotn);
    
    gpio_set_irq_enabled(PIN_EXPn,  GPIO_IRQ_EDGE_FALL, true);
    // gpio_set_irq_enabled(PIN_MREQ,  GPIO_IRQ_EDGE_FALL, true);
    gpio_set_irq_enabled(PIN_SLOTn, GPIO_IRQ_EDGE_FALL, true);
    irq_set_priority(IO_IRQ_BANK0, 0x00);
    irq_set_enabled(IO_IRQ_BANK0, true);
    // printf("gpio init done.\n");
}

void initRegisterPointers() {
    // printf("init register poi array...\n");
    for(int i=0; i<SPRITES_NUM; i++) {
        register_pointer_storage_read[REG_SPRITE_X + i*2]  = (uint8_t *)&sprites[i].x;
        register_pointer_storage_read[REG_SPRITE_X + i*2+1] = ((uint8_t *)&sprites[i].x) + 1;
        register_pointer_storage_read[REG_SPRITE_Y + i*2]  = (uint8_t *)&sprites[i].y;
        register_pointer_storage_read[REG_SPRITE_Y + i*2 + 1] = ((uint8_t *)&sprites[i].y) + 1;
        register_pointer_storage_read[REG_SPRITE_COLOR + i] = (uint8_t *) &sprites[i].color;
        register_pointer_storage_read[REG_SPRITE_PHASE + i] = (uint8_t *) &sprites[i].phase;
        register_pointer_storage_read[REG_SPRITE_FOREGROUND + i] = (uint8_t *) &sprites[i].foreground;
        register_pointer_storage_read[REG_SPRITE_ENABLE + i] = (uint8_t *) &sprites[i].enabled;
        register_pointer_storage_read[REG_SPRITE_COLORMODE + i] = (uint8_t *) &sprites[i].fullColor;
    }

    register_pointer_storage_read[REG_SPRITE_ENABLE_LOW]       = (uint8_t *)&registerSpriteEnabledRead;
    register_pointer_storage_read[REG_SPRITE_ENABLE_HIGH]      = (uint8_t *)&registerSpriteEnabledRead + 1;
    register_pointer_storage_read[REG_SPRITE_FOREGROUND_LOW]   = (uint8_t *)&registerSpriteForegroundRead;
    register_pointer_storage_read[REG_SPRITE_FOREGROUND_HIGH]  = (uint8_t *)&registerSpriteForegroundRead + 1;
    register_pointer_storage_read[REG_SPRITE_COLORMODE_LOW]   = (uint8_t *)&registerSpriteColorModeRead;
    register_pointer_storage_read[REG_SPRITE_COLORMODE_HIGH]  = (uint8_t *)&registerSpriteColorModeRead + 1;

    register_pointer_storage_read[REG_SPRITE_SP_COLLISION_LOW] = (uint8_t *)&registerSpSpCollision;
    register_pointer_storage_read[REG_SPRITE_SP_COLLISION_HIGH] = (uint8_t *)&registerSpSpCollision + 1;
    register_pointer_storage_read[REG_SPRITE_SP_IRQMASK_LOW]      = (uint8_t *)&registerSpSpIRQMask;
    register_pointer_storage_read[REG_SPRITE_SP_IRQMASK_HIGH]     = (uint8_t *)&registerSpSpIRQMask + 1;
    register_pointer_storage_read[REG_SPRITE_BG_COLLISION_LOW] = (uint8_t *)&registerSpBgCollision;
    register_pointer_storage_read[REG_SPRITE_BG_COLLISION_HIGH] = (uint8_t *)&registerSpBgCollision + 1;
    register_pointer_storage_read[REG_SPRITE_BG_IRQMASK_LOW]      = (uint8_t *)&registerSpBgIRQMask;
    register_pointer_storage_read[REG_SPRITE_BG_IRQMASK_HIGH]     = (uint8_t *)&registerSpBgIRQMask + 1;

    register_pointer_storage_read[REG_SPRITE_BASE_ADDR]        = (uint8_t *)&registerSpriteBaseAddress;

    register_pointer_storage_read[REG_SCREEN_VIDEOMODE] = (uint8_t *)&videoMode;
    register_pointer_storage_read[REG_SCREEN_SCREEN_BASE_ADDR] = (uint8_t *)&registerScreenBaseAddr;
    register_pointer_storage_read[REG_SCREEN_SCREEN_COLOR_BASE_ADDR] = (uint8_t *)&registerScreenColorBaseAddr;
    register_pointer_storage_read[REG_SCREEN_FONT_BASE_ADDR] = (uint8_t *)&registerFontBaseAddr;
    register_pointer_storage_read[REG_SCREEN_BITMAP_BASE_ADDR] = (uint8_t *)&registerBitmapBaseAddr;
    register_pointer_storage_read[REG_SCREEN_SCROLL_X] = (uint8_t *)&screenScrollXreg;
    register_pointer_storage_read[REG_SCREEN_SCROLL_Y] = (uint8_t *)&screenScrollYreg;
    register_pointer_storage_read[REG_SCREEN_BORDER_COLOR] = (uint8_t *)&registerBorderColor;

    register_pointer_storage_read[REG_MEMORY_P2] = &currentP2;
    register_pointer_storage_read[REG_MEMORY_P3] = &currentP3;
    register_pointer_storage_read[REG_MEMORY_ROM_PAGE] = &registerROMPageRead;

    register_pointer_storage_read[REG_FUNCTION_EXECUTE] = &registerFunctionSelect;
    register_pointer_storage_read[REG_FUNCTION_PARAM_START] = &registerFunctionParamStart;
    register_pointer_storage_read[REG_FUNCTION_RESULT] = &registerFunctionResult;
    register_pointer_storage_read[REG_DRIVE_SELECT] = &TVC_ROM[0x1810];
    register_pointer_storage_read[REG_FUNCTION_MULTI_EXECUTE] = &registerFunctionMultiSelect;
    register_pointer_storage_read[REG_FUNCTION_BITMAP_BASE] = &registerFunctionBitmapBase;

    register_pointer_storage_read[REG_USB_INIT] = &registerInitializedUSBDevices;
    register_pointer_storage_read[REG_USB_MOUSE_BUTTONS] = &registerUSBMouseButtons;
    register_pointer_storage_read[REG_USB_MOUSE_DX] = (uint8_t *)&mouseMove.dx;
    register_pointer_storage_read[REG_USB_MOUSE_DY] = (uint8_t *)&mouseMove.dy;
    register_pointer_storage_read[REG_USB_MOUSE_DW] = (uint8_t *)&registerUSBMouseDWheel;
    register_pointer_storage_read[REG_USB_MOUSE_SPEED] = (uint8_t *)&registerUSBMouseSpeedRead;
    register_pointer_storage_read[REG_USB_MSC_CMD] = &registerUSBMSCCommand;
    register_pointer_storage_read[REG_USB_DEBUG] = &registerUSBDebug;

    /* ------- READ/WRITE REGISTERS SO FAR ------------ */

    memcpy(register_pointer_storage_write, register_pointer_storage_read, sizeof(register_pointer_storage_write));

    /* ------- SEPARATED READ AND WRITE REGISTERS FROM HERE ------------ */

    register_pointer_storage_write[REG_SPRITE_ENABLE_LOW]       = (uint8_t *)&registerSpriteEnabledWrite;
    register_pointer_storage_write[REG_SPRITE_ENABLE_HIGH]      = (uint8_t *)&registerSpriteEnabledWrite + 1;
    register_pointer_storage_write[REG_SPRITE_FOREGROUND_LOW]   = (uint8_t *)&registerSpriteForegroundWrite;
    register_pointer_storage_write[REG_SPRITE_FOREGROUND_HIGH]  = (uint8_t *)&registerSpriteForegroundWrite + 1;
    register_pointer_storage_write[REG_SPRITE_COLORMODE_LOW]   = (uint8_t *)&registerSpriteColorModeWrite;
    register_pointer_storage_write[REG_SPRITE_COLORMODE_HIGH]  = (uint8_t *)&registerSpriteColorModeWrite + 1;
    
    register_pointer_storage_write[REG_SPRITE_SP_COLLISION_HIGH] = NULL;
    register_pointer_storage_write[REG_SPRITE_SP_COLLISION_LOW] = NULL;
    register_pointer_storage_write[REG_SPRITE_BG_COLLISION_LOW] = NULL;
    register_pointer_storage_write[REG_SPRITE_BG_COLLISION_HIGH] = NULL;

    register_pointer_storage_read[REG_SCREEN_Y] = (uint8_t *)&y;
    register_pointer_storage_read[REG_SCREEN_MAXY] = (uint8_t *)&screenMaxY;

    register_pointer_storage_read[REG_MEMORY_MAP_8M_P2_LOW] = (uint8_t *)&registerMapped8MP2;
    register_pointer_storage_read[REG_MEMORY_MAP_8M_P2_HIGH] = (uint8_t *)&registerMapped8MP2 + 1;
    register_pointer_storage_read[REG_MEMORY_MAP_8M_P3_LOW] = (uint8_t *)&registerMapped8MP3;
    register_pointer_storage_read[REG_MEMORY_MAP_8M_P3_HIGH] = (uint8_t *)&registerMapped8MP3 + 1;

    register_pointer_storage_write[REG_MEMORY_MAP_8M_P2_LOW] = (uint8_t *)&registerTempTarget8MP2;
    register_pointer_storage_write[REG_MEMORY_MAP_8M_P2_HIGH] = (uint8_t *)&registerTempTarget8MP2 + 1;
    register_pointer_storage_write[REG_MEMORY_MAP_8M_P3_LOW] = (uint8_t *)&registerTempTarget8MP3;
    register_pointer_storage_write[REG_MEMORY_MAP_8M_P3_HIGH] = (uint8_t *)&registerTempTarget8MP3 + 1;

    register_pointer_storage_read[REG_MEMORY_PSRAM_SIZE_IN_MB] = &registerPSRAMSize;

    register_pointer_storage_write[REG_MEMORY_ROM_PAGE] = &registerROMPageWrite;

    register_pointer_storage_read[REG_FW_VERSION_MAJOR] = &registerFirmwareVersionMajor;
    register_pointer_storage_read[REG_FW_VERSION_MINOR] = &registerFirmwareVersionMinor;

    register_pointer_storage_read[REG_DRIVE_DSK_VALID] = &TVC_ROM[0x1825];
    register_pointer_storage_read[REG_DRIVE_PSRAM_VALID] = &TVC_ROM[0x1824];
    register_pointer_storage_read[REG_DRIVE_FLASH_VALID] = (uint8_t *)&flash_drive_initialized;

    register_pointer_storage_write[REG_USB_INIT] = NULL;
    register_pointer_storage_write[REG_USB_MOUSE_BUTTONS] = NULL;
    register_pointer_storage_write[REG_USB_MOUSE_DX] = NULL;
    register_pointer_storage_write[REG_USB_MOUSE_DY] = NULL;
    register_pointer_storage_write[REG_USB_MOUSE_DW] = NULL;
    register_pointer_storage_write[REG_USB_MOUSE_SPEED] = (uint8_t *)&registerUSBMouseSpeedWrite;
    register_pointer_storage_write[REG_USB_DEBUG] = &registerUSBDebug;

    for(int i=0; i<SPRITES_NUM; i++) {
        if(sprites[i].enabled) {
            registerSpriteEnabledRead |= (1 << i);
        }

        if(sprites[i].foreground) {
            registerSpriteForegroundRead |= (1 << i);
        }

        if(sprites[i].fullColor) {
            registerSpriteColorModeRead |= (1 << i);
        }
    }

    for(int i=0; i<32; i++) {
        register_pointer_storage_read[REG_VSID_BASE + i] = &SID[i];
        register_pointer_storage_write[REG_VSID_BASE + i] = &dummySIDWriteRegister;
    }
    
    // printf("init register poi array done.\n");
}

void preinit_core_sys() {
    memcpy(&TVC_ROM[0], &z80_prog_bin, MIN(z80_prog_len, 0x1800));
}

void fill_ram() {
    for(unsigned int i=0; i<sizeof(TVC_RAM); i++) {
        TVC_RAM[i] = i % 256;
    }
}

/**
 * These z80 functions are executed on 
 * core 0 - sys core. These tasks are:
 * - USB
 * - register reads and writes
 * - TVC 256k++ routine execution
 * - PSRAM mapping in/out
 */

void processSpriteSetX(uint8_t registerSelect, uint8_t d) {
    if(registerSelect & 1) {
        uint8_t spriteIdx = registerSelect >> 1;
        if(d>1) {
            sprites[spriteIdx].x = (sprites[spriteIdx].x & 0xff) + 256;
        }
    }
}

void processSpriteSetY(uint8_t registerSelect, uint8_t d) {
    if(registerSelect & 1) {
        uint8_t spriteIdx = registerSelect >> 1;
        if(d>1) {
            sprites[spriteIdx].y = (sprites[spriteIdx].y & 0xff) + 256;
        }
    }
}

void processSpriteSetColor(uint8_t registerSelect, uint8_t d) {
    sprites[registerSelect & 0x0f].fullColor = ((d & 0x10) == 0x10);
}

int init_psram() {
    int res = psram_setup();
    if(res!=0) {
        registerPSRAMSize = 0;
        psram_array = NULL;
    } else {
        psram_array = (uint8_t *)PSRAM_NOCACHE_BASE;
        registerPSRAMSize = psram_size() / (1024 * 1024);
    }
    // printf("PSRAM initialized, found: %dMB\n", registerPSRAMSize);
    return res;
}

// bool mappedOut = true;

bool processPSRAMMapping() {
    if((registerMapped8MP2 != registerTarget8MP2) && 
        (registerTarget8MP2 >= registerPSRAMSize * 64)) {
        return false;
    } else if ((registerMapped8MP3 != registerTarget8MP3) && 
        (registerTarget8MP3 >= registerPSRAMSize * 64)) {
        return false;
    }

    if(registerMapped8MP2 != registerTarget8MP2) {
        if(registerMapped8MP2 != 0xffff) {
            memcpy(&psram_array[(uint32_t)registerMapped8MP2 * 16384], &TVC_RAM[MEMORY_RAM_SIZE * 1024], 16384);
        }
        memcpy(&TVC_RAM[MEMORY_RAM_SIZE * 1024], 
                &psram_array[(uint32_t)registerTarget8MP2 * 16 * 1024], 
                16 * 1024);
        registerMapped8MP2 = registerTarget8MP2;
    } else if(registerMapped8MP3 != registerTarget8MP3) {
        if(registerMapped8MP3 != 0xffff) {
            memcpy(&psram_array[(uint32_t)registerMapped8MP3 * 16 * 1024], 
                &TVC_RAM[(MEMORY_RAM_SIZE + 16 ) * 1024], 
                16 * 1024);
        }
        memcpy((void *)&TVC_RAM[(MEMORY_RAM_SIZE + 16 ) * 1024], 
                (void *)&psram_array[registerTarget8MP3 * 16 * 1024], 
                16 * 1024);
        registerMapped8MP3 = registerTarget8MP3;
    }
    return true;
}

uint8_t* getFunctionParamAddress() {
    uint32_t pos = 0;
    if(registerFunctionParamStart & 0x80) {
        if(currentP3 == 255) {
            return NULL;
        }
        pos = currentP3 * 16 * 1024 + (registerFunctionParamStart & 0x7f) * 128;
    } else {
        if(currentP2 == 255) {
            return NULL;
        }
        pos = currentP2 * 16 * 1024 + (registerFunctionParamStart) * 128;
    }
    return &TVC_RAM[pos];
}

void process_queue_cycle() {
    // uint16_t intCounter = 0;
    // absolute_time_t ts = get_absolute_time();
    while (true) {
        main_loop_task();

        // if(absolute_time_diff_us(ts,  get_absolute_time()) >= 5000000) { // Process the queue every 1ms
        //     ts = get_absolute_time();
        //     uint8_t p = dqPos;
        //     for(int i=-10; i<0; i++) {
        //         data_queue_t *entry = &data_queue[(uint8_t) (p + i)];
        //         if(entry->isWrite) {
        //             usb_printf("W%02X: %06X=%02X :: ", (uint8_t) (p + i), entry->address, entry->data);
        //         } else {
        //             usb_printf("R%02X: %06X=%02X :: ", (uint8_t) (p + i), entry->address, entry->data);
        //         }
        //     }
        //     usb_printf("%d, %d\n", currentP2, currentP3);
            // usb_printf("lprt: %d, lpra: %04x, lpr: %02x, lpwt: %d, lpwa: %04x, lpw: %02x\nlrt: %d, lra: %04x, lr: %02x, lwt: %d, lwa: %04x, lw: %02x\n", 
            //     lastprTime, lastprAddr, lastpRead, lastpwTime, lasptwAddr, lastpWritten, 
            //     lastrTime,  lastrAddr,  lastRead,  lastwTime,  lastwAddr,  lastWritten);
/*
            uint32_t c1 = busctrl_hw->counter[0].value;  // FASTPERI_STALL_UPSTREAM
            busctrl_hw->counter[0].value = 0;  // FASTPERI_STALL_UPSTREAM
            uint32_t c2 = busctrl_hw->counter[1].value; // FASTPERI_STALL_DOWNSTREAM
            busctrl_hw->counter[1].value = 0; // FASTPERI_STALL_DOWNSTREAM
            uint32_t c3 = busctrl_hw->counter[2].value; // FASTPERI_ACCESS_CONTESTED
            busctrl_hw->counter[2].value = 0; // FASTPERI_ACCESS_CONTESTED
            uint32_t c4 = busctrl_hw->counter[3].value; // FASTPERI_ACCESS
            busctrl_hw->counter[3].value = 0; // FASTPERI_ACCESS
            
            usb_printf("lpra: %04x, lpr: %02x, lpwa: %04x, lpw: %02x\nlra: %04x, lr: %02x, lwa: %04x, lw: %02x\nBUSCTRL: UP=%d, DOWN=%d, CONTESTED=%d, ACCESS=%d\n", lastprAddr, lastpRead, lasptwAddr, lastpWritten, lastrAddr, lastRead, lastwAddr, lastWritten, c1, c2, c3, c4);
*/

/*
            print_string_ascii("U:");
            print_hex_byte(((uint8_t *) &c1) + 2);
            print_hex_word((uint8_t *) &c1);
            print_string_ascii(" D:");
            print_hex_byte(((uint8_t *) &c2) + 2);
            print_hex_word((uint8_t *) &c2);
            print_string_ascii(" C:");
            
            print_hex_byte(((uint8_t *) &c3) + 2);
            print_hex_word((uint8_t *) &c3);
            print_string_ascii(" A:");
            print_hex_byte(((uint8_t *) &c4) + 2);
            print_hex_word((uint8_t *) &c4);
            print_string_ascii("\n");
*/
        // }
             // usb_printf("Queue cycle start, head: %d, tail: %d, cnt: %d\n", queueHead, queueTail, counter);
        if (queueHead != queueTail) {
            message_t msg = messageQueue[queueTail++];
            counter++;
            // usb_printf("Arrived message: {id=%d, type=%02X, address=%04X, data=%02X, regSelect=%08X}, head: %d, tail: %d, cnt: %d\n", 
            //         msg.id, msg.msgType, msg.address, msg.data, msg.registerSelect, queueHead, queueTail, counter);
            // printf("VideoMode: %02X, ScreenBaseAddr: %02X, ScreenColorBaseAddr: %02X, FontBaseAddr: %02X, BitmapBaseAddr: %02X, SpriteBaseAddr: %02X\n", 
            //         videoMode, registerScreenBaseAddr, registerScreenColorBaseAddr, registerFontBaseAddr, registerBitmapBaseAddr, registerSpriteBaseAddress);
            // Process the message
            switch (msg.msgType) {
                case MSG_TYPE_SLOTN_WRITE:
                    uint8_t d = msg.data;
                    switch(msg.registerSelect) {
                        case REG_SPRITE_FOREGROUND:
                            {
                                uint16_t sum = 0;
                                uint8_t *data = (uint8_t *)&sprites[0].foreground;
                                volatile int b = SPRITES_NUM;
                                for(int i=0; i<b; i++, data+=sizeof(sprite_t)) {
                                    *data = *data > 0;
                                    if(*data)
                                        sum |= (1<<i);
                                }
                                registerSpriteForegroundRead = sum;
                            }
                            break;
                        case REG_SPRITE_ENABLE:
                            {
                                uint16_t sum = 0;
                                uint8_t *data = (uint8_t *)&sprites[0].enabled;
                                volatile int b = SPRITES_NUM;
                                for(int i=0; i< b; i++, data+=sizeof(sprite_t)) {
                                    *data = *data > 0;
                                    if(*data)
                                        sum |= (1<<i);
                                }

                                registerSpriteEnabledRead = sum;
                            }
                            break;
                        case REG_SPRITE_COLORMODE:
                            {
                            uint16_t sum = 0;
                                uint8_t *data = (uint8_t *)&sprites[0].fullColor;
                                volatile int b = SPRITES_NUM;
                                for(int i=0; i<b; i++, data+=sizeof(sprite_t)) {
                                    *data = *data > 0;
                                    if(*data)
                                        sum |= (1<<i);
                                }
                                registerSpriteColorModeRead = sum;
                            }
                            break;
                        case REG_SPRITE_ENABLE_LOW:
                            for(int i=0; i<8; i++) {
                                sprites[i].enabled = d & 0x01;
                                d >>= 1;
                            }
                            *((uint8_t *)&registerSpriteEnabledRead) = msg.data;
                            break;
                        case REG_SPRITE_ENABLE_HIGH:
                            for(int i=8; i<16; i++) {
                                sprites[i].enabled = d & 0x01;
                                d >>= 1;
                            }
                            *((uint8_t *)&registerSpriteEnabledRead + 1) = msg.data;
                            break;
                        case REG_SPRITE_FOREGROUND_LOW:
                            for(int i=0; i<8; i++) {
                                sprites[i].foreground = d & 0x01;
                                d >>= 1;
                            }
                            *((uint8_t *)&registerSpriteForegroundRead) = msg.data;
                            break;
                        case REG_SPRITE_FOREGROUND_HIGH:
                            for(int i=8; i<16; i++) {
                                sprites[i].foreground = d & 0x01;
                                d >>= 1;
                            }
                            *((uint8_t *)&registerSpriteForegroundRead+1) = msg.data;
                            break;
                        case REG_SPRITE_COLORMODE_LOW:
                            for(int i=0; i<8; i++) {
                                sprites[i].fullColor = (d & 1);
                                d >>= 1;
                            }
                            *((uint8_t *)&registerSpriteColorModeRead) = msg.data;
                            break;
                        case REG_SPRITE_COLORMODE_HIGH:
                            for(int i=8; i<16; i++) {
                                sprites[i].fullColor = (d & 1);
                                d >>= 1;
                            }
                            *((uint8_t *)&registerSpriteColorModeRead+1) = msg.data;
                            break;
                        case REG_SPRITE_BASE_ADDR:
                            registerSpriteBaseAddress = d & 0x07;
                            break;
                        case REG_SCREEN_VIDEOMODE:
                            videoMode = d & 0x03;
                            break;
                        case REG_SCREEN_SCREEN_BASE_ADDR:
                            registerScreenBaseAddr = d & 0x7f;
                            break;
                        case REG_SCREEN_SCREEN_COLOR_BASE_ADDR:
                            registerScreenColorBaseAddr = d & 0x7f;
                            break;
                        case REG_SCREEN_FONT_BASE_ADDR:
                            registerFontBaseAddr = d & 0x3f;
                            break;
                        case REG_SCREEN_BITMAP_BASE_ADDR:
                            registerBitmapBaseAddr = d & 0x03;
                            break;
                        case REG_SCREEN_SCROLL_X:
                            screenScrollXreg &= 0b10000111;
                            break;
                        case REG_SCREEN_SCROLL_Y:
                            screenScrollYreg &= 0b10000111;
                            break;
                        case REG_SCREEN_BORDER_COLOR:
                            registerBorderColor &= 0x0f;
                            break;
                        case REG_SCREEN_MAXY:
                            if((d<240) && (d>1)) {
                                maxY = d + 21;
                                screenMaxY = maxY - 21;
                            }
                            break;
                        case REG_MEMORY_P2:
                            if(currentP2!=0xff)
                                currentP2 &= 0x0f;
                            break;
                        case REG_MEMORY_P3:
                            if(currentP3!=0xff)
                                currentP3 &= 0x0f;
                            break;
                        case REG_MEMORY_MAP_8M_P2_LOW:
                            registerTarget8MP2 = d;
                            if(processPSRAMMapping())
                                currentP2 = 16;

                            break;
                        case REG_MEMORY_MAP_8M_P2_HIGH:
                            registerTempTarget8MP2 &= 0x1ff;
                            break;
                        case REG_MEMORY_MAP_8M_P3_LOW:
                            registerTarget8MP3 = d;
                            if(processPSRAMMapping())
                                currentP3 = 17;
                            // printf("rm: %04x, rt: %04X, rtt: %04x\n", registerMapped8MP3, registerTarget8MP3, registerTempTarget8MP3);
                            break;
                        case REG_MEMORY_MAP_8M_P3_HIGH:
                            registerTempTarget8MP3 &= 0x1ff;
                            break;
                        case REG_MEMORY_ROM_PAGE:
                            if(d<2) {
                                memcpy(&TVC_ROM[0], (void *)&z80_prog_bin + (0x1800 * d), MIN(z80_prog_len, 0x1800));
                                registerROMPageRead = d;
                            }
                            break;
                        case REG_FUNCTION_EXECUTE:
                            uint8_t *functionParamAddress = getFunctionParamAddress();

                            if(functionParamAddress && tvc256k_funct_struct_array[d].func) {
                                registerFunctionResult = tvc256k_funct_struct_array[d].func(functionParamAddress);
                            } else {
                                registerFunctionResult = 0xff;
                            }
                            // usb_printf("func: after, res: %d\n", registerFunctionResult);main_loop_task();sleep_ms(50);
                            gpio_put(PIN_LED, 0);
                            registerFunctionSelect = 255;

                            break;
                        case REG_DRIVE_SELECT:
                            if(d>3) 
                                TVC_ROM[0x1810] = 3;
                            break;
                        case REG_FUNCTION_MULTI_EXECUTE:
                            functionParamAddress = getFunctionParamAddress();
                            if(functionParamAddress) {
                                long timeStamp = time_us_64();
                                uint8_t *functionParamAddressSave = functionParamAddress;
                                uint8_t numOfFunctions = d;
                                uint8_t result = 0;
                                registerFunctionResult = 0;
                                for(int i=0; i<numOfFunctions; i++) {
                                    uint8_t functionCode = *functionParamAddress++;
                                    uint8_t paramSize = getFunctionParamSize(functionParamAddress, tvc256k_funct_struct_array[functionCode].param_size);
                                    // if(paramSize!=0) {
                                    //     memcpy((void *)multiParamBuffer, (void *)functionParamAddress, paramSize);
                                    // }
                                    if(!tvc256k_funct_struct_array[functionCode].func) {
                                        registerFunctionResult = 0x80 + i + 1;
                                        break;
                                    }
                                    // result = tvc256k_funct_struct_array[functionCode].func(multiParamBuffer);
                                    result = tvc256k_funct_struct_array[functionCode].func((uint8_t *)functionParamAddress);
                                    if( result ) {
                                        *functionParamAddressSave = result;
                                        registerFunctionResult = i + 1;
                                        break;
                                    }

                                    functionParamAddress += paramSize;
                                    if(absolute_time_diff_us(timeStamp, time_us_64()) > 1000) {
                                        timeStamp = time_us_64();
                                        main_loop_task();
                                    }
                                }
                                registerFunctionMultiSelect = 255;
                            } else {
                                registerFunctionResult = 255;
                                registerFunctionMultiSelect = 255;
                            }
                            break;
                        case REG_FUNCTION_BITMAP_BASE:
                            if(registerFunctionBitmapBase != 0xff)
                                registerFunctionBitmapBase = d & 0x03;
                            break;
                        case REG_USB_MOUSE_SPEED:
                            d &= 0x7f;
                            if( (nextMouseSpeedPos < FLASH_SECTOR_SIZE) && (registerUSBMouseSpeedRead != d) ) {
                                int block_idx = nextMouseSpeedPos / FLASH_PAGE_SIZE;
                                flash_data_buffer[nextMouseSpeedPos++] = d;
                                uint32_t interrupts = save_and_disable_interrupts();
                                flash_range_program(MOUSE_SPEED_STORAGE_ADDR + block_idx * FLASH_PAGE_SIZE, 
                                                    &flash_data_buffer[block_idx * FLASH_PAGE_SIZE], 
                                                    FLASH_PAGE_SIZE);
                                restore_interrupts(interrupts);
                            }
                            registerUSBMouseSpeedRead = d;
                            break;
                        case REG_USB_MSC_CMD:
                            // usb_printf("Received MSC command: %d, reg: %d\n", d, registerUSBMSCCommand);main_loop_task();sleep_ms(50);
#if CFG_TUH_MSC
                            FRESULT fres = 0xff;
                            switch(d) {
                                case MSC_FOPENFILE:
                                    // usb_printf("msc: open before, drive: %d\n", TVC_ROM[0x1810]);main_loop_task();sleep_ms(50);
                                    switch(TVC_ROM[0x1810]) {
                                        case 0x00:
                                            fres = tvc_fatfs_pendrive_open_file();
                                            break;
                                        case 0x01:
                                            fres = tvc_lfs_psram_file_open();
                                            break;
                                        case 0x02:
                                            fres = tvc_lfs_flash_file_open();
                                            break;
                                        case 0x03:
                                            fres = tvc_fatfs_dskdrive_open_file();
                                            break;
                                    }
                                    // usb_printf("msc: open after, fres: %d\n", fres);main_loop_task();sleep_ms(50);

                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FCLOSEFILE:
                                    // usb_printf("close: before, drive: %d\n", TVC_ROM[0x1810]);main_loop_task();sleep_ms(50);
                                    switch(TVC_ROM[0x1810]) {
                                        case 0x00:
                                            fres = tvc_fatfs_pendrive_close_file();
                                            break;
                                        case 0x01:
                                            fres = tvc_lfs_psram_file_close();
                                            break;
                                        case 0x02:  
                                            fres = tvc_lfs_flash_file_close();
                                            break;
                                        case 0x03:
                                            fres = tvc_fatfs_dskdrive_close_file();
                                            break;
                                    }
                                    // usb_printf("close: after, fres: %d\n", fres);main_loop_task();sleep_ms(50);
                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FREAD:
                                    // usb_printf("read: before, drive: %d\n", TVC_ROM[0x1810]);main_loop_task();sleep_ms(50);
                                    switch(TVC_ROM[0x1810]) {
                                        case 0x00:
                                            fres = tvc_fatfs_pendrive_read_file();
                                            break;
                                        case 0x01:
                                            fres = tvc_lfs_psram_file_read();
                                            break;
                                        case 0x02:
                                            fres = tvc_lfs_flash_file_read();
                                            break;
                                        case 0x03:
                                            fres = tvc_fatfs_dskdrive_read_file();
                                            break;
                                    }

                                    // usb_printf("read: after, fres: %d\n", fres);main_loop_task();sleep_ms(50);

                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FWRITE:
                                    // usb_printf("write: before, drive: %d\n", TVC_ROM[0x1810]);main_loop_task();sleep_ms(50);
                                    switch(TVC_ROM[0x1810]) {
                                        case 0x00:
                                            fres = tvc_fatfs_pendrive_write_file();
                                            break;
                                        case 0x01:
                                            fres = tvc_lfs_psram_file_write();
                                            break;
                                        case 0x02:
                                            fres = tvc_lfs_flash_file_write();
                                            break;
                                        case 0x03:
                                            fres = tvc_fatfs_dskdrive_write_file();
                                            break;
                                    }
                                    // usb_printf("write: after, fres: %d\n", fres);main_loop_task();sleep_ms(50);
                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FOPENDIR:
                                    switch(TVC_ROM[0x1810]) {
                                        case 0:
                                            fres = tvc_fatfs_pendrive_open_dir();
                                            break;
                                        case 1:
                                            fres = tvc_lfs_psram_dir_open();
                                            break;
                                        case 2:
                                            fres = tvc_lfs_flash_dir_open();
                                            break;
                                        case 3:
                                            fres = tvc_fatfs_dskdrive_open_dir();
                                            break;
                                    }

                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FCLOSEDIR:
                                    switch(TVC_ROM[0x1810]) {
                                        case 0x00:
                                            fres = tvc_fatfs_pendrive_close_dir();
                                            break;
                                        case 0x01:
                                            fres = tvc_lfs_psram_dir_close();
                                            break;
                                        case 0x02:
                                            fres = tvc_lfs_flash_dir_close();
                                            break;
                                        case 0x03:
                                            fres = tvc_fatfs_dskdrive_close_dir();
                                            break;
                                    }

                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FREADDIR:
                                    switch(TVC_ROM[0x1810]) {
                                        case 0x00:
                                            fres = tvc_fatfs_pendrive_read_dir();
                                            break;
                                        case 0x01:
                                            fres = tvc_lfs_psram_dir_read();
                                            break;
                                        case 0x02:
                                            fres = tvc_lfs_flash_dir_read();
                                            break;
                                        case 0x03:
                                            fres = tvc_fatfs_dskdrive_read_dir();
                                            break;
                                    }
                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FWRITE_SRC:
                                    switch(TVC_ROM[0x1810]) {
                                        case 0:
                                            fres = tvc_fatfs_pendrive_write_file_source();
                                            break;
                                        case 1:
                                            fres = tvc_lfs_psram_file_write_source();
                                            break;
                                        case 2:
                                            fres = tvc_lfs_flash_file_write_source();
                                            break;
                                        case 3:
                                            fres = tvc_fatfs_dskdrive_write_file_source();
                                            break;
                                    }
                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FREAD_DEST:
                                    switch(TVC_ROM[0x1810]) {
                                        case 0:
                                            fres = tvc_fatfs_pendrive_read_file_dest();
                                            break;
                                        case 1: 
                                            fres = tvc_lfs_psram_file_read_dest();
                                            break;
                                        case 2:
                                            fres = tvc_lfs_flash_file_read_dest();
                                            break;
                                        case 3:
                                            fres = tvc_fatfs_dskdrive_read_file_dest();
                                            break;
                                    }

                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    // usb_printf("read dest: after, fres = %d\n", fres);main_loop_task();sleep_ms(50);
                                    break;
                                case MSC_FSEEK:
                                    switch(TVC_ROM[0x1810]) {
                                        case 0:
                                            fres = tvc_fatfs_pendrive_file_seek();
                                            break;
                                        case 1:
                                            fres = tvc_lfs_psram_file_seek();
                                            break;
                                        case 2:
                                            fres = tvc_lfs_flash_file_seek();
                                            break;
                                        case 3:
                                            fres = tvc_fatfs_dskdrive_file_seek();
                                            break;
                                    }

                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FGETCWD:
                                    switch(TVC_ROM[0x1810]) {
                                        case 0:
                                            fres = tvc_fatfs_pendrive_getcwd();
                                            break;
                                        case 1:
                                            fres = tvc_lfs_psram_getcwd();
                                            break;
                                        case 2:
                                            fres = tvc_lfs_flash_getcwd();
                                            break;
                                        case 3:
                                            fres = tvc_fatfs_dskdrive_getcwd();
                                            break;
                                    }

                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FCHDIR:
                                    switch(TVC_ROM[0x1810]) {
                                        case 0:
                                            fres = tvc_fatfs_pendrive_chdir();
                                            break;
                                        case 1:
                                            fres = tvc_lfs_psram_chdir();
                                            break;
                                        case 2:
                                            fres = tvc_lfs_flash_chdir();
                                            break;
                                        case 3:
                                            fres = tvc_fatfs_dskdrive_chdir();
                                            break;
                                    }
                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FMKDIR:
                                    switch(TVC_ROM[0x1810]) {
                                        case 0:
                                            fres = tvc_fatfs_pendrive_mkdir();
                                            break;
                                        case 1:
                                            fres = tvc_lfs_psram_mkdir();
                                            break;
                                        case 2:
                                            fres = tvc_lfs_flash_mkdir();
                                            break;
                                        case 3:
                                            fres = tvc_fatfs_dskdrive_mkdir();
                                            break;
                                    }

                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FDELETE:
                                    switch(TVC_ROM[0x1810]) {
                                        case 0:
                                            fres = tvc_fatfs_pendrive_delete();
                                            break;
                                        case 1:
                                            fres = tvc_lfs_psram_delete();
                                            break;
                                        case 2:
                                            fres = tvc_lfs_flash_delete();
                                            break;
                                        case 3:
                                            fres = tvc_fatfs_dskdrive_delete();
                                            break;
                                    }
                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FRENAME:
                                    switch(TVC_ROM[0x1810]) {
                                        case 0:
                                            fres = tvc_fatfs_pendrive_rename();
                                            break;
                                        case 1:
                                            fres = tvc_lfs_psram_rename();
                                            break;
                                        case 2:
                                            fres = tvc_lfs_flash_rename();
                                            break;
                                        case 3:
                                            fres = tvc_fatfs_dskdrive_rename();
                                            break;
                                    }

                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FSTAT:
                                    switch(TVC_ROM[0x1810]) {
                                        case 0x00:
                                            fres = tvc_fatfs_pendrive_getstat();
                                            break;
                                        case 0x01:
                                            fres = tvc_lfs_psram_getstat();
                                            break;
                                        case 0x02:
                                            fres = tvc_lfs_flash_getstat();
                                            break;
                                        case 0x03:
                                            fres = tvc_fatfs_dskdrive_getstat();
                                            break;
                                    }
                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_FSYNC:
                                    switch(TVC_ROM[0x1810]) {
                                        case 0:
                                            fres = tvc_fatfs_pendrive_sync();
                                            break;
                                        case 1:
                                            fres = tvc_lfs_psram_sync();
                                            break;
                                        case 2:
                                            fres = tvc_lfs_flash_sync();
                                            break;
                                        case 3:
                                            fres = tvc_fatfs_dskdrive_sync();
                                            break;
                                    }
                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_MOUNT_DSK:
                                    switch(TVC_ROM[0x1810]) {
                                        case 0:
                                            fres = tvc_fatfs_pendrive_mount_dsk();
                                            break;
                                        case 1:
                                            fres = tvc_lfs_psram_mount_dsk();
                                            break;
                                        case 2:
                                            fres = tvc_lfs_flash_mount_dsk();
                                            break;
                                        default:
                                            fres = 0x80;
                                    }
                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;
                                case MSC_UMOUNT_DSK:
                                // BEWARE OF THE SWITCH -> dsk_file_type
                                // instead of active drive!!
                                    switch(dsk_file_type) {
                                        case 1:
                                            fres = tvc_fatfs_pendrive_unmount_dsk();
                                            break;
                                        case 2:
                                            fres = tvc_lfs_psram_unmount_dsk();
                                            break;
                                        case 3:
                                            fres = tvc_lfs_flash_unmount_dsk();
                                            break;
                                        default:
                                            fres = 0x80;
                                    }
                                    registerUSBMSCCommand = (fres == FR_OK) ? 0 : fres | 0x80;
                                    break;                                    
                                default:
                                    registerUSBMSCCommand = 0xFF;
                                    break;
                            }
                            // usb_printf("Processed MSC command: %d, result: %d\n", d, registerUSBMSCCommand);main_loop_task();sleep_ms(50);
#endif  // CFG_TUH_MSC
                            break;
                        default:
                            // usb_printf("Arrived message: {id=%d, type=%02X, address=%04X, data=%02X, regSelect=%08X}, head: %d, tail: %d, cnt: %d\n", 
                            //         msg.id, msg.msgType, msg.address, msg.data, msg.registerSelect, queueHead, queueTail, counter);
                            break;
                        }
                    break;
                case MSG_TYPE_HEARTBEAT:
                    // printf("ID: %02X, Processed HB: Address=%04X, Data=%02X\n", msg.id, msg.address, msg.data);
                    // printf("Data on gpioc data bus: %08X\n", gpioc_hi_in_get());
                    // printf("Data on sio data bus:   %08X\n", sio_hw->gpio_hi_in);
                    break;
            }
        }
    }
}

void init_flash_sector(uint8_t defaultMouseSpeed) {
    uint32_t interrupts = save_and_disable_interrupts();
    flash_range_erase(MOUSE_SPEED_STORAGE_ADDR, FLASH_SECTOR_SIZE);
    memset(flash_data_buffer, 255, FLASH_SECTOR_SIZE); // set to 255 so subsequent writes can change bits to 0, but not the other way around without erasing again
    flash_data_buffer[0] = 0x75; // Just (-a random value-) my birthyear to indicate that the storage has been initialized
    flash_data_buffer[1] = defaultMouseSpeed; // Default mouse speed
    flash_range_program(MOUSE_SPEED_STORAGE_ADDR, flash_data_buffer, FLASH_PAGE_SIZE);
    restore_interrupts(interrupts);
    nextMouseSpeedPos = 2;
    registerUSBMouseSpeedRead = defaultMouseSpeed;
}

void init_mouse_speed_storage() {
    uint8_t *flash_ID = (uint8_t *)(MOUSE_SPEED_STORAGE_ADDR + XIP_BASE);
    if(*flash_ID != 0x75) {
        init_flash_sector(0x10);
    } else {
        memcpy(flash_data_buffer, (void *)flash_ID, FLASH_SECTOR_SIZE);
        uint8_t *ptr = &flash_data_buffer[1];
        nextMouseSpeedPos = 1;
        while( ( (*ptr & 0x80) == 0) && (nextMouseSpeedPos < FLASH_SECTOR_SIZE ) ) {
            ptr++;
            nextMouseSpeedPos++;
        }

        if(nextMouseSpeedPos >= (FLASH_SECTOR_SIZE-512) ) {
            init_flash_sector(*(ptr - 1));
        } else {
            registerUSBMouseSpeedRead = *(ptr - 1);
        }
    }
}

void init_debug_counters() {
    busctrl_hw->counter[0].value = 0;
    busctrl_hw->counter[0].sel = 0x0c;  // FASTPERI_STALL_UPSTREAM
    busctrl_hw->counter[1].value = 0;
    busctrl_hw->counter[1].sel = 0x0d; // FASTPERI_STALL_DOWNSTREAM
    busctrl_hw->counter[2].value = 0;
    busctrl_hw->counter[2].sel = 0x0e; // FASTPERI_ACCESS_CONTESTED
    busctrl_hw->counter[3].value = 0;
    busctrl_hw->counter[3].sel = 0x0f; // FASTPERI_ACCESS

    busctrl_hw->perfctr_en = 1;
}

void main_system(void) {
    init_mouse_speed_storage();
    flash_drive_init();
    init_psram();
    init_usb_stack(false);
    init_sound_subsystem();
    // init_debug_counters();
    process_queue_cycle();
}