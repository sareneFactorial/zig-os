const mem = @import("memory_allocator.zig");
const paging = @import("arch/x86/paging.zig");
const ll = @import("linked_list.zig");
const screen = @import("screen.zig");

// const Registers = extern struct {
//     cs: u32,
//     eip: u32,
//     eax: u32,
//     ebx: u32,
//     ecx: u32,
//     edx: u32,
//     ds: u32,
//     es: u32,
//     fs: u32,
// };

const Registers = extern struct {
    fs: u32 = 0x10,
    es: u32 = 0x10,
    ds: u32 = 0x10,
    edx: u32,
    ecx: u32,
    ebx: u32,
    eax: u32,
    eip: u32,
    cs: u32 = undefined,
    eflags: u32 = undefined,
    more: u32 = undefined,
    moree: u32 = undefined,
};


pub const Process = struct {
    pid: u32,
    regs: Registers = undefined,
    page_directory: *align(4096) [1024]paging.PageDirectoryEntry, // virtual address
    sleeping: u32 = 0,
    next_process: *Process = undefined,
};

pub var schedulingEnabled = false;

// pub var process_list = ll.LinkedList(Process){};
// pub var current_process: Process = undefined;
pub var current_process: *Process = undefined;

pub fn initializeScheduler() void {
    spinning_process.regs = Registers{
        .eip = @intFromPtr(&spinning),
        // .cs = 0,
        .eax = 0,
        .ebx = 0,
        .ecx = 0,
        .edx = 0,
        .ds = 0x10,
        .es = 0x10,
        .fs = 0x10,
        // .eflags = 0,
        // .esp = 0,
    };
    spinning_process.next_process = &spinning_process;
    current_process = &spinning_process;
    // process_list.prepend(spinning_process);
}

// pub fn tick() void {
//     // TODO: proper multitasking

//     var p = process_list.first orelse @panic("no process!!!!!");
//     while (p.next != null) {
//         if (p.*.data.sleeping > 0) {
//             p.*.data.sleeping -= 1;
//             // asm volatile("push %[value]"
//             // :
//             // : [value] "{eax}" (@ptrToInt(&spinning)));
//         }
//         if (p.next == null) {
//             break;
//         }
//         p = p.next orelse @panic("should't happen");
//     }

//     // const process = process_list.getNode(current_process) orelse @panic("uh oh process doesn't exist3");
//     // const next = if(process.next == null) { process.*.next; } else { process_list.first; };
// }

pub fn sleep(ticks: u32) void {
    var process = &(current_process orelse @panic("uh oh process doesn't exist"));
    process.*.sleeping = ticks;
    asm volatile ("hlt");
}

pub fn registerProcess(p: *Process) void {
    var temp = current_process.next_process;
    current_process.next_process = p;
    p.next_process = temp;
    // process_list.prepend(p);
}

fn spinning() void {
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn enableScheduling() void {
    schedulingEnabled = true;
}

var spinning_process = Process{
    .pid = 1,
    .regs = undefined,
    // .allocated_memory = @as(*mem.MemoryNode, @ptrFromInt(100)), // TODO: better way of determining a no-memory program OR easy memory allocation
    .page_directory = &paging.kernel_page_directory,
    // .next_process = &spinning_process,
};

export fn schedule(regs: Registers) callconv(.C) void {
    if(!schedulingEnabled) {
        return;
    }
    // _ = regs;
    // var reg: *Registers = @constCast(&regs); // evil
    
    // screen.print("EAX before = 0x");
    // screen.printInt(reg.eax);
    // screen.newLine();
    // screen.print("process before = 0x");
    // screen.printInt(@intFromPtr(current_process));
    // screen.newLine();

    // current_process.regs = reg.*;
    // current_process = current_process.next_process;
    // reg.* = current_process.*.regs;
    // reg.eip = @intFromPtr(&spinning);

    // screen.print("EAX after = 0x");
    // screen.printInt(reg.eax);
    // screen.newLine();
    // screen.print("process after = 0x");
    // screen.printInt(@intFromPtr(current_process));
    // screen.newLine();
    // screen.newLine();
    // reg.eax = reg.eax + 1;
    // screen.println("timer!!");
    screen.print("moree = 0x");
    screen.printInt(regs.moree);
    screen.newLine();
    screen.print("more = 0x");
    screen.printInt(regs.more);
    screen.newLine();
    screen.print("EFLAGS = 0x");
    screen.printInt(regs.eflags);
    screen.newLine();
    screen.print("CS = 0x");
    screen.printInt(regs.cs);
    screen.newLine();
    screen.print("EIP = 0x");
    screen.printInt(regs.eip);
    screen.newLine();
    screen.print("EAX = 0x");
    screen.printInt(regs.eax);
    screen.newLine();
    screen.print("EBX = 0x");
    screen.printInt(regs.ebx);
    screen.newLine();
    screen.print("ECX = 0x");
    screen.printInt(regs.ecx);
    screen.newLine();
    screen.print("EDX = 0x");
    screen.printInt(regs.edx);
    screen.newLine();
    screen.print("DS = 0x");
    screen.printInt(regs.ds);
    screen.newLine();
    screen.print("ES = 0x");
    screen.printInt(regs.es);
    screen.newLine();
    screen.print("FS = 0x");
    screen.printInt(regs.fs);
    screen.newLine();
}