; --------------------------------------------------------
segment .data
; --------------------------------------------------------
segment .bss
extern g_pixels, g_width, g_height

; --------------------------------------------------------
segment .text
global  draw_rect

; ========================================================
; draw_rect(Rect rect, u32 color)
draw_rect:
        enter   0, 0




        leave
        ret


; ========================================================
; draw_pixel(int x, int y, u32 color)
draw_pixel:
        enter   0, 0



        leave
        ret
