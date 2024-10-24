const mem = @import("memory_allocator.zig");

pub fn LinkedList(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Node = struct {
            next: ?*Node = null,
            data: T,
        };

        first: ?*Node = null,

        pub fn prepend(this: *Self, element: T) void {
            var new_node = mem.kernelAllocate(Node, 1); // TODO: more efficient memory allocation here (done in batches)
            if (this.first == null) {
                this.first = &new_node[0];
            } else {
                new_node[0].next = this.first;
                this.first = &new_node[0];
                new_node[0].data = element;
            }
        }

        pub fn getNode(this: Self, element: T) ?*Node {
            if (this.first == null) {
                return null;
            }
            var node = this.first orelse @panic("shouldn't happen");
            while (node.data != element) {
                if (node.next == null) {
                    return null;
                }
                node = node.next;
            }
            return node;
        }

        // TODO: flesh this class out
    };
}
