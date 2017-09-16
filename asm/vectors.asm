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
; void v2_lerp(v2 vector1, v2 vector2, float t, v2 *result)
v2_lerp:
        push ebp
        mov ebp, esp
        pusha



        popa
        leave
        ret


