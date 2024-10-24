// this code sets up a higher half kernel at 0xc0000000

const mb = @import("multiboot.zig");

var init_page_directory: [1024]u32 align(4096) linksection(".init") = undefined;

var identity_page_table: [1024]u32 align(4096) linksection(".init") = undefined;

extern fn start() noreturn;

// TODO: temporary GDT post-grub
// const temp_gdt = packed struct {
//     a: u32 = 0x00000000,
//     b: u32 = 0x00000000,
//     c: u32 = 0xffff0000,
//     d: u32 = 0x009acf00,
//     e: u32 = 0xffff0000,
//     f: u32 = 0x0092cf00
// } {};

// var gdtPointer: u48 = undefined;


const temp_gdt align(4) linksection(".init") = packed struct { a: u32 = 0x00000000, b: u32 = 0x00000000, c: u32 = 0x0000ffff, d: u32 = 0x00cf9a00, e: u32 = 0x0000ffff, f: u32 = 0x00cf9200 }{};
var gdtPointer linksection(".init") = packed struct {
    size: u16 = 23,
    address: usize = 0,
}{};

export fn higherHalfInit(mb_address: u32, magic: u32) linksection(".init") callconv(.C) void {

    // setting up temporary gdt TODO: make this cleaner, maybe eliminate this step
    gdtPointer.address = @intFromPtr(&temp_gdt);
    asm volatile ("lgdt (%[address])"
        :
        : [address] "{eax}" (@intFromPtr(&gdtPointer)),
    );
    asm volatile (
        \\mov $0x10, %%ax
        \\mov %%ax, %%ss
        \\mov %%ax, %%ds
        \\mov %%ax, %%es
        \\mov %%ax, %%fs
        \\mov %%ax, %%gs
        \\jmp $0x08,$exit
        \\exit:
    );

    // zeroing the init page directory and page table
    var i: usize = 0x00;
    while (i < 1024) : (i += 1) { // TODO: way to do this automatically?
        init_page_directory[i] = 0x00;
        identity_page_table[i] = 0x00;
    }

    // mapping the init page directory to itself
    init_page_directory[1023] = @intFromPtr(&init_page_directory) + 3; // flags = present + r@@intFromPtr
    // set up identity paging for first page, TODO: figure out exact size of kernel?
    for (0..1024) |ii| {
        identity_page_table[ii] = (ii << 12) + 3;
    }
    init_page_directory[0] = @intFromPtr(&identity_page_table) + 3;

    // set up kernel page table to the same exact page table
    init_page_directory[0xc0000000 >> 22] = @intFromPtr(&identity_page_table) + 3;
    init_page_directory[1023] = @intFromPtr(&init_page_directory) + 3; // mapping last page directory to itself

    asm volatile (
        \\mov %%eax, %%cr3
        \\mov %%cr0, %%eax
        \\or $0x80000001, %%eax
        \\mov %%eax, %%cr0
        :
        : [page_directory] "{eax}" (@intFromPtr(&init_page_directory)),
    );

    // mb.multiboot_info_location = ebx;

    asm volatile ("debugtest:");

    asm volatile (""
        :
        : [m] "{eax}" (magic), [addr] "{ebx}" (mb_address)
    );

    asm volatile (
        \\jmp $0x08,$start
    );

    // now we can use the other linked functions if we wanted to
    // start();
}
