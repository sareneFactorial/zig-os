; offsets for the bios parameter block
bOEM            equ 0x03 ; 8
bSectorSize     equ 0x0b ; 2
bClusterSize    equ 0x0d ; 1
bResvSectors    equ 0x0e ; 2
bNumFatTables   equ 0x10 ; 1
bRootSize       equ 0x11 ; 2
bTotalSectors   equ 0x13 ; 2
bMediaType      equ 0x15 ; 1
bFatSize        equ 0x16 ; 2
bTrackSectors   equ 0x18 ; 2
bNumHeads       equ 0x1a ; 2
bHiddenSectors  equ 0x1c ; 4
bSectorsOver32  equ 0x20 ; 4
bBootDrive      equ 0x24 ; 2
bExtBootSign    equ 0x26 ; 1
bVolumeID       equ 0x27 ; 4
bVolumeLabel    equ 0x2b ; 11
bFileSystem     equ 0x36 ; 8

; offsets for directory entry
dFileName   equ 0x00
dFileExt    equ 0x08
dFileAttr   equ 0x0b
dTimestamp  equ 0x16
dDatestamp  equ 0x18
dStartBlock equ 0x1a
dFileSize   equ 0x1c

; misc
bootOffset equ 0x7c00
FAT_SEGMENT     equ 0x0a00
FILE_SEGMENT    equ 0x0e00
