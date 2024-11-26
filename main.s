;6502 servo project.
; vasm6502_oldstyle -esc -Fbin -pad=0xff -dotdir -o main.bin main.s
; minipro -p 2816 -w /morfiles/programming/asm/6502/6502servo/main.bin


; the memory on this system is shadowed to be accessed from 0000-FFFF
; 
;  0000-07FF Real memory
;  0800-3FFF repeats
;
;  4000-400F 6522 #1
;  4010-401F 6522 #2
;  4020-7FFF repeats
;
;  8000-8003 8255
;  8004-DFFF repeats
;
;  C000-F7FF repeats of...
;  F800-FFFF repeat of memory

; becasue the 6502 likes to do dummy writes to 0xFFFF
; we need some fancy address decoding ;]

  ;--  Notes on 6522 T2 --      
  ;  
  ;  - The divider ONLY comes off the 8 bits of the counter
  ;  - loading T2CH will reload from the latch
  ;  - the first interval is wasted on pre-high time.
  ;  - the first interval starts after the completion of the last interval
  ;
  ;--


P6522A   = $4000
P6522B   = $4010
P8255    = $8000


VIA_PORTB  = $00
VIA_PORTA  = $01
VIA_DDRB   = $02
VIA_DDRA   = $03

VIA_T1CL   = $04
VIA_T1CH   = $05
VIA_T1LL   = $06
VIA_T1LH   = $07

VIA_T2CL   = $08
VIA_T2CH   = $09

VIA_SR     = $0A
VIA_ACR    = $0B
VIA_PCR    = $0C
VIA_IFR    = $0D
VIA_IER    = $0E
VIA_ORA2   = $0F

; ------------------------------------------
; I'm going to abstract this all to high memory
; Ram: (page 0)  0xF800 - 0xF8FF (R/W)
; Stack:         0xF900 - 0xF9FF
; Program:       0xFA00 - 0xFFFF (RO)


;  PORTA: pseudo IO
;    0    <-- PWM in
;    1    <-- monostable in
;    2
;    3
;    4
;    5
;    6
;    7
;  CA1
;  CA2
;
;
;  PORTB: driven IO
;    0     -> Serial TxD
;    1     --> Monostable trigger
;    2     --> Motor A
;    3     --> Motor B
;    4
;    5
;    6
;    7
;  CB1     -> (Serial Clock)
;  CB2     -> Serial RxD


; === this is page 0 stuff ===
  
  .org $F800
  .byte $00   ; get assembler to offset image properly
  
Delay_ctr0 = $00 
Delay_ctr1 = $01

TxD        = $02
TxMask     = $03
RxD_T      = $04
RxDR       = $05

BRInput    = $06
BROutput   = $07

StrPtrL    = $08
StrPtrH    = $09

tmpWordL   = $0A
tmpWordH   = $0B

MonAddressL = $0C
MonAddressH = $0D

;--

DelayCtrL = $10
DelayCtrH = $11





; ------------------------------------------
; page 1 (F900-F9FF) is used by the stack


; ===========================| code begin |==================================
  .org $0300 ;code starts here! !!!???!!! fix this address later.

; init 6522. 
;  write 1's to DDRs that need to be an output.
;
;  Control          in: PA0
;  Monostable Q     in: PA1
;  
;  Monostable trig out: PB1 
;  Motor phase A   out: PB2
;  Motor phase B   out: PB3
;

  ldx #$FF             ; port B all output  
  stx P6522A+VIA_DDRB  
  ; monostable trigger pin high, motor off (0, 0).
  lda #$02
  ora P6522A+VIA_DDRB ; set that bit
  and #$FC            ; clear those bits
  sta P6522A+VIA_DDRB ; save it.
  
; loup
ServoLoup:

; wait for input pulse to start
 lda #$01   ; pulse input bit
pulseWait:          
 bit P6522A+VIA_PORTA
 beq pulseWait 
 
; start monostable
  lda #$02             ; low pulse to trigger monostable
  eor P6522A+VIA_PORTB
  sta P6522A+VIA_PORTB 
  ora P6522A+VIA_PORTB
  sta P6522A+VIA_PORTB 

; delay for monostable to change state
  nop  ; (its not a fast processor)

; wait for monostable or input to go low
  lda #$03
diffWait:
  and P6522A+VIA_PORTA
  cmp #$03     
  beq diffWait

; if monostable ended first drive motor forward, goto pulse accumulate
   cmp #$02  
   ldx #$04    
   beq accPulse
; else if pulse ended first, drive motor reverse, goto pulse accumulate
   cmp #$01
   ldx #$08
   beq accPulse
; else were a pulse match, do nothing.
   jmp ServoLoup
        
; accumulate error time
accPulse:
  txa                    ; turn motor on whatever direction we decided.
  ora P6522A+VIA_PORTB
  sta P6522A+VIA_PORTB
    
  lda #$03
  ldx #$00
accChg:
  inx
  bit P6522A+VIA_PORTA
  bne accChg  

; multiply accumulated time * 128, store value
  lsr 
  sta DelayCtrH
  lda #$00
  ror
  sta DelayCtrL

; count down accumulated value to zero or abort of new pulse
accDisc:
  nop
  nop
  nop
  nop
  dec DelayCtrL
  bne accDisc
  dec DelayCtrH
  bne accDisc
  
; turn motor off (clear bits 1, 2, 3)
  lda #$F1
  and P6522A+VIA_PORTB
  sta P6522A+VIA_PORTB

  jmp ServoLoup












 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
; Hey you made to the bottom!
;  I'm a real person, you can talk to me
;  Twitter: @RueNahcMohr
;  IRC: Libera.chat  #robotics
