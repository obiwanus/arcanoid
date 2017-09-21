%include 'base.inc'
%include 'game.inc'
%include 'vectors.inc'
; --------------------------------------------------------
segment .data align=16
g_xmm_sign32            dd      0x80000000, 0x80000000, 0x80000000, 0x80000000  ; must be aligned
g_xmm_abs32             dd      0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF  ; must be aligned
g_level_initialised     dd      0
g_current_level         dd      0
g_wall_size             dd      __float32__(5.0)
const_bricks_per_row    dd      BRICKS_PER_ROW
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

        ; Update
        call update_bat
        call update_balls
        call draw_bricks
        call update_buffs

        call check_level_complete
        cmp eax, TRUE
        jne .level_not_complete
        ; Next level
        inc dword [g_current_level]
        mov dword [g_level_initialised], FALSE
        cmp dword [g_current_level], MAX_LEVELS
        jnb program_end
.level_not_complete:

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
        mov dword [edx + Ball.speed + v2.x], __float32__(1.0)
        mov dword [edx + Ball.speed + v2.y], __float32__(-1.0)
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
        addss xmm0, [ebx + Ball.speed + v2.x]

        movss xmm1, [ebx + Ball.y]
        addss xmm1, [ebx + Ball.speed + v2.y]

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
        movss xmm2, dword [ebx + Ball.speed + v2.x]
        xorps xmm2, [g_xmm_sign32]
        movss dword [ebx + Ball.speed + v2.x], xmm2     ; speed.x = -speed.x
.left_ok:
        ucomiss xmm0, xmm4      ; ball->x > right ?
        jna .right_ok
        movss xmm0, xmm4
        movss xmm2, dword [ebx + Ball.speed + v2.x]
        xorps xmm2, [g_xmm_sign32]
        movss dword [ebx + Ball.speed + v2.x], xmm2     ; speed.x = -speed.x
.right_ok:
        ucomiss xmm1, xmm3      ; ball->y < top ?
        jnb .top_ok
        movss xmm1, xmm3
        movss xmm2, dword [ebx + Ball.speed + v2.y]
        xorps xmm2, [g_xmm_sign32]
        movss dword [ebx + Ball.speed + v2.y], xmm2     ; speed.y = -speed.y
.top_ok:
        ucomiss xmm1, xmm5      ; ball->y > bottom ?
        jna .bottom_ok
        ; TODO: destroy ball, check buff
        movss xmm1, xmm5
        movss xmm2, dword [ebx + Ball.speed + v2.y]
        xorps xmm2, [g_xmm_sign32]
        movss dword [ebx + Ball.speed + v2.y], xmm2     ; speed.y = -speed.y
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
        movss xmm2, dword [ebx + Ball.speed + v2.y]
        xorps xmm2, [g_xmm_sign32]
        movss dword [ebx + Ball.speed + v2.y], xmm2     ; speed.y = -speed.y

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
        mov eax, [new_direction + v2.x]
        mov [ebx + Ball.speed + v2.x], eax
        mov eax, [new_direction + v2.y]
        mov [ebx + Ball.speed + v2.y], eax

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
        %arg ball:dword
        %assign %$localsize 0
        %local brick_rect:oword, left:dword, right:dword, top:dword, bottom:dword
        push ebp
        mov ebp, esp
        sub esp, 24
        pusha

        ; Get pointers - must not be modified
        lea ebx, [brick_rect]
        mov edx, [ball]

        ; Brute force - check every brick
        mov ecx, 0
.for_bricks:
        cmp byte [g_bricks + ecx], Brick_Empty
        je .next_brick

        ; Get brick rect
        push ebx
        push ecx
        call get_brick_rect
        add esp, 8

        ; Get collision rect (in float)
        cvtsi2ss xmm0, [ebx + Rect.left]        ; left
        subss xmm0, [edx + Ball.radius]
        cvtsi2ss xmm1, [ebx + Rect.left]        ; right
        cvtsi2ss xmm2, [ebx + Rect.width]
        addss xmm1, xmm2
        addss xmm1, [edx + Ball.radius]
        cvtsi2ss xmm2, [ebx + Rect.top]         ; top
        subss xmm2, [edx + Ball.radius]
        cvtsi2ss xmm3, [ebx + Rect.top]         ; bottom
        cvtsi2ss xmm4, [ebx + Rect.height]
        addss xmm3, xmm4
        addss xmm3, [edx + Ball.radius]

        ; Check collision
        ucomiss xmm0, [edx + Ball.x]
        ja .next_brick
        ucomiss xmm1, [edx + Ball.x]
        jb .next_brick
        ucomiss xmm2, [edx + Ball.y]
        ja .next_brick
        ucomiss xmm3, [edx + Ball.y]
        jb .next_brick

        ; Hit brick!
        dec byte [g_bricks + ecx]
        cmp byte [g_bricks + ecx], 0
        jne .end_hit_brick
        ; Erase
        push dword BG_COLOR
        push dword [ebx + Rect.height]
        push dword [ebx + Rect.width]
        push dword [ebx + Rect.top]
        push dword [ebx + Rect.left]
        call draw_rect
        add esp, 20
