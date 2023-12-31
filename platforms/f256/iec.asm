; First crack at a library for bit-banging IEC.
; Copyright Jessie Oberreuter, 2022,2023.
; Distributed under the MIT License: feel free to copy, hack, whatever,
; just give me credit for having slogged through making it work.

                .cpu        "w65c02"


                .namespace  platform
iec             .namespace


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Low level port routines.

port            .namespace

                .section        hardware
                
IEC_INPUT_PORT  = $D680 ; Read Only, this is the Value on the BUS
; IEC Input PORT
; Bit[0] IEC_DATA_i
; Bit[1] IEC_CLK_i
; Bit[2] Always 0
; Bit[3] Always 0
; Bit[4] IEC_ATN_i
; Bit[5] Always 0
; Bit[6] Always 0
; Bit[7] IEC_SREQ_i
IEC_DATA_i  = $01
IEC_CLK_i   = $02
IEC_ATN_i   = $10
IEC_SREQ_i  = $80

IEC_OUTPUT_PORT = $D681 ; Read and Write, When you read you read back the value written
; IEC Output PORT
; Bit[0] IEC_DATA_o
; Bit[1] IEC_CLK_o
; Bit[2] Always 0
; Bit[3] Always 0
; Bit[4] IEC_ATN_o
; Bit[5] Always 0
; Bit[6] Always 0
; Bit[7] IEC_SREQ_o
IEC_DATA_o  = $01
IEC_CLK_o   = $02
IEC_ATN_o   = $10
IEC_RST_o   = $40
IEC_SREQ_o  = $80


assert_bit      .macro  BIT
                pha
                lda     IEC_OUTPUT_PORT
                and     #~\BIT
                sta     IEC_OUTPUT_PORT
                pla
                rts
                .endm
            
release_bit     .macro  BIT
                pha
                lda     IEC_OUTPUT_PORT
                ora     #\BIT
                sta     IEC_OUTPUT_PORT
                pla
                rts
                .endm

read_bit        .macro  BIT
                pha
_loop           lda     IEC_INPUT_PORT
                cmp     IEC_INPUT_PORT
                bne     _loop
                and     #\BIT
                cmp     #1
                pla
                rts
                .endm
            
bit_funcs       .segment    NAME,IN,OUT
read_\NAME
                .read_bit       \IN
assert_\NAME
                .assert_bit     \OUT
release_\NAME
                .release_bit    \OUT
                .endm
                
    .bit_funcs  SREQ,   IEC_SREQ_i, IEC_SREQ_o
    .bit_funcs  ATN,    IEC_ATN_i,  IEC_ATN_o
    .bit_funcs  CLOCK,  IEC_CLK_i,  IEC_CLK_o
    .bit_funcs  DATA,   IEC_DATA_i, IEC_DATA_o


test_DATA   .proc
    ; Quickly peek at the external state of the DATA line,
    ; hopefully in a way that won't get detected by the
    ; other devices.
    
            pha
            phx
            phy

          ; Grab the current output state.
            ldx     IEC_OUTPUT_PORT
            
          ; Prepare to release DATA
            txa
            ora     #IEC_DATA_o
            tay
            
          ; Prepare to test DATA
            lda     #IEC_DATA_i

          ; Release DATA
            sty     IEC_OUTPUT_PORT
            
          ; Test DATA
            and     IEC_INPUT_PORT
            bne     _out
            
          ; Re-assert DATA if it's still low.
            stx     IEC_OUTPUT_PORT
            
_out
          ; Place the DATA state in the carry
            cmp     #1
          
            ply
            plx
            pla
            rts
            .pend

init        .proc
            jsr     sleep_1ms
            stz     io_ctrl
            jsr     release_ATN
            jsr     release_DATA
            jsr     release_SREQ
            jsr     assert_CLOCK   ; IDLE state            
            jsr     sleep_1ms
            jsr     sleep_1ms
            jsr     sleep_1ms
            clc
            rts
            .pend

            .send
            .endn   ; port


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Transaction routines

            .section    dp  ; For rx_eoi, could be ,x
self        .namespace
eoi_pending .byte       ?
rx_eoi      .fill       0   ; shared with mark
mark        .byte       ?
            .endn
            .send

            .section    hardware

