; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2023 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel
rtc         .namespace

            .section    kernel

SETTIM
RDTIM
          ; TODO: fill me in; use the RTC.
            rts

            .send
            .endn
            .endn
