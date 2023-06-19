
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;init and variables;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
init:
	clrf   PORTB        ; clear PORTB output latches
    	bsf    STATUS,RP0   ; memory page 1
    	movlw  b'11111111'  ; set portA pins to input 
    	movwf  TRISA        ; write to TRIS register 
    	movlw  b'00000000'  ; set portB pins to output 
    	movwf  TRISB        ; write to TRIS register 
    	bcf    STATUS,RP0   ; memory page 0
	
	INDF   EQU @bptr    ;the indf and fsr (used for indirect addressing) isn't normally accessable, this hack lets us use it
	FSR    EQU bptr
	
	xm	 EQU b0       ;most significant bit of x
	xl     EQU b1       ;least significant bit of x
	
	PC     EQU b2       ;program counter
	
	accm   EQU b3       ;accumulator
	accl   EQU b4
	
	tmpm	 EQU b19      ;Preserved
	tmp	 EQU b20      ;multipurpose temp register
	SA	 EQU b26      ;source address
	DA	 EQU b27      ;destination address
	
	;Constants
	base   EQU 0x30     ;The base address for where the data is stored in ram
	acc    EQU 0x3      ;The accumulator
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;The interpreter;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
main:
	movlw  base      
	movwf  PC           ;start the program counter with the base address of where the data is stored
	call   ldapgrm      ;load the program into memory
	
cycle:
	movfw  PC           ;grab the first instruction
	movwf  SA
	clrf   DA           ;put it in x
	call   wmovsd
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
HLT:  call   xsubhun      ;for the main loop, we subtract 100 from the value in x, and check if it is less than 0
	btfss  xm,7
	goto   ADD
hang: goto   hang         ;end was being fiddly, so i used this to end instead
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ADD:  call   xsubhun      ;100-200
	btfss  xm,7
	goto   SUB
	call   xaddhun
	
	;we have to add whatever is in x into the accumulator and store in the accumulator
	call   xl2loc       ;convert the address in x to a usable address
	movwf  FSR
	movfw  INDF         ;grab the msb of the thing in the address
	addwf  accm,F       ;add it to the msb of the accumulator
	incf   FSR,F        
	movfw  INDF         ;grab the lsb
	addwf  accl,F       ;add it to the lsb of the accumulator
	
	btfsc  STATUS,C     ;check if there is an overflow to the second byte
	incf   accm,F
	goto   nxt
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SUB:  call   xsubhun      ;200-300
	btfss  xm,7
	goto   STA
	call   xaddhun
	
	call   xl2loc       ;convert the address in x to a usable address
	movwf  FSR
	comf   INDF,W       ;grab the msb, and invert it at the same time
	addwf  accm,F       ;add it to the msb of the accumulator
	incf   FSR,F
	comf   INDF,W
	addwf  accl,F
	
	btfsc  STATUS,C     ;check for overflows
	incf   accm,F
	
	movlw  1            ;since it is 2s complement we need to add 1
	addwf  accl,F       ;we do this instead of incf as that doesnt' effect carry bit
	
	btfsc  STATUS,C     ;and then we need to check for overflows AGAIN
	incf   accm,F
	goto   nxt
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
STA:  call   xsubhun      ;300-400
	btfss  xm,7
	goto   STO
st:   call   xaddhun
	
	movlw  acc          ;our source is the accumulator
	movwf  sa
	call   xl2loc       ;our destination is the destination in xl
	movwf  da
	
	call   wmovsd       ;move accumulator to the place
	goto   nxt
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
STO:  call   xsubhun
	btfss  xm,7
	goto   LDA
	goto   st           ;STO does the same thing as STA so just go there
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LDA:  call   xsubhun
	btfss  xm,7
	goto   BRA
	call   xaddhun
	
	call   xl2loc       ;our source is the destination in xl
	movwf  sa
	movlw  acc          ;our destination is the accumulator
	movwf  da
	
	call   wmovsd       ;move x to accumulator
	goto   nxt
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BRA:  call   xsubhun
	btfss  xm,7
	goto   BRZ
	call   xaddhun

