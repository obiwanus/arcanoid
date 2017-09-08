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

        ; Init local vars
        mov eax, [ebp + 8]              ; eax = left
        add eax, [ebp + 16]             ; eax = left + width
        mov [ebp - 4], eax              ; right

        mov eax, [ebp + 12]             ; eax = top
        add eax, [ebp + 20]             ; eax = top + height
        mov [ebp - 8], eax              ; bottom

        ; Bounds check (xxx: is there an easy way to avoid branches?)
        cmp dword [ebp + 8], 0          ; left < 0 ?
        setge eax                       ; ebx = (left >= 0) ? 1 : 0
        neg eax                         ; ebx = (left >= 0) ? 0xFF.. : 0
        and [ebp + 8], eax              ; left = (left >= 0) ? left : 0
        ; cmp dword [ebp + 12], 0         ;


        ; Drawing loop
        mov eax, [ebp + 24]             ; color
        mov edx, [g_pixels]             ; base pixel address
        mov ebx, [ebp + 12]             ; ebx (y) = top
draw_rect_for_y:
        mov ecx, [ebp + 8]              ; ecx (x) = left
        mov edi, [g_width]              ; edi = current pixel offset
        imul edi, ebx
        add edi, ecx
draw_rect_for_x:
        ; Draw pixel
        mov [edx + 4 * edi], eax

        inc edi
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

        mov ecx, [g_width]              ; ecx to store pixel offset
        imul ecx, [ebp + 12]            ; ecx = width * y
        add ecx, [ebp + 8]              ; ecx += x

        mov eax, [ebp + 16]             ; eax is color
        mov ebx, [g_pixels]             ; base pixel pointer
        mov [ebx + 4 * ecx], eax        ; *pixel = color

        popa
        mov esp, ebp
        pop ebp
        ret
