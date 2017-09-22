%ifndef __GAME_INC__
%define __GAME_INC__

%define BG_COLOR                 0x00000000
%define WALL_SIZE                5
%define MAX_BALLS                10
%define MAX_LEVELS               3
%define MAX_BUFFS                10
%define MAX_BULLETS              100
%define BUFF_TTL                 30 * 60
%xdefine BRICKS_PER_ROW           11
%xdefine BRICKS_PER_COL           20
%define BRICKS_TOTAL             (BRICKS_PER_ROW * BRICKS_PER_COL)
%define BRICK_HEIGHT             20
%define DEFAULT_BAT_WIDTH        70
%define BAT_MOVE_STEP            9
%xdefine START_BALL_SPEED        __float32__(8.0)
%xdefine MAX_BALL_SPEED          8
%define BULLET_COOLDOWN          20

; === Rect

struc Rect
        .left           resd    1
        .top            resd    1
        .width          resd    1
        .height         resd    1
endstruc

; === Input

%define IB_up           0
%define IB_down         1
%define IB_left         2
%define IB_right        3
%define IB_space        4
%define IB_shift        5
%define IB_escape       6

%macro button_is_down 1
        push eax
        mov eax, [g_input]
        add eax, %1
        cmp byte [eax], 1
        pop eax
%endmacro

; === V2

struc v2
        .x      resd    1
        .y      resd    1
endstruc

; === Buffs

%define Buff_Inactive           0
%define Buff_Enlarge            1
%define Buff_Shrink             2
%define Buff_Sticky             3
%define Buff_MultiBall          4
%define Buff_PowerBall          5
%define Buff_Gun                6
%define Buff_BottomWall         7
%define Buff_Type__COUNT        8

struc Buff
        .type           resd    1
        .position       resq    1
endstruc

%define Buff__SIZE             16       ; aligned

; === Bat

struc Bat
        .left           resd    1
        .bottom         resd    1
        .width          resd    1
        .height         resd    1
        .color          resd    1
        .can_shoot      resd    1
endstruc

; === Ball

struc Ball
        .active         resb    1
        .attached       resb    1
        alignb 4
        .attached_x     resd    1
        .radius         resd    1
        .x              resd    1
        .y              resd    1
        .speed          resd    2
endstruc

; === Bricks

%define Brick_Empty             0
%define Brick_Normal            1
%define Brick_Strong            2
%define Brick_Unbreakable       3
%define Brick__COUNT            4


; === Vector macros

%macro LENGTH 1
        push eax
        lea eax, %1
        push eax                        ; pointer to v2
        call v2_length                  ; result in st0
        add esp, 4
        pop eax
%endmacro

%macro NORMALIZE 1
        push eax
        lea eax, %1
        push eax                        ; pointer to v2
        call v2_length                  ; result in st0
        add esp, 4

        fld dword [eax + v2.x]
        fdiv st1
        fstp dword [eax + v2.x]         ; vector->x /= len

        fld dword [eax + v2.y]
        fdiv st1
        fstp dword [eax + v2.y]         ; vector->x /= len

        ffree st0
        pop eax
%endmacro

; usage: SCALE [vector_ptr] factor:float32
%macro SCALE 2
        push eax

        push dword %2
        fld dword [esp]        ; load factor
        add esp, 4

        lea eax, %1

        fld dword [eax + v2.x]
        fmul st1
        fstp dword [eax + v2.x]

        fld dword [eax + v2.y]
        fmul st1
        fstp dword [eax + v2.y]

        ffree st0
        pop eax
%endmacro

%endif  ; __GAME_INC__
