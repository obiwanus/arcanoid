#include <assert.h>
#include "game.h"

bool ButtonIsDown(User_Input *input, Input_Button button) {
  return input->buttons[button];
}

bool ButtonWasDown(User_Input *input, Input_Button button) {
  if (input->old == NULL) return false;
  return input->old->buttons[button];
}

#define START_BALL_SPEED 5

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
  main_ball->speed.x = main_ball->speed.y = START_BALL_SPEED;
  main_ball->attached = true;

  state->current_level = 0;
  state->level_initialised = false;

  // Init levels
  {
    state->levels[0].layout =
        "xxxxxxxxxxx\n"
        " xxxxxxxxx \n"
        "  xxxxxxx  ";
    state->levels[1].layout =
        "xxxxxxxxxxx\n"
        " xxxxxxxxx \n"
        "  xxxxxxx  \n"
        " x x x x x ";
  }
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

void DrawCircle(Pixel_Buffer *screen, float X, float Y, float radius,
                u32 color) {
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
      float sq_distance = (x - X) * (x - X) + (y - Y) * (y - Y);
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

#define SCREEN_PADDING 2
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
  const int kLeft = SCREEN_PADDING, kRight = screen->width - SCREEN_PADDING;
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
    ball->x += ball->speed.x;
    ball->y += ball->speed.y;

    // Collision with screen borders
    const int kLeft = SCREEN_PADDING + ball->radius,
              kRight = screen->width - SCREEN_PADDING - ball->radius,
              kTop = SCREEN_PADDING + ball->radius,
              kBottom = screen->height - SCREEN_PADDING - ball->radius;

    if (ball->x < kLeft || ball->x > kRight) {
      ball->x = (ball->x < kLeft) ? kLeft : kRight;
      ball->speed.x = -ball->speed.x;
    }
    if (ball->y < kTop || ball->y > kBottom) {
      ball->y = (ball->y < kTop) ? kLeft : kBottom;
      ball->speed.y = -ball->speed.y;
    }

    // Collision with the bat
    Bat *bat = &state->bat;
    const float kBLeft = bat->left - ball->radius,
                kBRight = bat->left + bat->width + ball->radius,
                kBBottom = screen->height - bat->bottom,
                kBTop = kBBottom - bat->height - ball->radius,
                kBMiddle = (kBLeft + kBRight) / 2.0f;
    bool collides = (kBLeft <= ball->x && ball->x <= kBRight &&
                     kBTop <= ball->y && ball->y <= kBBottom);
    if (collides) {
      ball->y = kBTop;
      ball->speed.y = -ball->speed.y;

      // const float kReflect = bat->width / 10.0f;
      const v2 kVectorUp = {0, -1.0f};
      const v2 kVectorLeft = Normalize(V2(-1.5f, -1.0f));
      const v2 kVectorRight = Normalize(V2(1.5f, -1.0f));
      if (ball->x < kBMiddle) {
        float t = (kBMiddle - ball->x) / (kBMiddle - kBLeft);
        v2 new_direction = Lerp(kVectorUp, kVectorLeft, t);
        ball->speed = Scale(Normalize(new_direction), Length(ball->speed));
      } else {
        float t = (ball->x - kBMiddle) / (kBRight - kBMiddle);
        v2 new_direction = Lerp(kVectorUp, kVectorRight, t);
        ball->speed = Scale(Normalize(new_direction), Length(ball->speed));
      }
    }

    // Redraw
    DrawCircle(screen, ball->x, ball->y, ball->radius, ball->color);
  }
}

void DrawBricks(Pixel_Buffer *screen, Level *level) {
  for (int y = 0; y < BRICKS_PER_COL; ++y) {
    for (int x = 0; x < BRICKS_PER_ROW; ++x) {
    }
  }
}

bool UpdateAndRender(Pixel_Buffer *screen, Program_State *state,
                     User_Input *input) {
  Level *level = state->levels + state->current_level;
  assert(state->current_level < MAX_LEVELS - 1);

  // TODO: is it a good idea to check it every time?
  if (!state->level_initialised) {
    // Clean up all bricks
    for (int i = 0; i < BRICKS_PER_ROW * BRICKS_PER_COL; ++i) {
      state->bricks[i] = Brick_Empty;
    }

    // Init new bricks
    int brick_x = 0, brick_y = 0;
    char *b = level->layout;
    while (*b != '\0') {
      int brick_num = brick_y * BRICKS_PER_ROW + brick_x;
      if (*b == 'x') {
        state->bricks[brick_num] = Brick_Normal;
      } else if (*b == 'u') {
        state->bricks[brick_num] = Brick_Unbreakable;
      } else {
        state->bricks[brick_num] = Brick_Empty;
      }

      if (*b == '\n') {
        brick_x = 0;
        brick_y++;
      } else {
        brick_x++;
      }
      assert(brick_x < BRICKS_PER_ROW);
      assert(brick_y < BRICKS_PER_COL);
      b++;
    }
    state->level_initialised = true;
  }

  if (ButtonIsDown(input, IB_escape)) {
    return false;
  }

  Bat *bat = &state->bat;

  MoveBat(screen, bat, input);
  MoveBalls(screen, state);

  DrawBricks(screen, level);

  return true;
}
