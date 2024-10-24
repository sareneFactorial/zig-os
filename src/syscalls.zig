const screen = @import("screen.zig");
const x86 = @import("arch/x86/instructions.zig");

pub fn syscallDispatcher() callconv(.Interrupt) void {
    var eax = asm volatile (""
        : [output] "={eax}" (-> u32),
    );
    var ebx = asm volatile (""
        : [output] "={ebx}" (-> u32),
    );
    var ecx = asm volatile (""
        : [output] "={ecx}" (-> u32),
    );
    var edx = asm volatile (""
        : [output] "={edx}" (-> u32),
    );

    if(eax == 0x10) { // print int

    }
    if(eax == 0x11) { // set char. ecx = X, edx = Y, ebx = char 
        screen.setCursorPos(@truncate(ecx), @truncate(edx));
        screen.putChar(@truncate(ebx));
    }
    if(eax == 0x255) { // HCF (to be exit)
        while(true) {
            x86.cli();
            x86.hlt();
        }
    }

}
