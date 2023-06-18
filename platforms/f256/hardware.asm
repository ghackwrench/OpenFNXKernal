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
