const screen = @import("../../screen.zig");
const x86 = @import("instructions.zig");
const idt = @import("idt.zig");
const keyboard = @import("../../keyboard.zig");
const scheduler = @import("../../scheduler.zig");

extern fn schedule(regs: scheduler.Registers) void;

pub fn pageFaultHandler() callconv(.Interrupt) void {
    screen.println("Page fault!");
    while(true) {
        x86.cli();
        x86.hlt();
    }
}

pub fn breakpointHandler() callconv(.Interrupt) void {
    screen.println("Break!");
}

pub fn doubleFaultHandler() callconv(.Interrupt) void {
    screen.println("DOUBLE FAULT");
    while (true) {
        x86.cli();
        x86.hlt();
    }
}

pub fn GPFHandler() callconv(.Interrupt) void {
    screen.println("General Protection Fault!");
    while (true) {
        x86.cli();
        x86.hlt();
    }
}


pub fn timerHandler() callconv(.Interrupt) void {
    _ = asm volatile (
        \\ cli
        \\ pushl %%eax
        \\ pushl %%ebx
        \\ pushl %%ecx
        \\ pushl %%edx
        \\ push %%ds
        \\ push %%es
        \\ push %%fs
    :);

    _ = asm volatile (
        \\ call schedule
    :);

    _ = asm volatile (
        \\ pop %%fs
        \\ pop %%es
        \\ pop %%ds
        \\ popl %%edx
        \\ popl %%ecx
        \\ popl %%ebx
        \\ popl %%eax
        \\ sti
    :);

    // var ebx = asm volatile (""
    //     : [output] "={ebx}" (-> u32),
    // );
    // var ecx = asm volatile (""
    //     : [output] "={ecx}" (-> u32),
    // );
    // var edx = asm volatile (""
    //     : [output] "={edx}" (-> u32),
    // );

    // _ = eax;
    // _ = ebx;
    // _ = ecx;
    // _ = edx;

    // var process = &(scheduler.current_process orelse @panic("uh oh process doesn't exist 2"));

    // process.regs.eax = eax;
    // process.regs.ebx = ebx;
    // process.regs.ecx = ecx;
    // process.regs.edx = edx;



    // process.regs.eip = asm volatile ("mov %%eip, %%eax"
    //     : [output] "={eax}" (-> u32),
    // );

    // process.regs.eip = asm volatile (""
    //     : [output] "={eip}" (-> u32),
    // );

    // process.regs.esp = asm volatile (""
    //     : [output] "={eip}" (-> u32),
    // );

    // // TODO: pop helper function
    // process.regs.eip = asm volatile ("pop %%eax"
    //     : [output] "={eax}" (-> u32),
    // );

    // screen.printDynamic(&screen.byteToHex(@truncate(u8, eax)), 2);

    // scheduler.tick();
    idt.endOfInterrupt(0x20); // TODO: interrupt enum for numbers
    // _ = asm volatile(
    //     "iret" :
    // );
    // _ = asm volatile(
    //     \\nop
    //     \\nop
    //     \\nop
    //     \\nop
    //     \\nop
    //     \\nop 
    //     :
    // );
}

pub fn keyboardHandler() callconv(.Interrupt) void {
    const input = x86.inb(0x60);
    _ = keyboard.receiveScanCode(input);
    // screen.print(screen.byteToHex(input));
    // if(keyboard.receiveScanCode(input)) {
    //     screen.println("Gotten");
    //     const event = keyboard.keyboard_buffer.read();
    //     if(event != null) {
    //         var charr = keyboard.getPrintableChar(event.?.key, event.?.modifiers);
    //         if(charr == null) {
    //             screen.println("oh no!!");
    //         } else {
    //             screen.newLine();
    //             screen.newLine();
    //             screen.putChar(charr.?);
    //             screen.newLine();
    //             screen.newLine();
    //         }
    //     }
    // var aaaa = [_]u8 {'h', 'e', 'l', 'l', 'o', '!'};
    // screen.printDynamic(aaaa[0..aaaa.len], aaaa.len);
    // }
    idt.endOfInterrupt(0x21);
}

// TODO: integrate namespace

// TODO: move some of these into a util class

pub fn empty() void {}
