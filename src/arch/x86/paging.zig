const higher_half = @import("multiboot/higher_half_init.zig");
const screen = @import("../../screen.zig");

pub const PageDirectoryEntry = packed struct {
    present: bool = true,
    rw: bool = false,
    user: bool = false,
    write_through: bool = false,
    cache_disable: bool = false,
    accessed: bool = false,
    zero: u1 = 0,
    big_page: bool = false, // TODO: support big pages, losing 80386 support?
    unused: u4 = 0, // TODO: global flag?
    address: u20,

    // TODO: get this as a u32 or something?
};

pub const PageTableEntry = packed struct { 
    present: bool = false, 
    rw: bool = false, 
    user: bool = false, 
    write_through: bool = false, 
    cache_disable: bool = false, 
    accessed: bool = false, 
    dirty: bool = false, 
    zero: u1 = 0, 
    global: bool = false, 
    unused: u3 = 0, 
    address: u20 };

pub var kernel_page_table: [1024]PageTableEntry align(4096) = undefined;
pub var kernel_page_directory: [1024]PageDirectoryEntry align(4096) = undefined;

extern const _kernel_end_physical: u8;

pub fn initializePaging() void {
    const first_free_page = (@intFromPtr(&_kernel_end_physical) + 4095) & ~@as(u32, 4095);
    for(0..first_free_page/4096) |i| { 
        // TODO: detect crossing over page table boundary
        kernel_page_table[i] = PageTableEntry {
            .present = true,
            .rw = true,
            .address = @truncate(i),
        };
    }
    kernel_page_directory[0xc0000000 >> 22] = PageDirectoryEntry {
        .rw = true,
        .address = @truncate(virtualToPhysical(@intFromPtr(&kernel_page_table)) >> 12),
    };

    kernel_page_directory[0] = PageDirectoryEntry {
        .address = @truncate(virtualToPhysical(@intFromPtr(&kernel_page_table)) >> 12),
        .rw = true,
    };

    kernel_page_directory[1023] = PageDirectoryEntry {
        .address = @truncate(virtualToPhysical(@intFromPtr(&kernel_page_directory)) >> 12),
        .rw = true,
    };

    asm volatile (
        \\mov %%eax, %%cr3
        :
    : [page_directory] "{eax}" (virtualToPhysical(@intFromPtr(&kernel_page_directory))));
}

pub fn virtualToPhysical(v_address: usize) usize {
    const directory_index = v_address >> 22;
    const table_index = v_address >> 12 & 0x3ff;
    // the last page in the address space is the page directory
    var page_directory: *[1024]PageDirectoryEntry = @ptrFromInt(0xFFFFF000);
    // TODO: check if exists
    // screen.print("page dir addr: 0x");
    // screen.printInt(@intFromPtr(page_directory));

    // the last page directory entry is the page directory itself,
    // meaning the last 4mb of the address space points to all page tables in order (last one being the directory itself)
    // var page_dir = @as(*[1024]PageTableEntry, @ptrFromInt(0xFFC00000));
    var page_table: *[1024]PageTableEntry = @ptrFromInt(@as(usize, page_directory.*[directory_index].address) << 12);

    // TODO: check if exists
    return (@as(usize, page_table.*[table_index].address) << 12) + (v_address & 0xfff);
}

pub fn mapToEndOfKernelMem(p_address: usize) void {
    // TODO: support more than one page directory
    const first_free_page = (@intFromPtr(&_kernel_end_physical) + 4095) & ~@as(u32, 4095);
    const page_addr: u20 = @truncate(p_address >> 12);
    for (first_free_page/4096 .. 1024) |table| {
        if(!kernel_page_table[table].present) {
            kernel_page_table[table] = PageTableEntry {
                .present = true,
                .rw = true,
                .address = page_addr,
            };
            return;
        }
    }   
}