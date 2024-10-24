const screen = @import("screen.zig");
const gdt = @import("arch/x86/gdt.zig");
const idt = @import("arch/x86/idt.zig");
const x86 = @import("arch/x86/instructions.zig");
const keyboard = @import("keyboard.zig");
const shell = @import("shell.zig");
const mem = @import("memory_allocator.zig");
const paging = @import("arch/x86/paging.zig");
const scheduler = @import("scheduler.zig");
const page_allocator = @import("arch/x86/page_allocator.zig");
// const init = @import("arch/x86/multiboot/higher_half_init.zig"); // TODO: not make it reliant on multiboot
const testt = @import("std");
const multiboot = @import("arch/x86/multiboot/multiboot.zig");


const test_program = [29]u8{
    0xB8, 0x11, 0x00, 0x00, 0x00, 0xb9, 0x05, 0x00, 0x00, 0x00, 0xba, 0x05, 0x00, 0x00, 0x00, 0xbb, 0x01, 0x00, 0x00, 0x00, 0xcd, 0x80, 0xb8, 0x55, 0x02, 0x00, 0x00, 0xcd, 0x80,
};

fn testA() void {
    while(true) {
        screen.print("AA!");
    }
}

fn testB() void {
    while(true) {
        screen.print("BB!");
    }
}

export fn main(mb_address: u32, _: u32) void {
    // TODO: abstract this so it's not reliant on multiboot

    // var ebx: *multiboot.multiboot_info = @ptrFromInt(multiboot.multiboot_info_location);
    // var ebx: u32 = multi
    // _ = mb_address;

    screen.clearScreen();

    screen.println("Setting up GDT...");
    gdt.initGDT();

    screen.println("Registering Interrupt Vectors...");
    idt.initIDT();

    screen.println("Setting up memory map...");
    // page_allocator.initMemoryMap();
    multiboot.readMultibootInfo(mb_address);

    screen.println("Initializing Memory Allocator...");
    mem.initMemoryAllocator();

    screen.println("Setting up paging...");
    paging.initializePaging();

    screen.println("Starting PICs...");
    idt.initPIC();

    screen.println("Initializing Keyboard module...");
    keyboard.keyboardInit();
    x86.sti();

    screen.println("Starting init process...");
    scheduler.initializeScheduler();

    screen.newLine();
    screen.newLine();
    screen.newLine();

    screen.println("Welcome to sarene! OS");

    screen.println("Free memory:");
    screen.print("Lower memory: 0x");
    screen.printInt(multiboot.multiboot_info.mem_lower);
    screen.print( "kb");
    screen.newLine();
    screen.print("Upper memory: 0x");
    screen.printInt(multiboot.multiboot_info.mem_upper);
    screen.print( "kb");
    screen.newLine();


    var processA: *scheduler.Process = @ptrFromInt(mem.kmalloc(@sizeOf(scheduler.Process)));
    var processB: *scheduler.Process = @ptrFromInt(mem.kmalloc(@sizeOf(scheduler.Process)));

    
    processA.* = scheduler.Process{
        .pid = 1,
        .regs = undefined,
        // .allocated_memory = @as(*mem.MemoryNode, @ptrFromInt(100)), // TODO: better way of determining a no-memory program OR easy memory allocation
        .page_directory = &paging.kernel_page_directory,
        // .next_process = &spinning_process,
    };
    processA.regs.eip = @intFromPtr(&testA);

    processB.* = scheduler.Process{
        .pid = 1,
        .regs = undefined,
        // .allocated_memory = @as(*mem.MemoryNode, @ptrFromInt(100)), // TODO: better way of determining a no-memory program OR easy memory allocation
        .page_directory = &paging.kernel_page_directory,
        // .next_process = &spinning_process,
    };
    processB.regs.eip = @intFromPtr(&testB);

    scheduler.registerProcess(processA);
    scheduler.registerProcess(processB);
    scheduler.enableScheduling();

    screen.print("how'd we get here");


    // while (true) {
    //     // screen.print("testb ");
    //     // screen.print("testa ");
        
    // }



    // shell.shellMain();

    while (true) {
        // x86.cli();
        x86.hlt();
    }
}

pub fn panic(msg: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    screen.newLine();
    screen.println("KERNEL PANIC!!!");
    screen.printConst(msg);
    screen.newLine();
    while (true) {
        x86.cli();
        x86.hlt();
    }
}
