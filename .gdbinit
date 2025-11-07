# .gdbinit - Simplified 16-bit boot sector debugging
set confirm off
set pagination off
set print pretty on

# Configure for real mode
set architecture i8086

# Define capture function without symbol files
define capture_state
  # Timestamp
  shell echo "--- $(date) ---" >> gdb_capture.log
  
  # Capture registers to file
  printf "REGISTERS:\n" >> gdb_capture.log
  info registers >> gdb_capture.log
  printf "\n" >> gdb_capture.log
  
  # Capture specific segments
  printf "CS: 0x%04x, IP: 0x%04x\n", $cs, $pc >> gdb_capture.log
  printf "SS: 0x%04x, SP: 0x%04x\n", $ss, $sp >> gdb_capture.log
  printf "DS: 0x%04x, ES: 0x%04x\n", $ds, $es >> gdb_capture.log
  printf "FLAGS: 0x%04x\n", $eflags >> gdb_capture.log
  printf "\n" >> gdb_capture.log
  
  # Capture current instruction
  printf "CURRENT_INSTRUCTION:\n" >> gdb_capture.log
  x/5i $pc >> gdb_capture.log
  printf "\n" >> gdb_capture.log
  
  # Capture stack (32 bytes)
  printf "STACK_DUMP:\n" >> gdb_capture.log
  x/32xb $sp >> gdb_capture.log
  printf "\n" >> gdb_capture.log
  
  # Capture boot sector area
  printf "BOOT_SECTOR:\n" >> gdb_capture.log
  x/64xb 0x7c00 >> gdb_capture.log
  printf "\n" >> gdb_capture.log
  
  # Capture your heap area
  printf "HEAP_AREA:\n" >> gdb_capture.log
  x/128xb 0x10000 >> gdb_capture.log
  printf "\n" >> gdb_capture.log
  
  # Capture video memory
  printf "VIDEO_MEMORY:\n" >> gdb_capture.log
  x/80xb 0xb8000 >> gdb_capture.log
  printf "\n" >> gdb_capture.log
  
  # Binary dump of full memory state
  dump binary memory mem_snapshot.bin 0x0 0x100000
  printf "MEMORY_SNAPSHOT: mem_snapshot.bin\n" >> gdb_capture.log
  printf "\n" >> gdb_capture.log
  
  printf "=== STATE_CAPTURED ===\n\n" >> gdb_capture.log
end

# Simple step and capture function
define step_and_capture
  si
  capture_state
end

# Run and capture multiple steps
define run_and_capture
  set $count = 0
  while $count < 5
    si
    capture_state
    set $count = $count + 1
  end
end

# Set initial breakpoint at boot sector start
break *0x7c00
