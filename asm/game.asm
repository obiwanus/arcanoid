%include 'game.inc'
%include 'vectors.inc'
; --------------------------------------------------------
segment .data
g_level_initialised     dd      0
; --------------------------------------------------------
segment .bss

; Export
global g_pixels, g_width, g_height, g_state, g_input
global g_ball_count, g_current_level, g_falling_buffs
global g_bullet_cooldown, g_bullets_in_flight
global g_active_buffs, g_levels, g_balls, g_bricks
global g_buffs, g_bullets, g_bat

g_pixels        resd    1
g_width         resd    1
g_height        resd    1
g_state         resd    1
g_input         resd    1

g_ball_count            resd    1
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
global  update_and_render
extern  draw_rect, draw_pixel, draw_circle

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
        push dword 0x00662211
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


        ; Mark as initialised
        mov dword [g_level_initialised], TRUE

        popa
        leave
        ret
