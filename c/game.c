#include <assert.h>
#include "game.h"

int Abs(int x) {
  if (x < 0) return -x;
  return x;
}

float FAbs(float x) {
  if (x < 0) return -x;
  return x;
}

bool ButtonIsDown(User_Input *input, Input_Button button) {
  return input->buttons[button];
}

bool ButtonWasDown(User_Input *input, Input_Button button) {
  if (input->old == NULL) return false;
  return input->old->buttons[button];
}

void AttachToBat(Ball *ball, Bat *bat, Pixel_Buffer *screen) {
  ball->x = bat->left + bat->width / 2 + 5;
  ball->y =
      screen->height - (bat->bottom + bat->height + ball->radius / 2) - 5;
}

#define START_BALL_SPEED 5

void InitGameState(Program_State *state, Pixel_Buffer *screen) {
  state->bat.left = 100.0f;
  state->bat.bottom = 20;
  state->bat.width = 70;
  state->bat.height = 13;
  state->bat.color = 0x00FFFFFF;
  state->ball_count = 1;
  Ball *main_ball = &state->balls[0];
  main_ball->radius = 8.f;
  main_ball->color = 0x00FFFFFF;
  main_ball->attached = true;
  AttachToBat(main_ball, &state->bat, screen);
  main_ball->speed.x = START_BALL_SPEED;
  main_ball->speed.y = -START_BALL_SPEED;
  main_ball->attached = true;

  state->current_level = 0;
  state->level_initialised = false;

  // Init levels
  {
    int level = 0;
    state->levels[level++].layout =
        "           \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sx xxx xs \n"
        " sssssssss ";
    state->levels[level++].layout =
        " \n"
        "sxxxx\n"
        "sxxxxx \n"
        "sxxxxxx \n"
        "sxxxxxxx \n"
        "sxxxxxxxx \n"
        "sxxxxxxx \n"
        "sxxxxxx \n"
        "sxxxxx \n"
        "sxxxx \n"
        "sxxx \n"
        "sxxxx \n"
        "sxxxxx \n"
        "sxxxxxx \n"
        "sxxxxxxx \n"
        "sxxxxxxxx \n"
        "sxxxxxxxxx \n"
        "ssssssssss ";
    state->levels[level++].layout =
        "\n"
        "  s     s  \n"
        "  s     s  \n"
        "   s   s   \n"
        "   s   s   \n"
        "  xxxxxxx  \n"
        "  xxxxxxx  \n"
        " xxsxxxsxx \n"
        " xxsxxxsxx \n"
        "xxxxxxxxxxx\n"
        "xxxxxxxxxxx\n"
        "xxxxxxxxxxx\n"
        "x xxxxxxx x\n"
        "x x     x x\n"
        "x x     x x\n"
        "   ss ss   \n"
        "   ss ss   ";

    assert(level == MAX_LEVELS);
  }
}

void DrawPixel(Pixel_Buffer *screen, int x, int y, u32 color) {
  u32 *pixel = screen->pixels + screen->width * y + x;
  *pixel = color;
}

