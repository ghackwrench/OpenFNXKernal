; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2023 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel
iec         .namespace

            .section    kernel


SETTMO
          ; Not yet implemented at the IEC layer.
            rts

IECIN
            jsr     platform.iec.IECIN
            jmp     return_a

IECOUT
            lda     user.reg_a
            jmp     platform.iec.IECOUT

TALK
            lda     user.reg_a
            jmp     platform.iec.TALK
            
LISTEN
            lda     user.reg_a 
            jmp     platform.iec.LISTEN

LSTNSA
            lda     user.reg_a 
            jmp     platform.iec.LISTEN_SA
        
TALKSA
            lda     user.reg_a 
            jmp     platform.iec.TALK_SA

UNTALK      
            jmp     platform.iec.UNTALK

UNLSTN
            jmp     platform.iec.UNTALK

            .send
            .endn
            .endn
