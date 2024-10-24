global start
extern main

bits 32
start:
    mov esp, 0xc0010000
    push eax
    push ebx

    cli
    call main

    cli
    hlt
