const MAX_E820_ENTRIES: u8 = 128;

pub const E820Entry = packed struct {
    address: u64,
    length: u64,
    type: u32,
    EAB: u32, // unused currently
};

var E820Map: [MAX_E820_ENTRIES]E820Entry = undefined;
var numE820Entries: u8 = 0;

// TODO: support multiboot
pub fn initMemoryMap() void {
    var numEntries: *u8 = @ptrFromInt(0x8000);
    var entryPointer: [*]E820Entry = @ptrFromInt(0x8004);
    for (0..numEntries.*) |i| {
        E820Map[i] = entryPointer[i];
    }
}
