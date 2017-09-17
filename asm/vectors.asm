%include 'base.inc'
%include 'game.inc'
%include 'external.inc'

segment .text
global v2_length, v2_lerp

; ========================================================
; float v2_length(v2 *vector)
v2_length:
        push ebp
        mov ebp, esp
        pusha

        mov eax, [ebp + 8]              ; load pointer to v2
        fld dword [eax + v2_y]
        fmul st0
        fld dword [eax + v2_x]
        fmul st0
        faddp
        fsqrt

        popa
        leave
        ret


; ========================================================
; void v2_lerp(v2 *vector1, v2 *vector2, float t, v2 *result)
v2_lerp:
        %push
        %stacksize flat
        %arg a:dword, b:dword, t:dword, result:dword
        ; %assign %$localsize 0
        push ebp
        mov ebp, esp
        sub esp, 16
        pusha

        fld dword [t]
        ftst                    ; t < 0 ?
        fstsw ax
        sahf
        jnb .t_left_ok
        fldz
        fstp dword [t]          ; t = 0
        jmp .t_ok
.t_left_ok:
        fld1
        fcom st1                ; 1.0 < t ?
        fstsw ax
        sahf
        jnb .t_ok
        fstp dword [t]          ; t = 1.0
.t_ok:

        ; Load pointers to vectors
        mov ebx, [a]
        mov ecx, [b]
        mov edx, [result]

        fld dword [ecx + v2_x]
        fld dword [ebx + v2_x]
        fsubp st1               ; st0 = b.x - a.x
        fld dword [t]
        fmulp st1               ; st0 = t * (b.x - a.x)
        fld dword [ebx + v2_x]
        faddp st1               ; st0 = a.x + t * (b.x - a.x)
        fstp dword [edx + v2_x]

        fld dword [ecx + v2_y]
        fld dword [ebx + v2_y]
        fsubp st1               ; st0 = b.y - a.y
        fld dword [t]
        fmulp st1               ; st0 = t * (b.y - a.y)
        fld dword [ebx + v2_y]
        faddp st1               ; st0 = a.y + t * (b.y - a.y)
        fstp dword [edx + v2_y]

        popa
        leave
        ret
        %pop

