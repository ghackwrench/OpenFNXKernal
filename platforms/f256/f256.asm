; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2023 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; This file implements the kernal as a TinyCore MicroKernel module
; for use on an F256jr or F256K.  The resulting F256.bin file may
; be written into the on-board flash, installed in a ROM cartridge, 
; or loaded into any 8k block of expansion RAM.

; This implementation is complex because it supports either a 65c02 
; or a 65816 in either native or emulation mode.  A MUCH simpler
; version could be cut for systems guaranteed to contain a 65c02.

            .cpu        "65c02"

*           = $0000     ; Kernel Direct-Page
mmu_ctrl    .byte       ?
io_ctrl     .byte       ?
reserved    .fill       6
mmu         .fill       8     ; MMU LUT full-view.
            .dsection   dp

            .virtual    $0200
            .dsection   pages
            .dsection   kmem
            .endv

SLOT        =   5       ; The MicroKernel will map us here.

*           = $E000     ; Assemble as if at $E000.

            .text       $f2,$56     ; Signature
            .byte       1           ; 1 block
            .byte       SLOT        ; mount at $a000
            .word       start       ; Start here
            .word       0           ; version
            .word       0           ; kernel
            .null       "pwn"       ; Slot 8

start       = boot & $1fff | ($2000 * SLOT)

            .dsection   tables
            .dsection   pwn
            .dsection   hardware
            .dsection   kernel      ; Moves to $A000

            .section    pwn

boot
          ; Disable interrupts.  Note, we can't do anything about
          ; an NMI or ABORT here.
            sei         

          ; Trash our signature.
            stz     $a000

          ; We expect to be running in MMU_3, with the kernel in MMU_0.
            lda     #$b3        ; Edit #3 while running in #3.
            sta     mmu_ctrl

          ; Get the ID of our block.
            ldy     mmu+SLOT

          ; Install ourselves in the kernel's map.
            lda     #$83        ; Edit #0 while running in #3.
            sta     mmu_ctrl
            sty     mmu+SLOT
            sty     mmu+7
            
          ; Switch to running in $E000
            stz     mmu_ctrl    ; We're still here.
            jmp     reset       ; We're also there.
            
reset
        ; MMU_3 is all RAM

          ; Switch to the kernel's map, editing MMU_3
            lda     #$b0        ; Edit #3 while running in #0.
            sta     mmu_ctrl

          ; MMU_3 is all RAM
            ldx     #0
-           txa
            sta     mmu,x
            inx
            cpx     #8
            bne     -            

       ; Set up the kernel's memory map
            lda     #$80        ; Editing and running in zero.
            sta     mmu_ctrl

          ; 0: Kernel's RAM (block 8)
            lda     #$8
            sta     mmu+0

          ; 1: User's ZP (block 0)
            clr     mmu+1
            
          ; 2: Kernel's block in user's map (block 7)
            lda     #7
            sta     mmu+2
            
          ; 3&4 will be fatfs
          
          ; 5: generic kernel code
            lda     mmu+7
            inc     a
            sta     mmu+5
            
          ; 6: I/O
          ; 7: boot and hardware magic

          ; Re-lock the MMU.
            stz     mmu_ctrl

        ; Install the kernel interface and IRQ vectors.

          ; Copy the relevant code.
            ldx     #0
-           lda     $fe00,x
            sta     $5e00,x
            lda     $ff00,x
            sta     $5f00,x
            inx
            bne     -            

        ; Jump to the new kernel's reset vector.
            jmp     kernel.start

flash
    ; Build a flash reset into slot zero and chain.
            ldx     #0
-           lda     _gate,x
            sta     $300,x
            inx
            cpx     #_gate_size
            bne     -          
            jmp     $300
_gate
            lda     #$80
            sta     mmu_ctrl
            lda     #$7f
            sta     mmu+7
            jmp     ($fffc)
_gate_size  =   * - _gate            

            .send

regs_t      .struct
reg_a       .word       ?
reg_x       .word       ?
reg_y       .word       ?
reg_s       .word       ?
carry       .word       ?
            .ends
            
            .virtual    $5e00
user        .dstruct    regs_t
            .endv            

* = $fd5d
vectors     = * & $ff00 ; Vectors is the page containing the vectors.
            .namespace  kernel
            .dstruct    kernel.vectors
            .endn

