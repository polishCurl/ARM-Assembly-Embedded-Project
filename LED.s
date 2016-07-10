;--------------------------------------------------------------------------------------
; LED utility methods
; Krzysztof Koch
; 17th April 2016
;
; Last edit: 6th May 2016
; 
; Methods to control the LEDs on board.
; 
; (Tab size - 4)
;--------------------------------------------------------------------------------------


;---------------------------------------SETUP LEDs------------------------------------
; Initially switch off all the LEDs.
; Local registers:
; 	R4 - IOspace base pointer
; 	R5 - value to write to switch off al the LEDs

setupLEDs 		PUSH 	{R4-R5}
				MOV 	R4, #IOspace  			; switch off all the LEDs
				MOV 	R5, #0 					
				STRB 	R5, [R4, #LEDaddress]

				LDRB 	R5, [R4, #LEDEnAddress]	; enable LEDs
				ORR 	R5, R5, #LEDEnable
				STRB 	R5, [R4, #LEDEnAddress]
				POP 	{R4-R5}
				MOV 	PC, LR



;------------------------------------STORE LEDs STATE----------------------------------
; Save the state of LEDs in another memory location, so printing to LCD screen doesn't pernamently
; change the LED lights. I use this and the following method because of legacy code for printing
; characters to LCD screen that didn't consider that the same ports are used for LED lights. This 
; hasn't been a problem before I started doing PWM and printing the on cycle at the same time.
; Arguments:
; 	R0 - SVC call number, if called from supervisor mode then equal to MaxSVC
; Local registers:
; 	R4 - IOspace base pointer 
; 	R5 - byte to be moved between the memory locations to save LEDs state
; 	R6 - pointer to backup memory locations

storeLEDs 		CMP 	R0, #MaxSVC				; Check if we're dealing with SVC call. If so,
				POPNE 	{R4} 					; POP old R4 (before SVC table pointer)
				PUSH 	{R4-R6}
				MOV 	R4, #IOspace  			; Save the state at address 10000000,					
				LDRB 	R5, [R4, #LEDaddress] 	; actual lights that are on
				ADR 	R6, LEDstate
				STRB 	R5, [R6]
				LDRB 	R5, [R4, #LEDEnAddress] ; Save the state at address 10000004, 
				ADR 	R6, LEDcontrol 			; Most importantly LED enable bit
				STRB 	R5, [R6]
				POP 	{R4-R6}
				CMP 	R0, #MaxSVC
				MOVEQ   PC, LR  				; return to the caller method, OR...
				MOVS 	PC, LR 					; return from this Supervisor call [USER_CODE.s]



;-----------------------------------RESTORE LEDs STATE---------------------------------
; Restore the value in the extra memory location back to the address of LEDs
; Arguments:
; 	R0 - SVC call number, if called from supervisor mode then equal to MaxSVC
; Local registers:
; 	R4 - pointer to LED state backup locations
; 	R5 - LED bit pattern to be moved between the memory locations to restore the state
;	R6 - IOspace base pointer 

restoreLEDs 	CMP 	R0, #MaxSVC				; Check if we're dealing with SVC call. If so,
				POPNE 	{R4} 					; POP old R4 (before SVC table pointer)
				PUSH 	{R4-R6}
				ADR 	R4, LEDstate 			; Restore the state at address 10000000,
				LDRB 	R5, [R4] 				; actual lights that are on
				MOV 	R6, #IOspace  							
				STRB 	R5, [R6, #LEDaddress]	
				ADR 	R4, LEDcontrol 			; Restore the state at address 10000004
				LDRB 	R5, [R4] 				; Most importantly LED enable bit
				STRB 	R5, [R6, #LEDEnAddress]
				POP 	{R4-R6}
				CMP 	R0, #MaxSVC
				MOVEQ   PC, LR  				; return to the caller method, OR...
				MOVS 	PC, LR 					; return from this Supervisor call [USER_CODE.s]



;-----------------------------------SWITCH LED ON/OF-----------------------------------
; Method to turn the LED in R1 on/off depending on the value in R2
; Arguments:
; 	R0 - SVC call number, if called from supervisor mode then equal to MaxSVC
; 	R1 - LED number, LED to turn on/off
; 	R2 - 0 (off), any other value (on)
; Local register:
; 	R4 - pointer to the starting address of the I/O space
; 	R5 - state of LED before the change
; 	R6 - used to generate bitmask to turn specific pin on without affecting other pins
				
switchLED		CMP 	R0, #MaxSVC				; Check if we're dealing with SVC call. If so,
				POPNE 	{R4} 					; POP old R4 (before SVC table pointer)
				PUSH 	{R4-R6}
				MOV 	R4, #IOspace  			; enable LED switching	
			
				LDRB 	R5, [R4, #LEDaddress] 	; load the current bitmask for LED lights
				MOV 	R6, #1 	
				LSL 	R6, R6, R1 				; create bitmasks so that turning specific LED on/off
				CMP 	R2, #0 					; check if we should switch given LED on or off
				ORRNE 	R5, R5, R6 				; won't affect others
				MVNEQ 	R6, R6
				ANDEQ 	R5, R5, R6 
				STRB 	R5, [R4, #LEDaddress]	; update the state of LEDs

				CMP 	R0, #MaxSVC 
				POP 	{R4-R6}
				MOVEQ   PC, LR  				; return to the caller method, OR...
				MOVS 	PC, LR 					; return from this Supervisor call [USER_CODE.s]



;--------------------------------PULSE-WIDTH MODULATION------------------------------
; Pulse-width modulate the LED given in R0. The code assumes the period length is 20ms. And the 
; on-cycle length is read from pulseWidth memory location
; Arguments:
; 	R0 - LED number to apply PWM to
; Local register:
; 	R4 - temporarily holds the LED number so that it doesn't get overwritten
; 	R5 - pulse length (in milliseconds)
				
pwmLED 			PUSH 	{R4-R5, LR}
				MOV 	R4, R0 					; move the argument so it doesn't get overwritten
				ADR 	R5, pulseWidth 			; load the pulse Length from memory
				LDR 	R5, [R5] 				

				MOV 	R0, #LED_WRITE 			; switch the LED on
				MOV 	R1, R4 					
				MOV 	R2, #1
				SVC 	6
				MOV 	R0, R5 					; wait for the [pulseWidth] number of millisecons
				BL 		wait
				MOV 	R0, #LED_WRITE 			; switch the LED off
				MOV 	R1, R4
				MOV 	R2, #0
				SVC 	6
				RSB 	R0, R5, #period 		; wait the [period] - [pulseWidth] number of ms
				BL  	wait

				POP 	{R4-R5, LR}
				MOV 	PC, LR



;---------------------------------INCREASE PULSE WIDTH--------------------------------
; Increment the pulse width by 1.
; Local registers:
; 	R4 - pointer to the pulseWidth memory location
; 	R5 - value at pulseWidth

incrPulseWidth 	PUSH 	{R4-R5}
				ADR 	R4, pulseWidth
				LDR 	R5, [R4]
				CMP 	R5, #period 			; increment the pulse width only when it is shorter
				ADDLT 	R5, R5, #1 				; than the period
				STR 	R5, [R4] 
				POP 	{R4-R5}
				MOV 	PC, LR



;---------------------------------DECREASE PULSE WIDTH--------------------------------
; Decrement the pulse width by 1.
; Local registers:
; 	R4 - pointer to the pulseWidth memory location
; 	R5 - value at pulseWidth

decrPulseWidth 	PUSH 	{R4-R5}
				ADR 	R4, pulseWidth
				LDR 	R5, [R4]
				CMP 	R5, #0 					; decrement the pulse width only of it is positive
				SUBGT 	R5, R5, #1
				STR 	R5, [R4] 
				POP 	{R4-R5}
				MOV 	PC, LR



;---------------------------------CHANGE DEFAULT LED--------------------------------
; Calculate the next LED to be the default one for switching on and off (used in PWMtest.s)
; Arguments:
; 	R0 - index of the current LED to be switched On/Off on default
; Returns:
; 	R0 - index of the next LED to be controlled on default

changeLED 		ADD 	R0, R0, #1 				; make sure we wrap up the index to match the number 
				CMP 	R0, #numberOfLEDs 		; of LEDs on board
				MOVEQ 	R0, #0
				MOV 	PC, LR



; ---------------------------------DEFINITIONS--------------------------------------
LEDaddress 		EQU 	0x0 					; offset from IO space base to LED address
LEDEnAddress  	EQU 	0x4	 					; offset from IO space base to LED enable bit address
LEDEnable 	 	EQU 	0x10					; bitmask to enable/disable LED

numberOfLEDs 	EQU 	8 						; number of LEDs on the board
GreenLeft 		EQU 	0x0 					; bit numbers corresponding to specific lights 
AmberLeft 		EQU 	0x1 					; on the board
RedLeft 		EQU 	0x2 		
BlueLeft 		EQU 	0x3 		
GreenRight 		EQU 	0x4 		
AmberRight 		EQU 	0x5 		
RedRight 		EQU 	0x6 		
BlueRight 		EQU 	0x7 	

period 			EQU 	20 						; Pulse-width-modulation period (in ms)
pulseWidth 		DEFW 	20 						; Pulse-width-modulation on cycle (in ms) 

LEDstate 		DEFB 	0x0 					; temporaily holds LED states and control bitmask 
				ALIGN
LEDcontrol 		DEFB 	0x0 					; while character is printed to the LCD screen
				ALIGN