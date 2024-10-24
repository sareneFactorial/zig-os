const screen = @import("screen.zig");

pub fn RingBuffer(comptime T: type) type {
    return struct {
        const Self = @This();
        size: u16 = 256,
        read_index: u16 = 0,
        write_index: u16 = 1,
        // TODO: rewrite to allow for arbitrarily sized buffer
        // buffer: [*]T,
        buffer: [256]T = undefined,

        pub fn init(this: *Self) void {
            this.size = 256;
            this.read_index = 0;
            this.write_index = 0;
            // this.buffer = undefined;
            // this.size = length;
            // // var testbuf: [length]u8 = undefined;
            // var buf: [length]T = undefined;
            // this.buffer = buf[0..255];
            // this.buffer = [length]T;
        }

        pub fn read(this: *Self) ?T {
            // screen.print("Readin");
            if (this.write_index == this.read_index) {
                // screen.print("Null.");
                return null;
            }
            const value = this.buffer[this.read_index];
            this.read_index = (this.read_index + 1) % this.size;
            return value;
        }

        pub fn write(this: *Self, e: T) bool {
            // screen.print("Writin");
            // screen.newLine();
            // // screen.print("Write index: ");
            // var trunc: u8 = @truncate(u8, this.write_index);
            // var asdf = screen.byteToHex(trunc);
            // // screen.printDynamic(asdf[0..asdf.len], asdf.len);
            // // screen.newLine();
            // // screen.print("Read index: ");
            // trunc = @truncate(u8, this.read_index);
            // asdf = screen.byteToHex(trunc);
            // screen.printDynamic(asdf[0..asdf.len], asdf.len);
            // screen.newLine();
            // if(this.write_index == this.read_index) {
            //     screen.print("NOPENOT");
            //     return false;
            // }
            this.buffer[this.write_index] = e;
            this.write_index = (this.write_index + 1) % this.size;
            // screen.print("DONEWRIT");
            return true;
        }
    };
}
