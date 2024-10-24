extern start

section .bootloader
bits 16
org 0x0e000
%include "src/arch/x86/standalone/constants.asm"
KERNEL_SEGMENT equ 0x0200 ; kernel sector to load in
KERNEL_LOCATION equ 0x100000
second_stage:
    cli
    ; time to set a20 line!
    call checkA20 ; check if already on
    cmp ax, 0
    jne a20Done
    ; bios subroutine
    mov ax, 0x2401
    int 0x15
    call checkA20
    cmp ax, 0
    jne a20Done
    ; i8042 keyboard controller (??)
    call a20i8042Enable
    call checkA20
    cmp ax, 0
    jne a20Done
    ; fast a20, risky move
    in al, 0x92
    or al, 2
    out 0x92, al
    call checkA20
    cmp ax, 0
    jne a20Done
    ; a20 unavailable fail
    lea si, a20Fail
    call writeString
    cli
    hlt
    a20Done:

    ; put memory map at 0x8004 with length at 0x8000
    call do_e820

    ; setting up temporary GDT, to get into protected mode
    mov ax, 0   
    mov es, ax 
    mov di, 800 ; es:di = 0000:0800


    ; IDEA TO OPTIMIZE:
    ; tack on a GDT descriptor and GDT structure at the beginning of the kernel file,
    ; load in ONLY the kernel, and set up gdt in first stage
    ; would need to move A20 enabling to the kernel start itself

    lgdt [gdtPointer] ; HUGE

    ; ok copy pasting more code from first bootloader b/c we need some variables
    ; reset disks
    mov dl, [bootOffset + bBootDrive]
    xor ax, ax
    int 0x13
    jc bootFail

    ; calculate the number of sectors the root directory takes up
    mov ax, 32 ; directory entries are 32 bytes
    xor dx, dx ; clear higher part
    mul word [bootOffset + bRootSize] ; multiply 32 by number of entries to get size in bytes
    div word [bootOffset + bSectorSize] ; divide by sector size to get sectors
    mov cx, ax 
    mov [root_sectors], cx ; root_sectors has root size in sectors

    ; calculate start sector LBA of root directory
    ; numFat * fatSize + hiddenSectors + reservedSectors
    xor ax, ax
    mov al, [bootOffset + bNumFatTables]
    mov bx, [bootOffset + bFatSize]
    mul bx
    add ax, [bootOffset + bHiddenSectors] ; ignoring top 2 bytes for now. TODO: figure out something better probably
    add ax, [bootOffset + bResvSectors] 
    mov [root_start], ax ; store first root sector in root_start

    ; TODO: load kernel into memory and switch to 32 bit protected mode

    ; TODO: optimize with already loaded in data- maybe load in both files in 1st stage?
    ; read sectors time 
    readNext:
        push cx ; save cx, which contains the remaining sectors in the root
        push ax ; save ax, which contains the first root sector address
        mov bx, 0x8000 ; arbitrary location
        call readSector

        checkEntry:
            mov cx, 11  ; filenames are size 11 (8.3)
            mov di, bx  ; es:di = the address where the directory will be loaded, filename has offset 0
            lea si, kernelFileName ; ds:si = pointer to filename to compare with
            repz cmpsb  ; this one is a doozy
                        ; repz repeats an instruction while CX is not zero and the zero flag is set
                        ; it does it the # of times in CX so i'm assuming it decrements it each time? ???? ? ?? not sure
                        ; cmpsb compares two bytes between es:di and ds:si, sets zero flag if equal
                        ; essentially comparing two strings at es:di and ds:si, and breaking with not equal if any bytes don't match
            je foundFile ; jumps if the repz finished without breaking

            add bx, 32 ; go to next entry, add size of an entry to offset
            cmp bx, [bootOffset + bSectorSize] ; check if outside of sector boundary
            jne checkEntry ; if not, check next entry

            pop ax
            inc ax ; next sector!
            pop cx 
            loopnz readNext ; decrements cx, loops if not zero
            jmp bootFail ; could not find file

        foundFile: ; at this point, bx is pointing to the address of the directory entry
            mov ax, es:[bx+dStartBlock] ; get starting cluster of file
            mov [file_start], ax ; save for later

            mov ax, FAT_SEGMENT
            mov es, ax ; arbitrary segment for FAT loading

            ; get FAT offset
            mov ax, [bootOffset + bResvSectors]
            add ax, [bootOffset + bHiddenSectors]

            mov cx, [bootOffset + bFatSize] ; load number of sectors in FAT into cx
            xor bx, bx ; es:bx being 0a00:0000
            readNextFatSector:
                push cx
                push ax
                call readSector ; ax = sectors before FAT
                pop ax
                pop cx
                inc ax
                add bx, [bootOffset + bSectorSize] ; increase bx by size of a sector
                loopnz readNextFatSector ; loop until all sectors loaded
            
            ; time 2 load file
            mov ax, KERNEL_SEGMENT
            mov es, ax ; arbitrary segment for file loading
            xor bx, bx

            mov cx, [file_start] ; cx now points to first cluster of file in FAT

            readNextFileSector:
                mov ax, cx ; sector to read is the current fat entry
                add ax, [root_start] ; plus the start and size of the root directory
                add ax, [root_sectors]
                sub ax, 2 ; minus 2 for some reason?

                push cx
                call readSector 
                pop cx
                add bx, [bootOffset + bSectorSize]

                push ds ; save data segment
                mov dx, FAT_SEGMENT ; load fat segment
                mov ds, dx ; into ds

                mov si, cx ; make SI point to the current fat cluster
                mov dx, cx ; for fat12, it's 1.5 bytes per entry
                shr dx, 1  ; so halve the value (rounded down)
                add si, dx ; and add it back in
                
                mov word dx, ds:[si] ; read the FAT entry
                test cx, 1 ; test first bit to check even/odd
                jnz oddSegment
                and dx, 0x0fff ; mask out the top 4 bits
                jmp readDone
                oddSegment:
                shr dx, 4 ; shift right 4 bits
                readDone:
                pop ds ; restore ds
                mov cx, dx
                cmp cx, 0xff8 ; compare it to EOF in fat12 (above 0xff8)
                jl readNextFileSector

    ; now enable 32 bit protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    ; make sure code and data segments are good for protected mode
    mov ax, 0x0010
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    ; now it's in 32 bit mode!
    ; bits 32
    ; io delay: out 0x80, 0
    ; this bootloader is designed to be run from a floppy disk so assuming there is one is fine actually
    ; TODO: load kernel at 0x100000 using floppy controller


    ; jmp 0x08:0x2000
    db 0x66 
    db 0xea
    dd 0x02000 ; offset
    dw 0x0008 ; selector

