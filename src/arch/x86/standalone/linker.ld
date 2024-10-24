ENTRY(entry)
OUTPUT_FORMAT(elf32-i386)

SECTIONS {
    . = 0x2000;

    .init :
    {
        *(.init)
    }

    . += 0xC0000000;

    .start : AT(ADDR(.start)-0xC0000000)
    {
        *(.start)
    }
    .text : AT(ADDR(.text)-0xC0000000)
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