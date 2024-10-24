ENTRY(multibootEntry)
OUTPUT_FORMAT(elf32-i386)

SECTIONS {
    . = 0x100000;

    .multiboot :
    {
        KEEP(*(.multiboot_header))
    }

    .init :
    {
        *(.init)
    }
    . += 4;
    eax_temp = .;
    . += 4;
    ebx_temp = .;

    . += 0xC0000000;

    .text ALIGN(0x1000) : AT(ADDR(.text)-0xC0000000)
    {
        *(.text)
    }
    .rodata : AT(ADDR(.rodata)-0xC0000000)
    {
        *(.rodata)
    }
    .data : AT(ADDR(.data)-0xC0000000)
    {
        *(.data)
    }
    .bss : AT(ADDR(.bss)-0xC0000000)
    {
        *(.bss)
    }
    
    _kernel_end = .;
    _kernel_end_physical = . - 0xC0000000;
}