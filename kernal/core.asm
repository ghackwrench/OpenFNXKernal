; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2023 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

            .cpu    "w65c02"

            .namespace  kernel
            .section    kernel


io  .namespace
ioinit
setlfs
setnam
open
close
chkin
chkout
clrchn
;chrin
;chrout
getin
clall
    rts
    
chrin
            jsr     screen.cursor_on
            lda     #2
            sta     io_ctrl
_loop       inc     $c000+79
            bra     _loop
    .endn

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
load
save
    .endn     

keyboard    .namespace
stop
            .endn

scinit
ramtas
restor
vector
setmsg
membot
memtop
scnkey
settim
rdtim
udtim
;screen
plot
iobase

rts



        .send
        .endn