init
    ; Initialize the port and make sure ATN and SREQ aren't stuck.
    ; Carry set on error.

            jsr     platform.iec.port.init

          ; Bail if ATN and SRQ fail to float back up.
          ; We'll have a more thorough test when we send
          ; our first command.            
            nop
            nop
            nop
            jsr     platform.iec.port.read_SREQ
            bcc     _err
            jsr     platform.iec.port.read_ATN
            bcc     _err

            jsr     sleep_1ms

            clc
            rts
_err
            sec
            rts        
            

TALK 

            ora     #$40

          ; list1
            jsr     flush
            
          ; list2
            jmp     atn_list2   ; NOTE: does NOT drop ATN!

TALK_SA
          ; tksa
            jsr     atn_common

          ; tkatn
            sei            
            jsr     platform.iec.port.assert_DATA
            jsr     platform.iec.port.release_ATN
            jsr     platform.iec.port.release_CLOCK
_tkatn1     jsr     platform.iec.port.read_CLOCK
            bcs     _tkatn1
            cli
            rts

            
LISTEN

            ora     #$20

          ; list1
            jsr     flush
            
          ; list2
            jmp     atn_list2   ; NOTE: does NOT drop ATN!
            
LISTEN_SA
            jsr     atn_common
            jsr     platform.iec.port.release_ATN
            cli
            ; TODO: WARNING!  No delay here!  
            ; TODO: IMHO, should wait at least 100us to avoid accidental turn-around!
            ; TODO: tho we do protect against this in the send code.
            rts


UNTALK

            lda     #$5f

        ; There should never be a need to flush here, and if you
        ; do manage to call IECOUT between a TALK/TALKSA and an
        ; UNTALK, the C64 will flush it while ATN is asserted and 
        ; the drive will be mighty confused.
        ; 
        ; TODO: track the state and cause calls to IECOUT to fail.

          ; pre-sets CLOCK IMMEDIATELY before the ATN ... again, TODO: makes no sense
            sei
            jsr     platform.iec.port.assert_CLOCK

          ; isour
            jmp     atn_release


UNLISTEN

            lda     #$3f

          ; list1
            jsr     flush

            jmp atn_release
            
atn_list2

          ; list2
            sei
            jsr     platform.iec.port.release_DATA
            jsr     platform.iec.port.release_CLOCK ; TODO: makes /no/ sense; maybe we can remove...

          ; isoura
            jsr     atn_common  ; NOTE: does NOT release ATN!  Does NOT release IRQs!
            cli
            rts
            
atn_release
            jsr     atn_common            

            sei     ; NOTE: C64 doesn't block interrupts for this:
            jsr     platform.iec.port.release_ATN
            jsr     sleep_20us
            jsr     sleep_20us
            jsr     sleep_20us
            jsr     platform.iec.port.release_CLOCK
            jsr     platform.iec.port.release_DATA
            cli
            rts

atn_common
        ; NOTE: at present, leaves IRQs disabled on success!

          ; Assert ATN; if we aren't already in sending mode, 
          ; get there:
            sei
            jsr     platform.iec.port.assert_ATN
            jsr     platform.iec.port.assert_CLOCK
            jsr     platform.iec.port.release_DATA
            cli

          ; Now give the devices ~1ms to start listening.
            jsr     sleep_1ms
            
          ; If no one is listening, there's nothing on
          ; the bus, so signal an error.
            jsr     platform.iec.port.read_DATA
            bcs     _err

          ; ATN bytes are technically never EOI bytes
            stz     self.eoi_pending

            jmp send_common           

_err
          ; Always release the ATN line on error; TODO: add post delay
            jmp     platform.iec.port.release_ATN



send_eoi
send_data_eoi
            jsr     set_eoi
            jmp     send

set_eoi
            stz     self.eoi_pending
            dec     self.eoi_pending
            rts

send
            jsr     send_common
            cli
            rts
            
send_common
    ; A = byte
    ; Assumes we are in the sending state:
    ; the host is asserting CLOCK and the devices are asserting DATA.
    ; This part of the code should be moved to the kernel thread.

          ; There must be at least 100us between bytes.
            jsr     sleep_300us ; TODO: NOT in C64 code.


        ; Clever cheating

          ; Act as an ersatz listener to keep the other listeners busy
          ; until we are ready to receive.  This is NOT part of the
          ; IEC protocol -- we are doing this in lieu of an interrupt.
            jsr     platform.iec.port.assert_DATA

          ; Release CLOCK to signal that we are ready to send
          ; We can do this without disabling interrupts because
          ; we are also asserting DATA.
            jsr     platform.iec.port.release_CLOCK
            
        ; Now we wait for all of the listeners to acknowledge.
