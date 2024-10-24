const scheduler = @import("scheduler.zig");
const paging = @import("arch/x86/paging.zig");

// TODO: get total size of memory
var memory_bitmap: [131072]u8 = undefined;

pub var kernel_process: scheduler.Process = undefined;

pub fn initMemoryAllocator() void {
    kernel_process.pid = 0;
    kernel_process.allocated_memory = getNewNode();
    kernel_process.page_directory = &paging.kernel_page_directory;

    for (memory_bitmap, 0..) |_, i| {
        memory_bitmap[i] = 0x00;
    }

    for (initial_nodepage.arr, 0..) |_, i| {
        initial_nodepage.arr[i] = unusedNode;
    }

    var i: usize = 0;
    while (i < 1024 / 8) : (i += 1) {
        memory_bitmap[i] = 0b11111111;
    }

    kernel_process.allocated_memory.address = 0xC0000000;
    kernel_process.allocated_memory.size = 1024 * 4096;
    kernel_process.allocated_memory.next = getNewNode();

    var next = kernel_process.allocated_memory.next;
    next.?.*.address = 0xFFC00000;
    next.?.*.size = 1024 * 4096;
    next.?.*.prev = kernel_process.allocated_memory;
}

pub fn kernelAllocate(comptime T: type, amount: usize) [*]T {
    const total_bytes = @sizeOf(T);
    var curr_node = kernel_process.allocated_memory;
    while (true) {
        const next_addr: usize = curr_node.address + curr_node.size + 1; // catch @panic("OUT OF VIRTUAL MEMORY!");
        if (curr_node.next.?.address == next_addr or curr_node.next.?.address < next_addr + total_bytes) {
            curr_node = curr_node.next orelse @panic("fdskjh");
            continue;
        }

        var new_node = MemoryNode{ .address = next_addr, .size = total_bytes, .next = curr_node.next, .prev = curr_node };

        curr_node.next = &new_node;
        curr_node.next.?.prev = &new_node;

        return @as([*]T, @ptrFromInt(next_addr));
    }
}

pub fn kFreeVirtual(v_addr: usize) void {
    // TODO: double free checking
    // TODO: implement

}

// Represents USED memory
pub const MemoryNode = packed struct {
    address: usize,
    size: usize,

    next: ?*MemoryNode = null,
    prev: ?*MemoryNode = null,

    pub fn isUnused(self: MemoryNode) bool {
        return self.address == 0 and self.size == 0;
    }
};

const unusedNode = MemoryNode{
    .address = 0,
    .size = 0,
};

const NodePage = packed struct {
    arr: [255]MemoryNode,

    next: ?*NodePage,
};

var initial_nodepage align(4096) = NodePage{
    .arr = undefined,

    .next = null,
};

fn getNewNode() *MemoryNode {
    var currentNodePage: *NodePage = &initial_nodepage;
    while (true) {
        for (currentNodePage.arr, 0..) |v, i| {
            if (v.isUnused()) {
                return &currentNodePage.arr[i];
            }
        }
        if (currentNodePage.next == null) {
            // TODO: request new page
        }
        currentNodePage = currentNodePage.next.?;
    }
}
