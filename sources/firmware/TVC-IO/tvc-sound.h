#include "pico/stdlib.h"

void init_sound_subsystem(void);

typedef struct {
    uint32_t ts;
    uint16_t address_value;
} sid_write_queue_t;
