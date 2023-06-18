            .cpu    "w65c02"

            .namespace  platform
keyboard    .namespace

            .section    hardware

ps2_0       .hardware.ps2.f256
cbm_kbd     .platform.c64kbd.driver
;jr_kbd      .platform.jr_kbd.driver

; d6a0 system control, 
; d6a7 computer id reads jr=$02, k=$12

init
          ; Initialize the ps2 keyboard.
            jsr     ps2_0.init

          ; Initialize the appropriate CIA keyboard
            stz     io_ctrl
            lda     $d6a7
            cmp     #$02
            beq     _cbm
            cmp     #$12
            beq     _jr

            clc
            rts

_jr         ;jmp     jr_kbd.init           
_cbm        jmp     cbm_kbd.init

            .send
            .endn
            .endn
            
