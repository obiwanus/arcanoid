%include 'game.inc'
; --------------------------------------------------------
segment .data
g_level_initialised     dd      0
; --------------------------------------------------------
segment .bss
global g_pixels, g_width, g_height, g_state, g_input
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
g_balls                 resd    8 * MAX_BALLS  ; 8 dwords is struct size
g_bricks                resd    BRICKS_TOTAL
g_buffs                 resd    3 * MAX_BUFFS
g_bullets               resd    2 * MAX_BULLETS

; --------------------------------------------------------
segment .text
global  update_and_render
extern  draw_rect, draw_pixel, draw_circle

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

        mov eax, [g_level_initialised]
        not eax




        push dword 0x0066AACC           ; color
        push dword 100                  ; height
        push dword 150                  ; width
        push dword 100                  ; top
        push dword 100                  ; left
        call draw_rect
        add esp, 20                     ; remove parameters

        push dword 0x00AA66CC           ; color
        push dword 20                   ; radius
        push dword 300                  ; Y
        push dword 100                  ; X
        ; convert params to float
        fild dword [esp + 8]            ; load radius
        fild dword [esp + 4]            ; load Y
        fild dword [esp]                ; load X
        fstp dword [esp]
        fstp dword [esp + 4]
        fstp dword [esp + 8]
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



; init_level()
init_level:
        mov ebp, esp
        push esp
        pusha



        popa
        leave
        ret
