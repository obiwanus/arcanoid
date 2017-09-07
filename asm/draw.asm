; --------------------------------------------------------
segment .data
; --------------------------------------------------------
segment .bss
extern g_pixels, g_width, g_height

; --------------------------------------------------------
segment .text
global  draw_rect, draw_pixel

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
        pusha

        mov eax, [g_width]              ; eax to store offset
        mov ecx, [ebp + 12]
        mul ecx             ; eax = width * y
        add eax, [ebp + 8]              ; eax += x
        sal eax, 2                     ; each pixel 4 bytes
        mov ebx, [g_pixels]
        add ebx, eax                    ; ebx = &pixel

        mov eax, [ebp + 16]
        mov [ebx], eax                  ; *pixel = color

        popa
        leave
        ret
