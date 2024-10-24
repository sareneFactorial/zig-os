arch ?= x86
kernel := build/kernel-$(arch).bin
iso := build/os-$(arch).iso
grub_cfg := src/arch/$(arch)/multiboot/grub.cfg
zig := /home/sarene/.config/VSCodium/User/globalStorage/ziglang.vscode-zig/zig_install/zig

multiboot: $(kernel)
	@mkdir -p build/iso/boot/grub
	@cp $(kernel) build/iso/boot/kernel.bin
	@cp $(grub_cfg) build/iso/boot/grub
	@grub-mkrescue -o $(iso) build/iso

bochs: multiboot
	nm build/kernel-x86.bin | grep " [Tt] " | awk '{ print $$1" "$$3 }' > build/kernel-x86.sym 
	@bochs -q -f baseconfig

run: multiboot
	@qemu-system-i386 -cdrom $(iso) -d int,cpu_reset -no-reboot

debug: multiboot
	@qemu-system-i386 -s -S -cdrom $(iso)

$(kernel): assemblemultiboot
	@ld -m elf_i386 -n -T src/arch/x86/multiboot/linker.ld -o $(kernel) build/main.o build/multiboot_header.o build/start.o build/gdt.o build/init.o build/libcompiler_rt.a.o build/multiboot_entry.o

assemblemultiboot: compilekernel
	@mkdir -p build
	@nasm -f elf32 src/arch/x86/multiboot/multiboot_header.asm -o build/multiboot_header.o
	@nasm -f elf32 src/arch/x86/gdt.asm -o build/gdt.o
	@nasm -f elf32 -Ibuild src/arch/x86/start.asm -o build/start.o
	@nasm -f elf32 src/arch/x86/multiboot/multiboot_entry.asm -o build/multiboot_entry.o

compilekernel:
	@mkdir -p build
	@$(zig) build-obj -target x86-freestanding-none -mcpu=i386-sse-sse2 src/main.zig -femit-bin=build/main.o -Doptimize=ReleaseFast
	@$(zig) build-obj -target x86-freestanding-none -mcpu=i386-sse-sse2 src/arch/x86/multiboot/higher_half_init.zig -femit-bin=build/init.o -Doptimize=ReleaseFast
clean:
	@rm -r build

standalonetest: setupfloppy compilekernel
	@mkdir -p build
	-mkfs.fat -F 12 -n SARENEBOOT build/floppy.img
	@dd bs=1 count=450 if=build/first_stage.o of=build/floppy.img seek=62 conv=notrunc
	@mcopy -i build/floppy.img build/LOADER.BIN ::
	@nasm -f elf32 -Ibuild src/arch/x86/start.asm -o build/start.o
	@nasm -f elf32 src/arch/x86/gdt.asm -o build/gdt.o
	@ld -m elf_i386 -n -T src/arch/x86/standalone/linker.ld -o build/kernel.o build/main.o build/start.o build/gdt.o build/init.o build/libcompiler_rt.a.o
	@strip -s build/kernel.o -o build/kernel_strip.o
	@objcopy -O binary build/kernel_strip.o build/KERNEL.BIN
	@mcopy -i build/floppy.img build/KERNEL.BIN ::
	@qemu-system-i386 -fda build/floppy.img

setupfloppy:
	@mkdir -p build
	@nasm src/arch/x86/standalone/first_stage.asm -o build/first_stage.o
	@dd if=/dev/zero of=build/floppy.img bs=512 count=2880
	@nasm src/arch/x86/standalone/second_stage.asm -o build/LOADER.BIN 