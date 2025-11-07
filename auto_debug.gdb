
set confirm off
set pagination off
set architecture i8086

target remote localhost:1234

# Function to capture full state
define capture_state
    shell echo "=== CAPTURE $(date +'%s') ===" >> ./gdb_capture.log
    
    # Registers
    shell echo "REGISTERS:" >> ./gdb_capture.log
    info registers >> ./gdb_capture.log
    shell echo "" >> ./gdb_capture.log
    
    # Segments  
    printf "CS:IP=0x%%04x:0x%%04x\n" $cs $pc >> ./gdb_capture.log
    printf "SS:SP=0x%%04x:0x%%04x\n" $ss $sp >> ./gdb_capture.log
    shell echo "" >> ./gdb_capture.log
    
    # Current instruction
    x/3i $pc >> ./gdb_capture.log
    shell echo "" >> ./gdb_capture.log
    
    # Boot sector memory
    x/16xb 0x7c00 >> ./gdb_capture.log
    shell echo "" >> ./gdb_capture.log
    
    # Video memory (first 20 chars)
    x/40xb 0xb8000 >> ./gdb_capture.log
    shell echo "" >> ./gdb_capture.log
    
    # Full memory snapshot
    shell echo "DUMPING MEMORY..." >> ./gdb_capture.log
    dump binary memory ./mem_$(date +'%s').bin 0x0 0x100000
    shell echo "=== END CAPTURE ===" >> ./gdb_capture.log
    shell echo "" >> ./gdb_capture.log
end

# Execute and capture
capture_state
set $i = 0
while $i < 8
    si
    capture_state
    set $i = $i + 1
end

quit
