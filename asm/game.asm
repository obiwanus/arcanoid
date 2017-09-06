; --------------------------------------------------------
segment .data
; --------------------------------------------------------
segment .bss
; --------------------------------------------------------
segment .text
%ifdef ELF_TYPE
        global  update_and_render
update_and_render:
%else
        global  _update_and_render
_update_and_render:
%endif
        enter   0, 0                    ; setup routine
        pusha

; START --------------------------------------------------




; END ----------------------------------------------------

program_end:
        popa
        mov eax, 1                      ; return back to C
        leave
        ret

