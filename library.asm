        icl 'equates.asm'
        icl 'routines.asm'

        org $2000

        .proc main
    
        ;=============================================================
        ; print a string example
        ;
        ;mva #1 csrhinh                  ; hide the cursor
        ;mva #6 rowcrs                   ; set output row
        ;mva #10 colcrs                  ; set output column
        
        ;mva #<string1 strptr_lo         ; low byte of string1 address
        ;mva #>string1 strptr_hi         ; high byte o f string1 address
        ;jsr print_string                ; print the string

        ;jmp stop                        ; stop is inside routines.asm
        ;=============================================================

;======================================================
; draw pixels example
;======================================================

        jsr openGR8

        jsr clearScreen

       ; top edge
        mva #0    x1
        mva #0    x1_hi
        mva #0    y1
        mva #$3F  x2
        mva #$01  x2_hi
        mva #0    y2
        jsr drawLine

        ; bottom edge
        mva #0    x1
        mva #0    x1_hi
        mva #191  y1
        mva #$3F  x2
        mva #$01  x2_hi
        mva #191  y2
        jsr drawLine

        ; left edge
        mva #0    x1
        mva #0    x1_hi
        mva #0    y1
        mva #0    x2
        mva #0    x2_hi
        mva #191  y2
        jsr drawLine

        ; right edge
        mva #$3F  x1
        mva #$01  x1_hi
        mva #0    y1
        mva #$3F  x2
        mva #$01  x2_hi
        mva #191  y2
        jsr drawLine

        mva #160  cx
        mva #0    cx_hi
        mva #96   cy
        mva #50   radius
        jsr drawCircle

halt:
        jsr fightAttract
        jmp halt

        .endp

;===================================================================
; Data section
;===================================================================
        ;.local string1
        ;.byte 'HELLO FROM STRING ONE!',0
        ;.endl


        run main