*   = $fe00
args        .dstruct    regs_t

return_a
            sta     user.reg_a+0
            stz     user.reg_a+1
            rts

return_axy
            sta     user.reg_a+0
            stz     user.reg_a+1
return_xy
            stx     user.reg_x+0
            stz     user.reg_x+1
            sty     user.reg_y+0
            stz     user.reg_y+1
            rts
        
* = $fe24   ; Magic vector for SCREEN ($FFED)

          ; Make like we JSR'd from $FFED (SCREEN trashes X)
            ldx     #$ed+2  ; SCREEN vector + 2
            phx             ; Garbage (8-bit push, 16 bit load)
            phx             ; vector (8 or 16)
            jmp     gate


* = $fe40   ; Magic vector for CLALL ($FFE7)

          ; Make like we JSR'd from $FFE7 (CLALL trashes A+X)
            lda     #$ed+2  ; CLALL vector + 2
            pha             ; Garbage (8-bit push, 16 bit load)
            pha             ; vector (8 or 16)
            jmp     gate

; 7 bytes here

* = $fe4c
nmi
    ; The overhead needed to "safely" switch maps inside an NMI
    ; handler is excessive, so anything we do  will need to be 
    ; local to the map in place at the time of the interrupt.
    ; This could either involve modifying an address (which could
    ; appear in different places depending on the map), or it
    ; could involve modifying an I/O register.  For now, we will
    ; clear the scratch register on the UART, and trust the general
    ; IRQ handler to detect and dispatch on this condition.
            .cpu "65816"
            sep     #$20        ; NOP on a 65c02
            .cpu "65c02"
            pha
            lda     io_ctrl
            stz     io_ctrl
            stz     $cdf0+7     ; UART_SR
            sta     io_ctrl
            pla
            rti                 ; Restores register state.
        

write_axy
            sta     (_const+1) - $e000 + $4000 ; In kernel map.
            stz     mmu_ctrl
            lda     #3; mmu
            sta     mmu_ctrl
            stx     _op+1
            sty     _op+2
_const      lda     #0
_op         sta     $ffff            
            stz     mmu_ctrl
            rts

read_axy
            stz     mmu_ctrl
            lda     #3; mmu
            sta     mmu_ctrl
            stx     _op+1
            sty     _op+2
_op         lda     $ffff
            stz     mmu_ctrl
            rts
            
mmu_reset
            stz     mmu_ctrl
            jmp     flash

irq_6502    
            pha     ; On user's stack.

          ; Switch to kernel's mmu and stack
            lda     mmu_ctrl
            stz     mmu_ctrl

          ; Call
            pha
            lda     io_ctrl

                pha
                phx
                phy
                jsr     kernel.irq
                ply
                plx
                pla

            sta     io_ctrl
            pla

          ; Back to the user's mmu and stack
            sta     mmu_ctrl
            
            pla
            rti

irq_816
            .cpu    "65816"
            bit     $fe         ; NOP here; $fe24 (below) as a vector.
					
          ; Save registers in their original modes.
            pha
            phx     ; onto user's stack
            phy
            phd     ; Dunno if this gets trashed when resuming 816 mode.

          ; Make sure we can hold S in C
            php                 ; Save register modes (816) onto user's stack
            rep     #$30        ; NOP on 65c02; X and C can hold the stack pointer.

          ; Save the current SP in X
            tsx

          ; Map SP into $01xx, preserving it's value if already there.
            tsc
            and     #$ff
            tcs

          ; Grab the current mmu and i/o config in A.
            lda     $0

          ; We are, by definition, in usermode when this happens, so
          ; we can save locally.
            sta     _rest_a+1
            stx     _rest_x+1
          
          ; Switch CPU modes so the stack will wrap
            clc
            xce

          ; Switch to the kernel's stack, call, and switch back.
            pha
            stz     $0
            jsr     kernel.irq
            pla
            sta     $0

          ; Back to 16 bit 816 mode.
            sec
            xce
            rep     #$30

          ; Restore the stack
_rest_x     ldx     #0  
            txs          

          ; Restore the config
_rest_a     lda     #0
            sta     $0

          ; Restore the registers
            plp
            pld
            ply
            plx
            pla

            rti            
            .cpu    "65c02"


