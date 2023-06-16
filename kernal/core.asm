; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2023 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel
            .section    kernel


iec .namespace
lstnsa
talksa
settmo
iecin
iecout
untalk
unlstn
listen
talk
readst
    .endn     



        .send
        .endn
