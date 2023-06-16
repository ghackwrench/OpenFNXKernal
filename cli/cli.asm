; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Simple command-line interface for use when nothing else is included.

            .cpu    "w65c02"

*           =   $0000   ; Direct page
mmu_ctrl    .byte       ?
io_ctrl     .byte       ?
reserved    .fill       6
mmu         .fill       8       ; MMU LUT full-view.
            .dsection   dp

*           =   $200
            .dsection   data

*           =   $300    ; Just after the data
org         .word       shell.start + $c000 - org
            .dsection   strings
            .dsection   code
org_size    = * - org

shell       .namespace            

            .section    dp
src         .word       ?
dest        .word       ?
printing    .word       ?
device      .byte       ?
            .send            

            .section    data
cmd         .fill   80
            .send

            .section    strings

strings:
str         .namespace
unknown     .text   "?", 13, 0
prompt      .text   13,"READY DEVICE",0
dir         .null   "DIR"
stat        .null   "STAT"
rds         .null   "RDS"
cls         .null   "CLS"
list        .null   "LIST"
load        .null   "LOAD"
drive       .null   "DRIVE"
run         .null   "RUN"
sys         .null   "SYS"
help        .null   "HELP"
            .endn

commands
            .word   str.cls,    cls
            .word   str.dir,    dir
;            .word   str.list,   list
;            .word   str.load,   load
            .word   str.drive,  drive
;            .word   str.run,    platform.far_exec
            .word   str.help,   help
            .byte   0           


            .send
            
            .section    code

start
    ; The following code will be run in block 6 while the
    ; rest of the code is running in block 1.  Thus, the
    ; following must be position independent.

            lda     #$c0
            sta     src+1
            stz     src+0

            lda     #>org
            sta     dest+1
            lda     #<org
            sta     dest+0

            ldy     #0
            ldx     #>org_size
            beq     _bytes
_page       lda     (src),y
            sta     (dest),y
            iny
            bne     _page
            inc     src+1
            inc     dest+1
            dex
            bne     _page

_bytes      ldx     #<org_size
            beq     _done
_byte       lda     (src),y
            sta     (dest),y
            iny
            dex
            bne     _byte

_done       jmp     shell

put_str
    ; Y = LSB of a string in the 'strings' section above.
            sty     src+0
            ldy     #>strings
            sty     src+1
            bra     puts_src
puts
    ; X = LSB, Y = MSB of string to print. 
            stx     src+0
            sty     src+1
puts_src
            ldy     #0
_loop       lda     (src),y
            beq     _done
            jsr     CHROUT
            iny
            bne     _loop
            inc     src+1
            bra     _loop
_done       rts

banner
            ldx     #<_text
            ldy     #>_text
            jmp     puts
_text       .text   "Simple CLI for the C64 ABI.",13
            .text   "Type 'help' for help.",13,0

help
            ldx     #<_text
            ldy     #>_text
            jsr     puts
            clc
            rts
_text
            .text   13,"Supported commands:",13
            .text   "   cls         Clears the screen.",13
            .text   "   drive #     Changes the drive to #.",13
            .text   "   dir         Displays the directory.",13
            .text   "   load",$22,"fname",$22," Loads the given file ',1'.", 13
            .text   "   list        LISTs directories and simple programs.",13
            .text   "   run         Runs loaded programs.",13
            .text   "   help        Shows this help.",13
            .text   13,0

stop
            lda     #2
            sta     io_ctrl
_loop       inc     $c000+77
            bra     _loop            

shell
            jsr     SCINIT
            jsr     banner

            lda     #8
            sta     device

            jsr     prompt
_loop       jsr     get_cmd
            jsr     do_cmd
            bcc     _loop

            ldy     #<str.unknown
            jsr     put_str
            bra     _loop

prompt
            ldy     #<str.prompt
            jsr     put_str
            lda     #' '
            jsr     CHROUT
            lda     device
            ora     #'0'
            jsr     CHROUT
            jmp     cr
            
cr
            lda     #13
            jmp     CHROUT

get_cmd
            ldx     #0
_loop       phx           
            jsr     CHRIN

            plx
            sta     cmd,x
            inx
            cmp     #13
            bne     _loop
            jmp     CHROUT

do_cmd
            clc
            ldx     #0              ; Start of table
_loop       ldy     commands,x      ; Offset of next command in strings
            beq     error

          ; Move X to the address of the implementation
            inx
            inx

          ; Try to find a match with the command.
            jsr     strcmp
            bcs     _next       ; Not found

            jsr     _call       
            bcc     _ready

          ; Print an error if the command failed.            
            jsr     error
_ready            
            jmp     prompt
_next
          ; Advance to the next entry.
            inx
            inx
            bra     _loop
_out                    
            rts
_call
            jmp     (commands,x)

strcmp
          ; Point 'src' at the potential match.
            sty     src+0
            lda     #>strings
            sta     src+1

          ; Compare it to the string in 'cmd'.
            ldy     #0
-           lda     (src),y
            beq     _end
            cmp     cmd,y
            bne     _failed
            iny
            bra     -
_end        lda     cmd,y
            cmp     #13
            beq     _found
            cmp     #32
            beq     _found
_failed     sec
            rts            
_found      clc
            rts

error
            ldx     #<_text
            ldy     #>_text
            jsr     puts
            clc
            rts
_text       .text   "Unknown command.",13,0            

find_arg
    ; IN: Y points just beyond the command string

_loop
            lda     cmd,y
            cmp     #' '
            beq     _next
            cmp     #13
            beq     _error
            clc
            rts
_next
            iny
            bne     _loop
_error
            sec
            rts                                    

; Commands

cls         lda     #12
            jsr     CHROUT
            clc
            rts

drive
            jsr     find_arg
            lda     #ILLEGAL_DEVICE_NUMBER
            bcs     _done

            lda     cmd,y
            cmp     #'8'
            beq     _set
            cmp     #'9'
            beq     _set

            lda     #ILLEGAL_DEVICE_NUMBER
            sec
_done       
            rts
_set
            sbc     #'0'
            sta     device
            clc
            bra     _done                        

dir
            phx
            phy

          ; Point 'src' at the file name ("$").
            ldx     #<_fname
            ldy     #>_fname
            lda     #1
            jsr     SETNAM

          ; Request operation on 0,device,0
            lda     #0      ; Logical device # ... not meaningful here.
            ldx     device
            ldy     #0      ; No sub-device / "command" -> use $0801
            jsr     SETLFS

          ; Load the data
            lda     #0      ; load, not verify
            ldx     #<$801
            ldy     #>$801
            jsr     LOAD
            bcs     _out    ; TODO: print the error
            
          ; Show the data
            jsr     list
            
_out
            ply
            plx
            rts
_fname      .text   "$"            

list
            sec
            rts


            .send 
            .endn
                     

