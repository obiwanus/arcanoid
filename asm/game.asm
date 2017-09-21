%include 'base.inc'
%include 'game.inc'
%include 'vectors.inc'
; --------------------------------------------------------
segment .data align=16
g_xmm_sign32            dd      0x80000000, 0x80000000, 0x80000000, 0x80000000  ; must be aligned
g_level_initialised     dd      0
g_current_level         dd      0
g_wall_size             dd      __float32__(5.0)
const_bricks_per_row    dd      BRICKS_PER_ROW
const_brick_height      dd      20
; --------------------------------------------------------
segment .bss

; Export
global g_pixels, g_width, g_height, g_state, g_input
global g_ball_count, g_ball_color, g_falling_buffs
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
g_falling_buffs         resd    1
g_bullet_cooldown       resd    1
g_bullets_in_flight     resd    1
g_active_buffs          resd    Buff_Type__COUNT
g_levels                resd    1
g_balls                 resb    MAX_BALLS * Ball_size
g_bricks                resb    BRICKS_TOTAL
g_buffs                 resd    3 * MAX_BUFFS
g_bullets               resd    2 * MAX_BULLETS
g_bat                   resd    6

; --------------------------------------------------------
segment .text
global update_and_render, attach_to_bat
extern draw_rect, draw_pixel, draw_circle, draw_bat, draw_ball
extern v2_length, v2_lerp

; ========================================================
; update_and_render(
;       Pixel_Buffer *screen,
;       User_Input *input,
;       Level *levels)
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
        mov eax, [ebp + 16]
        mov [g_levels], eax

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

        call update_bat
        call update_balls
        call draw_bricks


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
        mov dword [g_bat + Bat.left],   100
        mov dword [g_bat + Bat.bottom], 20
        mov dword [g_bat + Bat.width],  DEFAULT_BAT_WIDTH
        mov dword [g_bat + Bat.height], 13
        mov dword [g_bat + Bat.color],  0x00FFFFFF
        mov dword [g_bat + Bat.can_shoot], FALSE

        ; Reset all balls
        mov ecx, MAX_BALLS
        mov edx, g_balls
.reset_balls:
        mov byte  [edx + Ball.active], FALSE
        mov byte  [edx + Ball.attached], FALSE
        mov dword [edx + Ball.radius], __float32__(8.0)
        mov dword [edx + Ball.speed + v2_x], __float32__(1.0)
        mov dword [edx + Ball.speed + v2_y], __float32__(-1.0)
        NORMALIZE [edx + Ball.speed]
        SCALE [edx + Ball.speed], START_BALL_SPEED
        add edx, Ball_size
        loop .reset_balls

        ; Activate and attach main ball
        mov dword [g_ball_count], 1
        mov dword [g_ball_color], 0x00FFFFFF
        mov byte [g_balls + Ball.active], TRUE
        mov byte [g_balls + Ball.attached], TRUE
        mov eax, [g_bat + Bat.width]
        sar eax, 1  ; divide by 2
        add eax, 5  ; attached_x = bat->width / 2 + 5
        mov dword [g_balls + Ball.attached_x], eax
        push dword g_balls      ; pointer to main ball
        call attach_to_bat
        add esp, 4

        mov eax, [g_balls + Ball.x]
        mov eax, [g_balls + Ball.y]
        mov eax, [g_balls + Ball.radius]

        ; Clean up all bricks
        mov ecx, BRICKS_TOTAL
.clean_up_brick:
        mov byte [g_bricks + ecx - 1], Brick_Empty
        loop .clean_up_brick

        ; Init new bricks
        mov edx, [g_levels]             ; pointer to levels
        mov eax, [g_current_level]      ; current level number
        mov edx, [edx + eax * 4]        ; pointer to level string
        mov ebx, 0                      ; brick_x
        mov ecx, 0                      ; brick_y

.init_brick:
        cmp byte [edx], 0
        je .init_brick_end              ; while (*b != '\0')

        cmp byte [edx], 0x0A            ; \n
        je .init_brick_newline
        mov eax, ecx
        imul eax, BRICKS_PER_ROW
        add eax, ebx                    ; eax = brick_y * BRICKS_PER_ROW + brick_x
        inc ebx                         ; brick_x++
        cmp byte [edx], 'x'
        jne .not_x
        mov byte [g_bricks + eax], Brick_Normal
        jmp .init_brick_next
