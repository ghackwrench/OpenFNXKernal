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
            
MEMBOT
            bcc     set_bot

_load       ldx     mem_end+0
            ldy     mem_end+1
            jmp     return_xy

set_bot     stx     mem_end+0
            sty     mem_end+1
            rts

MEMTOP
            bcc     set_top

_load       ldx     mem_start+0
            ldy     mem_start+1
            jmp     return_xy

set_top     stx     mem_start+0
            sty     mem_start+1
            rts

            .send
            .endn
            .endn
            
