; routines.asm
        org $3000               ; routines live at $3000


;=========================================================================================
; draw a circle using Bresenham's circle algorithm
; ON ENTRY: cx/cx_hi = center X, cy = center Y, radius = radius
; ON EXIT:  circle drawn on screen

        .proc drawCircle

        ; initialize error term: cerr = 1 - radius
        lda #1
        sec
        sbc radius
        sta cerr_lo
        lda #0
        sbc #0
        sta cerr_hi

        ; initialize offsets
        mva #0  circX       ; circX = 0
        lda radius
        sta circY           ; circY = radius

circleloop:

        ; plot point 1: (cx + circX, cy + circY)
        lda cx
        clc
        adc circX
        sta plotX_lo
        lda cx_hi
        adc #0
        sta plotX_hi
        lda cy
        clc
        adc circY
        sta plotY

        lda plotX_lo
        pha
        lda plotX_hi
        pha
        jsr plotPoint
        pla
        sta plotX_hi
        pla
        sta plotX_lo

        ; plot point 2: (cx - circX, cy + circY)
        lda cx
        sec
        sbc circX
        sta plotX_lo
        lda cx_hi
        sbc #0
        sta plotX_hi
        lda cy
        clc
        adc circY
        sta plotY

        lda plotX_lo
        pha
        lda plotX_hi
        pha
        jsr plotPoint
        pla
        sta plotX_hi
        pla
        sta plotX_lo

        ; plot point 3: (cx + circX, cy - circY)
        lda cx
        clc
        adc circX
        sta plotX_lo
        lda cx_hi
        adc #0
        sta plotX_hi
        lda cy
        sec
        sbc circY
        sta plotY

        lda plotX_lo
        pha
        lda plotX_hi
        pha
        jsr plotPoint
        pla
        sta plotX_hi
        pla
        sta plotX_lo

        ; plot point 4: (cx - circX, cy - circY)
        lda cx
        sec
        sbc circX
        sta plotX_lo
        lda cx_hi
        sbc #0
        sta plotX_hi
        lda cy
        sec
        sbc circY
        sta plotY

        lda plotX_lo
        pha
        lda plotX_hi
        pha
        jsr plotPoint
        pla
        sta plotX_hi
        pla
        sta plotX_lo

        ; plot point 5: (cx + circY, cy + circX)
        lda cx
        clc
        adc circY
        sta plotX_lo
        lda cx_hi
        adc #0
        sta plotX_hi
        lda cy
        clc
        adc circX
        sta plotY

        lda plotX_lo
        pha
        lda plotX_hi
        pha
        jsr plotPoint
        pla
        sta plotX_hi
        pla
        sta plotX_lo

        ; plot point 6: (cx - circY, cy + circX)
        lda cx
        sec
        sbc circY
        sta plotX_lo
        lda cx_hi
        sbc #0
        sta plotX_hi
        lda cy
        clc
        adc circX
        sta plotY

        lda plotX_lo
        pha
        lda plotX_hi
        pha
        jsr plotPoint
        pla
        sta plotX_hi
        pla
        sta plotX_lo

        ; plot point 7: (cx + circY, cy - circX)
        lda cx
        clc
        adc circY
        sta plotX_lo
        lda cx_hi
        adc #0
        sta plotX_hi
        lda cy
        sec
        sbc circX
        sta plotY

        lda plotX_lo
        pha
        lda plotX_hi
        pha
        jsr plotPoint
        pla
        sta plotX_hi
        pla
        sta plotX_lo

        ; plot point 8: (cx - circY, cy - circX)
        lda cx
        sec
        sbc circY
        sta plotX_lo
        lda cx_hi
        sbc #0
        sta plotX_hi
        lda cy
        sec
        sbc circX
        sta plotY

        lda plotX_lo
        pha
        lda plotX_hi
        pha
        jsr plotPoint
        pla
        sta plotX_hi
        pla
        sta plotX_lo

        ; advance circX
        inc circX

        ; check sign of cerr
        lda cerr_hi
        bmi update_negative     ; cerr < 0

        ; positive path: cerr >= 0
        dec circY               ; circY = circY - 1
        lda circX
        sec
        sbc circY               ; A = circX - circY
        asl                     ; A = 2*(circX-circY)
        clc
        adc #1                  ; A = 2*(circX-circY) + 1
        clc
        adc cerr_lo
        sta cerr_lo
        lda cerr_hi
        adc #0
        sta cerr_hi
        jmp check_done          ; skip negative path

