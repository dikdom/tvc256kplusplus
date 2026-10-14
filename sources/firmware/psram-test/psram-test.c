#include <stdio.h>
#include "pico/stdlib.h"
#include "psram.h"
#include "hardware/clocks.h"
#include "pico/critical_section.h"
#include "hardware/xip_cache.h"
#include "string.h"
#include "pico/sync.h"

#include "hardware/dma.h"
#include "hardware/regs/addressmap.h"
#include "hardware/structs/xip_ctrl.h"
#include "hardware/structs/qmi.h"
#include "hardware/vreg.h"

#define DATA_SIZE  256*1024

void blink(int delay) {
    while(true) {
        gpio_xor_mask(1<<PICO_DEFAULT_LED_PIN);
        sleep_ms(delay);
    }
}

void check_fix_byte(uint8_t value) {
    uint8_t* psram_arr = (uint8_t*)PSRAM_NOCACHE_BASE;
    gpio_put(PICO_DEFAULT_LED_PIN, 1);
    sleep_ms(30);
    gpio_put(PICO_DEFAULT_LED_PIN, 0);
    printf("Setting 8MB PSRAM chip to %02x... ", value);
    memset(psram_arr, value, 8*1024*1024);
    printf("done.\n");
    bool passed = true;

    printf("Checking 8MB PSRAM chip %02x... ", value);
    for(int i=0; i< psram_size(); i++) {
        if(psram_arr[i] != value) {
            printf("\nData mismatch at %d, expected: %02x, got: %02x\n", i, value, psram_arr[i]);
            passed = false;
        }
        if((i % 65536) == 0) {
            printf("\x1b[1GChecking PSRAM: %d / %zu", i, psram_size());
        }
    }
    printf("\x1b[1GChecking PSRAM: %d / %zu\n", psram_size(), psram_size());
    if(passed) {
        printf("Test passed.\n");
    } else {
        printf("Test failed.\n");
        blink(100);
    }
}

int main()
{
    // vreg_set_voltage(VREG_VOLTAGE_1_20);
    // sleep_ms(100);
    // set_sys_clock_khz(336000, true); // Set system clock in kHz

    stdio_init_all();
    gpio_init(PICO_DEFAULT_LED_PIN);
    gpio_init(23);
    gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
    gpio_set_dir(23, GPIO_IN);
    for(int i=0; i<10; i++) {
        printf("%d ", i);
        sleep_ms(1000);
        if(gpio_get(23) == 0) {
            gpio_put(PICO_DEFAULT_LED_PIN, 1);
            sleep_ms(200);
            gpio_put(PICO_DEFAULT_LED_PIN, 0);
            break;
        }
    }
    printf(".\n");


    printf("PSRAM CS pin: %d\n", PSRAM_CS_PIN);
    psram_setup();

    const psram_id_t* id = psram_get_id();
    if (id) {
        printf("PSRAM Manufacturer ID: 0x%02X\n", id->mfid);
        printf("PSRAM Known Good Die: 0x%02X\n", id->kgd);
        printf("PSRAM EID: ");
        for (int i = 0; i < 6; i++) {
            printf("%02X", id->eid[i]);
        }
        printf("\n");
        printf("Size of PSRAM: %zu bytes\n", psram_size());

        if(psram_size() != 8*1024*1024) {
            printf("ERROR!!! PSRAM size is smaller than 8MB!!!\n");
            blink(100);
        } else {
            uint8_t test_data[DATA_SIZE];
            uint32_t sum = 0;

            printf("Test 1: write to PSRAM and read back\n");
            check_fix_byte(0xff);

            printf("Test 2: write to 0x00 PSRAM and read back\n");
            check_fix_byte(0x00);

            printf("Test 3: write to 0xaa PSRAM and read back\n");
            check_fix_byte(0xaa);

            printf("Test 4: write to 0x55 PSRAM and read back\n");
            check_fix_byte(0x55);

            printf("Test 5: write increments to PSRAM and read back\n");
            uint8_t* psram_arr = (uint8_t*)PSRAM_NOCACHE_BASE;

            for(int i=0; i<8*1024*1024; i++) {
                psram_arr[i] = i & 0xFF;
                if((i % 65536) == 0) {
                    printf("\x1b[1GSetting PSRAM: %d / %zu", i, psram_size());
                }
            }
            printf("\x1b[1GSetting PSRAM: %d / %zu\n", psram_size(), psram_size());

            for(int i=0; i<8*1024*1024; i++) {
                if(psram_arr[i] != (i & 0xFF)) {
                    printf("\nData mismatch at %d, expected: %02x, got: %02x\n", i, i & 0xFF, psram_arr[i]);
                    blink(100);
                }
                if((i % 65536) == 0) {
                    printf("\x1b[1GChecking PSRAM: %d / %zu", i, psram_size());
                }
            }
            printf("\x1b[1GChecking PSRAM: %d / %zu\n", psram_size(), psram_size());

            printf("\nAll tests completed.\n");
        }
        blink(1000);

    } else {
        printf("No PSRAM detected.\n");
        blink(100);
    }

}
