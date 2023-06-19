;Vectors:
            .virtual    $ff81-1*3
SDCARD      .fill   3

SCINIT      .fill   3
IOINIT      .fill   3
RAMTAS      .fill   3
RESTOR      .fill   3
VECTOR      .fill   3
SETMSG      .fill   3
LSTNSA      .fill   3
TALKSA      .fill   3
MEMBOT      .fill   3
MEMTOP      .fill   3
SCNKEY      .fill   3
SETTMO      .fill   3
IECIN       .fill   3
IECOUT      .fill   3
UNTALK      .fill   3
UNLSTN      .fill   3
LISTEN      .fill   3
TALK        .fill   3
READST      .fill   3
SETLFS      .fill   3
SETNAM      .fill   3
OPEN        .fill   3
CLOSE       .fill   3
CHKIN       .fill   3
CHKOUT      .fill   3
CLRCHN      .fill   3
CHRIN       .fill   3
CHROUT      .fill   3
LOAD        .fill   3
SAVE        .fill   3
SETTIM      .fill   3
RDTIM       .fill   3
STOP        .fill   3
GETIN       .fill   3
CLALL       .fill   3
UDTIM       .fill   3
SCREEN      .fill   3
PLOT        .fill   3
IOBASE      .fill   3
            .endv

; KERNAL errors:

TOO_MANY_FILES          =   1
FILE_OPEN               =   2
FILE_NOT_OPEN           =   3
FILE_NOT_FOUND          =   4
DEVICE_NOT_PRESENT      =   5
NOT_INPUT_FILE          =   6
NOT_OUTPUT_FILE         =   7
MISSING_FILE_NAME       =   8
ILLEGAL_DEVICE_NUMBER   =   9

; FAT32 operations (load in X before calling SDCARD):

                .virtual    0
FAT_INIT        .byte       ?            
FAT_CTX_NEW     .byte       ?            
FAT_CTX_FREE    .byte       ?
FAT_CTX_SET     .byte       ?
                .byte       ?
FAT_FOPEN       .byte       ?
FAT_FCREATE     .byte       ?   ; Set carry to overwrite.
FAT_FCLOSE      .byte       ?
                .byte       ?
                .byte       ?
FAT_READ        .byte       ?
FAT_WRITE       .byte       ?
                .byte       ?
                .byte       ?
FAT_DOPEN       .byte       ?
FAT_DREAD       .byte       ?   ; A/Y = address of dirent struct.
FAT_DCLOSE      = FAT_FCLOSE
                .byte       ?
                .byte       ?
FAT_DELETE      .byte       ?
FAT_RENAME      .byte       ?   ; Y=page w/ new name, A=length of new name.
                .byte       ?
                .byte       ?
FAT_MKDIR       .byte       ?
FAT_RMDIR       .byte       ?
FAT_VREAD       .byte       ?   ; A/Y = address of dirent struct.
                .byte       ?
                .byte       ?
FAT_MKFS        .byte       ?
                .endv                                                                        

; FAT32 dirent structure:

dirent_t        .struct
fname           .fill   256
attributes      .byte   ?
start           .dword  ?   ; start cluster
size            .dword  ?   ; size in bytes
mtime_year      .byte   ?
mtime_month     .byte   ?
mtime_day       .byte   ?
mtime_hours     .byte   ?
mtime_minutes   .byte   ?
mtime_seconds   .byte   ?
                .ends

; Fat32 errors:

ERRNO_OK               = 0
ERRNO_READ             = 1
ERRNO_WRITE            = 2
ERRNO_ILLEGAL_FILENAME = 3
ERRNO_FILE_EXISTS      = 4
ERRNO_FILE_NOT_FOUND   = 5
ERRNO_FILE_READ_ONLY   = 6
ERRNO_DIR_NOT_EMPTY    = 7
ERRNO_NO_MEDIA         = 8
ERRNO_NO_FS            = 9
ERRNO_FS_INCONSISTENT  = 10
ERRNO_WRITE_PROTECT_ON = 11
ERRNO_OUT_OF_RESOURCES = 12

