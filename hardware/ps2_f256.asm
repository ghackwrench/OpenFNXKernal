; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2023 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; This file implements the F256 low level PS2 transciever interface. 

            .cpu        "w65c02"
            .namespace  hardware
            .namespace  ps2


f256        .macro      BASE=$D640, PORT=0, IRQ=hardware.irq.ps2_0

                    .virtual    \BASE
KBD_MSE_CTRL_REG    .byte   ?   ; D640
KBD_MS_WR_DATA_REG  .byte   ?   ; D641
READ_SCAN_REG
KBD_RD_SCAN_REG     .byte   ?   ; D642
MS_RD_SCAN_REG      .byte   ?   ; D643
KBD_MS_RD_STATUS    .byte   ?   ; D644
KBD_MSE_NOT_USED    .byte   ?   ; D645
FIFO_BYTE_COUNT
KBD_FIFO_BYTE_CNT   .byte   ?   ; D646
MSE_FIFO_BYTE_CNT   .byte   ?   ; D647
                    .endv            

            .virtual    kernel.DevState
decoder     .byte       ?   ; Stream decoder.
            .endv
            
vectors     .kernel.device.mkdev    dev

init
            jsr     kernel.device.alloc
            bcs     _out

          ; Try to allocate a PS2 mode-2 keyboard stream decoder.
            phx
            jsr     hardware.kbd2.init
            txa
            plx
            bcc     +
            jsr     kernel.device.free
            sec
            bra     _out
+           sta     decoder,x

          ; Install our vectors.
            lda     #<vectors
            sta     kernel.src+0
            lda     #>vectors
            sta     kernel.src+1
            jsr     kernel.device.install

          ; Flush the port
            lda     #$10<<\PORT
            sta     KBD_MSE_CTRL_REG
            stz     KBD_MSE_CTRL_REG

          ; Associate ourselves with the interrupt.
            txa
            ldy     #\IRQ
            jsr     hardware.irq.install

          ; Enable the interrupt
            lda     #\IRQ
            jsr     hardware.irq.enable

            clc
_out        
            rts

dev_irq
            lda     KBD_MS_RD_STATUS
            bit     #1<<\PORT
            bne     _done

    lda     #2
    sta     io_ctrl
    inc     $c000+78
    stz     io_ctrl

            phx
            lda     decoder,x
            tax
            lda     READ_SCAN_REG+\PORT
            jsr     kernel.device.recv
            plx
            bra     dev_irq
            
_done
            rts

dev_send
    ; Every byte sent down the PS2 interface must be
    ; acknowledged before the next byte is sent, so
    ; no queuing is necessary.
    
          ; May be called any time; protect the registers
          ; from a potential key-stroke interrupt.
            php
            sei
            sta     KBD_MS_WR_DATA_REG
            lda     #2+6*\PORT
            sta     KBD_MSE_CTRL_REG
            stz     KBD_MSE_CTRL_REG
            plp
            rts

dev_recv
dev_ctrl
dev_status
dev_fetch
dev_get
dev_set
            sec
            rts

            .endm
            .endn
            .endn


