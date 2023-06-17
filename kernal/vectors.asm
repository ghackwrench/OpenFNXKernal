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
RAMTAS      jmp     mem.RAMTAS
RESTOR      jmp     io.RESTOR
VECTOR      jmp     io.VECTOR
SETMSG      jmp     err.SETMSG
LSTNSA      jmp     iec.LSTNSA
TALKSA      jmp     iec.TALKSA
MEMBOT      jmp     mem.MEMBOT
MEMTOP      jmp     mem.MEMTOP
SCNKEY      jmp     kbd.SCNKEY
SETTMO      jmp     iec.SETTMO
IECIN       jmp     iec.IECIN
IECOUT      jmp     iec.IECOUT
UNTALK      jmp     iec.UNTALK
UNLSTN      jmp     iec.UNLSTN
LISTEN      jmp     iec.LISTEN
TALK        jmp     iec.TALK
READST      jmp     io.READST
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
SAVE        jmp     io.SAVE
SETTIM      jmp     rtc.SETTIM
RDTIM       jmp     rtc.RDTIM
STOP        jmp     kbd.STOP
GETIN       jmp     io.GETIN
CLALL       jmp     io.clall
UDTIM       jmp     kbd.UDTIM
SCREEN      jmp     screen.SCREEN
PLOT        jmp     screen.PLOT
IOBASE      jmp     io.IOBASE
            .ends

            .send
            .endn
