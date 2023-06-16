; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "65c02"

            .namespace  kernel
io          .namespace

QUEUE_LEN   = 16        ; Must be a power of two.
LINE_LEN    = 80        ; Line buffer length.

          ; Variables for keyboard buffering.
            .section    dp
kbd_head    .byte       ?       ; Head of keyboard circular queue. 
kbd_tail    .byte       ?       ; Tail of keyboard circular queue.
            .send


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
kbd_queue   .fill       QUEUE_LEN   ; Simple keyboard buffer.
line        .fill       LINE_LEN    ; Q&D line buffer.
            .send
            
            .section    kernel
            
init
            stz     kbd_head
            stz     kbd_tail
            stz     line_length
            stz     reporting
            rts
            
key_pressed
    ; A contains the key, Y=1 (pressed) or Y=0 (released).
    ; Carry set on non-ASCII.
    ; Preserve X.


          ; Skip non-ascii events
            bcs     _done

          ; Ignore key released events
            cpy     #0
            beq     _done
            
        stz io_ctrl
        inc io_ctrl
        inc io_ctrl
        inc $c000+79
        stz io_ctrl

          ; Try to queue the key.
            ldy     kbd_head
            sta     kbd_queue,y
            tya
            inc     a
            and     #QUEUE_LEN - 1
            cmp     kbd_tail
            beq     _done
            sta     kbd_head
            clc
_done
            rts

CHROUT      
            lda     user.reg_a
            jmp     screen.putch

getch
            ldy     #0          ; No key found
            ldx     kbd_tail
            cpx     kbd_head
            beq     _done
            ldy     kbd_queue,x
            txa
            inc     a
            and     #QUEUE_LEN - 1
            sta     kbd_tail
_done       tya
            rts

GETIN
            jsr     getch
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
-           jsr     getch
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
           
_done       jmp     return_a            
   

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
            ldx     #<$c000
            ldy     #>$c000
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
            inc     dest+0
            bne     +
            inc     dest+1
+           bvc     -            
            
          ; Close.
            jsr     platform.iec.UNTALK                        
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
            lda     #$1f    ; Size of the vector table.
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
            .word   keyboard.stop
            .word   io.GETIN
            .word   io.clall
            .word   _user
            .word   io.LOAD
            .word   io.save


VECTOR
            lda     #$1f    ; Size of the vector table.
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