_wait
          ; We're still asserting DATA.
            cli
            jsr     sleep_20us

          ; If the other listeners are ready, we need to respond
          ; quickly, so disable interrupts and "peek" at the
          ; bus by releasing DATA, sampling it, and quickly
          ; re-asserting it if was still low.  There's a race
          ; condition here, in that a drive might release just
          ; as we are re-asserting, but with luck, the debounce
          ; code will just see it as line noise :).
            sei
            jsr     platform.iec.port.test_DATA
            bcs     _ready
            
          ; Other listeners are still busy; go back to sleep.
            bra     _wait

_ready
            bit     self.eoi_pending
            bpl     _send
            bmi     _eoi

_eoi
        ; Alas, we can't get too clever here, or the 1541 hates us.
        
        ; Hard-wait the 200us for the drive to acknowledge the EOI.
        ; This duration is technically unbounded, but the ersatz
        ; listener trick during the EOI signal, and the drive
        ; already had the opportunity to delay before starting the
        ; ack, so hopefully it will stay in nominal 250us range.
        
_Tye        jsr     platform.iec.port.read_DATA
            bcs     _Tye

        ; Now we're basically back to the point where we are waiting
        ; for Rx ack.  The trick does work here.

          ; Clear the eoi minus flag, so our next send will be data.
            lsr     self.eoi_pending

          ; The drive should hold DATA for at least 60us.  Give it
          ; 20us, and then repeat our ersatz listener trick.
            jsr     sleep_20us
            jsr     platform.iec.port.assert_DATA
            bra     _wait

_send
        ; Give the listeners time to notice that the've all ack'd
            jsr     sleep_20us  ; NOT on the C64

        ; Now start pushing out the bits.  Note that the timing
        ; is not critical, but each clock state must last at
        ; least 20us (with 70us more typical for clock low).

            phx
            ldx     #8
_loop
          ; Don't let an interrupt put space between the clock
          ; and the data.
            sei     ; Already true for the first bit.

        ; TODO: opt test for a frame error

          ; Clock out the next bit
            jsr     platform.iec.port.assert_CLOCK
            jsr     sleep_20us
            lsr     a
            bcs     _one
            bcc     _zero
_zero       jsr     platform.iec.port.assert_DATA
            bra     _clock
_one        jsr     platform.iec.port.release_DATA
            bra     _clock
_clock
          ; Toggle the clock; interrupts are fine here
            cli
            jsr     sleep_20us  ; TODO: Maybe extend this.

            jsr     sleep_20us  ; 1541 needs this.
            jsr     platform.iec.port.release_CLOCK

            jsr     sleep_20us
            dex
            bne     _loop
            plx
            
          ; Finish the last bit and wait for the listeners to ack.
          ; Again do this synchronously.
            sei
            jsr     platform.iec.port.release_DATA
            jsr     platform.iec.port.assert_CLOCK

        ; Now wait for listener ack.  Of course, if there are
        ; multiple listeners, we can only know that one ack'd.
        ; This can take up to a millisecond, so another good
        ; candidate for a kernel thread or interrupt.

    ; TODO: ATN release timing appears to be semi-critical; we may need
    ; to completely change the code below.

_ack        jsr     platform.iec.port.read_DATA
            bcs     _ack
            clc
            rts
_done
            rts

sleep_20us
            phx
            ldx     #20
_loop       dex
            bne     _loop
            plx
            rts
            
sleep_100us
            phx
            ldx     #5
_loop       jsr     sleep_20us
            dex
            bne     _loop
            plx
            rts                

sleep_300us
            jsr     sleep_100us
            jsr     sleep_100us
            jsr     sleep_100us
            rts
            
sleep_1ms
            jsr     sleep_300us
            jsr     sleep_300us
            jsr     sleep_300us
            jmp     sleep_100us
            

recv_data
    
        ; Assume not EOI until proved otherwise
            stz     self.rx_eoi

        ; Wait for the sender to have a byte
        ; Good place to use an interrupt...
_wait1      jsr     platform.iec.port.read_CLOCK
            bcc     _wait1

