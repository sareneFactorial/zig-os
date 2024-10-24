const ringBuffer = @import("ringbuffer.zig");
const screen = @import("screen.zig");

pub var keyboard_buffer: ringBuffer.RingBuffer(KeyEvent) = undefined;

// only keydown events for now
// TODO: key event class
const Keyboard = enum(u8) { VK_Q, VK_W, VK_E, VK_R, VK_T, VK_Y, VK_U, VK_I, VK_O, VK_P, VK_A, VK_S, VK_D, VK_F, VK_G, VK_H, VK_J, VK_K, VK_L, VK_Z, VK_X, VK_C, VK_V, VK_B, VK_N, VK_M, VK_SPACE, VK_ENTER, VK_ONE, VK_TWO, VK_THREE, VK_FOUR, VK_FIVE, VK_SIX, VK_SEVEN, VK_EIGHT, VK_NINE, VK_ZERO, VK_CTRL, VK_ALT, VK_SUPER, VK_ESC, UNKNOWN };

// TODO: key repeat type
const EventType = enum(u8) {
    KEY_UP,
    KEY_DOWN,
};

pub const LEFT_CTRL = 1 << 0;
pub const LEFT_ALT = 1 << 1;
pub const LEFT_SHIFT = 1 << 2;
pub const LEFT_SUPER = 1 << 3;
pub const RIGHT_CTRL = 1 << 4;
pub const RIGHT_ALT = 1 << 5;
pub const RIGHT_SHIFT = 1 << 6;
pub const RIGHT_SUPER = 1 << 7;

var modifier_state: u8 = 0;

const KeyEvent = packed struct {
    key: Keyboard,
    event_type: EventType,
    modifiers: u8,
};

pub fn keyboardInit() void {
    keyboard_buffer.init();
}

fn keyDown(key: Keyboard) KeyEvent {
    return KeyEvent{
        .key = key,
        .event_type = EventType.KEY_DOWN,
        .modifiers = modifier_state,
    };
}

pub fn receiveScanCode(byte: u8) bool {
    const key_event = parseKeyEvent(byte);
    if (key_event != null) {
        _ = keyboard_buffer.write(key_event.?);
        return true;
    } else {
        return false;
    }
}

fn parseKeyEvent(byte: u8) ?KeyEvent {
    return switch (byte) {
        0x01 => keyDown(Keyboard.VK_ESC),
        0x02 => keyDown(Keyboard.VK_ONE),
        0x03 => keyDown(Keyboard.VK_TWO),
        0x04 => keyDown(Keyboard.VK_THREE),
        0x05 => keyDown(Keyboard.VK_FOUR),
        0x06 => keyDown(Keyboard.VK_FIVE),
        0x07 => keyDown(Keyboard.VK_SIX),
        0x08 => keyDown(Keyboard.VK_SEVEN),
        0x09 => keyDown(Keyboard.VK_EIGHT),
        0x0A => keyDown(Keyboard.VK_NINE),
        0x0B => keyDown(Keyboard.VK_ZERO),

        0x1E => keyDown(Keyboard.VK_A),
        0x30 => keyDown(Keyboard.VK_B),
        0x2E => keyDown(Keyboard.VK_C),
        0x20 => keyDown(Keyboard.VK_D),
        0x12 => keyDown(Keyboard.VK_E),
        0x21 => keyDown(Keyboard.VK_F),
        0x22 => keyDown(Keyboard.VK_G),
        0x23 => keyDown(Keyboard.VK_H),
        0x17 => keyDown(Keyboard.VK_I),
        0x24 => keyDown(Keyboard.VK_J),
        0x25 => keyDown(Keyboard.VK_K),
        0x26 => keyDown(Keyboard.VK_L),
        0x32 => keyDown(Keyboard.VK_M),
        0x31 => keyDown(Keyboard.VK_N),
        0x18 => keyDown(Keyboard.VK_O),
        0x19 => keyDown(Keyboard.VK_P),
        0x10 => keyDown(Keyboard.VK_Q),
        0x13 => keyDown(Keyboard.VK_R),
        0x1F => keyDown(Keyboard.VK_S),
        0x14 => keyDown(Keyboard.VK_T),
        0x16 => keyDown(Keyboard.VK_U),
        0x2F => keyDown(Keyboard.VK_V),
        0x11 => keyDown(Keyboard.VK_W),
        0x2D => keyDown(Keyboard.VK_X),
        0x15 => keyDown(Keyboard.VK_Y),
        0x2C => keyDown(Keyboard.VK_Z),

        0x39 => keyDown(Keyboard.VK_SPACE),
        0x1C => keyDown(Keyboard.VK_ENTER),

        else => KeyEvent{
            .key = Keyboard.UNKNOWN,
            .event_type = EventType.KEY_DOWN,
            .modifiers = modifier_state,
        },
    };
}

// TODO: locales or languages or whatever
pub fn getPrintableChar(key: Keyboard, modifiers: u8) ?u8 {
    // screen.printConst(@tagName(key));
    if (modifiers & (LEFT_SHIFT | RIGHT_SHIFT) == 0) {
        return switch (key) {
            Keyboard.VK_ONE => '1',
            Keyboard.VK_TWO => '2',
            Keyboard.VK_THREE => '3',
            Keyboard.VK_FOUR => '4',
            Keyboard.VK_FIVE => '5',
            Keyboard.VK_SIX => '6',
            Keyboard.VK_SEVEN => '7',
            Keyboard.VK_EIGHT => '8',
            Keyboard.VK_NINE => '9',
            Keyboard.VK_ZERO => '0',

            Keyboard.VK_Q => 'q',
            Keyboard.VK_W => 'w',
            Keyboard.VK_E => 'e',
            Keyboard.VK_R => 'r',
            Keyboard.VK_T => 't',
            Keyboard.VK_Y => 'y',
            Keyboard.VK_U => 'u',
            Keyboard.VK_I => 'i',
            Keyboard.VK_O => 'o',
            Keyboard.VK_P => 'p',
            Keyboard.VK_A => 'a',
            Keyboard.VK_S => 's',
            Keyboard.VK_D => 'd',
            Keyboard.VK_F => 'f',
            Keyboard.VK_G => 'g',
            Keyboard.VK_H => 'h',
            Keyboard.VK_J => 'j',
            Keyboard.VK_K => 'k',
            Keyboard.VK_L => 'l',
            Keyboard.VK_Z => 'z',
            Keyboard.VK_X => 'x',
            Keyboard.VK_C => 'c',
            Keyboard.VK_V => 'v',
            Keyboard.VK_B => 'b',
            Keyboard.VK_N => 'n',
            Keyboard.VK_M => 'm',

            Keyboard.VK_SPACE => ' ',
            Keyboard.VK_ENTER => '\n',

            else => null,
        };
    } else {
        // TODO: implement
        return null;
    }
}
