%include 'base.inc'
%include 'external.inc'
%include 'game.inc'

; --------------------------------------------------------
segment .text
global  draw_rect, draw_pixel, draw_circle, draw_bat

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

        ; Bounds check
        xor ebx, ebx                    ; ebx = 0
        cmp dword [ebp + 8], 0          ; left < 0 ?
        setge bl                        ; ebx = (left >= 0) ? 1 : 0
        neg ebx                         ; ebx = (left >= 0) ? 0xFF.. : 0
        and [ebp + 8], ebx              ; left = (left >= 0) ? left : 0

        xor ebx, ebx                    ; ebx = 0
        cmp dword [ebp + 12], 0         ; top < 0 ?
        setge bl                        ; ebx = (top >= 0) ? 1 : 0
        neg ebx                         ; ebx = (top >= 0) ? 0xFF.. : 0
        and [ebp + 12], ebx             ; top = (top >= 0) ? top : 0

        xor ebx, ebx
        mov ecx, [g_width]
        cmp [ebp - 4], ecx              ; right < screen->width ?
        setl bl                         ; ebx = (right < width) ? 1 : 0
        neg ebx                         ; ebx = (right < width) ? 0xFF.. : 0
        and [ebp - 4], ebx              ; right = (right < width) ? right : 0
        not ebx                         ; ebx = (right < width) ? 0 : 0xFF..
        and ecx, ebx                    ; ecx = (right < width) ? 0 : width
        add [ebp - 4], ecx              ; right = (right < width) ? right : width

        xor ebx, ebx
        mov ecx, [g_height]
        cmp [ebp - 8], ecx              ; bottom < screen->height ?
        setl bl                         ; ebx = (bottom < height) ? 1 : 0
        neg ebx                         ; ebx = (bottom < height) ? 0xFF.. : 0
        and [ebp - 8], ebx              ; bottom = (bottom < height) ? bottom : 0
        not ebx                         ; ebx = (bottom < height) ? 0 : 0xFF..
        and ecx, ebx                    ; ecx = (bottom < height) ? 0 : height
        add [ebp - 8], ecx              ; bottom = (bottom < height) ? bottom : height

        ; Drawing loop
        mov eax, [ebp + 24]             ; color
        mov edx, [g_pixels]             ; base pixel address
        mov ebx, [ebp + 12]             ; ebx (y) = top
.for_y:
        mov ecx, [ebp + 8]              ; ecx (x) = left
        mov edi, [g_width]              ; edi = current pixel offset
        imul edi, ebx
        add edi, ecx
.for_x:
        ; Draw pixel
        mov [edx + 4 * edi], eax

        inc edi
        inc ecx
        cmp ecx, [ebp - 4]              ; x < right ?
        jl .for_x
        inc ebx
        cmp ebx, [ebp - 8]              ; y < bottom ?
        jl .for_y

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


; ========================================================
; draw_circle(float X, float Y, float radius, u32 color)
draw_circle:
        %push
        %stacksize flat
        %arg X:dword, Y:dword, radius:dword, color:dword
        %assign %$localsize 0
        %local left:dword, right:dword, top:dword, bottom:dword, x:dword, y:dword
        push ebp
        mov ebp, esp
        sub esp, 24
        pusha

        fld dword [X]
        fsub dword [radius]             ; st0 = X - radius
        fstp dword [left]               ; left = X - radius

        fld dword [X]
        fadd dword [radius]             ; st0 = X + radius
        fstp dword [right]              ; right = X + radius

        fld dword [Y]
        fsub dword [radius]             ; st0 = Y - radius
        fstp dword [top]                ; top = Y - radius

        fld dword [Y]
        fadd dword [radius]             ; st0 = Y + radius
        fstp dword [bottom]             ; bottom = Y + radius

        ; TODO: bounds check


        ; Drawing loop
        fld dword [top]
        fstp dword [y]
.for_y:
        fld dword [left]
        fstp dword [x]
.for_x:
        fld dword [x]
        fsub dword [X]
        fmul st0                        ; st0 = (x - X) ^ 2
        fld dword [y]
        fsub dword [Y]
        fmul st0                        ; st0 = (y - Y) ^ 2
        fadd st1                        ; st0 = sq_distance
        ffree st1
        fld dword [radius]
        fmul st0                        ; st0 = radius * radius
        fcompp                          ; sq_radius > sq_distance ?
        fstsw ax
        sahf
        jna .skip_pixel
        ; draw pixel
        push dword [color]
        push dword 0                    ; placeholder for y
        push dword 0                    ; placeholder for x
        fld dword [x]
        fistp dword [esp]               ; fill in x
        fld dword [y]
        fistp dword [esp + 4]           ; fill in y
        call draw_pixel
        add esp, 12
.skip_pixel:
        fld dword [x]
        fld1
        faddp st1                       ; st0 = x + 1
        fst dword [x]                   ; x = x + 1
        fcomp dword [right]             ; x <= right ?
        fstsw ax
        sahf
        jna .for_x
        fld dword [y]
        fld1
        faddp st1
        fst dword [y]                   ; increment y
        fcomp dword [bottom]            ; y <= bottom ?
        fstsw ax
        sahf
        jna .for_y

        popa
        leave
        ret
        %pop


; ========================================================
; draw_bat(u32 color)
draw_bat:
        %push
        %stacksize flat
        %arg color:dword
        push ebp
        mov ebp, esp
        pusha

        mov eax, [color]
        push dword [color]
        push dword [g_bat + Bat_height]
        push dword [g_bat + Bat_width]
        mov eax, [g_height]
        sub eax, [g_bat + Bat_bottom]
        sub eax, [g_bat + Bat_height]
        push eax
        push dword [g_bat + Bat_left]
        call draw_rect
        add esp, 20

        popa
        leave
        ret
        %pop