update_negative:
        ; negative path: cerr < 0
        lda circX
        asl                     ; A = 2*circX
        clc
        adc #1                  ; A = 2*circX + 1
        clc
        adc cerr_lo
        sta cerr_lo
        lda cerr_hi
        adc #0
        sta cerr_hi
                                ; fall through to check_done

check_done:
        lda circX
        cmp circY
        bcc keep_going      ; circX < circY — short forward branch
        beq keep_going      ; circX = circY — short forward branch
        rts                 ; circX > circY — done!
keep_going:
        jmp circleloop      ; jump back — unlimited range
        .endp


; =====================================================================
; fightAttract
; Call this every frame in your stop loop to prevent attract mode
; from desaturating your colors
; ON ENTRY: nothing
; ON EXIT:  attract mode defeated for this frame
;======================================================================
        .proc fightAttract

        ; defeat attract mode and set colors
        mva #0    ATRACT
        mva #$FF  ATRMSK

        rts
        .endp

; =====================================================================
; Clear the screen

        .proc clearScreen

; initialize pointer from SAVMSC
        lda SAVMSC
        sta scrptr_lo
        lda SAVMSC+1
        sta scrptr_hi

; here we have a nested loop the iner loop will start at 0 and end at 255. 
; When Y overflows from 255 to 0, bne does NOT branch (falls through)
; because Y equals zero — exiting the inner loop into the outer loop.

        ldx #30             ; X = 30 pages to clear
        ldy #0              ; Y = byte index within page

clearpage:
        lda #$00
        sta (scrptr_lo),y   ; write $00
        iny                 ; next byte
        bne clearpage       ; inner loop — 256 bytes

        inc scrptr_hi       ; advance to next page
        dex                 ; X = X - 1
        bne clearpage       ; outer loop — 30 pages

        rts
        .endp


; =====================================================================
; Open Graphics Mode 8

        .proc openGR8

; =====================================================================
; STEP 1: Close IOCB6
; Good practice to close before opening — ensures clean state.
; ON ENTRY: X must contain IOCB number × $10 ($60 for IOCB6)
; ON ENTRY: ICCOM must contain the command ($0C = CLOSE)
; ON EXIT:  IOCB6 is closed and ready to be reopened
; =====================================================================
        ldx #$60                    ; X = $60        (select IOCB6)
        lda #$0C                    ; A = $0C        (CLOSE command)
        sta ICCOM,x                 ; ICCOM = $0C    (store command in IOCB6)
        jsr CIOV                    ; CALL CIOV      (execute the close)

; =====================================================================
; STEP 2: Open Graphics Mode 8
; Fills in all IOCB6 fields then calls CIOV to execute the open.
; CIO sets up the display list, allocates screen RAM, configures
; ANTIC — everything needed for graphics mode automatically.
; ON ENTRY: nothing required
; ON EXIT:  GR.8 screen is active, SAVMSC points to screen RAM
; =====================================================================


;   Draw yellow pixels on the Atari 800XL in Graphics Mode 8
;   Uses CIO (Central I/O) to open the graphics mode, then writes
;   pixel data directly to screen RAM.
;   GR.8:   320 pixels wide × 192 tall   1 bit per pixel     2 colors
;   GR.8:   40 bytes × 192 rows = 7,680 bytes
;   GR.8:   320 pixels ÷ 8 pixels per byte = 40 bytes per row
;   GR.8 byte:  P P P P P P P P
;               | | | | | | | |
;               7 6 5 4 3 2 1 0   (8 pixels, 1 bit each, on or off)

        ldx #$60                    ; X = $60        (select IOCB6)
        lda #$03                    ; A = $03        (OPEN command)
        sta ICCOM,x                 ; ICCOM = $03    (store open command)
        lda #<scrname               ; A = low byte of "S:" string address
        sta ICBAL,x                 ; ICBAL = low byte (tell CIO device name location)
        lda #>scrname               ; A = high byte of "S:" string address
        sta ICBAH,x                 ; ICBAH = high byte
        lda #$08                    ; A = $08        (graphics mode 8)
        sta ICAX2,x                 ; ICAX2 = $08    (store graphics mode number)
        lda #$0C                    ; A = $0C        (read/write access)
        sta ICAX1,x                 ; ICAX1 = $0C    (store access mode)
        jsr CIOV                    ; CALL CIOV      (execute open — sets up entire graphics mode!)