br:   call   xl2loc       ;change the pc to have what is in xl (as an address)
	movwf  PC
	goto   cycle        ;skip the adding stuff to pc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BRZ:  call   xsubhun
	btfss  xm,7
	goto   BRP
	call   xaddhun
	
	movf   accm,F       ;Now we check if accm and accl are zero    
	btfss  STATUS,Z
	goto   nxt          ;in this case, it is not zero
	movf   accl,F             
	btfss  STATUS,Z
	goto   nxt          ;in this case, it is not zero
	
	goto   br           ;it is zero, so we branch
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BRP:  call   xsubhun
	btfss  xm,7
	goto   IO
	call   xaddhun
	
	BTFSS  accm,7       ;check the highest bit of accm to see if it is negative or not
	goto   br           ;if it is, branch
	goto   nxt
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
IO:   call   xsubhun
	btfss  xm,7
	goto   hang
	call   xaddhun
	
	btfss  xl,0         ;Check if the first bit is on, if it is we take input
	goto   out
in:   movfw  PORTA        ;for input get it from PORTA
	movwf  accl
	goto   nxt
out:  movfw  accl
	movwf  PORTB        ;four output put it in PORTB
	goto   nxt
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
nxt: 
	incf   PC,F         ;increment it twice since it does it in words
	incf   PC,F
	goto   cycle        ;Go back and do it all again lol
	
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Helper functions;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
wmovsd: ;move word from source address to destination address, i feel like this could be improved
	movfw  SA           ;grab the source
	movwf  FSR      
	movfw  INDF
	movwf  tmpm         ;put it in msb of temp
	incf   FSR,F        ;change it to grab the lsB
	movfw  INDF
	movwf  tmp          ;put it in the lsb of tmp
	
	movfw  DA           ;change INDF to look at destination
	movwf  FSR
	movfw  tmpm
	movwf  INDF         ;put temp msp in destination msB
	incf   FSR,F
	movfw  tmp
	movwf  INDF         ;lsB
	return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
xsubhun: ;Subtract 100 from x
	clrf    FSR         ;we want to change x (which is at 0)
	movlw   b'11111111' ;top half of -100
	addwf   INDF,F      ;add it
	incf    FSR,F
	movlw   b'10011100' ;bottom half of -100
	addwf   INDF,F      ;add it
	btfss   STATUS,C    ;check for overflows
	return
	nop                 ;i hate this language
	decf    FSR,F
	incf    INDF,F
	return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
xaddhun: ;this doesn't actually add 100 to x, it just reverses a single xsubhun, so only use in that context
	movlw   100
	addwf   xl,F        ;add 100 to lsb
	clrf    xm          ;msb will always be 0
	return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
xl2loc: ;convert xl to a location in memory and put it in w
	movfw  xl
	addwf  xl,W         ;add it twice to get the actual location
	addlw  base         ;you need to shift it with the base
	return
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;Load the program;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
blit:
	movwf  INDF         ;put the number we just loaded into destination
	incf   FSR,F        ;increment to the next one
	return
ldapgrm:
	movlw  base         ;our destination starts out with being base, but is incremented each time
	movwf  FSR
	
	;simple prime finder script
	movlw 0x02          ;522
	call blit
	movlw 0x0a
	call blit
	movlw 0x00          ;121
	call blit
	movlw 0x79
	call blit
	movlw 0x01          ;322
	call blit
	movlw 0x42
	call blit
	movlw 0x02          ;521
	call blit
	movlw 0x09
	call blit
	movlw 0x01          ;323
	call blit
	movlw 0x43
	call blit
	movlw 0x02          ;523
	call blit
	movlw 0x0b
	call blit
	movlw 0x00          ;121
	call blit
	movlw 0x79
	call blit
	movlw 0x01          ;323
	call blit
	movlw 0x43
	call blit
	movlw 0x00          ;222
	call blit
	movlw 0xde
	call blit
	movlw 0x00          ;221
	call blit
	movlw 0xdd
	call blit
	movlw 0x00          ;123
	call blit
	movlw 0x7b
	call blit
	movlw 0x03          ;817
	call blit
	movlw 0x31
	call blit
	movlw 0x02          ;522
	call blit
	movlw 0x0a
	call blit
	movlw 0x00          ;223
	call blit
	movlw 0xdf
	call blit
	movlw 0x02          ;700
	call blit
	movlw 0xbc
	call blit
	movlw 0x03          ;813
	call blit
	movlw 0x2d
	call blit
	movlw 0x02          ;605
	call blit
	movlw 0x5d
	call blit
	movlw 0x02          ;522
	call blit
	movlw 0x0a
	call blit
	movlw 0x03          ;902
	call blit
	movlw 0x86
	call blit
	movlw 0x03          ;800
	call blit
	movlw 0x20
	call blit
	movlw 0x00          ;000
	call blit
	movlw 0x00
	call blit
	movlw 0x00          ;001
	call blit
	movlw 0x01
	call blit
	movlw 0x00          ;001
	call blit
	movlw 0x01
	call blit
	
	return
