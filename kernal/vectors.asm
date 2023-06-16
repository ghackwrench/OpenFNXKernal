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
RESTOR      jmp     io.RESTOR
VECTOR      jmp     io.VECTOR
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
SAVE        jmp     io.save
SETTIM      jmp     settim
RDTIM       jmp     rdtim
STOP        jmp     keyboard.stop
GETIN       jmp     io.GETIN
CLALL       jmp     io.clall
UDTIM       jmp     udtim
SCREEN      jmp     screen.SCREEN
PLOT        jmp     screen.PLOT
IOBASE      jmp     io.IOBASE
            .ends

            .send
            .endn
