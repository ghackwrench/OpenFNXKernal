            .cpu    "w65c02"

platform    .namespace
            .endn

f256        .namespace            

            .section    hardware
            
ps2_0       .hardware.ps2.f256


init
            jsr     platform.iec.IOINIT

            lda     #$10
            jsr     screen.init
            
            jsr     ps2_0.init
            rts

            .send
            .endn
