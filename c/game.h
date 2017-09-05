#ifndef _GAME_H_
#define _GAME_H_

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <assert.h>
#include <time.h>

#include "vectors.h"

#define BG_COLOR 0x00000000

typedef uint32_t u32;
typedef uint64_t u64;
typedef int32_t i32;
typedef int64_t i64;

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
  bool can_shoot;
} Bat;

typedef struct Ball {
  bool active;
  bool attached;
  float attached_x;
  float radius;
  u32 color;
  float x;
  float y;
  v2 speed;
} Ball;

typedef struct Level { char *layout; } Level;

typedef struct Rect {
  int left;
  int top;
  int width;
  int height;
} Rect;

typedef enum Brick {
  Brick_Empty = 0,
  Brick_Normal,
  Brick_Strong,
  Brick_Unbreakable,
  Brick__COUNT,
} Brick;

typedef enum Buff_Type {
  Buff_Inactive = 0,
  Buff_Enlarge,
  Buff_Shrink,
  Buff_Sticky,
  Buff_MultiBall,
  Buff_PowerBall,
  Buff_SlowBall,
  Buff_Gun,
  Buff_BottomWall,
  Buff__COUNT,
} Buff_Type;

typedef struct Buff {
  Buff_Type type;
  v2 position;
} Buff;

typedef v2 Bullet;

#define MAX_BALLS 10
#define MAX_LEVELS 3
#define MAX_BUFFS 10
#define MAX_BULLETS 100
#define BUFF_TTL 30 * 60  // in frames
#define BRICKS_PER_ROW 11
#define BRICKS_PER_COL 20
#define WALL_SIZE 5
#define DEFAULT_BAT_WIDTH 70
#define BAT_MOVE_STEP 6.0f
#define START_BALL_SPEED 4
#define MAX_BALL_SPEED 8
#define BULLET_COOLDOWN 20

// TODO: maybe move bricks to level?
typedef struct Program_State {
  bool level_initialised;
  int ball_count;
  int current_level;
  int falling_buffs;
  int bullet_cooldown;
  int bullets_in_flight;
  int active_buffs[Buff__COUNT];  // stores time to live
  Bat bat;
  Level levels[MAX_LEVELS];
  Ball balls[MAX_BALLS];
  Brick bricks[BRICKS_PER_COL * BRICKS_PER_ROW];
  Buff buffs[MAX_BUFFS];
  Bullet bullets[MAX_BULLETS];
} Program_State;

bool UpdateAndRender(Pixel_Buffer *screen, Program_State *state, User_Input *input);

void InitGameState(Program_State *state, Pixel_Buffer *screen);

u64 LinuxGetWallClock();

void fatal_error(char *string);

#endif  // _GAME_H_
