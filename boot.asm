org 0x7c00

start:
    ; Print 'A' using BIOS interrupt
    mov ah, 0x0e    ; BIOS teletype function
    mov al, 'A'     ; character to print
    int 0x10        ; call BIOS
    
    ; Infinite loop
    jmp $

; Boot signature
times 510-($-$$) db 0
dw 0xaa55