const scheduler = @import("scheduler.zig");
const paging = @import("arch/x86/paging.zig");
const mb = @import("arch/x86/multiboot/multiboot.zig");
const screen = @import("screen.zig");

// memory bitmap for entire 4gb space
// 1 = used, 0 = free
var memory_bitmap: [131072]u8 align(4) = undefined;

pub var kernel_process: scheduler.Process = undefined;

extern const _kernel_end_physical: u8;
pub const first_free_byte = &_kernel_end_physical;
pub var first_free_page: u32 = 0;

pub var first_memory_block: *MemoryBlock = undefined;

pub fn initMemoryAllocator() void {
    first_free_page = (@intFromPtr(first_free_byte) + 4095) & ~@as(u32, 4095);

    const u32_bitmap: *[32768]u32 = @ptrCast(&memory_bitmap);
    for(0..32768) |i| {
        u32_bitmap[i] = 0;
    }

    // TODO: optimize this lmfao
    const last_free_page = (0x100000 + (mb.multiboot_info.mem_upper*1024)) & ~@as(u32, 4095);
    for(0..(0x100000/4096)) |i| { // set memory bitmap for lower memory (leaving it unused)
        memory_bitmap[i / 8] |= @as(u8, 1) << @truncate(i % 8); 
    }
    for((0x100000/4096)..(first_free_page/4096)) |i| { // set kernel memory as used
        // memory_bitmap[i / 8] |= @as(u32, 1) << @as(u3, i % 8); 
        memory_bitmap[i / 8] |= @as(u8, 1) << @truncate(i % 8); 
    }

    // for((last_free_page/4096 + 1).. ((last_free_page/4096 + 1) + 4095) & ~@as(u32, 4095)) |i| {
        
    // }
    // TODO: make the free pages reach to the end rather than truncating it short
    for(last_free_page/4096/8 - 1..131071) |i| { // nonexistent memory is marked as used
        // memory_bitmap[i / 8] |= @as(u8, 1) << (i % 8); 
        // memory_bitmap[i / 8] |= @as(u32, 1) << @as(u3, i % 8); 
        memory_bitmap[i] = 0b11111111;
    }

    const free_page = getFreePage();
    var block: *MemoryBlock = @ptrFromInt(free_page);
    block.free = true;
    block.end_of_memory = true;
    block.size = 4096 - 4;
    first_memory_block = block;

}


// represents a block of memory, as a header at the beginning of each block
const MemoryBlock = packed struct {
    free: bool,
    end_of_memory: bool,
    size: u30, // size is free memory and not the struct
};

// TODO: implement freeing memory

pub fn getFreePage() usize {
    var i: usize = (first_free_page/4096)/8; // start at first free page
    while (true) : (i += 1) {
        var x = memory_bitmap[i];
        if (x == 0b11111111) {
            continue;
        } else {
            var n: u32 = 0;
            var mask = ~x;
            while (mask > 0) { // get index of bit
                n += 1;
                mask >>= 1;
            }
            memory_bitmap[i] |= @as(u8, 1) << @truncate(n);
            // invert
            n = 8 - n;
            return (i * 4096 * 8) + (n * 4096);
        }
    }
    return 0; // TODO: implement
}

// TODO: support mallocs bigger than 1 page
pub fn kmalloc(size: usize) usize {
    var current_block: *MemoryBlock = first_memory_block;

    while(true) {
        if(!current_block.free) {
            current_block = nextMemoryBlock(current_block);
            continue;
        }
        if(current_block.size < @sizeOf(MemoryBlock) + size) {
            if(current_block.end_of_memory) {
                paging.mapToEndOfKernelMem(getFreePage());
                current_block.size += 4096;
                continue;
            }
            current_block = nextMemoryBlock(current_block);
            continue;
        }

        const previous_size = current_block.size;
        const previous_EOM = current_block.end_of_memory;
        const previous_block_ptr = current_block;

        current_block.size = @truncate(size);
        current_block.free = false;
        current_block.end_of_memory = false;

        current_block = nextMemoryBlock(current_block);
        current_block.size = @truncate(previous_size - size - 4);
        current_block.free = true;
        current_block.end_of_memory = previous_EOM;

        return @intFromPtr(previous_block_ptr) + @sizeOf(MemoryBlock);
    }
}

// given a memory block, gives the supposed address of the next memory block according to size.
// does not account for EOM
pub fn nextMemoryBlock(block: *MemoryBlock) *MemoryBlock {
    var pointer = @intFromPtr(block);
    pointer += block.size + @sizeOf(MemoryBlock); 
    return @ptrFromInt(pointer);
}

// special form of kmalloc() that gets an aligned page
// the header is placed at the last 4 bytes of the previous page, which means this allocates 2 pages sometimes
// the previous block is still usable, just 4 bytes shorter
pub fn getAlignedPage() usize {
    // TODO: don't always assign a new page here, find free that have an aligned page within them
    var current_block: *MemoryBlock = first_memory_block;
    while(!current_block.end_of_memory) {
        current_block = nextMemoryBlock(current_block);
    }
    if(current_block.size < 4) {
        paging.mapToEndOfKernelMem(getFreePage());
        current_block.size += 4096;
        return getAlignedPage();
    }
    current_block.size -= 4;
    current_block.end_of_memory = false;
    current_block = nextMemoryBlock(current_block);
    current_block.free = false;
    current_block.size = 4096;
    current_block.end_of_memory = true;
    return @intFromPtr(current_block) + @sizeOf(MemoryBlock);
}

pub fn newUserPageDirectory(lower_bound: usize, upper_bound: usize) *[1024]paging.PageDirectoryEntry {
    // TODO: support initial mappings bigger than one directory entry
    const pageDir: *[1024]paging.PageDirectoryEntry = @ptrFromInt(getAlignedPage());
    const pageTable: *[1024]paging.PageTableEntry = @ptrFromInt(getAlignedPage());

    const lower_page = (lower_bound / 4096) & (~@as(usize, 4095));
    const upper_page = (upper_bound / 4096 + 4095) & (~@as(usize, 4095));

    for(lower_page..upper_page) |i| { 
        // TODO: detect crossing over page table boundary
        pageTable[i] = paging.PageTableEntry {
            .present = true,
            .rw = true,
            .user = true,
            .address = @truncate(getFreePage() >> 12),
        };
    }
    pageDir[0xc0000000 >> 22] = paging.PageDirectoryEntry {
        .rw = true,
        .address = @truncate(paging.virtualToPhysical(@intFromPtr(&paging.kernel_page_table)) >> 12),
    };

    pageDir[lower_bound >> 22] = paging.PageDirectoryEntry {
        .address = @truncate(paging.virtualToPhysical(@intFromPtr(&pageTable)) >> 12),
        .rw = true,
    };

    pageDir[1023] = paging.PageDirectoryEntry {
        .address = @truncate(paging.virtualToPhysical(@intFromPtr(&pageDir)) >> 12),
        .rw = true,
    };

    return pageDir;
}