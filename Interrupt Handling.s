
                    THUMB                                           ; Thumb instruction set
                    AREA            My_code, CODE, READONLY         ; define this as a code area
                    EXPORT          __MAIN                          ; make __MAIN viewable externally
                    EXPORT          EINT3_IRQHandler
                    ENTRY                                           ; define the access point

__MAIN



RNG_SETUP           MOV             R11, #0xABCD                    ; init the random number generator with a non-zero number



IRQ_SETUP           ; enabling GPIO interrupts, otherwise, the PC will not know to go to the IRQ Handler when P2.10 changes states
                    LDR             R0, =ISER0                      ; get the address of the Interrupt Set-Enable Register 0
                    MOV             R3, #0x00200000                 ; set the 21st bit high, corresponds to P2.10
                    STR             R3, [R0]                        ; store R3 in ISER0 to enable P2.10 GPIO interrupts

                    ; enabling falling edge interrupts, otherwise, the IRQ will be triggered when we are not pressing the button
                    LDR             R0, =IO2IntEnf                  ; get the address to enable the falling edge interrupt of port 2
                    MOV             R3, #0x00000400                 ; set the 10th bit high, corresponds to P2.10
                    STR             R3, [R0]                        ; store R3 in ISER0 to enable P2.10 falling edge GPIO interrupts



LED_SETUP           LDR             R10, =LED_BASE_ADR              ; R10 is a permenant pointer to the base address for the LEDs, offset of 0x20 and 0x40 for the ports
                    BL              TURN_LEDS_OFF                   ; turn off all the LEDs



