; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2023 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; This file implements the raw device driver interface.

            .cpu        "w65c02"
            
            .namespace  kernel

            .section    pages
Device      .fill       256
DevBuf      .fill       256
DevState    .fill       256
            .send    

device      .namespace

mkdev       .macro  PREFIX
            .word   \1_irq
            .word   \1_send
            .word   \1_recv
            .word   \1_ctrl
            .word   \1_status
            .word   \1_fetch
            .word   \1_get
            .word   \1_set
            .endm

            .section    kernel
irq         jmp     (Device+$0,x)
send        jmp     (Device+$2,x)
recv        jmp     (Device+$4,x)
ctrl        jmp     (Device+$6,x)
status      jmp     (Device+$8,x)
fetch       jmp     (Device+$a,x)
get         jmp     (Device+$c,x)
set         jmp     (Device+$e,x)
            .send

            .section    dp
entries     .byte       ?
            .send            

            .section    kernel
init
            stz     entries
            lda     #16
-           tax
            jsr     free
            adc     #16
            bne     -            
            clc
            rts
            
alloc
            sec
            ldx     entries
            beq     +
            pha
            lda     Device,x
            sta     entries
            pla
            clc
+           rts

free
            pha
            lda     entries
            sta     Device,x
            stx     entries
            pla
            rts

install                        
            phx
            phy

            ldy     #0
-           lda     (kernel.src),y
            iny
            sta     Device,x
            inx
            cpy     #16
            bne     -          
            
            ply
            plx
            rts
            

            .send
            .endn
            .endn
            
