#include "game.h"

void fatal_error(char *string) {
  printf("%s\n", string);
  assert(0);
}

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
  ball->x = bat->left + ball->attached_x;
  ball->y = screen->height - (bat->bottom + bat->height + ball->radius / 2) - 5;
}

#define START_BALL_SPEED 5

void ResetBall(Ball *ball, Bat *bat) {
  ball->radius = 8.f;
  ball->color = 0x00FFFFFF;
  ball->attached = true;
  ball->attached_x = bat->width / 2 + 5;
  ball->speed.x = START_BALL_SPEED;
  ball->speed.y = -START_BALL_SPEED;
}

void InitGameState(Program_State *state, Pixel_Buffer *screen) {
  srand((unsigned)LinuxGetWallClock());

  state->bat.left = 100.0f;
  state->bat.bottom = 20;
  state->bat.width = DEFAULT_BAT_WIDTH;
  state->bat.height = 13;
  state->bat.color = 0x00FFFFFF;
  state->ball_count = 1;
  Ball *main_ball = &state->balls[0];
  ResetBall(main_ball, &state->bat);
  AttachToBat(main_ball, &state->bat, screen);

  state->current_level = 0;
  state->level_initialised = false;

  // Init buffs
  state->falling_buffs = 0;
  for (int i = 0; i < MAX_BUFFS; ++i) {
    state->buffs[i].type = Buff_Inactive;
  }
  for (int i = 0; i < Buff__COUNT; ++i) {
    state->active_buffs[i] = 0;
  }

  // Init levels
  {
    int level = 0;
    state->levels[level++].layout =
        "           \n"
        " \n"
        " \n"
        " \n"
        " \n"
        " \n"
        " \n"
        " \n"
        " \n"
        " \n"
        " \n"
        " \n"
        " \n"
        " \n"
        " \n"
        " \n"
        " \n"
        "         x ";
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

void DrawBat(Pixel_Buffer *screen, Bat *bat, u32 color) {
  int left = (int)bat->left;
  int top = screen->height - bat->bottom - bat->height;
  Rect bat_rect = {left, top, bat->width, bat->height};
  DrawRect(screen, bat_rect, color);
}

bool BuffActivated(Program_State *state, Buff_Type type) {
  return state->active_buffs[type] == BUFF_TTL;
}

bool BuffDeactivated(Program_State *state, Buff_Type type) {
  return state->active_buffs[type] == 1;
}

bool BuffIsActive(Program_State *state, Buff_Type type) {
  return state->active_buffs[type] > 0;
}

void MoveBat(Pixel_Buffer *screen, Program_State *state, User_Input *input) {
  Bat *bat = &state->bat;

  // Erase first
  DrawBat(screen, bat, BG_COLOR);

  // Check buffs
  {
    if (BuffActivated(state, Buff_Enlarge)) {
      bat->width = 2 * DEFAULT_BAT_WIDTH;
      bat->left -= DEFAULT_BAT_WIDTH / 2;
      if (bat->left < SCREEN_PADDING) {
        bat->left = SCREEN_PADDING;
      }
      state->active_buffs[Buff_Shrink] = 0;  // cancel shrink if present
    } else if (BuffDeactivated(state, Buff_Enlarge)) {
      bat->width = DEFAULT_BAT_WIDTH;
      bat->left += DEFAULT_BAT_WIDTH / 2;
      const int kMaxLeft = screen->width - SCREEN_PADDING - bat->width;
      if (bat->left > kMaxLeft) {
        bat->left = kMaxLeft;
      }
    }
    if (BuffActivated(state, Buff_Shrink)) {
      bat->width = DEFAULT_BAT_WIDTH / 2;
      bat->left += DEFAULT_BAT_WIDTH / 4;
      state->active_buffs[Buff_Enlarge] = 0;  // cancel enlarge if present
    } else if (BuffDeactivated(state, Buff_Shrink)) {
      bat->width = DEFAULT_BAT_WIDTH;
      bat->left += DEFAULT_BAT_WIDTH / 4;
      const int kMaxLeft = screen->width - SCREEN_PADDING - bat->width;
      if (bat->left > kMaxLeft) {
        bat->left = kMaxLeft;
      }
    }
    // Release balls on deactivation
    if (BuffDeactivated(state, Buff_Sticky)) {
      for (int i = 0; i < MAX_BALLS; ++i) {
        state->balls[i].attached = false;
      }
    }
  }

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
  DrawBat(screen, bat, bat->color);
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

Rect GetBatRect(Pixel_Buffer *screen, Bat *bat) {
  Rect result = {(int)bat->left, screen->height - bat->bottom - bat->height,
                 bat->width, bat->height};

  return result;
}

bool RectsIntersect(Rect r1, Rect r2) {
  int r1_right = r1.left + r1.width;
  int r2_right = r2.left + r2.width;
  int r1_bottom = r1.top + r1.height;
  int r2_bottom = r2.top + r2.height;
  bool miss = (r1.left > r2_right || r2.left > r1_right || r1.top > r2_bottom ||
               r2.top > r1_bottom);
  return !miss;
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
        if (BuffIsActive(state, Buff_Sticky)) {
          ball->attached = true;
          ball->attached_x = ball->x - bat->left;
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

        // Hit the brick
        if (brick == Brick_Strong) {
          bricks[i] = Brick_Normal;
        } else if (brick == Brick_Normal) {
          // Erase
          bricks[i] = Brick_Empty;
          DrawRect(screen, brick_rect, BG_COLOR);
        }

        // Reflect the ball
        {
          float ldist = FAbs(left - ball->x);
          float rdist = FAbs(right - ball->x);
          float tdist = FAbs(top - ball->y);
          float bdist = FAbs(bottom - ball->y);

          if (ldist + rdist < tdist + bdist) {
            // ball->x = (ldist < rdist) ? left : right;
            ball->speed.x =
                (ldist < rdist) ? -FAbs(ball->speed.x) : FAbs(ball->speed.x);
          } else {
            // ball->y = (tdist < bdist) ? top : bottom;
            ball->speed.y =
                (tdist < bdist) ? -FAbs(ball->speed.y) : FAbs(ball->speed.y);
          }
        }

        // Drop buffs/debuffs
        {
          const int kChance = 15;  // percent
          if ((rand() % 100) < kChance && state->falling_buffs < MAX_BUFFS) {
            state->falling_buffs++;
            int next_available_buff = -1;
            for (int i = 0; i < MAX_BUFFS; ++i) {
              if (state->buffs[i].type == Buff_Inactive) {
                next_available_buff = i;
                break;
              }
            }
            assert(next_available_buff >= 0);
            Buff *buff = state->buffs + next_available_buff;

            // Init new buff
            buff->type = (Buff_Type)((rand() % (Buff__COUNT - 1)) + 1);
            buff->position = V2(brick_rect.left, brick_rect.top);
          }
        }

        break;  // don't collide with other bricks
      }
    }

    // Redraw
    DrawCircle(screen, ball->x, ball->y, ball->radius, ball->color);
  }
}

void MoveBuffs(Pixel_Buffer *screen, Program_State *state) {
  if (state->falling_buffs < 1) return;

  const int kBuffWidth = 40;
  const int kBuffHeight = 15;
  const float kBuffSpeed = 1.5f;

  Rect bat_rect = GetBatRect(screen, &state->bat);

  int falling_seen = 0;
  for (int i = 0; i < MAX_BUFFS; ++i) {
    Buff *buff = state->buffs + i;
    if (buff->type == Buff_Inactive) continue;

    ++falling_seen;

    Rect buff_rect = {(int)buff->position.x, (int)buff->position.y, kBuffWidth,
                      kBuffHeight};

    // Erase
    DrawRect(screen, buff_rect, BG_COLOR);

    u32 color = 0x00FFFFFF;
    switch (buff->type) {
      case Buff_Enlarge: {
        color = 0x00F3B191;
      } break;
      case Buff_Shrink: {
        color = 0x0013B1F1;
      } break;
      case Buff_Sticky: {
        color = 0x00F311F1;
      } break;
      case Buff_MultiBall: {
        color = 0x00AA0100;
      } break;
      case Buff_PowerBall: {
        color = 0x0033F199;
      } break;
      case Buff_SlowBall: {
        color = 0x004433FF;
      } break;
      case Buff_Gun: {
        color = 0x0088FF22;
      } break;
      case Buff_BottomWall: {
        color = 0x0099D622;
      } break;
      default: { fatal_error("Unknown buff type"); } break;
    }

    buff->position.y += kBuffSpeed;
    buff_rect.top = (int)buff->position.y;

    // Destroy if reaches the bottom
    if (buff->position.y > screen->height) {
      buff->type = Buff_Inactive;
      state->falling_buffs--;
      continue;
    }

    if (RectsIntersect(bat_rect, buff_rect)) {
      // Activate buff
      if (BuffIsActive(state, buff->type)) {
        // If already active, don't activate again, but prolong
        state->active_buffs[buff->type] = BUFF_TTL - 1;
      } else {
        state->active_buffs[buff->type] = BUFF_TTL;
      }

      // Consume
      buff->type = Buff_Inactive;
      state->falling_buffs--;

      continue;
    }

    DrawRect(screen, buff_rect, color);

    if (state->falling_buffs <= falling_seen) return;
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

bool LevelComplete(Brick *bricks) {
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
    // Clear screen
    Rect screen_rect = {0, 0, screen->width, screen->height};
    DrawRect(screen, screen_rect, BG_COLOR);

    // Clean up all bricks
    for (int i = 0; i < BRICKS_PER_ROW * BRICKS_PER_COL; ++i) {
      state->bricks[i] = Brick_Empty;
    }

    // Clean up all buffs
    for (int i = 0; i < MAX_BUFFS; ++i) {
      state->buffs[i].type = Buff_Inactive;
    }

    // Reset ball to the attached state. Remove other balls
    state->ball_count = 1;
    ResetBall(&state->balls[0], &state->bat);
    AttachToBat(&state->balls[0], &state->bat, screen);

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

  MoveBat(screen, state, input);
  MoveBalls(screen, state);

  DrawBricks(screen, state->bricks);

  // Decrement all buffs
  for (int i = 0; i < Buff__COUNT; ++i) {
    if (state->active_buffs[i] > 0) {
      state->active_buffs[i]--;
    }
  }
  MoveBuffs(screen, state);

  if (LevelComplete(state->bricks)) {
    state->current_level++;
    state->level_initialised = false;
    if (state->current_level >= MAX_LEVELS) {
      printf("You won!\n");
      return false;
    }
  }

  return true;
}
