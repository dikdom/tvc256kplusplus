#ifndef __TVC_USB_H__
#define __TVC_USB_H__

#include "pico/stdlib.h"
// #include "tusb.h"

typedef struct __packed {
    int32_t dx_sum;
    int32_t dy_sum;
    int8_t dx;
    int8_t dy;
} mouse_move_t;

// void start_usb_stack(bool start_cdc);
void init_usb_stack(bool start_cdc);
void main_loop_task(void);
void main_loop_task_from_gfx_core(void);
void pio_usb_host_frame(void);  // implemented in PIO USB
int usb_printf(const char *fmt, ...);

#endif