.not_x:
        cmp byte [edx], 'u'
        jne .not_u
        mov byte [g_bricks + eax], Brick_Unbreakable
        jmp .init_brick_next
.not_u:
        cmp byte [edx], 's'
        jne .not_s
        mov byte [g_bricks + eax], Brick_Strong
        jmp .init_brick_next
.not_s:
        ; nothing
        mov byte [g_bricks + eax], Brick_Empty
        jmp .init_brick_next
.init_brick_newline:
        mov ebx, 0                      ; brick_x = 0
        inc ecx                         ; brick_y++
.init_brick_next:
        inc edx
        jmp .init_brick
.init_brick_end:

        ; TODO: finish level init
        ; // Remove all bullets
        ; state->bullet_cooldown = 0;
        ; state->bullets_in_flight = 0;
        ; for (int i = 0; i < MAX_BULLETS; ++i) {
        ;   state->bullets[i] = V2(-1, -1);  // negative means inactive
        ; }

        ; // Clean up all buffs
        ; state->falling_buffs = 0;
        ; for (int i = 0; i < MAX_BUFFS; ++i) {
        ;   state->buffs[i].type = Buff_Inactive;
        ; }
        ; for (int i = 0; i < Buff_Type__COUNT; ++i) {
        ;   state->active_buffs[i] = 0;
        ; }

        ; Mark as initialised
        mov dword [g_level_initialised], TRUE

        popa
        leave
        ret


; ========================================================
; attach_to_g_bat + Bat.Ball*ball)
attach_to_bat:
        %push
        %stacksize flat
        %arg ball:dword

        push ebp
        mov ebp, esp
        pusha

        mov eax, [ball]     ; took some time to figure out
        mov ebx, [g_bat + Bat.left]
        add ebx, [eax + Ball.attached_x]
        mov dword [eax + Ball.x], ebx
        fild dword [eax + Ball.x]
        fstp dword [eax + Ball.x]       ; convert to float and store

        fld dword [eax + Ball.radius]
        fistp dword [eax + Ball.radius] ; tmp convert to int
        mov ebx, [eax + Ball.radius]
        fild dword [eax + Ball.radius]
        fstp dword [eax + Ball.radius]  ; convert back to float
        sar ebx, 1
        add ebx, [g_bat + Bat.height]
        add ebx, [g_bat + Bat.bottom]
        add ebx, 5
        sub ebx, [g_height]
        neg ebx
        mov [eax + Ball.y], ebx
        fild dword [eax + Ball.y]
        fstp dword [eax + Ball.y]

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
        ; TODO: wall size
        mov dword [max_left], 5
        mov eax, [g_width]
        sub eax, 5
        sub eax, [g_bat + Bat.width]
        mov [max_right], eax

        ; Move bat
        mov eax, [g_bat + Bat.left]

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
        mov [g_bat + Bat.left], eax

        ; Redraw bat
        push dword [g_bat + Bat.color]
        call draw_bat
        add esp, 4

        popa
        leave
        ret
        %pop


; ========================================================
; update_balls()
segment .data
const_bat_margin        dd      __float32__(2.0)        ; must be 2.0
const_vector_up         dd      __float32__(0.0), __float32__(-1.0)
const_vector_left       dd      __float32__(-0.832050), __float32__(-0.554700)
const_vector_right      dd      __float32__( 0.832050), __float32__(-0.554700)

segment .text
update_balls:
        %push
        %stacksize flat
        %assign %$localsize 0
        %local new_direction:qword
        push ebp
        mov ebp, esp
        sub esp, 8
        pusha

        mov ecx, 0              ; ball index
        mov ebx, g_balls        ; ball ptr
.for_each_ball:
        cmp byte [ebx + Ball.active], TRUE
        jne .next_ball   ; continue

        ; Release
        button_is_down IB_space
        jne .skip_release
        mov byte [ebx + Ball.attached], FALSE
.skip_release:

        ; Erase ball
        push dword BG_COLOR
        push ebx
        call draw_ball
        add esp, 8

        cmp byte [ebx + Ball.attached], TRUE
        jne .not_attached
        push ebx
        call attach_to_bat
        add esp, 4
        jmp .draw_and_next
