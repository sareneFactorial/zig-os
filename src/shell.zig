const keyboard = @import("keyboard.zig");
const screen = @import("screen.zig");
const x86 = @import("arch/x86/instructions.zig"); // TODO: work this out of here

var buffer: [256]u8 = undefined;

// TODO: implement with a TTY emulator

pub fn shellMain() void {
    var typedChars: usize = 0;

    makePrompt();

    screen.enableCursor();
    // screen.setCursorPos(4,screen.TEXT_HEIGHT);

    while (true) {
        const event = keyboard.keyboard_buffer.read();
        if (event != null) {
            var char = keyboard.getPrintableChar(event.?.key, event.?.modifiers);
            if (typedChars == 256 and char != null and char.? != '\n') {
                continue; // TODO: terminal bell or pc speaker or something
            }
            if (char != null and char.? == '\n') {
                screen.newLine();
                const code = parseCommand(buffer[0..typedChars]);
                if (code == 1) {
                    screen.println("Unknown command.");
                }
                typedChars = 0;
                makePrompt();
            } else if (char != null and char.? != '\n') {
                screen.putChar(char.?);
                buffer[typedChars] = char.?;
                typedChars += 1;
                if (screen.column_pos == screen.TEXT_WIDTH) {
                    screen.newLine();
                }
                screen.setCursorPos((screen.column_pos) % screen.TEXT_WIDTH, screen.TEXT_HEIGHT - 1);
            }
        } else {
            x86.hlt();
        }
    }
}

fn parseCommand(command: []u8) u8 {
    if (equalsLiteral(command, "hello")) {
        screen.println("HELLO!!!!!!!!");
        return 0;
    } else if (equalsLiteral(command, "")) {
        return 2;
    }
    return 1; // TODO: error code enum or consts
}

fn makePrompt() void {
    screen.print("$ > ");
    screen.setCursorPos(screen.column_pos, screen.TEXT_HEIGHT - 1);
}

// TODO: move to util file
pub fn equalsLiteral(a: []u8, comptime b: []const u8) bool {
    if (a.len != b.len) {
        return false;
    }
    for (a, b) |charA, charB| {
        if (charA != charB) {
            return false;
        }
    }
    return true;
}
