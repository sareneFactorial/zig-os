global flushSegments

section .text
bits 32
flushSegments:
    mov ax, 0x10 ; flush data segment registers with new data selector
    mov ds, ax ; TODO: possibly make this a parameter? probably not
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    jmp 0x08:flushCS
flushCS:
    ret