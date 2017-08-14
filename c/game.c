#include "game.h"

bool ButtonIsDown(User_Input *input, Input_Button button) {
  return input->buttons[button];
}

bool ButtonWasDown(User_Input *input, Input_Button button) {
  if (input->old == NULL) return false;
  return input->old->buttons[button];
}

void DrawRect(Pixel_Buffer *screen, int left, int top, int width, int height,
              u32 color) {
  int right = left + width;
  int bottom = top + height;
  if (left < 0) left = 0;
  if (top < 0) top = 0;
  if (right > screen->width) right = screen->width;
  if (bottom > screen->height) bottom = screen->height;
  for (int y = top; y < bottom; ++y) {
    u32 *pixel = screen->pixels + screen->width * y + left;
    for (int x = left; x < right; ++x) {
      *pixel++ = color;
    }
  }
}

void _DrawBat(Pixel_Buffer *screen, Bat *bat, u32 color) {
  int left = (int)bat->left;
  int top = screen->height - bat->bottom - bat->height;
  DrawRect(screen, left, top, bat->width, bat->height, color);
}

void EraseBat(Pixel_Buffer *screen, Bat *bat) {
  _DrawBat(screen, bat, BG_COLOR);
}

void DrawBat(Pixel_Buffer *screen, Bat *bat) {
  _DrawBat(screen, bat, bat->color);
}

#define BAT_MOVE_STEP 4.0f

void MoveBat(Bat *bat, User_Input *input) {
  float move = 0;
  if (ButtonIsDown(input, IB_left)) {
    move -= BAT_MOVE_STEP;
  }
  if (ButtonIsDown(input, IB_right)) {
    move += BAT_MOVE_STEP;
  }
  bat->left += move;
}

bool UpdateAndRender(Pixel_Buffer *screen, Program_State *state,
                     User_Input *input) {
  if (ButtonIsDown(input, IB_escape)) {
    return false;
  }

  Bat *bat = &state->bat;

  EraseBat(screen, bat);

  MoveBat(bat, input);

  DrawBat(screen, bat);

  return true;
}
