%define IB_up           0
%define IB_down         1
%define IB_left         2
%define IB_right        3
%define IB_space        4
%define IB_shift        5
%define IB_escape       6

%macro  button_is_down 1
        mov eax, [g_input]
        add eax, %1
        cmp byte [eax], 1
%endmacro
