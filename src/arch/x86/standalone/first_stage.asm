bits 16
org 0x7c3e

%include "src/arch/x86/standalone/constants.asm"


bootLoader:
    ; mov ah, 0x0A
    ; mov al, 'h'
    ; mov bh, 0
    ; mov cx, 20
    ; int 0x10
    ; cli
    ; hlt

    ;set up segments
    cli
    mov [bootOffset + bBootDrive], dl
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    sti

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

    ; read sectors time 
    readNext: ; TODO: turn into macro or something
        push cx ; save cx, which contains the remaining sectors in the root
        push ax ; save ax, which contains the first root sector address
        mov bx, 0x8000 ; arbitrary location
        call readSector

        checkEntry:
            mov cx, 11  ; filenames are size 11 (8.3)
            mov di, bx  ; es:di = the address where the directory will be loaded, filename has offset 0
            lea si, loaderFileName ; ds:si = pointer to filename to compare with
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
            mov ax, FILE_SEGMENT
            mov es, ax ; arbitrary segment for file loading
            xor bx, bx

            mov cx, [file_start] ; cx now points to first cluster of file in FAT

            readNextFileSector:
                mov ax, cx ; sector to to read is the current fat entry
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
    ; mov ax, FILE_SEGMENT
    ; mov cs, ax
    ; xor ax, ax
    jmp FILE_SEGMENT:0000


            
; TODO: fit this into a macro or something
readSector: ; AX = LBA of sector to read, ES:BX = output to read it to
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

; BP = string offset
; BL = color
writeString:
    lodsb ; load si into al and increment

    or al, al ; check if 0
    jz writeStringDone

    mov ah, 0xe ; teletype output
    mov bh, 0 ; page 0
    int 0x10

    jmp writeString
writeStringDone:
    retw


bootFail:
    lea si, textBootFail
    call writeString
    cli
    hlt

; consts
textBootFail: db "Boot Failed!",0
loaderFileName: db "LOADER  BIN"

; variables
root_sectors: dw 0
root_start: dw 0
file_start: dw 0


times 448 - ($-$$) db 0
dw 0xaa55