; Step 3: Setup color registers
; change COLPF1 to change pixel color

        mva #$1E  $02C5     ; COLPF1 = yellow (foreground - pixel color)
        mva #$00  $02C6     ; COLPF2 = black (background)
        mva #$00  $02C8     ; COLBK  = black (border)

        rts
        .endp

;=========================================================================================
; draw a line using Bresenham's algorithm

        .proc drawLine

        ; first step, compute:
        ; dx = x2 - x1    (16-bit subtraction)
        ; dy = y2 - y1    (8-bit subtraction)

        lda y2          ; A = Y2
        sec             ; set carry
        sbc y1          ; A = A - Y1
        sta dy          ; dy = A

        lda x2          ; A = x2 (low byte)
        sec             ; set carry
        sbc x1          ; A = A - X1 (low byte)
        sta dx_lo       ; save low byte, but do not re-set carry

        lda x2_hi       ; A = X2 (high byte)
        sbc x1_hi       ; A = A - X1 (high byte)
        sta dx_hi       ; save high byte

        ; check for vertical line (dx = 0)
        lda dx_lo
        ora dx_hi       ; OR low and high bytes together
        bne not_vertical ; if result != 0, not vertical

        ; handle vertical line
        ; initialize position first!
        lda x1
        sta plotX_lo
        lda x1_hi
        sta plotX_hi
        lda y1
        sta plotY

        ; just loop Y from y1 to y2
vertical_loop:
        lda plotX_lo    ; save plotX before plotPoint destroys it
        pha
        lda plotX_hi
        pha
        
        jsr plotPoint
        
        pla             ; restore plotX
        sta plotX_hi
        pla
        sta plotX_lo
        
        inc plotY
        lda plotY
        cmp y2
        bne vertical_loop
        
        ; plot final point
        lda plotX_lo
        pha
        lda plotX_hi
        pha
        jsr plotPoint
        pla
        sta plotX_hi
        pla
        sta plotX_lo
        
        rts

not_vertical:
        ; continue with normal Bresenham...

        ; initialize current position to start point
        lda x1          ; A = X1
        sta plotX_lo    ; plotX_lo = A
        lda x1_hi       ; A = X1_hi
        sta plotX_hi    ; plotX_hi = A
        lda y1          ; A = Y1
        sta plotY       ; plotY = A

        ; initialize error to 0
        mva #0 err_lo           ; err_lo = 0
        mva #0 err_hi           ; err_hi = 0

lineloop:
        ; save plotX before plotPoint destroys it
        lda plotX_lo
        pha
        lda plotX_hi
        pha

        jsr plotPoint

        ; restore plotX after plotPoint
        pla
        sta plotX_hi
        pla
        sta plotX_lo

; add dy to error accumulator (16-bit + 8-bit addition)
        lda err_lo              ; A = err_lo
        clc                     ; clear carry
        adc dy                  ; A += dy
        sta err_lo              ; err_lo = A
        lda err_hi              ; A = err_hi
        adc #0                  ; propagate carry trick. if the carry was set it gets added to the high byte
        sta err_hi              ; err_hi = A

        ; check if error * 2 >= dx
        ; compute error + error (16-bit)
        lda err_lo              ; A = err_lo
        clc                     ; clear carry
        adc err_lo              ; A += err_lo (err_lo * 2)
        sta temp_lo             ; temp_lo = A
        lda err_hi              ; A = err_hi
        adc err_hi              ; A += err_hi ((err_hi * 2) + carry)
        sta temp_hi             ; temp_hi = A

        ; compare temp (error*2) to dx
        ; 16-bit comparison: check high byte first, then low byte
        lda temp_hi     ; A = temp_hi
        cmp dx_hi       ; Does temp_hi == dx_hi? 
        bcc skip_y      ; temp_hi < dx_hi, no Y step needed (branch if carry is clear)
        bne do_y_step   ; temp_hi > dx_hi, Y step needed (branch if not equal)
        lda temp_lo     ; A = temp_lo (high bytes equal, check low bytes (if we got here, high bytes are equal))
        cmp dx_lo       ; Does temp_lo == dx_lo?
        bcc skip_y      ; temp_lo < dx_lo, no Y step needed

