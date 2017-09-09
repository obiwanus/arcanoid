; --------------------------------------------------------
segment .data
; --------------------------------------------------------
segment .bss
global g_pixels, g_width, g_height, g_state, g_input
g_pixels        resd    1
g_width         resd    1
g_height        resd    1
g_state         resd    1
g_input         resd    1

; --------------------------------------------------------
segment .text
global  update_and_render
extern  draw_rect, draw_pixel

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
        mov [g_state], eax
        mov eax, [ebp + 16]
        mov [g_input], eax

        push dword 0x0066AACC           ; color
        push dword 800                  ; height
        push dword 600                  ; width
        push dword -20                  ; top
        push dword -10                  ; left
        call draw_rect
        add esp, 20                     ; remove parameters

; END ----------------------------------------------------

program_end:
        popa
        mov eax, 1                      ; return back to C
        leave
        ret

