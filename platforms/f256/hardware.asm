            .cpu    "w65c02"

f256        .namespace            

            .section    hardware
            
ps2_0       .hardware.ps2.f256


init
            lda     #$10
            jsr     screen.init
            
            jsr     ps2_0.init
            rts

            .send
            .endn
