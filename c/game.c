#include "game.h"

bool ButtonIsDown(User_Input *input, Input_Button button) {
  return input->buttons[button];
}

bool ButtonWasDown(User_Input *input, Input_Button button) {
  if (input->old == NULL) return false;
  return input->old->buttons[button];
}

void InitGameState(Program_State *state) {
  state->bat.left = 100.0f;
  state->bat.bottom = 10;
  state->bat.width = 70;
  state->bat.height = 13;
  state->bat.color = 0x00FFFFFF;
  state->ball_count = 1;
  Ball *main_ball = &state->balls[0];
  // TODO: draw attached
  main_ball->radius = 8.f;
  main_ball->color = 0x00FFFFFF;
  main_ball->x = state->bat.left + state->bat.width / 2;
  main_ball->y = state->bat.bottom + state->bat.height + main_ball->radius / 2;
  main_ball->speed_x = main_ball->speed_y = 0;
  main_ball->attached = true;
}

void DrawPixel(Pixel_Buffer *screen, int x, int y, u32 color) {
  u32 *pixel = screen->pixels + screen->width * y + x;
  *pixel = color;
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

void DrawCircle(Pixel_Buffer *screen, float X, float Y, float radius, u32 color) {
  float screen_right = (float)screen->width;
  float screen_bottom = (float)screen->height;

  float left = (X > radius) ? X - radius : 0;
  float right = (X + radius < screen_right) ? X + radius : screen_right - 1;
  float top = (Y > radius) ? Y - radius : 0;
  float bottom = (Y + radius < screen_bottom) ? Y + radius : screen_bottom - 1;

  // The simplest brute force algorithm
  float sq_radius = radius * radius;
  for (float y = top; y <= bottom; y += 1.0f) {
    for (float x = left; x <= right; x += 1.0f) {
      float sq_distance = (x - X) * (x - X) + (y - Y) * (y -Y);
      if (sq_distance < sq_radius) {
        DrawPixel(screen, (int)x, (int)y, color);  // know it's not efficient
      }
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

#define BAT_MOVE_STEP 6.0f

void MoveBat(Pixel_Buffer *screen, Bat *bat, User_Input *input) {

  // Erase first
  EraseBat(screen, bat);

  // Move
  float move = 0;
  if (ButtonIsDown(input, IB_left)) {
    move -= BAT_MOVE_STEP;
  }
  if (ButtonIsDown(input, IB_right)) {
    move += BAT_MOVE_STEP;
  }
  const int kLeft = 2, kRight = screen->width - 2;
  bat->left += move;
  if (bat->left < kLeft) {
    bat->left = kLeft;
  }
  if (bat->left + bat->width > kRight) {
    bat->left = kRight - bat->width;
  }

  // Redraw
  DrawBat(screen, bat);
}

void MoveBalls(Pixel_Buffer *screen, Program_State *state) {
  for (int i = 0; i < state->ball_count; ++i) {
    Ball *ball = state->balls + i;

    // Erase
    DrawCircle(screen, ball->x, ball->y, ball->radius, BG_COLOR);

    // Move

    // Redraw
    DrawCircle(screen, ball->x, ball->y, ball->radius, ball->color);
  }
}

bool UpdateAndRender(Pixel_Buffer *screen, Program_State *state,
                     User_Input *input) {
  if (ButtonIsDown(input, IB_escape)) {
    return false;
  }

  Bat *bat = &state->bat;

  MoveBat(screen, bat, input);
  MoveBalls(screen, state);

  return true;
}
