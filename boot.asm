

bits 16
org 0x7c00

HEAP_START equ 0x10000
heap_ptr: dd HEAP_START

start:
    mov ax, 0xB800
    mov es, ax
    xor di, di
    
    mov ax, 0x0748      ; 'H'
    mov [es:di], ax
    add di, 2
    
    ; Allocate 256 bytes
    mov ax, 256
    call malloc
    
    ; ax now contains the pointer
    ; Print 'M' for success
    mov ax, 0x074d      ; 'M'
    mov [es:di], ax
    add di, 2
    
    cli
    hlt

; malloc: Allocate bytes from heap
; Input: ax = number of bytes to allocate
; Output: ax = pointer to allocated memory
malloc:
    push bx
    push dx
    
    mov bx, [heap_ptr]      ; Get current heap pointer
    mov dx, ax              ; Save requested size in dx
    add ax, bx              ; Calculate new heap_ptr
    mov [heap_ptr], ax      ; Update heap_ptr
    mov ax, bx              ; Return old pointer in ax
    
    pop dx
    pop bx
    ret

times 510-($-$$) db 0
dw 0xAA55