* = $fefe   ; Magic vector for UDTIM ($FFEA)

          ; Make like we JSR'd from $FFEA (UDTIM trashes A+X)
            lda     #$ea+2  ; UDTIM vector + 2
            pha     ; garbage (8-bit push, 16 bit load)
            pha     ; vector (8 or 16)

          ; Fall through to gate.
            
gate
    ; 65c02 / 65816 compatible cross-map call gate.

          ; Save the args in a reserved region.
            sta     args.reg_a
            stx     args.reg_x
            sty     args.reg_y
            stz     args.carry
            rol     args.carry

          ; Save the stack (might be a 16 bit pointer)
            tsx
            stx     args.reg_s

          ; Force 8/8, leaving the original mode in A.
            php
            .cpu    "65816"
            sep     #$30        ; 8x8; NOP on the 65c02.
            .cpu    "65c02"
            pla                 ; 'A' contains the original config.

          ; Clear the decimal flag so we don't need to worry.
            cld

          ; Pull the call vector off the stack while we have it.
            plx
            ply     ; garbage (generally $ff); don't need it.

          ; Force stack to $1xx before switching to MMU_0.
          ; Users MUST reserve $1xx for possible stack use by the 
          ; CPU during an interrupt.
            .cpu    "65816"
            sec                 ; Emulation mode
            xce                 ; NOP on a 65c02, stack now in $1xx.
            xce                 ; NOP on a 65c02, 816 mode restored.    
            .cpu    "65c02"

          ; Stash the original CPU mode on the user's $01xx stack.
            pha

          ; Grab the original MMU settings.
            lda     mmu_ctrl

          ; Switch to the kernel's stack
            stz     mmu_ctrl

          ; Save the MMU settings on the kernel's stack.
            pha

          ; Call the vector in the kernel's map.
            jsr     _call

          ; Restore the user's MMU and stack
            pla
            sta     mmu_ctrl
            
          ; Restore the processor state plus the current carry.
            rol     a       ; LSB contains the carry.
            plp             ; Restore the original CPU state. 
            ror     a       ; Restore the carry state.

          ; Restore the stack.
            ldx     args.reg_s
            inx
            inx
            txs

          ; Restore the registers.
            lda     args.reg_a
            ldx     args.reg_x
            ldy     args.reg_y
            
          ; Return to caller
            rts            

_call       
            jmp     (vectors-1,x)       ; The jmp /target/ (I know...)



disp_nmi
            lda     $cdf0+7
            bne     +
            jsr     kernel.nmi
            inc     $cdf0+7
+           rts

userland
            lda     #3
            sta     mmu_ctrl
            lda     #4
            sta     io_ctrl
            jmp     ($c000)
             
* = $ff5d
          ; Populate the "normal" vectors.
          ; The last two overlap with 816 native COP and BRK,
          ; so those two features are presently unavailable.
            .for    i := $5d, i < $e7, i += 3
            jsr     gate
            .next
            
          ; Build the special "twisty" vectors.
          ; These are CBM vectors which overlap 816 native vectors.

          ; $FFE7: CLALL and native ABORT.
            .byte   $6c     ; jmp indirect for CLALL
            .word   abort   ; Vector for abort handler.

          ; $FFEA: UDTIM and native NMI
            .byte   $4c     ; jmp for UDTIM; addr low for native NMI.
            .byte   $fe     ; addr high for native NMI, addr low for UDTIM.
            .byte   $fe     ; addr high for UDTIM.
            
          ; $FFED: SCREEN and native IRQ
            .byte   $6c     ; jmp indirect for SCREEN.
            .word   irq_816 ; vector for irq; irq starts w/ &screen :).
          
          ; $FFF0: PLOT
            jsr     gate
            
          ; $FFF3: IOBASE and emulation COP (don't use!)
            jsr     gate

          ; $FFF6   ; Stash our emulation ABORT handler here.
abort       .byte   $40 ; rti for ABORT; lsb for CLALL
            .byte   $fe ; msb for CLALL
            
          ; $FFF8   ; emulation ABORT vector
            .word   abort

          ; $FFFA - original 6502 vectors
            .word   nmi
            .word   mmu_reset
            .word   irq_6502                     

