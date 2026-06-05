; routines.asm
        org $3000               ; routines live at $3000

; print a string
; Assumptions
; strptr_lo = low address of the string
; strptr_hi = high address of the string
;       together we have a 16-bit address of the string

; Y = index of current character to process, starts at 0
; example calling code:
;       mva #1 csrhinh                  ; hide the cursor
;        mva #6 rowcrs                   ; set output row
;        mva #10 colcrs                  ; set output column
;        
;        mva #<string1 strptr_lo         ; low byte of string1 address
;        mva #>string1 strptr_hi         ; high byte o f string1 address
;        jsr print_string                ; print the string
;
;========= don't forget you'll need data
;       .local string1
;        .byte 'HELLO FROM STRING ONE!',0
;        .endl


        .proc print_string
        ldy #0
loop:
        lda (strptr_lo),y               ; with an offset of Y bytes, grab the byte at the 16-bit address
        cmp #0                          ; test if we found the 0 string terminator: A == 0?   
        beq exit                        ; if true, branch to exit
        tya                             ; A = Y
        pha                             ; push A onto the stack
        lda (strptr_lo),y               ; re-fetch current byte of string
        jsr putchar                     ; call putchar to write a character out
        pla                             ; A = pop stack
        tay                             ; Y = A
        iny                             ; Y = Y + 1
        jmp loop                        ; GOTO loop
exit:
        rts                             ; exit subroutine
        .endp

stop:
        jmp stop                        ; GOTO stop                   (infinite loop = program halts here)


; print a character
; Assumptions
; 1. the character is in register A
; 2. the character has been converted to ATASCII
; 3. before calling, save values of X and Y registers

        .proc putchar
        tax             ; X = A                       (save character from A into X because A is about to be clobbered)
        lda putchar_ptr+1 ; A = memory[$347]          (load high byte of OS print routine address)
        pha             ; push A onto stack            (high byte on stack, will be popped second by rts)
        lda putchar_ptr ; A = memory[$346]            (load low byte of OS print routine address)
        pha             ; push A onto stack            (low byte on stack, will be popped first by rts)
        txa             ; A = X                       (restore original character back into A because OS print routine expects character value in A)
        rts             ; RETURN                      (pops OS address from stack and jumps there, OS prints character in A, then returns to main)
        .endp           ; end of putchar procedure


; plot a point (x,y)
; Step 1: Find which ROW we're on
;        plotY × 40 = how many bytes to skip to reach our row
;        (each row is 40 bytes wide)
;        2^3 + 2^2
; Step 2: Find which BYTE within that row
;        plotX ÷ 8 = which byte contains our pixel
;        (each byte holds 8 pixels)
;
; Step 3: Add them together
;        (plotY × 40) + (plotX ÷ 8) = total byte offset from start of screen RAM
;
; Step 4: Add SAVMSC
;        SAVMSC + offset = actual address in memory of our byte
;
; Step 5: Find which BIT within that byte
;        7 - (plotX mod 8) = which bit is our pixel
;
; Step 6: Set that bit
;        read the byte
;        OR with our bit mask
;        write the byte back
;
        .proc plotPoint

        ; see multiplyingYby40.txt for full breakdown with an example!

        ; defeat attract mode on every plot
        mva #0    ATRACT
        mva #$FF  ATRMSK

        ; Step 1: Find which ROW we're on
        lda plotY
        sta temp_lo         ; temp = plotY
        lda #0
        sta temp_hi         ; high byte starts at 0

        ; × 2
        asl temp_lo         ; shift temp_lo to the left one bit
        rol temp_hi         ; shift temp_hi to the left one bit and include the carry 

        ; × 4
        asl temp_lo
        rol temp_hi

        ; × 8  ← save this!
        asl temp_lo
        rol temp_hi
        lda temp_lo
        sta save_lo
        lda temp_hi
        sta save_hi

        ; × 16
        asl temp_lo
        rol temp_hi

        ; × 32
        asl temp_lo
        rol temp_hi

        lda temp_lo         ; A = temp_lo    (low byte of plotY × 32)
        clc                 ; clear carry
        adc save_lo         ; A = temp_lo + save_lo  (add plotY × 8)
        sta temp_lo         ; temp_lo = low byte of plotY × 40

        lda temp_hi         ; A = temp_hi    (high byte of plotY × 32)
        adc save_hi         ; A = temp_hi + save_hi + carry  (add high bytes)
        sta temp_hi         ; temp_hi = high byte of plotY × 40
        ; we now have the offset to our target row in temp_lo and temp_hi

        ; calculate which bit 
        lda plotX_lo
        and #%00000111      ; mask bottom 3 bits = plotX mod 8
        sta bitpos          ; save for Step 5

        ; Step 2: find offset from start of row to our pixel
        ; plotX ÷ 8 using 16-bit right shift
        ; ON ENTRY: plotX_hi/plotX_lo contains X coordinate (0-319)
        ; ON EXIT:  A contains column byte offset (0-39)
        lsr plotX_hi        ; shift high byte right, bit 0 → carry
        ror plotX_lo        ; carry → bit 7 of low byte, bit 0 → carry

        lsr plotX_hi        ; shift again
        ror plotX_lo

        lsr plotX_hi        ; shift again
        ror plotX_lo        ; plotX_lo now contains plotX ÷ 8

        ; Step 3: add results from step 1 and 2 together
        lda temp_lo
        clc
        adc plotX_lo
        sta temp_lo

        lda temp_hi
        adc #0
        sta temp_hi
        ; temp now contains total byte offset from SAVMSC

        ; Step 4: Add SAVMSC Base Address
        lda temp_lo
        clc
        adc SAVMSC
        sta scrptr_lo

        lda temp_hi
        adc SAVMSC+1
        sta scrptr_hi

        ; Step 5: find which bit to turn on
        ; algo:  bit position = 7 - (plotX mod 8)
        ; Step 5: find which bit to turn on
        lda #$80            ; A = %10000000  (start with bit 7)
        ldx bitpos          ; X = number of times to shift right
        beq done_shift      ; if bitpos = 0 no shifting needed!
shift_loop:
        lsr                 ; shift A right one position
        dex                 ; X = X - 1
        bne shift_loop      ; if X != 0 keep shifting
done_shift:
                            ; A now contains our bit mask

        ; Step 6: turn on our bit!!
        sta bitmask             ; save mask
        ldy #0                  ; Y = 0 for indirect indexed addressing
        lda (scrptr_lo),y       ; read current byte from screen RAM
        ora bitmask             ; OR with our bit mask (sets our pixel bit)
        sta (scrptr_lo),y       ; write modified byte back to screen RAM

        rts
        .endp


; =====================================================================
; DATA
; =====================================================================
scrname .byte 'S:',$9B             ; device name string for CIO OPEN
                                    ; 'S:' = screen device
                                    ; $9B  = ATASCII end-of-line terminator