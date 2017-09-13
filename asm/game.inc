%define TRUE    1
%define FALSE   0

%define MAX_BALLS                10
%define MAX_LEVELS               3
%define MAX_BUFFS                10
%define MAX_BULLETS              100
%define BUFF_TTL                 30 * 60
%xdefine BRICKS_PER_ROW           11
%xdefine BRICKS_PER_COL           20
%define BRICKS_TOTAL             (BRICKS_PER_ROW * BRICKS_PER_COL)
%define WALL_SIZE                5
%define DEFAULT_BAT_WIDTH        70
%define BAT_MOVE_STEP            6.0
%xdefine START_BALL_SPEED        4
%xdefine MAX_BALL_SPEED          8
%define BULLET_COOLDOWN          20

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

%define v2_x    0
%define v2_y    4

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

; === Bat

%define Bat_left        0
%define Bat_bottom      4
%define Bat_width       8
%define Bat_height      12
%define Bat_color       16
%define Bat_can_shoot   20

; === Ball

%define Ball_active             0
%define Ball_attached           1
%define Ball_attached_x         4
%define Ball_radius             8
%define Ball_x                  12
%define Ball_y                  16
%define Ball_speed              20      ; v2
%define Ball__SIZE              28


; === Vector macros

%macro NORMALIZE 1
        push eax
        lea eax, %1
        push eax                        ; pointer to v2
        call v2_length                  ; result in st0
        add esp, 4

        fld dword [eax + v2_x]
        fdiv st1
        fstp dword [eax + v2_x]         ; vector->x /= len

        fld dword [eax + v2_y]
        fdiv st1
        fstp dword [eax + v2_y]         ; vector->x /= len

        ffree st0
        pop eax
%endmacro


%macro SCALE 2
        ; TODO
%endmacro