void DrawRect(Pixel_Buffer *screen, Rect rect, u32 color) {
  int left = rect.left;
  int top = rect.top;
  int right = left + rect.width;
  int bottom = top + rect.height;
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
  Rect bat_rect = {left, top, bat->width, bat->height};
  DrawRect(screen, bat_rect, color);
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

Rect GetBrickRect(Pixel_Buffer *screen, int number) {
  const int kPadding = 10;
  const int kBrickWidth = (screen->width - kPadding * 2) / BRICKS_PER_ROW;
  const int kBrickHeight = 20;

  int brick_x = (number % BRICKS_PER_ROW) * kBrickWidth + kPadding;
  int brick_y = (number / BRICKS_PER_ROW) * kBrickHeight + kPadding;

  Rect result = {brick_x, brick_y, kBrickWidth, kBrickHeight};
  return result;
}

void MoveBalls(Pixel_Buffer *screen, Program_State *state) {
  for (int i = 0; i < state->ball_count; ++i) {
    Ball *ball = state->balls + i;

    // Erase
    DrawCircle(screen, ball->x, ball->y, ball->radius, BG_COLOR);

    if (ball->attached) {
      AttachToBat(ball, &state->bat, screen);
    }

    // Move
    ball->x += ball->speed.x;
    ball->y += ball->speed.y;

    // Collision with screen borders
    const float kLeft = SCREEN_PADDING + ball->radius,
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
    {
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
    }

    // Collision with the bricks (brute force)
    {
      Brick *bricks = state->bricks;
      for (int i = 0; i < BRICKS_PER_ROW * BRICKS_PER_COL; ++i) {
        Brick brick = bricks[i];
        if (brick == Brick_Empty) continue;
        Rect brick_rect = GetBrickRect(screen, i);

        // Check collision
        const float left = brick_rect.left - ball->radius;
        const float right = brick_rect.left + brick_rect.width + ball->radius;
        const float top = brick_rect.top - ball->radius;
        const float bottom = brick_rect.top + brick_rect.height + ball->radius;

        // TODO: handle corners
        bool collides = (left <= ball->x && ball->x <= right &&
                         top <= ball->y && ball->y <= bottom);
        if (!collides) continue;

        if (brick == Brick_Strong) {
          bricks[i] = Brick_Normal;
        } else if (brick == Brick_Normal) {
          // Erase
          bricks[i] = Brick_Empty;
          DrawRect(screen, brick_rect, BG_COLOR);
        }

        float ldist = FAbs(left - ball->x);
        float rdist = FAbs(right - ball->x);
        float tdist = FAbs(top - ball->y);
        float bdist = FAbs(bottom - ball->y);

        if (ldist + rdist < tdist + bdist) {
          ball->x = (ldist < rdist) ? left : right;
          ball->speed.x =
              (ldist < rdist) ? -FAbs(ball->speed.x) : FAbs(ball->speed.x);
        } else {
          ball->y = (tdist < bdist) ? top : bottom;
          ball->speed.y =
              (tdist < bdist) ? -FAbs(ball->speed.y) : FAbs(ball->speed.y);
        }
      }
    }

    // Redraw
    DrawCircle(screen, ball->x, ball->y, ball->radius, ball->color);
  }
}

void DrawBricks(Pixel_Buffer *screen, Brick *bricks) {
  for (int i = 0; i < BRICKS_PER_ROW * BRICKS_PER_COL; ++i) {
    if (bricks[i] == Brick_Empty) continue;

    // Draw brick
    u32 color = 0x00BBBBBB;
    if (bricks[i] == Brick_Strong) {
      color = 0x00999999;
    } else if (bricks[i] == Brick_Unbreakable) {
      color = 0x00AA8888;
    }
    DrawRect(screen, GetBrickRect(screen, i), color);
  }
}

bool WonLevel(Brick *bricks) {
  for (int i = 0; i < BRICKS_PER_ROW * BRICKS_PER_COL; ++i) {
    if (bricks[i] != Brick_Empty) return false;
  }
  return true;
}

bool UpdateAndRender(Pixel_Buffer *screen, Program_State *state,
                     User_Input *input) {
  Level *level = state->levels + state->current_level;
  assert(state->current_level < MAX_LEVELS);

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
      if (*b == '\n') {
        brick_x = 0;
        brick_y++;
      } else {
        assert(brick_x < BRICKS_PER_ROW);
        assert(brick_y < BRICKS_PER_COL);
        int brick_num = brick_y * BRICKS_PER_ROW + brick_x;
        if (*b == 'x') {
          state->bricks[brick_num] = Brick_Normal;
        } else if (*b == 'u') {
          state->bricks[brick_num] = Brick_Unbreakable;
        } else if (*b == 's') {
          state->bricks[brick_num] = Brick_Strong;
        } else {
          state->bricks[brick_num] = Brick_Empty;
        }
        brick_x++;
      }
      b++;
    }
    state->level_initialised = true;
  }

  if (ButtonIsDown(input, IB_escape)) {
    return false;
  }

  if (ButtonWasDown(input, IB_space)) {
    for (int i = 0; i < state->ball_count; ++i) {
      state->balls[i].attached = false;
    }
  }

  Bat *bat = &state->bat;

  MoveBat(screen, bat, input);
  MoveBalls(screen, state);

  DrawBricks(screen, state->bricks);

  if (WonLevel(state->bricks)) {
    state->current_level++;
    state->level_initialised = false;
    if (state->current_level >= MAX_LEVELS) {
      printf("You won!\n");
      return false;
    }
  }

  return true;
}
