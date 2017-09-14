%include 'base.inc'
%include 'game.inc'
%include 'vectors.inc'
; --------------------------------------------------------
segment .data
g_level_initialised     dd      0
; --------------------------------------------------------
segment .bss

; Export
global g_pixels, g_width, g_height, g_state, g_input
global g_ball_count, g_ball_color, g_current_level, g_falling_buffs
global g_bullet_cooldown, g_bullets_in_flight
global g_active_buffs, g_levels, g_balls, g_bricks
global g_buffs, g_bullets, g_bat

g_pixels        resd    1
g_width         resd    1
g_height        resd    1
g_state         resd    1
g_input         resd    1

g_ball_count            resd    1
g_ball_color            resd    1
g_current_level         resd    1
g_falling_buffs         resd    1
g_bullet_cooldown       resd    1
g_bullets_in_flight     resd    1
g_active_buffs          resd    Buff_Type__COUNT
g_levels                resd    MAX_LEVELS
g_balls                 resb    MAX_BALLS * Ball__SIZE
g_bricks                resd    BRICKS_TOTAL
g_buffs                 resd    3 * MAX_BUFFS
g_bullets               resd    2 * MAX_BULLETS
g_bat                   resd    6

; --------------------------------------------------------
segment .text
global  update_and_render, attach_to_bat
extern  draw_rect, draw_pixel, draw_circle, draw_bat, draw_ball

; ========================================================
; update_and_render(
;       Pixel_Buffer *screen,
;       Program_State *state,
;       User_Input *input)
update_and_render:
        enter   0, 0                    ; setup routine
        pusha

; START --------------------------------------------------

        ; Save parameters in global pointers for easy access
        mov eax, [ebp + 8]
        mov ebx, [eax]
        mov [g_pixels], ebx
        mov ebx, [eax + 4]
        mov [g_width], ebx
        mov ebx, [eax + 8]
        mov [g_height], ebx
        mov eax, [ebp + 12]
        mov [g_input], eax

        ; Check exit condition
        button_is_down IB_escape
        je program_end

        ; if (!state->level_initialised || state->ball_count <= 0)
        xor eax, eax
        cmp dword [g_level_initialised], FALSE
        sete al
        cmp dword [g_ball_count], 0
        setle ah
        or al, ah
        jz .level_is_ok
        call init_level
.level_is_ok:

        push dword 0x0066AACC           ; color
        push dword 100                  ; height
        push dword 150                  ; width
        push dword 100                  ; top
        push dword 100                  ; left
        call draw_rect
        add esp, 20                     ; remove parameters

        push dword 0x00AA66CC           ; color
        push dword __float32__(20.0)    ; radius
        push dword __float32__(300.0)   ; Y
        push dword __float32__(100.0)   ; X
        call draw_circle
        add esp, 16                     ; remove parameters

        call update_bat
        call update_balls


; END ----------------------------------------------------

program_continue:
        popa
        mov eax, 1                      ; return true
        leave
        ret

program_end:
        popa
        mov eax, 0                      ; return false
        leave
        ret


; ========================================================
; init_level()
init_level:
        push ebp
        mov ebp, esp
        pusha

        ; Clear screen
        push dword BG_COLOR
        push dword [g_height]
        push dword [g_width]
        push dword 0
        push dword 0
        call draw_rect
        add esp, 20

        ; Init bat
        mov dword [g_bat + Bat_left],   100
        mov dword [g_bat + Bat_bottom], 20
        mov dword [g_bat + Bat_width],  DEFAULT_BAT_WIDTH
        mov dword [g_bat + Bat_height], 13
        mov dword [g_bat + Bat_color],  0x00FFFFFF
        mov dword [g_bat + Bat_can_shoot], FALSE

        ; Reset all balls
        mov ecx, MAX_BALLS
        mov edx, g_balls
.reset_balls:
        mov byte  [edx + Ball_active], FALSE
        mov byte  [edx + Ball_attached], FALSE
        mov dword [edx + Ball_radius], __float32__(8.0)
        mov dword [edx + Ball_speed + v2_x], __float32__(1.0)
        mov dword [edx + Ball_speed + v2_y], __float32__(-1.0)
        NORMALIZE [edx + Ball_speed]
        SCALE [edx + Ball_speed], START_BALL_SPEED
        add edx, Ball__SIZE
        loop .reset_balls

        ; Activate and attach main ball
        mov dword [g_ball_count], 1
        mov dword [g_ball_color], 0x00FFFFFF
        mov byte [g_balls + Ball_active], TRUE
        mov byte [g_balls + Ball_attached], TRUE
        mov eax, [g_bat + Bat_width]
        sar eax, 1  ; divide by 2
        add eax, 5  ; attached_x = bat->width / 2 + 5
        mov dword [g_balls + Ball_attached_x], eax
        push dword g_balls      ; pointer to main ball
        call attach_to_bat
        add esp, 4

        mov eax, [g_balls + Ball_x]
        mov eax, [g_balls + Ball_y]
        mov eax, [g_balls + Ball_radius]

        ; TODO: finish level init

        ; Mark as initialised
        mov dword [g_level_initialised], TRUE

        popa
        leave
        ret