do_y_step:
        inc plotY       ; y = y + 1

        ; error = error - dx (16-bit subtraction)
        lda err_lo      ; A = err_lo
        sec             ; set the carry
        sbc dx_lo       ; A -= dx_lo
        sta err_lo      ; err_lo = A
        lda err_hi      ; A = err_hi
        sbc dx_hi       ; A -= dex_hi
        sta err_hi      ; err_hi = A

skip_y:
        ; advance x (16-bit increment)
        inc plotX_lo            ; plotX_lo++
        bne lineloop_check      ; if no overflow, check if done 
                                ; if plotX_lo != 0 JUMP FORWARD to lineloop_check
        inc plotX_hi            ; handle overflow from low to high byte
                                ; only reaches here if plotX_lo overflowed to 0

lineloop_check:
        ; are we done? compare plotX to x2
        lda plotX_lo            ; A = plotX_lo
        cmp x2                  ; test: A = X2 ?
        bne lineloop            ; not done, keep going
                                ; if plotX_lo != x2 JUMP BACK to lineloop
        lda plotX_hi            ; A = plotX_hi
        cmp x2_hi               ; test: A = x2_hi ?
        bne lineloop            ; not done, keep going
                                ; if plotX_hi != x2_hi JUMP BACK to lineloop
                                ; if both match we fall through - done!

        

        rts
        .endp


;=========================================================================================
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

;======================================================================
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
;======================================================================

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

;========================================================================================
;       print a 16-bit decimal
;       ON ENTRY: p16_val_lo/p16_val_hi contains the value to print

        .proc printBigDecimal

        ; Ten thousands place
        mva #0 p16_digit

tenthousands:
        ; is p16_val >= 10000?
        lda p16_val_hi          ; A = p16_val_hi
        cmp #$27                ; 10,000 base 10 is $2710, that's why we're comparing $27 here, the hi byte
        bcc doneTenThousands    ; < 10000, done
        bne do_subTenThousands  ; > 10000, subtract
        lda p16_val_lo          ; A = p16_val_lo
        cmp #$10                ; now we're comparing the low byte of the literal $2710 hex value
        bcc doneTenThousands    ; = exactly check low byte

do_subTenThousands:
        ; subtract 10000 (16-bit)
        lda p16_val_lo          ; A = p16_val_lo
        sec                     ; set the carry
        sbc #$10                ; A -= $10 (we are subtracting the low byte first. looks weird because it's a literal)
        sta p16_val_lo          ; p16_val_lo = A
        lda p16_val_hi          ; A = p16_val_hi
        sbc #$27                ; A -= $27 (we are subtracting the high byte of $2710 or 10,000 base 10)
        sta p16_val_hi          ; p16_val_hi = A
        inc p16_digit           ; p16_digit++
        jmp tenthousands        ; keep going

doneTenThousands:
        ; print the digit
        lda p16_digit
        clc
        adc #offset_to_char
        jsr putchar

        ; Thousands
        mva #0 p16_digit        ; reset our counter
thousands:
        ; is p16_val >= 1000?
        lda p16_val_hi          ; A = p16_val_hi
        cmp #$3                 ; 1000 base 10 is $03E8, that's why we're comparing $3 here, the hi byte
        bcc doneThousands       ; < 1000, done
        bne do_subThousands     ; > 1000, subtract
        lda p16_val_lo          ; A = p16_val_lo
        cmp #$E8                ; now we're comparing the low byte of the literal $03E8 hex value
        bcc doneThousands       ; = exactly check low byte

