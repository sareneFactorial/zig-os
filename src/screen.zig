const x86 = @import("arch/x86/instructions.zig");

pub const TEXT_HEIGHT = 25;
pub const TEXT_WIDTH = 80;
const VGA_BUFFER: *[TEXT_HEIGHT][TEXT_WIDTH]VgaChar = @as([*][TEXT_WIDTH]VgaChar, @ptrFromInt(0xb8000 + 0xc0000000))[0..TEXT_HEIGHT];
// TODO: move vga mode specific part into x86 arch folder

pub var column_pos: u8 = 0;
var text_color: Color = Color.white;

const VgaChar = packed struct {
    char: u8,
    color: VgaColor,
};

const VgaColor = packed struct {
    foreground: Color,
    background: Color,
};

const Color = enum(u4) { black, blue, green, cyan, red, magenta, brown, light_gray, dark_gray, light_blue, light_green, light_cyan, light_red, pink, yellow, white };

const BLANK_CHAR = VgaChar{ .char = ' ', .color = VgaColor{
    .foreground = Color.green,
    .background = Color.black,
} };

pub fn putChar(char: u8) void {
    if (column_pos >= TEXT_WIDTH) {
        newLine();
    }
    if (char == '\n') {
        newLine();
    } else {
        VGA_BUFFER[TEXT_HEIGHT - 1][column_pos] = VgaChar{ .char = char, .color = VgaColor{
            .foreground = Color.green,
            .background = Color.black,
        } };
        column_pos += 1;
    }
}

pub fn setCursorPos(x: u8, y: u8) void {
    const pos: usize = @as(usize, @intCast(y)) * TEXT_WIDTH + @as(usize, @intCast(x));

    x86.outb(0x3d4, 0x0f);
    x86.outb(0x3d5, @as(u8, @truncate(pos)));
    x86.outb(0x3d4, 0x0e);
    x86.outb(0x3d5, @as(u8, @truncate(pos >> 8)));
}

pub fn enableCursor() void {
    x86.outb(0x3d4, 0x09);
    x86.outb(0x3d5, 0x0f);

    x86.outb(0x3d4, 0x0a);
    x86.outb(0x3d5, (x86.inb(0x3d5) & 0xc0) | 14);

    x86.outb(0x3d4, 0x0B);
    x86.outb(0x3d5, (x86.inb(0x3d5) & 0xe0) | 15);
}

pub fn print(comptime string: []const u8) void {
    for (string) |char| {
        putChar(char);
    }
}

pub fn printDynamic(string: [*]u8, length: usize) void {
    for (string[0..length]) |char| {
        putChar(char);
    }
}

pub fn printConst(string: []const u8) void {
    for (string) |char| {
        putChar(char);
    }
}

pub fn println(comptime string: []const u8) void {
    print(string);
    newLine();
}

pub fn setColor(color: Color) void {
    text_color = color;
}

pub fn newLine() void {
    var y: usize = 0;
    while (y < TEXT_HEIGHT - 1) : (y += 1) {
        for (VGA_BUFFER[y], 0..) |_, x| {
            VGA_BUFFER[y][x] = VGA_BUFFER[y + 1][x];
        }
    }
    for (VGA_BUFFER[TEXT_HEIGHT - 1], 0..) |_, x| {
        VGA_BUFFER[TEXT_HEIGHT - 1][x] = BLANK_CHAR;
    }
    column_pos = 0;
}

// TODO: make this more efficient by clearing instead of just newline
pub fn clearScreen() void {
    var y: usize = 0;
    while (y < TEXT_HEIGHT) : (y += 1) {
        newLine();
    }
}

pub fn nibbleToHex(nibble: u8) u8 {
    return switch (nibble) {
        0b0000 => '0',
        0b0001 => '1',
        0b0010 => '2',
        0b0011 => '3',
        0b0100 => '4',
        0b0101 => '5',
        0b0110 => '6',
        0b0111 => '7',
        0b1000 => '8',
        0b1001 => '9',
        0b1010 => 'A',
        0b1011 => 'B',
        0b1100 => 'C',
        0b1101 => 'D',
        0b1110 => 'E',
        0b1111 => 'F',
        else => 'X',
    };
}

// TEMP DEBUG FUNCTIONS
pub fn byteToHex(byte: u8) [2]u8 {
    return [_]u8{ nibbleToHex(byte >> 4), nibbleToHex(byte & 0b1111) };
}

pub fn printInt(int: u32) void {
    printConst(&byteToHex(@truncate(int >> 24)));
    printConst(&byteToHex(@truncate(int >> 16)));
    printConst(&byteToHex(@truncate(int >> 8)));
    printConst(&byteToHex(@truncate(int )));
    // newLine();
}

pub fn printByte(byte:u8) void {
    printConst(&byteToHex(@truncate(byte)));
}