_ready
          ; Sadly, we must do the rests with interrupts disabled.
          ; TODO: start and check a timer
            sei

          ; Signal we are ready to receive
            jsr     platform.iec.port.release_DATA

          ; Wait for all other listeners to signal
_wait2      jsr     platform.iec.port.read_DATA
            bcc     _wait2
    
          ; Wait for the first bit or an EOI condition
          ; Each iteration takes 6-7us
            lda     #0      ; counter
_wait3      inc     a
            beq     _eoi
            jsr     platform.iec.port.read_CLOCK
            bcc     _recv
            adc     #7      ; microseconds per loop
            bcc     _wait3
_eoi
            lda     self.rx_eoi
            bmi     _error

          ; Ack the EOI; we can enable IRQs for this.
            jsr     platform.iec.port.assert_DATA
            cli
            jsr     sleep_20us
            jsr     sleep_20us
            jsr     sleep_20us

          ; Set the EOI flag.  
            dec     self.rx_eoi ; TODO: error on second round
          
          ; Go back to the ready state
            bra     _ready            

_error
            cli
            sec
            rts

_recv
          ; Clock in the bits
            phx
            ldx     #8

_wait_fall  jsr     platform.iec.port.read_CLOCK
            bcs     _wait_fall

_wait_rise  jsr     platform.iec.port.read_CLOCK
            bcc     _wait_rise
           
            jsr     platform.iec.port.read_DATA
            ror     a
            dex
            bne     _wait_fall
            plx

          ; Ack
            jsr     sleep_20us
            jsr     platform.iec.port.assert_DATA
            cli

          ; Drives /usually/ work with a lot less, but
          ; I see failures on the SD2IEC on a status check
          ; after file-not-found when debugging is turned off.
            jsr     sleep_20us  ; Seems to be missing the ack.
            jsr     sleep_20us  ; Seems to be missing the ack.
            jsr     sleep_20us  ; Seems to be missing the ack.
            jsr     sleep_20us  ; Seems to be missing the ack.
            
          ; Return EOI in NV
            clc
            bit     self.rx_eoi
            ora     #0
            rts

            .send


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; KERNAL IEC routines

            .section    dp
delayed     .byte       ?       ; There is a delayed byte in the queue
queue       .byte       ?
            .send

            .section    hardware

IOINIT
    ; Initializes the IEC interface.
    ; Carry set if no devices found.
            stz     delayed
            jmp     init

IECIN
    ; Receives a byte into A;
    ; NV set on EOI
            jmp     recv_data
            
IECOUT

    ; Sends the byte in A.
    ; Actually, sends the previous IECOUT byte, and queues
    ; this one for later transmission.  This is done to
    ; ensure that we can mark the last data byte with an EOI.

        clc
        bit     delayed
        bpl     _queue

      ; Send the old byte
        pha
        lda     queue
        jsr     send
        pla
        stz     delayed

      ; Queue the new byte
_queue          
        sta     queue
        dec     delayed
        rts

flush
    ; Sends the queued byte with an EOI
        bit     delayed
        bpl     _done
        pha
        lda     queue
        stz     delayed
        jsr     send_eoi
        pla
_done
        rts

OPEN
        ora     #$f0
        jmp     LISTEN_SA

DEV_SEND
        ora     #$60
        jmp     TALK_SA

DEV_RECV
        ora     #$60
        jmp     LISTEN_SA

CLOSE
        ora     #$E0
        jmp     LISTEN_SA


probe_device    ; Soft reset

        phy
        tay
    
        jsr     LISTEN
        bcs     _out

        lda     #$0f
        jsr     DEV_RECV
        bcs     _out
        
        lda     #'U' 
        jsr     IECOUT
        lda     #'I'    ; TODO: test 'J' (hard) instead.
        jsr     IECOUT

        php
        tya
        jsr     UNLISTEN
        plp
        
_out
        ply
        rts

request_status
clear_status

    ; TODO: handle recoverable errors.

        phy
        tay
    
        jsr     TALK
        bcs     _out

      ; Request data from the control channel
        lda     #$0f
        jsr     DEV_SEND
        bcs     _close
        
_loop
        jsr     IECIN
        bcs     _close
        bvc     _loop
        
_close
        php
        tya
        jsr     UNTALK
        plp
        
_out
        ply
        rts

            .send

            .endn
            .endn

