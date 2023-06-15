; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "65c02"

            .namespace  kernel
io          .namespace

QUEUE_LEN   = 16        ; Must be a power of two.
LINE_LEN    = 80        ; Line buffer length.

            .section    dp
kbd_head    .byte       ?       ; Head of keyboard circular queue. 
kbd_tail    .byte       ?       ; Tail of keyboard circular queue.
line_length .byte       ?       ; # of chars in 'line' below.
reporting   .byte       ?       ; non-zero if chrin is reporting.
            .send            

            .section    kmem
kbd_queue   .fill       QUEUE_LEN   ; Simple keyboard buffer
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

chrout      
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

getin
            jsr     getch
            jmp     return_a            
            
chrin
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
            cmp     #13
            bne     _done
            stz     reporting
           
_done       jmp     return_a            
   


ioinit
setlfs
setnam
open
close
chkin
chkout
clrchn
clall
            rts

            .send
            .endn
            .endn