; ========================================================
; attach_to_bat(Ball *ball)
attach_to_bat:
        %push
        %stacksize flat
        %arg ball:dword

        push ebp
        mov ebp, esp
        pusha

        mov eax, [ball]     ; took some time to figure out
        mov ebx, [g_bat + Bat_left]
        add ebx, [eax + Ball_attached_x]
        mov dword [eax + Ball_x], ebx
        fild dword [eax + Ball_x]
        fstp dword [eax + Ball_x]       ; convert to float and store

        fld dword [eax + Ball_radius]
        fistp dword [eax + Ball_radius] ; tmp convert to int
        mov ebx, [eax + Ball_radius]
        fild dword [eax + Ball_radius]
        fstp dword [eax + Ball_radius]  ; convert back to float
        sar ebx, 1
        add ebx, [g_bat + Bat_height]
        add ebx, [g_bat + Bat_bottom]
        add ebx, 5
        sub ebx, [g_height]
        neg ebx
        mov [eax + Ball_y], ebx
        fild dword [eax + Ball_y]
        fstp dword [eax + Ball_y]

        %pop
        popa
        leave
        ret


; ========================================================
; update_bat()
update_bat:
        %push
        %stacksize flat
        %assign %$localsize 0
        %local max_left:dword, max_right:dword
        push ebp
        mov ebp, esp
        pusha

        ; Erase bat
        push dword BG_COLOR
        call draw_bat
        add esp, 4

        ; Get move boundaries
        mov dword [max_left], WALL_SIZE
        mov eax, [g_width]
        sub eax, WALL_SIZE
        sub eax, [g_bat + Bat_width]
        mov [max_right], eax

        ; Move bat
        mov eax, [g_bat + Bat_left]

        button_is_down IB_left
        jne .left_skip
        sub eax, BAT_MOVE_STEP
.left_skip:
        button_is_down IB_right
        jne .right_skip
        add eax, BAT_MOVE_STEP
.right_skip:

        ; Restrict movement
        cmp eax, [max_left]
        jge .left_ok
        mov eax, [max_left]
.left_ok:
        cmp eax, [max_right]
        jle .right_ok
        mov eax, [max_right]
.right_ok:

        ; Apply new position
        mov [g_bat + Bat_left], eax

        ; Redraw bat
        push dword [g_bat + Bat_color]
        call draw_bat
        add esp, 4

        popa
        leave
        ret
        %pop


; ========================================================
; update_balls()
update_balls:
        %push
        %stacksize flat
        %assign %$localsize 0
        %local bleft:dword, bright:dword, btop:dword, bbottom:dword
        %local bradius:dword, bx:dword, by:dword
        push ebp
        mov ebp, esp
        sub esp, 20
        pusha

        mov ecx, 0              ; ball index
        mov ebx, g_balls        ; ball ptr
.for_each_ball:
        cmp byte [ebx + Ball_active], TRUE
        jne .next_ball   ; continue

        ; Release
        button_is_down IB_space
        jne .skip_release
        mov byte [ebx + Ball_attached], FALSE
.skip_release:

        ; Erase ball
        push dword BG_COLOR
        push ebx
        call draw_ball
        add esp, 8

        cmp byte [ebx + Ball_attached], TRUE
        jne .not_attached
        push ebx
        call attach_to_bat
        add esp, 4
        jmp .draw_and_next
.not_attached:

        ; Move
        fld dword [ebx + Ball_x]
        fld dword [ebx + Ball_speed + v2_x]
        faddp st1
        fstp dword [ebx + Ball_x]

        fld dword [ebx + Ball_y]
        fld dword [ebx + Ball_speed + v2_y]
        faddp st1
        fstp dword [ebx + Ball_y]

        ; Get screen borders
        fld dword [ebx + Ball_radius]
        fistp dword [bradius]

        mov eax, WALL_SIZE
        add eax, [bradius]
        mov [bleft], eax
        mov [btop], eax

        mov eax, [g_width]
        sub eax, WALL_SIZE
        sub eax, [bradius]
        mov [bright], eax

        mov eax, [g_height]
        sub eax, WALL_SIZE
        sub eax, [bradius]
        mov [bbottom], eax

        ; Collision with screen borders
        mov eax, [bleft]
        cmp [ebx + Ball_x], eax
        jge .left_ok
        mov [ebx + Ball_x], eax

.left_ok

.draw_and_next:
        ; Redraw ball
        push dword [g_ball_color]
        push ebx
        call draw_ball
        add esp, 8

.next_ball:
        add ebx, Ball__SIZE
        inc ecx
        cmp ecx, MAX_BALLS
        jl .for_each_ball

        popa
        leave
        ret
        %pop
