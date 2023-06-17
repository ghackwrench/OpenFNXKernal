; FoenixKERNAL - a clean-room implementation of the C64's KERNAL ABI.
; Copyright 2023 Jessie Oberreuter <Gadget@HackwrenchLabs.com>.
; SPDX-License-Identifier: GPL-3.0-only

; This file implements the text screen primitives for an MMU based
; F256 machine.

            .cpu        "65c02"

screen      .namespace

            .section    dp
line        .word       ?
row         .byte       ?
col         .byte       ?
cursor      .byte       ?   ; $ff when the cursor is off.
under       .byte       ?   ; Character under the curson when on.
src         .word       ?
dest        .word       ?
            .send            

            .section    hardware

PLOT
            lda     user.carry
            beq     _set
_get
            ldx     col
            ldy     row
            jmp     return_xy

_set
            ldx     user.reg_x
            stx     col
            ldy     user.reg_y
            sty     row
            
            lda     #6
            sta     line+1
            tya
            asl     a
            asl     a
            adc     row
            rol     line+1
            
            asl     a
            rol     line+1
            asl     a
            rol     line+1
            asl     a
            rol     line+1
            asl     a
            rol     line+1
                                       
            sta     line+0
            rts

TEXT_LUT_FG = $D800
TEXT_LUT_BG = $D840

init
    ; Initializes the screen.
    ; IN:   A = the fg/bg attribute byte.
    
        phx
        pha

        lda     #$ff
        sta     cursor

        stz     row
        stz     col
        stz     line+0
        lda     #$c0
        sta     line+1

        stz     io_ctrl
        jsr     init_palette
        pla
        jsr     scroll_init
        ldx     #3
        stx     io_ctrl
        jsr     fill
        jsr     cls
        plx
        rts

putch
            pha
            phy
            ldy     #2
            sty     io_ctrl
            cmp     #12
            beq     _cls
            cmp     #13
            beq     _cr
            cmp     #32
            bcc     _out
            ldy     col
            sta     (line),y
            iny
            cpy     #80
            bne     _done
_lf         ldy     #0
            lda     row
            inc     a
            cmp     #60
            bcc     _adv
            jsr     scroll
            bra     _done
_adv        sta     row
            lda     line+0
            adc     #80
            sta     line+0
            bcc     _done
            inc     line+1
            
_done
            sty     col
            stz     io_ctrl
_out        ply
            pla
            rts            
_cls
            jsr     cls
            bra     _done
_cr
            lda     #32
            ldy     col
-           cpy     #80
            bcs     _lf
            sta     (line),y
            iny
            bra     -

SCREEN
            ldx     #80
            ldy     #60
            jmp     return_xy


init_palette
            ldx     #0
_loop       lda     _palette,x
            sta     TEXT_LUT_FG,x
            sta     TEXT_LUT_BG,x
            inx
            cpx     #64
            bne     _loop
            rts
_palette
            .dword  $000000
            .dword  $ffffff
            .dword  $880000
            .dword  $aaffee
            .dword  $cc44cc
            .dword  $00cc55
            .dword  $0000aa
            .dword  $dddd77
            .dword  $dd8855
            .dword  $664400
            .dword  $ff7777
            .dword  $333333
            .dword  $777777
            .dword  $aaff66
            .dword  $0088ff
            .dword  $bbbbbb


scroll_init
    ; Fills the first line after the bottom of the screen
    ; with spaces.
    ;
    ; IN/OUT:   A = the attribute byte for the line.
    
            phx
            ldx     #3
            stx     io_ctrl
            jsr     _fill
            ldx     #2
            stx     io_ctrl
            pha     
            lda     #32
            jsr     _fill
            pla
            stz     io_ctrl
            plx
            rts
_fill
          ; Fill the first line /after/ the text screen,
          ; so scrolling will 
            ldx     #80
-           sta     $c000+60*80-1,x
            dex
            bne     -
            rts

cls
            lda     #2
            sta     io_ctrl
            lda     #32
            jsr     fill
            stz     row
            stz     col
            stz     line+0
            lda     #$c0
            sta     line+1
            rts

fill
            phx
            ldx     #240
-           
            .for    i := $c000, i < $d2c0, i += 240
            sta     i-1,x
            .next

            dex
            bne     -
            stz     io_ctrl
            plx
            rts

scroll
            phx
            phy
            lda     #2
            sta     io_ctrl
            jsr     _scroll
            lda     #3
            sta     io_ctrl
            jsr     _scroll
            stz     io_ctrl
            ply
            plx
            rts
_scroll
            lda     #$c0
            sta     src+1
            sta     dest+1
            lda     #80
            sta     src+0
            stz     dest+0

            ldx     #$12
            ldy     #0
_page       lda     (src),y
            sta     (dest),y
            iny
            bne     _page
            inc     src+1
            inc     dest+1
            dex
            bne     _page

            ldx     #$c0
_byte       lda     (src),y
            sta     (dest),y
            iny
            dex
            bne     _byte
            
            rts

cursor_on
            inc     cursor
            bne     _done
            lda     #2
            sta     io_ctrl
            ldy     col
            lda     (line),y
            sta     under
            lda     #'_'
            sta     (line),y
            stz     io_ctrl
_done       rts        
            
cursor_off
            pha
            phy
            dec     cursor
            bpl     _done     
            lda     #2
            sta     io_ctrl
            ldy     col
            lda     under
            sta     (line),y
            stz     io_ctrl
_done       ply
            pla
            rts            

            .send
            .endn
