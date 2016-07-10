;--------------------------------------------------------------------------------------
; Pulse-Width-Modulation tester program
; Krzysztof Koch
; 18th April 2016
;
; Last edit: 6th May 2016
; 
; User program to present Pulse-Width-Modulation on a given LED.
; 
; Instructions:
; 	1. Change the LED to Pulse-Width-Modulate using the lower button on board
;  	2. Using '*' and '#' buttons on the first keyboard incrent and decrement the on-cycle
;      of the LED
;
; Register use:
;	R4 - holds the last button pressed for comparison to detect when the button was released
; 	R5 - index of LED to perform PWM on
; (Tab size - 4)
;--------------------------------------------------------------------------------------


; ===================================PWM TESTER FSM====================================
pwmTest 		MOV 	R5, #GreenLeft  		; Pick the initial LED to PWM on
				BL 		pwmOutput 				; print the info message about the current on-cycle


; ----------------------------------TEST IF KEY PRESSED--------------------------------
pwmKeyTest		MOV 	R0, #READ_KEYBOARD		; poll the keyboard											
				SVC 	4
				CMP 	R0, #keyNoTotal 		; if no key pressed jump to buttons polling
				BGE 	pwmButtonTest
				MOV		R4, R0 	 				; otherwise, store the character in R4


; --------------------------------WAITING FOR KEY RELEASE------------------------------
notReleasedKey	MOV 	R0, #READ_KEYBOARD 		; keep checking if the same key is still pressed
				SVC 	4 						
				CMP		R0, R4 					
				BEQ 	notReleasedKey 			
				

; -----------------------------------INTERPTET THE KEY---------------------------------
				MOV 	R0, R4 					; run the method that analyses the key pressed
				BL 		processKey 				; interpret the key pressed
				BL 		pwmOutput 				; print the info message about the new on-cycle


; ---------------------------------TEST IF BUTTON PRESSED------------------------------
pwmButtonTest 	MOV 	R0, #READ_BUTTONS 		; poll the on-board buttons
				SVC 	3
				CMP 	R0, #0
				BEQ 	modulate 				; if no button pressed, perform PWM
				MOV 	R4, R0


; --------------------------------WAITING FOR BUTTON RELEASE---------------------------
notReleasedBtn	MOV 	R0, #READ_BUTTONS 		; keep checking if the same button is still pressed
				SVC 	3 						
				CMP		R0, R4 					
				BEQ 	notReleasedBtn


; -------------------------------INTERPRET THE BUTTON PRESSED--------------------------
				TST 	R4, #upPressed 			; if upper button pressed then close the program
				MOVNE 	R0, #EXIT 				
				SVCNE 	0
				TST 	R4, #lowPressed   		; If lower then change the LED to PWM on
				MOVNE 	R0, R5		
				BL 		changeLED
				MOV 	R5, R0

; ---------------------------------DO PULSE-WIDTH MODULATION---------------------------
modulate 		MOV 	R0, R5
				BL 		pwmLED
				B 		pwmKeyTest

; =====================================================================================
				


; ------------------------------PROCESS KEY PRESSED-----------------------------------
; Run the appropriate handler method according to the key pressed. Increment or decrement
; pulse width
; Arguments
; 	R0 - index of they key pressed 

processKey 		PUSH 	{LR}
				CMP 	R0, #decrPulseKey
				BLEQ 	decrPulseWidth
				CMP 	R0, #incrPulseKey
				BLEQ 	incrPulseWidth
				POP 	{PC}
				


; ---------------------------DISPLAY OUTPUT TO THE USER------------------------------
; Display output to the user on the LCD screen.
				
pwmOutput		PUSH 	{LR}
				MOV 	R0, #LED_STORE 			; store the LED state, because of legacy code I didn't
				SVC 	7 						; change the #PRINT_CHAR SVC call that clears the LCDs state. 
				ADR 	R0, pwmMessage 			; This time I want to repeatedly use LEDs and LCD in turn so 
				BL 		printString 			; I want to preserve LEDs state. Print the message to the user
				BL 		printPWM 				; print the Pulse width
				MOV 	R0, #PRINT_CHAR 		; Append the '%' at the end 
				MOV 	R1, #percentASCII
				MOV 	R2, #ctrlWriteChar
				SVC 	1
				MOV 	R0, #LED_LOAD 			; restore the LCD state
				SVC 	8
				POP 	{PC} 



; -------------------------------PRINT PWM VALUE--------------------------------------
; Print the On-Cycle value. Print the percentage of time the LED is on during the period
; Local registers:
;	R4 - pointer to the pulseWidth memory location
; 	R5 - multplier by 100

printPWM 		PUSH 	{R4-R5, LR}
				ADR 	R4, pulseWidth 			; load the pulseWidth value
				LDR 	R4, [R4]
				MOV 	R5, #100 				; multiply it by 100 and then devide by period
				MUL 	R0, R4, R5 				; to get the percentage 
				MOV 	R1, #period
				BL 		divide 	   
				BL 		bcd_convert				; conver the percentage to BCD and print it
				BL 		printBCD
				
				POP 	{R4-R5, LR}
				MOV 	PC, LR


; ---------------------------------DEFINITIONS--------------------------------------
decrPulseKey	EQU 	9 						; index of the '*' key - decrement pulse width
incrPulseKey 	EQU 	11						; index of the '#' key - increment pulse width
percentASCII 	EQU 	0x25 					; ASCII code for '%'

pwmMessage		DEFB 	FF, "Pulse width:", LF, NULL ; Message that keeps being printed all time this 
				ALIGN 							; app is running
