; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2022 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

platform    .namespace

            .section    hardware
            
init
            jsr     iec.IOINIT

            lda     #$10
            jsr     screen.init
            
            jsr     keyboard.init

            rts

            .send
            .endn
