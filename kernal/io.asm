; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "65c02"

            .namespace  kernel
io          .namespace

LINE_LEN    = 80        ; Line buffer length.


          ; Variables for SETLFS & SETNAM.
          
            .section    dp
file_id     .byte       ?
device_id   .byte       ?
channel_id  .byte       ?
fname_len   .byte       ?
            .send

            .section    pages
fname       .fill       256         ; File name copied from userland.
            .send

          ; Variables for CHRIN.
            .section    dp
line_length .byte       ?       ; # of chars in 'line' below.
reporting   .byte       ?       ; non-zero if chrin is reporting.
            .send            

            .section    kmem
line        .fill       LINE_LEN    ; Q&D line buffer.
            .send
            
            .section    kernel
            
init
            jsr     kbd.init
            stz     line_length
            stz     reporting
            rts
            
READST
          ; TODO: implement.

            lda     #0
            jmp     return_a

CHROUT      
            lda     user.reg_a
            jmp     screen.putch

GETIN
            jsr     kbd.get_key
            clc
            jmp     return_a
            
CHRIN
    ; CHRIN on stdin is modal ... it provides screen editing until
    ; <ENTER> is pressed, then it returns the contents of the current
    ; line, including the carriage return.
    
          ; Handle reporting.
            ldy     reporting
            bne     _report

          ; Read a key.
_getch      jsr     screen.cursor_on
-           jsr     kbd.get_key
            beq     -
            jsr     screen.cursor_off            

          ; TODO: at least handle backspace...
          ; (this whole function is just a stub)

          ; Try to append it to the line buffer.
            ldy     line_length
            cpy     #LINE_LEN
            bcs     _getch
            sta     line,y
            inc     line_length

          ; Write it to the screen
            jsr     screen.putch
            
          ; If it's not <ENTER>, get another key.
            cmp     #13
            bne     _getch
            
          ; Start reporting
            ldy     #0

_report
            lda     line,y
            inc     reporting
     
          ; BASIC expects all tokens in upper-case.
          ; OpenKernal only upcases characters not
          ; in quotes, but this code is mostly for
          ; demonstration purposes. Make it your own.
            cmp     #'a'
            bcc     _ok
            cmp     #'z'+1
            bcs     _ok
            eor     #32     ; Toggle lower to upper.

_ok         cmp     #13
            bne     _done
            stz     line_length
            stz     reporting
           
_done       clc
            jmp     return_a            
   

SCINIT
          ; TODO: restore default I/O to keyboard/screen.
            
          ; Re-init the video.
            lda     #$36
            jmp     screen.init

IOINIT
          ; CIA already initialized by platform code;
          ; could potentially do it here-ish instead.

          ; TODO: init the SIDs.

          ; Set memory top.
            ldx     #<$800
            ldy     #>$800
            jsr     mem.set_top

          ; Set memory bottom.
            ldx     #<$a000
            ldy     #>$a000
            jsr     mem.set_bot

          ; Interrupt timer already initialized by platform code;
          ; could potentially do it here, instead.

            rts

IOBASE
            ldx     #<$dc00
            ldy     #>$dc00
            jmp     return_xy

SETLFS
            lda     user.reg_a
            ldx     user.reg_x
            ldy     user.reg_y
            
            sta     file_id
            stx     device_id
            sty     channel_id

            rts

SETNAM
            stz     dest+0
            lda     #>fname
            sta     dest+1
            
            lda     user.reg_a
            sta     fname_len
            sta     tmp

            ldx     user.reg_x
            ldy     user.reg_y
-           jsr     read_axy
            sta     (dest)
            inc     dest+0
            dec     tmp
            bne     -

            rts

LOAD
            lda     user.reg_a
            bne     _verify            

            lda     user.reg_x
            sta     dest+0
            lda     user.reg_y
            sta     dest+1 

          ; Open the file by name.

            lda     device_id
            jsr     platform.iec.LISTEN
            bcs     _error
            
            lda     channel_id
            jsr     platform.iec.OPEN
            bcs     _error
            
            ldx     #0
-           lda     fname,x
            jsr     platform.iec.IECOUT
            bcs     _error
            inx
            cpx     fname_len
            bne     -
            
            jsr     platform.iec.UNLISTEN
            bcs     _error
                        
            
          ; Read the data.
          
            lda     device_id
            jsr     platform.iec.TALK
            bcs     _error
            
            lda     channel_id
            jsr     platform.iec.DEV_SEND
            bcs     _error
            
-           jsr     platform.iec.IECIN
            bcs     _error  ; TODO: not-found if first read.
            ldx     dest+0
            ldy     dest+1
            jsr     write_axy
            bvs     _close
            inc     dest+0
            bne     +
            inc     dest+1
+           bra     -            
            
          ; Close.
_close      jsr     platform.iec.UNTALK                        
            lda     device_id
            jsr     platform.iec.LISTEN
            lda     channel_id
            jsr     platform.iec.CLOSE
            jsr     platform.iec.UNLISTEN
            

          ; Return end of data.
            ldx     dest+0
            ldy     dest+1
            clc
            jmp     return_xy
            
_error
            lda     #0
            sec
            jmp     return_a

_verify
            sec
            lda     #0
            jmp     return_a

open
close
chkin
chkout
clrchn
clall
save
            rts

RESTOR
            lda     #$20    ; Size of the vector table.
            sta     tmp

            lda     #<_iovec
            sta     src+0
            lda     #>_iovec
            sta     src+1
 
            ldx     #<$314
            ldy     #>$314
-           lda     (src)
            jsr     write_axy
            inc     src+0
            bne     +
            inc     src+1
+           inx            
            dec     tmp
            bne     -
_user       rts
_break      rts
_iovec
            .word   irq_6502    ; Not safe for 816 code.
            .word   _break      ; TODO: Not sure what belongs here.
            .word   nmi
            .word   io.open     
            .word   io.close
            .word   io.chkin
            .word   io.chkout
            .word   io.clrchn
            .word   io.CHRIN
            .word   io.CHROUT
            .word   kbd.STOP
            .word   io.GETIN
            .word   io.clall
            .word   _user
            .word   io.LOAD
            .word   io.save


VECTOR
            lda     #$20    ; Size of the vector table.
            sta     tmp

            lda     user.carry
            bne     _out
        
_in
            lda     #<$2000+$314
            sta     dest+0
            lda     #>$2000+$314
            sta     dest+1
 
            ldx     user.reg_x
            ldy     user.reg_y
-           jsr     read_axy
            sta     (dest)
            inc     dest
            inx     
            bne     +
            iny
+           dec     tmp
            bne     -
            rts

_out
            lda     #<$2000+$314
            sta     src+0
            lda     #>$2000+$314
            sta     src+1
 
            ldx     user.reg_x
            ldy     user.reg_y
-           lda     (src)
            jsr     write_axy
            inc     src
            inx     
            bne     +
            iny
+           dec     tmp
            bne     -
            rts


            .send
            .endn
            .endn
