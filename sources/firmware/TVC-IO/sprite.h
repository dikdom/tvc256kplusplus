#ifndef SPRITE_H
#define SPRITE_H

#include <stdint.h>
#include <stdbool.h>
#include "tvc-colors.h"

#define SPRITES_NUM 16

typedef struct {
    uint16_t x;
    uint16_t y;
    bool enabled;
    bool foreground;
    color_t color;
    uint8_t phase;
    bool fullColor;
    uint8_t padding[3];  // Padding to make the struct size a multiple of 4 bytes
} sprite_t;


/*
void init_sprite(Sprite* sprite, int x, int y, int width, int height);
void move_sprite(Sprite* sprite, int dx, int dy);
void draw_sprite(const Sprite* sprite);
*/

#endif // SPRITE_H