bits 16

waitFor8042Command:
    in al,0x64
    test al, 2
    jnz waitFor8042Command
    ret
waitFor8042Data:
    in al,0x64
    test al,1
    jz waitFor8042Data
    ret

a20i8042Enable:
    call waitFor8042Command
    mov al, 0xad ; disable keyboard
    out 0x64, al

    call waitFor8042Command
    mov al, 0xd0 ; read from input
    out 0x64, al

    call waitFor8042Data
    in al, 0x60 ; read input
    push eax

    call waitFor8042Command
    mov al, 0xd1 ; write to output
    out 0x64, al

    call waitFor8042Command
    pop eax ; write back input
    or al, 2 ; with bit 2 set
    out 0x60, al

    call waitFor8042Command
    mov al, 0xae ; enable keyboard
    out 0x64, al

    call waitFor8042Command ; just for good measure

    ret


; returns 0 in ax if a20 is disabled, 1 if it's enabled
checkA20: ; this is slightly arcane to me. TODO: document
    pushf
    push ds
    push es
    push di
    push si
    cli

    xor ax, ax
    mov es, ax
    mov di, 0x0500

    mov ax, 0xffff
    mov ds, ax
    mov si, 0x0510

    mov al, [es:di]
    push ax
    mov al, byte [ds:si]
    push ax
    mov byte [es:di], 0x00
    mov byte [ds:si], 0xff

    cmp byte [es:di], 0xff

    pop ax
    mov [ds:si], al
    pop ax
    mov [es:di], al

    mov ax, 0
    je checkA20Exit
    mov ax, 1
    checkA20Exit:
        pop si
        pop di
        pop es
        pop ds
        popf
        ret



readSector: ; AX = LBA of sector to read, ES:BX = output to read it to ; TODO: turn into protected mode read
    xor cx, cx ; tries to zero
    sectloop:
        push ax ; LBA block
        push cx ; tries
        push bx ; buffer offset

        ; calculation time :sunglasses:
        ; cylinder  = (LBA / TrackSectors) / Numheads
        ; sector    = (LBA % TrackSectors) + 1
        ; head      = (LBA / TrackSectors) % NumHeads

        mov bx, [bootOffset + bTrackSectors]
        xor dx, dx
        div bx  ; divide dx:ax / b, which ends up being the LBA / TrackSectors
        inc dx  ; add 1 to the remainder (mod) for sector
        mov cl, dl ; store in cl for int 13h

        mov bx, [bootOffset + bNumHeads]
        xor dx, dx
        div bx  ; now dividing (LBA/TrackSectors) by NumHeads
        mov ch, al ; quotient is cylinder, moving to ch for int 13h
        mov dh, dl ; move remainder (mod) up to dh where it should be for int 13h 

        ; int 13h time :sunglasses:
        ; AH = subfunction (0x02 for read sector)
        ; AL = num sectors to read
        ; CH = cylinder #
        ; CL = sector #
        ; DH = head #
        ; DL = drive #
        ; ES:BX = buffer
        
        mov ah, 0x02
        mov al, 0x01
        pop bx ; pop data buffer offset
        mov dl, [bootOffset + bBootDrive]
        int 0x13
        jc readFail ; carry flag set = int 13h failed

        ; on success
        pop cx ; discard saved parameters
        pop ax 
        ret

        readFail:
        pop cx  ; increase try, try again
        inc cx 
        cmp cx, 4
        je bootFail ; give up after 4 tries

        xor ax, ax ; subfunction 0: recallibrate/reset disks
        int 0x13

        pop ax ; get LBA back
        jmp sectloop

