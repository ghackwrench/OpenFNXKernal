            .cpu    "w65c02"

kernel      .namespace

            .section    dp
tmp         .byte       ?
src         .word       ?
dest        .word       ?

            .send
                        
            .section    kernel

nmi
            rts

irq         = hardware.irq.dispatch

            
start
            jsr     hardware.irq.init   ; Init the IRQ dispatcher.
            jsr     device.init         ; Init the kernel's device pool.
            jsr     io.init             ; Init the kernel's i/o system.
            jsr     f256.init           ; Init the platform devices.
            jsr     IOINIT
            jsr     SCINIT
            jsr     RAMTAS

        ; Mount the CLI in the user's address space,
        ; and start it.

          ; Get our block ID.
            lda     #$80
            sta     mmu_ctrl
            ldx     mmu+7
            
          ; CLI follows
            inx

          ; Mount it at $a000
            lda     #$b0        ; Edit #3 while running in #0.
            sta     mmu_ctrl
            stx     mmu+5
            
          ; Back to the kernel map.
            lda     #$80
            sta     mmu_ctrl

          ; Copy first five pages of the following block into
          ; the user's $E000 block.
            inx
            stx     mmu+1
            ldy     #0
-           .for    i := 0, i < $500, i += $100
            lda     $2000+i,y
            sta     $4000+i,y       
            .next
            iny
            bne     -
            
          ; Restore the shadow of the user's zp 
            stz     mmu+1

          ; Re-lock the MMU
            stz     mmu_ctrl
            
          ; Run the block at $a000
            jmp     userland


.if false            
          ; Mount it under the I/O segment
            lda     #$b0        ; Edit #3 while running in #0.
            sta     mmu_ctrl
            stx     mmu+6
            
          ; Re-lock the MMU
            stz     mmu_ctrl
            
          ; Disable the I/O.
            lda     #4
            sta     io_ctrl
            
          ; Run the block at $a000
            jmp     userland
.endif            
            .send
            .endn
            