.end_hit_brick:

        jmp .break

        ; Bounce (TODO: powerball)
        subss xmm0, [edx + Ball.x]      ; ldist
        andps xmm0, [g_xmm_abs32]
        subss xmm1, [edx + Ball.x]      ; rdist
        andps xmm1, [g_xmm_abs32]
        subss xmm2, [edx + Ball.y]      ; tdist
        andps xmm2, [g_xmm_abs32]
        subss xmm3, [edx + Ball.y]      ; bdist
        andps xmm3, [g_xmm_abs32]

        movss xmm4, [edx + Ball.speed + v2.x]   ; abs ball speed x
        andps xmm4, [g_xmm_abs32]
        movss xmm5, [edx + Ball.speed + v2.y]   ; abs ball speed y
        andps xmm5, [g_xmm_abs32]

        ucomiss xmm0, xmm1      ; ldist <= rdist
        ja .not_left
        ucomiss xmm0, xmm2      ; ldist <= tdist
        ja .not_left
        ucomiss xmm0, xmm3      ; ldist <= bdist
        ja .not_left
        ; Bounce left
        xorps xmm4, [g_xmm_sign32]
        movss [edx + Ball.speed + v2.x], xmm4   ; speed.x = -abs(speed.x)
        jmp .bounce_end
.not_left:

        ucomiss xmm1, xmm0      ; rdist <= ldist
        ja .not_right
        ucomiss xmm1, xmm2      ; rdist <= tdist
        ja .not_right
        ucomiss xmm1, xmm3      ; rdist <= bdist
        ja .not_right
        ; Bounce right
        movss [edx + Ball.speed + v2.x], xmm4   ; speed.x = abs(speed.x)
        jmp .bounce_end
.not_right:

        ucomiss xmm2, xmm1      ; tdist <= rdist
        ja .not_top
        ucomiss xmm2, xmm0      ; tdist <= ldist
        ja .not_top
        ucomiss xmm2, xmm3      ; tdist <= bdist
        ja .not_top
        ; Bounce top
        xorps xmm5, [g_xmm_sign32]
        movss [edx + Ball.speed + v2.y], xmm5   ; speed.y = -abs(speed.y)
        jmp .bounce_end
.not_top:

        ucomiss xmm3, xmm0      ; bdist <= ldist
        ja .not_bottom
        ucomiss xmm3, xmm1      ; bdist <= rdist
        ja .not_bottom
        ucomiss xmm3, xmm2      ; bdist <= tdist
        ja .not_bottom
        ; Bounce bottom
        movss [edx + Ball.speed + v2.y], xmm5   ; speed.y = -abs(speed.y)
        jmp .bounce_end
.not_bottom:

.bounce_end:
        jmp .break

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
; get_brick_rect(int num, Rect *brick_rect)
get_brick_rect:
        %push
        %stacksize flat
        %arg num:dword, brick_rect:dword
        %assign %$localsize 0
        %local x:dword, y:dword
        push ebp
        mov ebp, esp
        sub esp, 12
        pusha

        ; Get pointer to result
        mov ebx, [brick_rect]

        ; Get brick width
        mov eax, [g_width]
        sub eax, WALL_SIZE
        sub eax, WALL_SIZE
        mov edx, 0
        idiv dword [const_bricks_per_row]
        mov [ebx + Rect.width], eax     ; Store width

        mov dword [ebx + Rect.height], BRICK_HEIGHT   ; Store height

        ; Get brick x,y
        mov edx, 0
        mov eax, [num]
        idiv dword [const_bricks_per_row]
        mov dword [x], edx
        mov dword [y], eax
        mov eax, [ebx + Rect.width]
        imul eax, [x]
        add eax, WALL_SIZE
        mov [ebx + Rect.left], eax      ; store final brick x
        mov eax, BRICK_HEIGHT
        imul eax, [y]
        add eax, WALL_SIZE
        mov [ebx + Rect.top], eax       ; store final brick y

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

        mov ecx, 0
.draw_brick:
        cmp byte [g_bricks + ecx], Brick_Empty
        je .next_brick

        ; Get brick rect
        lea eax, [brick_rect]
        push eax        ; &brick_rect
        push ecx        ; num
        call get_brick_rect
        add esp, 8

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

        ; Draw
        lea ebx, [brick_rect]
        push eax
        push dword [ebx + Rect.height]
        push dword [ebx + Rect.width]
        push dword [ebx + Rect.top]
        push dword [ebx + Rect.left]
        call draw_rect
        add esp, 20

.next_brick:
        inc ecx
        cmp ecx, BRICKS_TOTAL
        jl .draw_brick

        popa
        leave
        ret
        %pop


; ========================================================
; check_level_complete() -> bool
check_level_complete:
        %push
        %stacksize flat
        %assign %$localsize 0
        %local complete:dword
        push ebp
        mov ebp, esp
        sub esp, 4
        pusha

        mov dword [complete], FALSE

        mov ecx, BRICKS_TOTAL - 1
.for_bricks:
        cmp byte [g_bricks + ecx], Brick_Empty
        jne .return     ; return FALSE
        loop .for_bricks

        mov dword [complete], TRUE
.return:
        popa
        mov eax, [complete]
        leave
        ret
        %pop


; ========================================================
; update_buffs()
update_buffs:
        %push
        %stacksize flat
        ; %assign %$localsize 0
        ; %local complete:dword
        push ebp
        mov ebp, esp
        sub esp, 4
        pusha

        ; Decrement all buffs
        mov ecx, Buff_Type__COUNT - 1
.decrement_buffs:
        cmp dword [g_active_buffs + ecx], 0
        jna .decrement_next
        dec dword [g_active_buffs + ecx]
.decrement_next:
        loop .decrement_buffs

        ; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        TODO: create buffs and update them
        ; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

        popa
        leave
        ret
        %pop
