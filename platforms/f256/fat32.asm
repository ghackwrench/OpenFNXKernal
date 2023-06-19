; Modified code from the 65c02 TinyCore MicroKernel.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Hooks into the Commander X16 Fat32 library:
; Fat32 https://github.com/commanderx16/x16-rom
; Copyright 2020 Frank van den Hoef, Michael Steil.


            .cpu        "w65c02"

            .namespace  platform

sdcard      .namespace

                        .virtual    $8000
            
magic                   .word   ?
dirent                  .word   ?
size                    .word   ?

fat_init                .fill   3

get_error               .fill   3
get_size                .fill   3
set_size                .fill   3
set_ptr                 .fill   3
set_ptr2                .fill   3
set_time                .fill   3

fat32_alloc_context     .fill   3
fat32_set_context       .fill   3
fat32_free_context      .fill   3

fat32_mkfs              .fill   3

fat32_open              .fill   3
fat32_create            .fill   3
fat32_read              .fill   3
fat32_write             .fill   3
fat32_write_byte        .fill   3
seek                    .fill   3
fat32_close             .fill   3

fat32_rename            .fill   3
fat32_delete            .fill   3

fat32_open_dir          .fill   3
fat32_get_vollable      .fill   3
fat32_read_dirent       .fill   3
fat32_get_free_space    .fill   3
dat32_close_dir         .fill   3

fat32_mkdir             .fill   3
fat32_rmdir             .fill   3

                        .endv

            .section    pages
new_name    .fill       256
            .send            

            .section    hardware

SDCARD

          ; X = Function #.
            ldx     user.reg_x

          ; X = Vector of function.
            php
            txa
            asl     a
            tax
            plp
            cpx     #_table_size
            bcs     _error

          ; Bank in fat32's RAM.
            lda     #$80
            sta     mmu_ctrl
            lda     #9
            sta     mmu+1
            
          ; Load the registers.
            lda     user.carry
            lsr     a
            lda     user.reg_a
            ldy     user.reg_y

          ; Make sure $C000 is I/O.
            stz     io_ctrl

          ; Make the call.
            jsr     _call
            bcs     _return
            jsr     get_error

_return     
            stz     mmu+1       ; Bank the user's ZP back in.
            stz     mmu_ctrl    ; Re-lock the MMU.
            jmp     return_a            

_call       jmp     (_table,x)            
_error      clc
            lda     #0  ; Unspecified error
            bra     _return
_table
            .word   fat32_init
            .word   fat32_alloc_context
            .word   fat32_free_context
            .word   fat32_set_context
            .word   _error              ; get_context
            .word   open
            .word   create
            .word   close
            .word   _error              ; read
            .word   _error              ; write
            .word   read_byte
            .word   fat32_write_byte
            .word   _error              ; get_offset
            .word   _error              ; seek
            .word   open_dir
            .word   read_dirent
            .word   _error              ; read_dirent_filtered
            .word   _error              ; find_dirent
            .word   delete
            .word   rename
            .word   _error              ; set_attribute
            .word   _error              ; chdir
            .word   mkdir
            .word   rmdir
            .word   read_volume
            .word   _error              ; set_vollable
            .word   _error              ; get_free_space
            .word   fat32_mkfs
_table_size =   * - _table

fat32_init

          ; Verify that fat32 is installed.
            clc
            lda     magic+0
            eor     #$fa
            bne     _out
            lda     magic+1
            eor     #$32
            bne     _out

          ; Init is a wrapper, and it returns status in
          ; a/x, with zero->success.
            jsr     fat_init
            eor     #1
            ror     a

_out        rts

set_name
          ; Terminate the filename (passed in via SETNAM).
            ldx     kernel.io.fname_len
            stz     kernel.io.fname,x

          ; Give fat32 the name.
            lda     #>kernel.io.fname
            jmp     set_ptr

open
          ; Set the file name.
            jsr     set_name

          ; Open the file.
            jmp     fat32_open
            
create
          ; Preserve the carry (contains the overwrite flag).
            php

          ; Set the file name.
            jsr     set_name

          ; Restore the carry (C=1 for overwrite).
            plp

          ; Create the file.
            jmp     fat32_create
            
close
          ; TODO: set the time.
          
          ; Close the file.
            jmp     fat32_close

read_byte
    ; Hacky ... use the fname buffer.

          ; Stash the first byte of the name.
            ldx     kernel.io.fname
            phx

          ; Point fat32 at the fname buffer
            lda     #>kernel.io.fname
            jsr     set_ptr

          ; Request one byte.
            lda     #1
            jsr     set_size
            
          ; Read it.
            jsr     fat32_read
            lda     kernel.io.fname
            
          ; Restore the original fname byte.
            plx
            stx     kernel.io.fname
            
            rts
          

open_dir
          ; Terminate the filename (passed in via SETNAM).
            ldx     kernel.io.fname_len
            stz     kernel.io.fname,x

          ; Set path (null ptr for "current" directory).
            txa
            beq     +
            lda     #>kernel.io.fname
+           jsr     set_ptr

          ; Open the directory.
            jmp     fat32_open_dir

read_dirent

        ; Load the next entry into dirent.
            jsr     fat32_read_dirent
            bcc     _out
            bra     copy_dirent
_out        rts                       

read_volume
        ; Load the next entry into dirent.
            jsr     fat32_get_vollable
            bcc     _out
            bra     copy_dirent
_out        rts                       


copy_dirent
        ; Copy dirent to userland.
          
          ; 'src' is the address of fat32's dirent struct.
            lda     dirent+0
            sta     kernel.src+0
            lda     dirent+1
            sta     kernel.src+1

          ; X/Y = dest ptr
            ldx     user.reg_a
            ldy     user.reg_y

            stz     kernel.tmp  ; Copy 256 bytes.
            jsr     _copy
            lda     #15
            sta     kernel.tmp

_copy            
-           lda     (kernel.src)
            jsr     write_axy
            inc     kernel.src+0
            bne     +
            inc     kernel.src+1
+           inx
            bne     +
            iny
+           dec     kernel.tmp
            bne     - 

            sec
            rts                       

rename
    ; A = new name length
    ; Y = user page containing the new name.
    
          ; Make sure we have a new name.
            clc
            lda     user.reg_a
            beq     _err

          ; Copy the new name into our buffer and terminate.
            ldx     #0
            ldy     user.reg_y
-           jsr     read_axy
            sta     new_name,x
            inx
            cpx     user.reg_a
            bne     -
            stz     new_name,x

          ; Set the original name.
            jsr     set_name
            
          ; Set the new name.
            lda     #>new_name
            jsr     set_ptr2

          ; Chain to the fat32 rename function.
            jmp     fat32_rename
            
_err
            lda     #8  ; Missing file name.
            rts
       
delete

          ; Set the file name.
            jsr     set_name

          ; Delete the file
            jmp     fat32_delete


mkdir

          ; Set the file name.
            jsr     set_name

          ; mkdir
            jmp     fat32_mkdir


rmdir

          ; Set the file name.
            jsr     set_name

          ; rmdir
            jmp     fat32_rmdir


            .send
            .endn
            .endn
