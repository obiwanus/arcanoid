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
%define START_BALL_SPEED         4
%define MAX_BALL_SPEED           8
%define BULLET_COOLDOWN          20

; === Input

%define IB_up           0
%define IB_down         1
%define IB_left         2
%define IB_right        3
%define IB_space        4
%define IB_shift        5
%define IB_escape       6

%macro  button_is_down 1
        push eax
        mov eax, [g_input]
        add eax, %1
        cmp byte [eax], 1
        pop eax
%endmacro

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
