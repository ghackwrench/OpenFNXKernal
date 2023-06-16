; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2023 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel
err         .namespace

            .section    kernel

SETMSG
          ; Storing it in the user's memory for now.
          ; Could be in our private memory; dunno if
          ; anyone in userland expects to access it
          ; directly.
            sta     $2000+$9d
            rts
            
            .send
            .endn
            .endn
