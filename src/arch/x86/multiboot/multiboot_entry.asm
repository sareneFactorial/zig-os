section .init
global multibootEntry
extern higherHalfInit
extern eax_temp
extern ebx_temp
bits 32

multibootEntry:
    ; mov ebx, [ebx_temp]
    ; mov eax, [eax_temp]
    push eax
    push ebx
    cli
    call higherHalfInit

    cli
    hlt
