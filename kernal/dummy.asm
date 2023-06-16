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

test
.if true
    .cpu "65816"
    sec
    xce
    .cpu "65c02"    
.endif
            lda     #2
            sta     io_ctrl
            
            jsr     $ffed
            stx     $c000
            sty     $c001
            bra     _loop

            ldx     #0
-           txa
            sta     $c000+800,x
            jsr     $ffd2
            inx
            bne     -
_loop       inc     $c000+79
            bra     _loop
test_size   = * - test
            
            
start
            jsr     hardware.irq.init
            jsr     device.init
            jsr     io.init
            jsr     f256.init

        ; Mount the CLI in the user's address space,
        ; and start it.

          ; Get our block ID.
            lda     #$80
            sta     mmu_ctrl
            ldx     mmu+7
            
          ; CLI follows
            inx
            
          ; Mount it under the I/O segment
            lda     #$b0        ; Edit #3 while running in #0.
            sta     mmu_ctrl
            stx     mmu+6
            
          ; Re-lock the MMU
            stz     mmu_ctrl
            
          ; Disable the I/O.
            lda     #4
            sta     io_ctrl
            
          ; Run the block at $c000
            jmp     userland
            
            .send
            .endn
            
