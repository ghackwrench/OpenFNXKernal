; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "65c02"

            .namespace  kernel

            .section    dp
mem_start   .word       ?
mem_end     .word       ?
            .send            

mem         .namespace
            .section    kernel

RAMTAS

    ; Users $0000-$1fff is mapped at our $2000.

            ldx     #2
-           stz     $2000,x
            inx
            bne     -
            stz     $2100
            stz     $2101

            ldx     #0
-           stz     $2200,x
            sta     $2300,x
            inx
            bne     -

            ldx     #<$800
            ldy     #>$800
            jsr     set_top

            ldx     #<$a000
            ldy     #>$a000
            jsr     set_bot

            rts


            
MEMBOT
            lda     user.carry
            beq     set_bot

_load       ldx     mem_end+0
            ldy     mem_end+1
            jmp     return_xy

set_bot     stx     mem_end+0
            sty     mem_end+1
            rts

MEMTOP
            lda     user.carry
            beq     set_top

_load       ldx     mem_start+0
            ldy     mem_start+1
            jmp     return_xy

set_top     stx     mem_start+0
            sty     mem_start+1
            rts

            .send
            .endn
            .endn
            
