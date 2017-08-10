#include "game.h"

bool button_is_down(User_Input *input, Input_Button button) {
  return input->buttons[button];
}

bool button_was_down(User_Input *input, Input_Button button) {
  if (input->old == NULL) return false;
  return input->old->buttons[button];
}

void draw_rect(Pixel_Buffer *screen, int left, int top, int width, int height,
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

bool update_and_render(Pixel_Buffer *screen, User_Input *input) {
  draw_rect(screen, 100, 100, 100, 20, 0x00FFFFFF);
  return true;
}