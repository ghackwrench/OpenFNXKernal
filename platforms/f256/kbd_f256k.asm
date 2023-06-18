; Modified code from the 65c02 TinyCore MicroKernel
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; Driver for a VIC20/C264 keyboard connected to the 6522 port.

            .cpu        "w65c02"

            .namespace  platform
jr_kbd      .namespace

driver      .macro  IRQ=hardware.irq.frame

vectors     .kernel.device.mkdev    dev

init

      ; Verify that we have a valid IRQ id.
        lda     #\IRQ
        jsr     hardware.irq.disable
        bcs     _out

        jsr     platform.jr_kbd.init

      ; Allocate the device table entry.
        jsr     kernel.device.alloc
        bcs     _out
        
      ; Install our vectors.
        lda     #<vectors
        sta     kernel.src+0
        lda     #>vectors
        sta     kernel.src+1
        jsr     kernel.device.install

      ; Associate ourselves with the line interrupt
        txa
        ldy     #\IRQ
        jsr     hardware.irq.install
        
      ; Enable the hardware interrupt.
        lda     #\IRQ
    	jsr     hardware.irq.enable
    	
        clc
_out    rts       

dev_irq     = platform.jr_kbd.scan
   
dev_send
dev_recv
dev_ctrl
dev_status
dev_fetch
dev_get
dev_set
    rts

        .endm

JRA  =  $dc01  ; CIA#1 (Port Register A)
JDRA =  $dc03  ; CIA#1 (Data Direction Register A)

JRB  =  $dc00  ; CIA#1 (Port Register B)
JDRB =  $dc02  ; CIA#1 (Data Direction Register B)

PRA  =  $db01  ; CIA#1 (Port Register A)
DDRA =  $db03  ; CIA#1 (Data Direction Register A)

PRB  =  $db00  ; CIA#1 (Port Register B)
DDRB =  $db02  ; CIA#1 (Data Direction Register B)

        .section    dp  ; Could be in kmem or dev mem.
enabled .byte       ?   ; negative if keyscanning enabled.
mask    .byte       ?   ; Copy of PRA output
hold    .byte       ?   ; Copy of PRB during processing
bitno   .byte       ?   ; # of the col bit being processed
event   .byte       ?   ; PRESSED or RELEASED
raw     .byte       ?   ; Raw code
flags   .byte       ?   ; Flags
caps    .byte       ?   ; capslock set
        .send

        .section    dp  ; could be in kmem.
state:  .fill       8+1 ; key tracking (PB bits) w/ extra column
extra:  .byte       ?   ; Collected bits from extra column
        .send

PRESSED     = 1
RELEASED    = 0

        .section    hardware
        
init:
        stz     io_ctrl

      ; Turn off capslock
        jsr     caps_released

      ; CIA0 (joystick, two keys)
        lda     #$7f    ; output: pull-ups to bits 0-6, 7 hi-z (not used).
        sta     JDRA
        sta     JRA     ; pull-ups for 0-6
        stz     JRB     ; input

      ; CIA#1 port A = outputs 
        lda     #$ff    
        sta     DDRA             
        sta     PRA

      ; CIA#1 port B = inputs
        lda     #$00    
        sta     DDRB   

      ; Init the roll-table
        lda     #$ff    ; no key grounded
        ldx     #7+1    ; + extra col
_loop   sta     state,x
        dex
        bpl     _loop

        clc
        rts

        
scan
        stz     io_ctrl

      ; Set up the keyboard scan
        lda     #$7f
        ldx     #0
        
_loop   
        sta     PRA
        sta     mask        

      ; Extra column
        lda     JRB
        rol     a
        rol     extra
      
      ; Regular columns
        lda     PRB
        sta     hold
        eor     state,x
        beq     _next

        jsr     report        

_next
        inx
        lda     mask
        sec
        ror     a
        bcs     _loop

      ; Leave PRA ready for a joystick read.
        sta     PRA
        
      ; Report any changes associated with the extra column.
        lda     extra
        sta     hold
        eor     state,x
        beq     _done
        jsr     report

_done
        rts


report

    ; Current state doesn't match last state.
    ; Walk the bits and report any new keys.

_loop ; Process any bits that differ between PRB and state,x

      ; Y->next diff bit to check
        tay
        lda     hardware.irq.first_bit,y
        sta     bitno
        tay

      ; Clear the current state for this bit
        lda     hardware.irq.bit,y   ; 'A' contains a single diff-bit
        eor     #$ff
        and     state,x
        sta     state,x

      ; Report key and update the state
        lda     hardware.irq.bit,y   ; 'A' contains a single diff-bit
        and     hold        ; Get the state of this specific bit
        bne     _released   ; Key is released; report it
        pha
        jsr     _pressed    ; Key is pressed; report it.
        pla
_save
      ; Save the state of the bit
        ora     state,x
        sta     state,x
_next  
        lda     hold
        eor     state,x
        bne     _loop 

_done   rts

_pressed
        lda     #PRESSED
        bra     _report
