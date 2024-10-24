const CODE: u8 = 0b11010;
const DATA: u8 = 0b10010;
const KERNEL: u8 = 0b10000000;
const USER: u8 = 0b11100000;

const CODE_KERNEL: u8 = 0b10011010; // temporary workaround
const DATA_KERNEL: u8 = 0b10010010;

extern fn flushSegments() void;

const GDTEntry = packed struct {
    limit_1: u16,
    base_1: u16,
    base_2: u8,
    access: u8,
    limit_2: u4,
    flags: u4,
    base_3: u8,
};

const GDTReference = extern struct {
    size: u16 align(1),
    address: *const GDTEntry align(1),
};

const gdt = [_]GDTEntry{
    newGDTEntry(0, 0, 0, 0), // null descriptor
    newGDTEntry(0, 0xffffffff, CODE_KERNEL, 0b1100),
    newGDTEntry(0, 0xffffffff, DATA_KERNEL, 0b1100),
    newGDTEntry(0, 0, 0, 0), // reserved for future use
    newGDTEntry(0, 0, 0, 0),
    newGDTEntry(0, 0, 0, 0),
};

const gdt_reference: GDTReference = GDTReference{ 
    .size = @as(u16, @sizeOf(@TypeOf(gdt)) - 1), 
    .address = &gdt[0] 
    };

// TODO: structs for access and flags? maybe?
pub fn newGDTEntry(base: usize, limit: usize, access: u8, flags: u4) GDTEntry {
    return GDTEntry{ 
        .limit_1 = @as(u16, @truncate(limit)), 
        .base_1 = @as(u16, @truncate(base)), 
        .base_2 = @as(u8, @truncate(base >> 16)), 
        .access = access, 
        .limit_2 = @as(u4, @truncate(limit >> 16)), 
        .flags = flags, 
        .base_3 = @as(u8, @truncate(base >> 24)) };
}

pub fn initGDT() void {
    loadGDT(&gdt_reference);
}

pub inline fn loadGDT(address: *const GDTReference) void {
    asm volatile ("lgdt (%[address])"
        :
        : [address] "{eax}" (address),
    );
    flushSegments();
}
