#ifndef _GAME_H_
#define _GAME_H_

#include <stdbool.h>
#include <stdint.h>

typedef uint32_t u32;

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
  bool key_pressed;

  struct User_Input *old;
} User_Input;

typedef struct Pixel_Buffer {
  u32 *pixels;
  int width;
  int height;
} Pixel_Buffer;

bool update_and_render(Pixel_Buffer *screen, User_Input *input);

#endif  // _GAME_H_