.not_attached:

        ; Move ball
        movss xmm0, [ebx + Ball.x]
        addss xmm0, [ebx + Ball.speed + v2_x]

        movss xmm1, [ebx + Ball.y]
        addss xmm1, [ebx + Ball.speed + v2_y]

        ; Get screen borders
        ; xmm3 - left, top
        ; xmm4 - right
        ; xmm5 - bottom

        movss xmm3, [g_wall_size]
        addss xmm3, [ebx + Ball.radius]

        cvtsi2ss xmm4, dword [g_width]
        subss xmm4, [g_wall_size]
        subss xmm4, [ebx + Ball.radius]

        cvtsi2ss xmm5, dword [g_height]
        subss xmm5, [g_wall_size]
        subss xmm5, [ebx + Ball.radius]

        ; Collision with screen borders
        ; (xmm0 is ball->x, xmm1 is ball->y)
        ucomiss xmm0, xmm3      ; ball->x < left ?
        jnb .left_ok
        movss xmm0, xmm3
        movss xmm2, dword [ebx + Ball.speed + v2_x]
        xorps xmm2, [g_xmm_sign32]
        movss dword [ebx + Ball.speed + v2_x], xmm2     ; speed.x = -speed.x
.left_ok:
        ucomiss xmm0, xmm4      ; ball->x > right ?
        jna .right_ok
        movss xmm0, xmm4
        movss xmm2, dword [ebx + Ball.speed + v2_x]
        xorps xmm2, [g_xmm_sign32]
        movss dword [ebx + Ball.speed + v2_x], xmm2     ; speed.x = -speed.x
.right_ok:
        ucomiss xmm1, xmm3      ; ball->y < top ?
        jnb .top_ok
        movss xmm1, xmm3
        movss xmm2, dword [ebx + Ball.speed + v2_y]
        xorps xmm2, [g_xmm_sign32]
        movss dword [ebx + Ball.speed + v2_y], xmm2     ; speed.y = -speed.y
.top_ok:
        ucomiss xmm1, xmm5      ; ball->y > bottom ?
        jna .bottom_ok
        ; TODO: destroy ball, check buff
        movss xmm1, xmm5
        movss xmm2, dword [ebx + Ball.speed + v2_y]
        xorps xmm2, [g_xmm_sign32]
        movss dword [ebx + Ball.speed + v2_y], xmm2     ; speed.y = -speed.y
.bottom_ok:

        ; Collision with the bat
        ; xmm3 - left
        ; xmm4 - right
        ; xmm5 - bottom
        ; xmm6 - top
        ; xmm7 - middle

        cvtsi2ss xmm3, [g_bat + Bat.left]
        subss xmm3, [ebx + Ball.radius]
        addss xmm3, [const_bat_margin]

        cvtsi2ss xmm4, [g_bat + Bat.left]
        cvtsi2ss xmm2, [g_bat + Bat.width]
        addss xmm4, xmm2
        addss xmm4, [ebx + Ball.radius]
        subss xmm4, [const_bat_margin]

        cvtsi2ss xmm5, [g_height]
        cvtsi2ss xmm2, [g_bat + Bat.bottom]
        subss xmm5, xmm2

        movss xmm6, xmm5
        cvtsi2ss xmm2, [g_bat + Bat.height]
        subss xmm6, xmm2
        subss xmm6, [ebx + Ball.radius]

        movss xmm7, xmm3
        addss xmm7, xmm4
        divss xmm7, [const_bat_margin]      ; just so happens it's 2.0

        ucomiss xmm0, xmm3              ; ball->x < left ?
        jb .no_bat_collision
        ucomiss xmm0, xmm4              ; ball->x > right ?
        ja .no_bat_collision
        ucomiss xmm1, xmm6              ; ball->y < top ?
        jb .no_bat_collision
        ucomiss xmm1, xmm5              ; ball->y > bottom ?
        ja .no_bat_collision

        ; Collision!
        movss xmm1, xmm6                ; ball->y = top
        movss xmm2, dword [ebx + Ball.speed + v2_y]
        xorps xmm2, [g_xmm_sign32]
        movss dword [ebx + Ball.speed + v2_y], xmm2     ; speed.y = -speed.y

        ; top and bottom no longer needed, so xmm5 and xmm6 are free

        ; Get reflection angle (calculate new direction)
        ; t = xmm2
        ucomiss xmm0, xmm7              ; ball->x < middle ?
        ja .right_half
.left_half:
        movss xmm2, xmm7
        subss xmm2, xmm0                ; xmm2 = middle - ball->x
        movss xmm5, xmm7
        subss xmm5, xmm3                ; xmm5 = middle - left
        divss xmm2, xmm5                ; t = (middle-ball->x) / (middle-left)

        sub esp, 8
        lea eax, [new_direction]
        mov dword [esp + 4], eax                ; &new_direction
        movss dword [esp], xmm2                 ; t
        push dword const_vector_left
        push dword const_vector_up
        call v2_lerp
        add esp, 16
        jmp .new_speed
