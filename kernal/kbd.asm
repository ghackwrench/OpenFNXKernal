; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2023 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel
kbd         .namespace

QUEUE_LEN   = 16        ; Must be a power of two.

            .section    dp
kbd_head    .byte       ?       ; Head of keyboard circular queue. 
kbd_tail    .byte       ?       ; Tail of keyboard circular queue.
stop        .byte       ?
            .send

            .section    kmem
kbd_queue   .fill       QUEUE_LEN   ; Simple keyboard buffer.
            .send
            
            .section    kernel

init
            stz     stop
            php
            sei
            stz     kbd_head
            stz     kbd_tail
            plp
            rts            

key_pressed
    ; A contains the key, Y=1 (pressed) or Y=0 (released).
    ; Carry set on non-ASCII.
    ; Preserve X.

          ; Skip non-ascii events for now.
            bcs     _done

          ; Ignore key released events
            cpy     #0
            beq     _done
            
          ; Immediately record a CTRL-C
            cmp     #3
            bne     +
            inc     stop
+            

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

get_key
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


SCNKEY
    ; IIRC, callers use this when they've otherwise disabled
    ; or redirected interrupts.  They otherwise none-the-less
    ; expect the keyboard ISR to update the various status
    ; flags.
    
          ; TODO: Possibly support user-initiated scanning
          ; of the VIA keyboard.
          
          ; TODO: Users will almost certainly want some form
          ; of keyboard state tracking, but that will likely
          ; be done generically in response to key events.
          
            rts

UDTIM
    ; Here b/c this function may be used to query for a CTRL-C.

            rts

STOP
            lda     stop
            bne     _stop
            
            lda     #$ff
            clc
            jmp     return_a
            
_stop
            jsr     io.clrchn
            jsr     init
            lda     #0
            sec
            jmp     return_a

            .send
            .endn
            .endn
