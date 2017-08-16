#ifndef _GAME_H_
#define _GAME_H_

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>

#include "vectors.h"

#define BG_COLOR 0x00000000

typedef uint32_t u32;
typedef uint64_t u64;

typedef enum Input_Button {
  IB_up = 0,
  IB_down,
  IB_left,
  IB_right,

  IB_space,
  IB_shift,
  IB_escape,

  IB__COUNT,
} Input_Button;

typedef struct User_Input {
  bool buttons[IB__COUNT];

  struct User_Input *old;
} User_Input;

typedef struct Pixel_Buffer {
  u32 *pixels;
  int width;
  int height;
} Pixel_Buffer;

typedef struct Bat {
  float left;
  int bottom;  // const
  int width;
  int height;
  u32 color;
} Bat;

typedef struct Ball {
  bool attached;
  float radius;
  u32 color;
  float x;
  float y;
  v2 speed;
} Ball;

#define MAX_BALLS 10

typedef struct Program_State {
  Ball balls[MAX_BALLS];
  Bat bat;
  int ball_count;
} Program_State;

bool UpdateAndRender(Pixel_Buffer *screen, Program_State *state,
                     User_Input *input);

void InitGameState(Program_State *state);

#endif  // _GAME_H_
