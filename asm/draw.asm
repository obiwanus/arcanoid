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
        push ebp
        mov ebp, esp
        sub esp, 8                      ; 2 local vars
        pusha

        mov eax, [ebp + 8]              ; eax = left
        add eax, [ebp + 16]             ; eax = left + width
        mov [ebp - 4], eax              ; right

        mov eax, [ebp + 12]             ; eax = top
        add eax, [ebp + 20]             ; eax = top + height
        mov [ebp - 8], eax              ; bottom

        ; TODO: bounds check

        mov ebx, [ebp + 12]             ; ebx (y) = top
draw_rect_for_y:
        mov ecx, [ebp + 8]              ; ecx (x) = left
draw_rect_for_x:
        push dword [ebp + 24]           ; color
        push ebx                        ; y
        push ecx                        ; x
        call draw_pixel
        add esp, 12

        inc ecx
        cmp ecx, [ebp - 4]              ; x < right ?
        jl draw_rect_for_x
        inc ebx
        cmp ebx, [ebp - 8]              ; y < bottom ?
        jl draw_rect_for_y

        popa
        mov esp, ebp
        pop ebp
        ret


; ========================================================
; draw_pixel(int x, int y, u32 color)
draw_pixel:
        push ebp
        mov ebp, esp
        pusha

        mov eax, [g_width]              ; eax to store offset
        mul dword [ebp + 12]            ; eax = width * y
        add eax, [ebp + 8]              ; eax += x
        sal eax, 2                      ; each pixel 4 bytes
        mov ebx, [g_pixels]
        add ebx, eax                    ; ebx = &pixel

        mov eax, [ebp + 16]
        mov [ebx], eax                  ; *pixel = color

        popa
        mov esp, ebp
        pop ebp
        ret
