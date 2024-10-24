const interrupts = @import("interrupts.zig");
const x86 = @import("instructions.zig");
const sys = @import("../../syscalls.zig");

const CALLER_KERNEL = 0;
const CALLER_USER = 0b01100000;

const TRAP_GATE = 0b01111;
const INTERRUPT_GATE = 0b01110;

const IDTEntry = packed struct {
    handler_1: u16,
    gdt_selector: u16,
    zero: u8 = 0,
    options: u8,
    handler_2: u16,
};

const IDTReference = extern struct {
    size: u16 align(1),
    address: *[256]IDTEntry align(1),
};

var idt: [256]IDTEntry = undefined;

const idt_reference = IDTReference{
    .size = @as(u16, @sizeOf(@TypeOf(idt))),
    .address = &idt,
};

pub fn initIDT() void {
    registerIDTEntry(3, TRAP_GATE, interrupts.breakpointHandler);
    registerIDTEntry(8, TRAP_GATE, interrupts.doubleFaultHandler);
    registerIDTEntry(13, TRAP_GATE, interrupts.GPFHandler);
    registerIDTEntry(14, TRAP_GATE, interrupts.pageFaultHandler);
    registerIDTEntry(0x20, INTERRUPT_GATE, interrupts.timerHandler);
    registerIDTEntry(0x21, INTERRUPT_GATE, interrupts.keyboardHandler);
    registerIDTEntry(0x80, INTERRUPT_GATE, sys.syscallDispatcher);

    lidt(&idt_reference);
}

pub fn registerIDTEntry(i: u8, options: u8, comptime handler: fn () callconv(.Interrupt) void) void {
    // TODO: figure out a way to handle error codes
    idt[i].handler_1 = @as(u16, @truncate(@intFromPtr(&handler)));
    idt[i].gdt_selector = 0b1000; // selects kernel code, index 1 (1 << 3 temp workaround)
    idt[i].options = options | 0b10000000; // makes present
    idt[i].handler_2 = @as(u16, @truncate(@intFromPtr(&handler) >> 16));
}

const PIC1_COMMAND = 0x20;
const PIC1_DATA = 0x21;
const PIC2_COMMAND = 0xA0;
const PIC2_DATA = 0xA1;

const IC1_ICW4 = 0x01;
const IC1_INIT = 0x10;

pub const IRQ_OFFSET = 0x20;

pub fn initPIC() void {
    // start init
    x86.outb(PIC1_COMMAND, IC1_INIT | IC1_ICW4);
    io_pause();
    x86.outb(PIC2_COMMAND, IC1_INIT | IC1_ICW4);
    io_pause();

    // set offset
    x86.outb(PIC1_DATA, IRQ_OFFSET);
    io_pause();
    x86.outb(PIC2_DATA, IRQ_OFFSET + 8);
    io_pause();

    // set up cascade
    x86.outb(PIC1_DATA, 4);
    io_pause();
    x86.outb(PIC2_DATA, 2);
    io_pause();

    // genuinely no idea what this does
    x86.outb(PIC1_DATA, 1);
    io_pause();
    x86.outb(PIC2_DATA, 1);
    io_pause();
}

pub fn endOfInterrupt(irq: u8) void {
    if (irq - IRQ_OFFSET >= 8) {
        x86.outb(PIC2_COMMAND, 0x20);
    }
    x86.outb(PIC1_COMMAND, 0x20);
}

pub inline fn io_pause() void {
    x86.outb(0x80, 0);
}

pub inline fn lidt(address: *const IDTReference) void {
    asm volatile ("lidt (%[address])"
        :
        : [address] "{eax}" (address),
        : "eax"
    );
}