.right_half:
        movss xmm2, xmm0
        subss xmm2, xmm7                ; xmm2 = ball->x - middle
        movss xmm5, xmm4
        subss xmm5, xmm7                ; xmm5 = right - middle
        divss xmm2, xmm5                ; t = (ball->x - middle) / (right - middle)

        sub esp, 8
        lea eax, [new_direction]
        mov dword [esp + 4], eax                ; &new_direction
        movss dword [esp], xmm2                 ; t
        push dword const_vector_right
        push dword const_vector_up
        call v2_lerp
        add esp, 16

.new_speed:
        NORMALIZE [new_direction]
        LENGTH [ebx + Ball.speed]       ; result in ST0
        sub esp, 4
        fstp dword [esp]
        mov eax, [esp]
        add esp, 4
        SCALE [new_direction], eax

        ; Set new speed
        mov eax, [new_direction + v2_x]
        mov [ebx + Ball.speed + v2_x], eax
        mov eax, [new_direction + v2_y]
        mov [ebx + Ball.speed + v2_y], eax

.no_bat_collision:

        ; Apply x and y
        movss [ebx + Ball.x], xmm0
        movss [ebx + Ball.y], xmm1

        ; Collision with the bricks
        push ebx
        call collide_with_bricks
        add esp, 4

.draw_and_next:
        ; Redraw ball
        push dword [g_ball_color]
        push ebx
        call draw_ball
        add esp, 8

.next_ball:
        add ebx, Ball_size
        inc ecx
        cmp ecx, MAX_BALLS
        jl .for_each_ball

        popa
        leave
        ret
        %pop


; ========================================================
; collide_with_bricks(Ball *ball)
collide_with_bricks:
        %push
        %stacksize flat
        %assign %$localsize 0
        %local brick_rect:oword, left:dword, right:dword, top:dword, bottom:dword
        push ebp
        mov ebp, esp
        sub esp, 24
        pusha

        ; Brute force - check every brick
        mov ecx, 0
.for_bricks:
        cmp byte [g_bricks + ecx], Brick_Empty
        je .next_brick


.next_brick:
        inc ecx
        cmp ecx, BRICKS_TOTAL
        jl .for_bricks
.break:

        popa
        leave
        ret
        %pop


; ========================================================
; draw_bricks()
draw_bricks:
        %push
        %stacksize flat
        %assign %$localsize 0
        %local brick_rect:oword
        push ebp
        mov ebp, esp
        sub esp, 12
        pusha

        ; ; Get brick width
        ; mov eax, [g_width]
        ; sub eax, WALL_SIZE
        ; sub eax, WALL_SIZE
        ; mov edx, 0
        ; idiv dword [const_bricks_per_row]
        ; mov [brick_width], eax

        mov ecx, 0
.draw_brick:
        cmp byte [g_bricks + ecx], Brick_Empty
        je .next_brick

        ; Get brick rect
        lea eax, [brick_rect]

        ; ; Get brick x,y
        ; mov edx, 0
        ; mov eax, ecx
        ; idiv dword [const_bricks_per_row]
        ; mov dword [brick_x], edx
        ; mov dword [brick_y], eax
        ; mov eax, [brick_width]
        ; imul eax, [brick_x]
        ; add eax, WALL_SIZE
        ; mov [brick_x], eax      ; store final brick_x
        ; mov eax, [const_brick_height]
        ; imul eax, [brick_y]
        ; add eax, WALL_SIZE
        ; mov [brick_y], eax      ; store final brick_y

        ; Get color
        mov eax, 0x00BBBBBB
        cmp byte [g_bricks + ecx], Brick_Strong
        jne .not_strong
        mov eax, 0x00999999
.not_strong:
        cmp byte [g_bricks + ecx], Brick_Unbreakable
        jne .not_unbreakable
        mov eax, 0x00AA8888
.not_unbreakable:

        ; ; Draw
        ; push eax
        ; push dword [const_brick_height]
        ; push dword [brick_width]
        ; push dword [brick_y]
        ; push dword [brick_x]
        ; call draw_rect
        ; add esp, 20

.next_brick:
        inc ecx
        cmp ecx, BRICKS_TOTAL
        jl .draw_brick

        popa
        leave
        ret
        %pop