bootFail:
    lea si, textBootFail
    call writeString
    cli
    hlt


; taken from osdev wiki
; use the INT 0x15, eax= 0xE820 BIOS function to get a memory map
; note: initially di is 0, be sure to set it to a value so that the BIOS code will not be overwritten. 
;       The consequence of overwriting the BIOS code will lead to problems like getting stuck in `int 0x15`
; inputs: es:di -> destination buffer for 24 byte entries
; outputs: bp = entry count, trashes all registers except esi
mmap_ent equ 0x8000             ; the number of entries will be stored at 0x8000
do_e820:
        mov di, 0x8004          ; Set di to 0x8004. Otherwise this code will get stuck in `int 0x15` after some entries are fetched 
	xor ebx, ebx		; ebx must be 0 to start
	xor bp, bp		; keep an entry count in bp
	mov edx, 0x0534D4150	; Place "SMAP" into edx
	mov eax, 0xe820
	mov [es:di + 20], dword 1	; force a valid ACPI 3.X entry
	mov ecx, 24		; ask for 24 bytes
	int 0x15
	jc short .failed	; carry set on first call means "unsupported function"
	mov edx, 0x0534D4150	; Some BIOSes apparently trash this register?
	cmp eax, edx		; on success, eax must have been reset to "SMAP"
	jne short .failed
	test ebx, ebx		; ebx = 0 implies list is only 1 entry long (worthless)
	je short .failed
	jmp short .jmpin
.e820lp:
	mov eax, 0xe820		; eax, ecx get trashed on every int 0x15 call
	mov [es:di + 20], dword 1	; force a valid ACPI 3.X entry
	mov ecx, 24		; ask for 24 bytes again
	int 0x15
	jc short .e820f		; carry set means "end of list already reached"
	mov edx, 0x0534D4150	; repair potentially trashed register
.jmpin:
	jcxz .skipent		; skip any 0 length entries
	cmp cl, 20		; got a 24 byte ACPI 3.X response?
	jbe short .notext
	test byte [es:di + 20], 1	; if so: is the "ignore this data" bit clear?
	je short .skipent
.notext:
	mov ecx, [es:di + 8]	; get lower uint32_t of memory region length
	or ecx, [es:di + 12]	; "or" it with upper uint32_t to test for zero
	jz .skipent		; if length uint64_t is 0, skip entry
	inc bp			; got a good entry: ++count, move to next storage spot
	add di, 24
.skipent:
	test ebx, ebx		; if ebx resets to 0, list is complete
	jne short .e820lp
.e820f:
	mov [mmap_ent], bp	; store the entry count
	clc			; there is "jc" on end of list to this point, so the carry must be cleared
	ret
.failed:
	stc			; "function unsupported" error exit
	ret

; consts
textBootFail: db "Boot Failure",0
a20Fail: db "A20 Unavailable",0 ; TODO: more descriptive errors
kernelFileName: db "KERNEL  BIN"



; BP = string offset
; BL = color
writeString:
    lodsb ; load [si] into al and increment

    or al, al ; check if 0
    jz writeStringDone

    mov ah, 0xe ; teletype output
    mov bh, 0 ; page 0
    int 0x10

    jmp writeString
writeStringDone:
    retw

align 4 ; gdt needs to be aligned
gdtStart:
gdtNull: ; first descriptor is always a null one for Some Reason
    dd 0x0
    dd 0x0
gdtCode:
    dw 0xffff ; limit = 4gb
    dw 0x0000 ; base offset = 0
    db 0x00   ; base cont.
    db 0x9a   ; access byte, present, kernel, executable, readable
    db 0xcf   ; granularity 1
    db 0x00   ; base cont.
gdtData:
    dw 0xffff ; limit = 4gb
    dw 0x0000 ; base offset = 0
    db 0x00 ; base cont.
    db 0x92 ; access byte, present, kernel, nonexecutable, writable
    db 0xcf ; granularity 1
    db 0x00 ; base cont.
gdtEnd:

gdtPointer:
    dw gdtEnd - gdtStart - 1 ; size
    dd gdtStart ; pointer





; variables
root_sectors: dw 0
root_start: dw 0
file_start: dw 0
    