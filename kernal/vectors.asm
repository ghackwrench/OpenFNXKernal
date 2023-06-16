; OpenKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "65c02"

            .namespace  kernel
            .section    kernel
            
dummy       rts

vectors     .struct                 ; $ffd5

            jmp     dummy           ; Available
            jmp     dummy           ; Available
            jmp     dummy           ; Available
            jmp     dummy           ; Available
            jmp     dummy           ; Available
            jmp     dummy           ; Available
            jmp     dummy           ; Available
            jmp     dummy           ; Available
            jmp     dummy           ; Available
            jmp     dummy           ; Available
            jmp     dummy           ; Available
            jmp     dummy           ; Available

SCINIT      jmp     io.SCINIT       ; $ff81
IOINIT      jmp     io.IOINIT
RAMTAS      jmp     ramtas
RESTOR      jmp     restor
VECTOR      jmp     vector
SETMSG      jmp     setmsg
LSTNSA      jmp     iec.lstnsa
TALKSA      jmp     iec.talksa
MEMBOT      jmp     mem.MEMBOT
MEMTOP      jmp     mem.MEMTOP
SCNKEY      jmp     scnkey
SETTMO      jmp     iec.settmo
IECIN       jmp     iec.iecin
IECOUT      jmp     iec.iecout
UNTALK      jmp     iec.untalk
UNLSTN      jmp     iec.unlstn
LISTEN      jmp     iec.listen
TALK        jmp     iec.talk
READST      jmp     iec.readst
SETLFS      jmp     io.SETLFS
SETNAM      jmp     io.SETNAM
OPEN        jmp     io.open
CLOSE       jmp     io.close
CHKIN       jmp     io.chkin
CHKOUT      jmp     io.chkout
CLRCHN      jmp     io.clrchn
CHRIN       jmp     io.CHRIN
CHROUT      jmp     io.CHROUT
LOAD        jmp     io.LOAD
SAVE        jmp     iec.save
SETTIM      jmp     settim
RDTIM       jmp     rdtim
STOP        jmp     keyboard.stop
GETIN       jmp     io.GETIN
CLALL       jmp     io.clall
UDTIM       jmp     udtim
SCREEN      jmp     screen.screen
PLOT        jmp     plot
IOBASE      jmp     iobase
            .ends

.if false            

ivec_start
            .word   irq
            .word   break
            .word   nmi
            .word   io.open     
            .word   io.close
            .word   io.chkin
            .word   io.chkout
            .word   io.clrchn
            .word   io.CHRIN
            .word   io.CHROUT
            .word   keyboard.stop
            .word   io.getin
            .word   io.clall
            .word   user
            .word   iec.load
            .word   iec.save
ivec_end
ivec_size   =   ivec_end - ivec_start

            
           
restor
            pha
            phx
            ldx     #0
_loop       lda     ivec_start,x
            sta     $314,x
            inx
            cmp     #ivec_size
            bne     _loop
            plx
            pla
            rts

vector
            stx     src+0
            sty     src+1

            ldy     #0
            bcs     _out      
        
_in         lda     (src),y
            sta     $314,y
            iny
            cpy     #ivec_size
            bne     _in
            rts
            
_out        lda     $314,y
            sta     (src),y
            iny
            cpy     #ivec_size
            bne     _out
            rts



irq
break
nmi
user
        sec
        rts
        
.endif
            .send
            .endn
