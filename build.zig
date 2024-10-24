const std = @import("std");
const Builder = std.build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const exe = b.addExecutable("src", "src/main.zig");
    exe.setOutputDir("build/iso/boot");

    exe.addAssemblyFile("src/arch/x86/multiboot/multiboot_header.S");
    exe.addAssemblyFile("src/arch/x86/start.S");

    // TODO: support for multiple architectures maybe ?
    exe.setTarget(std.zig.CrossTarget {
        .cpu_arch = std.Target.Cpu.Arch.i386,
        .os_tag = std.Target.Os.Tag.freestanding,
        .abi = std.Target.Abi.none,
    });
    exe.setBuildMode(b.standardReleaseOptions());

    exe.setLinkerScriptPath("src/arch/x86/linker.ld");
     
    // b.addSystemCommand("grub-mkrescue", "-o", "build/os.iso", "-d", "/usr/lib/grub/i386-pc", "build/iso");
    const make_iso = b.addSystemCommand(&[_][]const u8{
        "grub-mkrescue", "-o", "build/os.iso", "build/iso"});
    make_iso.step.dependOn(&exe.step);

    b.default_step.dependOn(&make_iso.step);
}