do_subThousands:
        ; subtract 1000 (16-bit)
        lda p16_val_lo          ; A = p16_val_lo
        sec                     ; set the carry
        sbc #$E8                ; A -= $E8 (we are subtracting the low byte first. looks weird because it's a literal)
        sta p16_val_lo          ; p16_val_lo = A
        lda p16_val_hi          ; A = p16_val_hi
        sbc #$3                 ; A -= $3 (we are subtracting the high byte of $03E8 or 1000 base 10)
        sta p16_val_hi          ; p16_val_hi = A
        inc p16_digit           ; p16_digit++
        jmp thousands           ; keep going

doneThousands:
        ; print the digit
        lda p16_digit
        clc
        adc #offset_to_char
        jsr putchar      


        ; Hundreds
        mva #0 p16_digit        ; reset our counter
hundreds:
        ; is p16_val >= 100?
        lda p16_val_hi          ; A = p16_val_hi
        cmp #$0                
        bcc doneHundreds     
        bne do_subHundreds     
        lda p16_val_lo          ; A = p16_val_lo
        cmp #$64              
        bcc doneHundreds        ; = exactly check low byte

do_subHundreds:
        ; subtract 100 (16-bit)
        lda p16_val_lo          ; A = p16_val_lo
        sec                     ; set the carry
        sbc #$64                ;  (we are subtracting the low byte first. looks weird because it's a literal)
        sta p16_val_lo          ; p16_val_lo = A
        lda p16_val_hi          ; A = p16_val_hi
        sbc #$0                 ;  (we are subtracting the high byte of $03E8 or 1000 base 10)
        sta p16_val_hi          ; p16_val_hi = A
        inc p16_digit           ; p16_digit++
        jmp hundreds           ; keep going

doneHundreds:
        ; print the digit
        lda p16_digit
        clc
        adc #offset_to_char
        jsr putchar   

        ; Tens
        mva #0 p16_digit        ; reset our counter
tens:
        ; is p16_val >= 10?
        lda p16_val_hi          ; A = p16_val_hi
        cmp #$0                
        bcc doneTens     
        bne do_subTens     
        lda p16_val_lo          ; A = p16_val_lo
        cmp #$0A              
        bcc doneTens        ; = exactly check low byte

do_subTens:
        ; subtract 100 (16-bit)
        lda p16_val_lo          ; A = p16_val_lo
        sec                     ; set the carry
        sbc #$0A                ;  (we are subtracting the low byte first. looks weird because it's a literal)
        sta p16_val_lo          ; p16_val_lo = A
        lda p16_val_hi          ; A = p16_val_hi
        sbc #$0                 ;  (we are subtracting the high byte of $03E8 or 1000 base 10)
        sta p16_val_hi          ; p16_val_hi = A
        inc p16_digit           ; p16_digit++
        jmp tens           ; keep going

doneTens:
        ; print the digit
        lda p16_digit
        clc
        adc #offset_to_char
        jsr putchar

        ; ones are whatever is left in p16_val_lo
        lda p16_val_lo
        clc
        adc #offset_to_char
        jsr putchar

        rts
        .endp


;========================================================================================
        ; print both digits in base 10, from left to right
        ; strategy is to continue subracting 10 from our hex value until it is less than 10
        ; once we are there we now have the "tens digit" in X and the "ones digit" in A
        ; Assumtions: A contains the hex value of the number to print

        .proc printDecimal
        ldx #0
checkCount:
        ; if A < 10   → carry = 0  → bcc branches   (carry CLEAR)
        ; if A >= 10  → carry = 1  → bcs branches   (carry SET)
        cmp #10             ; Does A = 10?
        bcc doneCounting    ; branch if carry is cleared
        sec                 ; set carry
        sbc #10             ; A = A - 10
        inx                 ; X = X + 1
        jmp checkCount

doneCounting:   
        pha                 ; push(A) (push A onto the stack)
        txa                 ; A = X
        clc
        adc #offset_to_char
        jsr putchar

        pla                 ; A = pop() (pop the next value off the stack)
        clc 
        adc #offset_to_char
        jsr putchar
        rts
        .endp
;==================================================================================================

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
;======================================================================

; =====================================================================
; DATA
; =====================================================================
scrname .byte 'S:',$9B             ; device name string for CIO OPEN
                                    ; 'S:' = screen device
                                    ; $9B  = ATASCII end-of-line terminator