_released
        pha
        lda     #RELEASED
        jsr     _report        
        pla
        bra     _save

_report
        sta     event

      ; A = row #
        txa     ; Row #

      ; Bit numbers are the reverse of
      ; the table order, so advance one
      ; row and then "back up" by bitno.
        inc     a

      ; A = table offset for row
        asl     a
        asl     a
        asl     a

      ; A = table entry for key
        sbc     bitno
        
      ; Y-> table entry
        tay

        lda     keytab,y
        sta     raw

      ; If it's a meta-key, the ascii is zero, queue.
        cmp     #16
        bcs     _key
        cmp     #CAPS
        beq     _caps
        lda     #$80
        sta     flags
        lda     #0
        bra     _queue
_caps   jmp     capslock
_key
        stz     flags
        
      ; Handle special Foenix keys
        lda     state+0
        bit     #32
        beq     _foenix

      ; Always handle SHIFT; lots of special keys are shifted.
        bit     caps
        bmi     _shift
        lda     state+1
        bit     #16
        beq     _shift
        lda     state+6
        bpl     _shift
        lda     raw

      ; Translate special keys into ctrl codes and queue
_emacs
        cmp     #$80
        bcs     _special

_ctrl
        pha
        lda     state+0
        bit     #4
        bne     _alt
        pla
        and     #$1f
        pha
        lda     state+0
        
_alt
        and     #32
        cmp     #32
        pla
        
        bcs     _queue
        ora     #$80
        
_queue

        phy

      ; 'A' contains the ASCII (if valid).

      ; Set carry on non-ascii.
        ldy     flags
        cpy     #1
        
      ; Y = pressed/released.
        ldy     event
        
      ; Queue.
        jsr     kernel.kbd.key_pressed
        
        ply
        rts


.if false
        phy
        jsr     kernel.event.alloc
        bcs     _end    ; TODO: beep or something
            
        sta     kernel.event.entry.key.ascii,y
        lda     raw
        sta     kernel.event.entry.key.raw,y
        lda     flags
        sta     kernel.event.entry.key.flags,y
        lda     event
        sta     kernel.event.entry.type,y
            
        jsr     kernel.event.enque
_end
        ply
        rts        
.endif

_foenix
        lda     raw
        jsr     map_foenix
        bra     _emacs

_shift
        lda     shift,y
        bra     _emacs

_out    rts

_special
        phy
        ldy     #0
_l2
        cmp     _map,y
        beq     _found
        iny
        iny
        cpy     #_emap
        bne     _l2
        ply
        bra     _queue
_found
        lda     _map+1,y
        ply        
        bra     _queue
_map
        .byte   HOME,   'A'-64
        .byte   END,    'E'-64
        .byte   UP,     'P'-64
        .byte   DOWN,   'N'-64
        .byte   LEFT,   'B'-64
        .byte   RIGHT,  'F'-64
        .byte   DEL,    'D'-64
        .byte   ESC,    27
        .byte   TAB,    'I'-64
        .byte   ENTER,  'M'-64
        .byte   BKSP,   'H'-64
        .byte   BREAK,  'C'-64
_emap   = * - _map

map_foenix
        phy
        ldy     #0
_loop   cmp     _map,y
        beq     _found
        iny
        iny
        cpy     #_end
        bne     _loop
_done
        ply
        rts
_found
        lda     _map+1,y
        bra     _done        
_map  
        .text   "7~"
        .text   "8`"
        .text   "9|"
        .text   "0\"
_end    = * - _map

capslock
        lda     event
        cmp     #RELEASED
        bne     _done
        lda     caps
        bmi     caps_released
_pressed
        dec     caps
        lda     $d6a0
        ora     #$20
        sta     $d6a0
_done
        rts
caps_released
        stz     caps
        lda     $d6a0
        and     #$ff-$20
        sta     $d6a0
        rts

        .enc   "none"
keytab: .text  BREAK,"q",LMETA," 2",LCTRL,BKSP,"1"
        .text  "/",RALT,LEFT,RSHIFT,HOME,"']="
        .text  ",[;.",CAPS,"lp-"
        .text  "nokm0ji9"
        .text  "vuhb8gy7"
        .text  "xtfc6dr5"
        .text  LSHIFT,"esz4aw3"
        .byte  UP, F5, F3, F1, F7, LEFT, ENTER, BKSP
        .byte  DOWN,RIGHT,0,0,0,0,RIGHT,DOWN

shift:  .text  ESC,"Q",LMETA,32,"@",LCTRL,0,"!"
        .text  "?",RALT,LEFT,RSHIFT,END,34,"}+"
        .text  "<{:>",CAPS,"LP_"
        .text  "NOKM)JI("
        .text  "VUHB*GY&"
        .text  "XTFC^DR%"
        .text  LSHIFT,"ESZ$AW#"
        .byte   UP, F6, F4, F2, F8, LEFT, ENTER, INS
        .byte  DOWN,RIGHT,0,0,0,0,RIGHT,DOWN

        .send
        .endn
        .endn
