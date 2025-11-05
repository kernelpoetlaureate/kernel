bits 16
org 0x7c00

HEAP_START equ 0x10000
heap_ptr: dd HEAP_START

start:
    ; *** SET UP STACK FIRST ***
    
    ; 0x00007c0d: fb (sti) - BEFORE THIS LINE
    ; EAX=00007c00 ESP=00001222 SS=7c00 (base 0x7c000)
    cli                     ; Disable interrupts while setting up
    
    ; 0x00007c0e: b8 00 b8 (movw $0xb800, %ax) - BEFORE THIS LINE
    ; EAX=00007c00 EBX=00000000 ESP=00001222
    ; CS=0000 SS=7c00 ES=0000 DS=0000
    mov ax, 0x7C00          ; Stack segment base
    
    ; 0x00007c11: 8e c0 (movw %ax, %es) - AFTER mov ax, 0x7C00 EXECUTED
    ; This line moves 0x7C00 into SS
    mov ss, ax              ; Set stack segment
    
    ; 0x00007c13: 31 ff (xorw %di, %di) - AFTER mov ss, ax EXECUTED
    ; Stack segment now set to 0x7C00 (physical base 0x7C000)
    mov sp, 0x1222          ; Stack pointer (grows downward from 0x7C00)
    
    ; 0x00007c15: b8 48 07 (movw $0x748, %ax) - AFTER mov sp, 0x1222
    ; ESP=00001222 shows SP correctly set
    ; Interrupts re-enabled at 0x00007c0d: sti
    sti                     ; Re-enable interrupts
    
    ; Now safe to use stack
    
    ; 0x00007c18: 26 89 05 (movw %ax, %es:(%di)) - BEFORE THIS LINE
    ; Shows ES=b800 000b8000 - video memory segment loaded
    ; EAX=0000b800 EDI=00000000 means ES:DI points to 0xB8000 + 0 = 0xB8000
    mov ax, 0xB800         ; Load video memory segment (0xB8000)
    
    ; 0x00007c1b: 83 c7 02 (addw $2, %di) - AFTER movw %ax, %es
    ; ES now = b800, pointing to base 0xB8000
    mov es, ax              ; Set ES to video segment
    
    ; 0x00007c1e: b8 00 01 (movw $0x100, %ax) - AFTER xor di, di
    ; EDI=00000000 shows DI cleared to 0
    xor di, di              ; Clear DI to 0 (start of video memory)
    
    ; 0x00007c21: e8 0b 00 (callw 0x7c2f) - AFTER mov ax, 0x0748
    ; EAX=00000748 shows 'H' loaded (0x48='H', 0x07=white attr)
    mov ax, 0x0748          ; 'H' with white attribute
    
    ; 0x00007c24: b8 4d 07 (movw $0x74d, %ax) - AFTER movw %ax, %es:(%di)
    ; Character written to ES:0x0000 (video memory at 0xB8000)
    ; EAX=00000000 after return from malloc, EDI=00000002 (advanced 2 bytes)
    mov [es:di], ax         ; Write 'H' to video memory at ES:0
    
    ; 0x00007c27: 26 89 05 (movw %ax, %es:(%di)) - AFTER add di, 2
    ; EDI now 0x0002, character already visible
    add di, 2               ; Advance DI by 2 (next screen position)
    
    ; 0x00007c2a: 83 c7 02 (addw $2, %di) - AFTER movw %ax, %es:(%di)
    ; EAX=0000074d shows 'M' loaded (0x4d='M')
    ; Character 'M' written at ES:0x0002
    ; Allocate 256 bytes
    mov ax, 256             ; Request 256 bytes from malloc
    
    ; 0x00007c2f: 53 (pushw %bx) - BEFORE malloc call at 0x00007c21
    ; ESP=00001220 after CALL (return addr pushed)
    ; Stack: [return_addr] at 0x7C000 + 0x1220
    call malloc             ; Call malloc; result (old heap_ptr) returned in AX
    
    ; *** MALLOC FUNCTION TRACE (0x00007c2f - 0x00007c40) ***
    
    ; 0x00007c30: 52 (pushw %dx) - INSIDE malloc
    ; ESP=00001220 after pushw %bx (2 bytes)
    ; Stack: [bx_saved][return_addr]
    ; (function prologue continues)
    
    ; 0x00007c31: 8b 1e 00 7c (movw 0x7c00, %bx) - INSIDE malloc
    ; Loads heap_ptr (0x10000 initially) into BX
    ; BX = 0x10000 (HEAP_START)
    
    ; 0x00007c35: 89 c2 (movw %ax, %dx) - INSIDE malloc
    ; DX = 0x0100 (256 bytes requested, copied from AX)
    
    ; 0x00007c37: 01 d8 (addw %bx, %ax) - INSIDE malloc
    ; AX = AX + BX = 0x0100 + 0x10000 = 0x10100
    ; New heap_ptr value calculated
    
    ; 0x00007c39: a3 00 7c (movw %ax, 0x7c00) - INSIDE malloc
    ; [heap_ptr] = 0x10100 (updates heap position for next allocation)
    ; NOTE: This modifies code/data at 0x7C00!
    
    ; 0x00007c3c: 89 d8 (movw %bx, %ax) - INSIDE malloc
    ; AX = BX = 0x10000 (return old heap pointer to caller)
    ; Return value: 0x10000 (address where 256 bytes allocated)
    
    ; 0x00007c3e: 5a (popw %dx) - INSIDE malloc
    ; Restore DX from stack
    
    ; 0x00007c3f: 5b (popw %bx) - INSIDE malloc
    ; Restore BX from stack, ESP=00001222 (back to entry)
    
    ; 0x00007c40: c3 (retw) - INSIDE malloc
    ; Return to caller (0x7c24), ESP adjusted, AX=0x10000
    
    ; *** BACK TO MAIN (after malloc returns) ***
    
    ; AX now contains the pointer (0x10000)
    ; BUT NEXT LINE IGNORES IT! (uses ES:DI instead)
    mov ax, 0x074d          ; 'M' with white attribute
    
    ; 0x00007c27: 26 89 05 (movw %ax, %es:(%di)) - WRITES AT ES:0x0002, NOT HEAP!
    ; EAX=0000074d (M character)
    ; ES:DI = 0xB8000 + 0x0002 (video memory, not allocated heap)
    mov [es:di], ax         ; Write 'M' to video memory at ES:DI (0xB8002)
    
    ; 0x00007c2a: 83 c7 02 (addw $2, %di) - AFTER second character write
    ; DI advanced to 0x0004
    add di, 2               ; Advance DI by 2 (next screen position)
    
    ; 0x00007c2d: fa (cli) - BEFORE hlt
    ; Clear interrupt flag before halt
    cli                     ; Disable interrupts before halt
    
    ; 0x00007c2e: f4 (hlt) - FINAL INSTRUCTION
    ; CPU halts, waiting for interrupt
    hlt                     ; Halt CPU

malloc:
    ; FUNCTION: malloc(size in AX) -> returns old heap_ptr in AX
    ; Modifies: AX (return value), BX (temp), DX (temp)
    ; Side effects: updates heap_ptr at 0x7C00
    
    push bx                 ; Save BX (callee-saved)
    push dx                 ; Save DX (temp register)
    
    mov bx, [heap_ptr]      ; BX = current heap_ptr (old value)
    mov dx, ax              ; DX = size requested (save AX)
    add ax, bx              ; AX = size + heap_ptr (new heap position)
    mov [heap_ptr], ax      ; Update heap_ptr for next allocation
    mov ax, bx              ; AX = old heap_ptr (return value to caller)
    
    pop dx                  ; Restore DX
    pop bx                  ; Restore BX
    ret                     ; Return with AX = allocated address

times 510-($-$$) db 0
dw 0xAA55