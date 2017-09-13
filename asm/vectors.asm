%include "game.inc"
%include "external.inc"

segment .text
global v2_length

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


