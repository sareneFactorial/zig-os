pub const multiboot_info_struct = struct {
    mem_lower: u32,
    mem_upper: u32,
};

pub var multiboot_info: multiboot_info_struct = multiboot_info_struct {
    .mem_lower = 0,
    .mem_upper = 0,
};

const multiboot_tag = extern struct {
    type: u32,
    size: u32,
};


pub extern var eax_temp : u32 linksection(".init");
pub extern var ebx_temp : u32 linksection(".init");

pub fn readMultibootInfo(addr: u32) void {
    // const total_size: u32 = *@as(*u32, @ptrFromInt(addr));
    var currentTag: *multiboot_tag = @ptrFromInt(addr + 8);

    // TODO: decode full info structure
    while (currentTag.type != 4 and currentTag.type != 0) {
        currentTag = @ptrFromInt((@intFromPtr(currentTag) + currentTag.size + 7) & ~@as(u32, 7)); // aligning to 8 bytes
    } 
    if(currentTag.type == 0) {
        @panic("invalid multiboot header");
    }

    var m_tag: *memory_tag = @ptrCast(currentTag);

    multiboot_info.mem_lower = m_tag.mem_lower;
    multiboot_info.mem_upper = m_tag.mem_upper;

}


const memory_tag = extern struct {
    type: u32,
    size: u32,
    mem_lower: u32,
    mem_upper: u32,
};
