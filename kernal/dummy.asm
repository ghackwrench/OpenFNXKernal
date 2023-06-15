            .cpu    "w65c02"

kernel      .namespace

            .section    dp
kbd_queue   .byte       ?
src         .word       ?
dest        .word       ?
            .send
                        
            .section    kernel

init_key
            stz     kbd_queue
            rts

get_key
            lda     kbd_queue
            beq     _out
            stz     kbd_queue
_out            
            rts

put_key
            bcs     _done       ; Don't report non-ascii
            cpy     #0
            beq     _done       ; Don't report releases
            sta     kbd_queue
_done
            rts

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
            jsr     init_key
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
            jmp     Gadget.fork
            

        ; Install a "test" cli
            ldx     #0
-           lda     test,x
            sta     $2200,x     ; $0200 in userland
            inx
            cpx     #test_size
            bne     -
            stz     mmu_ctrl
            lda     #3
            sta     mmu
            ldx     #<$0200
            ldy     #>$0200
            jsr     Gadget.setptr
            jmp     Gadget.chainptr

            lda     #2
            sta     io_ctrl
            ldx     #0
_loop       lda     _test,x
            beq     _done
            sta     $c000,x
            inx
            bra     _loop
_done       
            lda     #2
            sta     io_ctrl
            inc     $c000+79
            jsr     get_key
            beq     _done
            ldx     #2
            stx     io_ctrl
            sta     $c000
            bra     _done

_test       .null   "pwned!"

            .send
            .endn
            