FLASH_LED           ; port 1
                    EOR             R1, R1, #0xB0000000             ; flip the port 1 LED instructions, ON to OFF or OFF to ON
                    STR             R1, [R10, #0x20]                ; implement the instruction

                    ; port 2
                    EOR             R2, R2, #0x0000007C             ; flip the port 2 LED insturctions, ON to OFF or OFF to ON
                    STR             R2, [R10, #0x40]                ; implement the instruction



HIGH_F_DELAY        MOV             R0, #3                          ; 0.1s delay * 3 = 0.3s delay
                                                                    ; 1Hz = 1/s = 1/ 0.3 =  3.33Hz 
                                                                    ; storing 3 in R0 will result is a 3.33Hz delay      
                    BL              DELAY_CALC                      ; branch to the subroutine which will result in the delay
                    B               FLASH_LED                       ; if we have waited 3.33Hz change the LEDs status



TURN_LEDS_OFF       STMFD           R13!, {R14}                      

                    ; turn off port 1 LEDS
                    MOV             R1, #0xB0000000                 ; store instruction to turn off port 1 LEDs in R1
                    STR             R1, [R10, #0x20]                ; implement the instruction

                    ; turn off port 2 LEDS
                    MOV             R2, #0x0000007C                 ; store instruction to turn off port 2 LEDs in R2
                    STR             R2, [R10, #0x40]                ; implement the instruction

                    LDMFD           R13!, {R15}                     ; pop the latest push, the link register, to the program counter to return where we were previously
                              
                              

; Display the number in R6 onto the 8 LEDs
DISPLAY_NUM         STMFD           R13!, {R1, R2, R5, R6, R7, R14} ; preserve registers we are modifying
                    EOR             R7, R6, #0xFF                   ; flip the bits as the LEDs are active low

                    ; get instruction for port 2 LEDs
                    MOV32           R1, #0x0000001F                  ; make the five LSBs OF R1 high to help isolate the bits of the reaction time number corresponding to port 2 in the next line
                    AND             R1, R1, R7                          
                    LSL             R1, R1, #27                          
                    RBIT            R1, R1                          ; reverse the bit's order (as the LEDs of port 2 are in increasing order from right to left)
                                                                    ; CLZ ensures that the five bits we wanted are in the least significant positions when the bit's positions are reversed
                    LSL             R1, #2                          ; shift the bits two to the left so the LSB now aligns with the bit instruction of P2.2


                    ; get instruction for port 1 LEDs, R2 holds the instruction we will write to the port

                    ; get bit 7 and put it in the 28th bit of R2
                    MOV32           R2, 0x00000080                  ; make only the 7th bit of R2 high to isolate the 7th bit of R7 in the next instruction
                    AND             R2, R2, R7
                    LSL             R2, #21                         ; shift the 7th bit to the 28th bit of 22

                    ; get the 6th bit of the number and put it in the 29th bit of R2
                    MOV32           R5, 0x00000040                  ; make only the 6th bit of R5 high to isolate the 6th bit of R7 in the next instruction
                    AND             R5, R5, R7
                    LSL             R5, #23                         ; shift the 6th bit to the 29th bit of R5
                    ADD             R2, R2, R5                      ; add R5 to R2, now LEDs P2.28 and P2.29 have their corresponding instructions

                    ; get the 5th bit of the number and put it in the 31st bit of R2
                    MOV32           R5, #0x00000020                 ; make only the 5th bit of R5 high to isolate the 5th bit of R7 in the next instruction
                    AND             R5, R5, R7
                    LSL             R5, #26                         ; shift the 5th bit to the 31th bit of R5
                    ADD             R2, R2, R5                      ; add R5 to R2, now, all LEDs of P.2 have their instructions

                    ; implement LEDs instructions
                    STR             R2, [R10, #0x20]                ; port 1
                    STR             R1, [R10, #0x40]                ; port 2

                    LDMFD           R13!, {R1, R2, R5, R6, R7, R15} ; return and restore modified registers




; Subroutine which calculates the length of the delay
DELAY_CALC          STMFD           R13!, {R5, R14}                 ; preserve the registers we are modifying
                    MOV32             R5, #0x208D5                  ; set the counter to the number of DELAY_LOOP loops which results in 0.1ms time
                                                                    ; (4M/s)*(0.1s) = 400000 cyles per 1ms
                                                                    ; (400000 cycles) / (3 cycles/delay loop) ~= 133333 loops    
                    MUL             R5, R5, R0                      ; store the total delay value in R2 by multiplying it by R0 (R0 holds the time in 1ms the program needs to delay)         

; implement the delay specified by looping
DELAY_LOOP          SUBS            R5, #0x1                        ; decrement the delay counter
                    BGT             DELAY_LOOP                      ; continue decreasing the delay counter until it reaches zero                          
                    LDMFD           R13!,{R5, R15}                  ; set the PC to the line after the line which called this subroutine



; Interrupt Service Routine (ISR) for EINT3_IRQHandler
; This ISR handles the interrupt triggered when the INT0 push-button is pressed
; with the assumption that the interrupt activation is done in the main program
EINT3_IRQHandler    STMFD           R13!, {R0, R1, R4, R14}         ; preserve registers we are using         

                    BL              RNG                             ; get a random number and store it in R6
                    MOV             R6, R11

; scale the random number generated to result in a value between 50 and 250 using modulus
SCALE_NUM           MOV32           R1, #0xC9                      ; have R1 store the value 201
                    UDIV            R0, R6, R1                      ; divide R6 by 201, this gives the quotient
                    MUL             R0, R0, R1                      ; multiply the quotient by the divsor and store it in R0
                    SUB             R6, R6, R0                      ; subtract the random number generated by R0, this gives the remainder
                    ADD             R6, R6, #0x32                   ; the remainder is a number between 0 and 200, thus we must add 50 to give a number between 50 and 250
                              
SET_DELAY_NUM           MOV             R0, #10                     ; move 10 into R0, this is used to represent a 1 second delay in the delay subroutine

DISPLAY_NUMS_LOOP   BL              DISPLAY_NUM                     ; branch to the subroutine which displays R6 onto the board
                    BL              DELAY_CALC                      ; call the delay subroutine
                    SUBS            R6, #10                         ; subtract 10 from R6, to represent subtracting a second
                    BGT             DISPLAY_NUMS_LOOP               ; if R6 > 0, loop back to DISPLAY_NUMS_LOOP, otherwise, go on to end the interrupt

DONE                BL              TURN_LEDS_OFF                   ; call the subroutine to turn the LEDs off
                    BL              DELAY_CALC                      ; call the delay subroutine

CLEAR_INTERRUPT     LDR             R0, =IO2IntClr                  ; load the GPIO Interrupt Clear register for port 2 address into R0
                    MOV32           R1, #0x400                      ; make only the tenth bit of R1 high, corresponds to P2.10
                    STR             R1, [R0]                        ; clear the interrupt by writing a 1 to the tenth bit of the GPIO Interrupt Clear register for port 2
                                                                    ; otherwise, we will never return back to the main program

EXIT                LDMFD           R13!, {R0, R1, R4, R15}         ; exit out of the interrupt request and restore modofied registers



; generate a random 16-bit number
RNG                 STMFD           R13!, {R1, R2, R3, R14}          ; Random Number Generator
                    AND             R1, R11, #0x8000
                    AND             R2, R11, #0x2000
                    LSL             R2, #2
                    EOR             R3, R1, R2
                    AND             R1, R11, #0x1000
                    LSL             R1, #3
                    EOR             R3, R3, R1
                    AND             R1, R11, #0x0400
                    LSL             R1, #5
                    EOR             R3, R3, R1                          ; the new bit to go into the LSB is present
                    LSR             R3, #15
                    LSL             R11, #1
                    ORR             R11, R11, R3
                    LDMFD           R13!, {R1, R2, R3, R15}



; Given list of useful registers with their respective memory addresses.
LED_BASE_ADR        EQU         0x2009c000                          ; Base address of the memory that controls the LEDs
PINSEL3             EQU         0x4002C00C                          ; Pin Select Register 3 for P1[31:16]
PINSEL4             EQU         0x4002C010                          ; Pin Select Register 4 for P2[15:0]
FIO1DIR             EQU         0x2009C020                          ; Fast Input Output Direction Register for Port 1
FIO2DIR             EQU         0x2009C040                          ; Fast Input Output Direction Register for Port 2
FIO1SET             EQU         0x2009C038                          ; Fast Input Output Set Register for Port 1
FIO2SET             EQU         0x2009C058                          ; Fast Input Output Set Register for Port 2
FIO1CLR             EQU         0x2009C03C                          ; Fast Input Output Clear Register for Port 1
FIO2CLR             EQU         0x2009C05C                          ; Fast Input Output Clear Register for Port 2
IO2IntEnf           EQU         0x400280B4                          ; GPIO Interrupt Enable for port 2 Falling Edge
ISER0               EQU         0xE000E100                          ; Interrupt Set-Enable Register 0
IO2IntClr           EQU         0x400280AC                          ; GPIO Interrupt Clear register for port 2

                    ALIGN

                    END