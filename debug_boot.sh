#!/bin/bash
# Compile the test boot sector
echo "Compiling test boot sector..."
nasm -f bin test_boot.asm -o test_boot.bin

# Start QEMU with debug stub
echo "Starting QEMU in debug mode..."
qemu-system-x86_64 -drive format=raw,file=test_boot.bin -s -S &
QEMU_PID=$!

# Wait for QEMU to start
sleep 2

echo "Connecting GDB..."
# Connect GDB and run the capture sequence
gdb -batch \
    -ex "set confirm off" \
    -ex "set architecture i8086" \
    -ex "target remote localhost:1234" \
    -ex "break *0x7c00" \
    -ex "continue" \
    -ex "define capture_state" \
    -ex "  shell echo --- \$(date) --- >> gdb_capture.log" \
    -ex "  printf REGISTERS:\\n >> gdb_capture.log" \
    -ex "  info registers >> gdb_capture.log" \
    -ex "  printf \\n >> gdb_capture.log" \
    -ex "  printf CS: 0x%04x, IP: 0x%04x\\n \$cs, \$pc >> gdb_capture.log" \
    -ex "  printf SS: 0x%04x, SP: 0x%04x\\n \$ss, \$sp >> gdb_capture.log" \
    -ex "  printf \\n >> gdb_capture.log" \
    -ex "  x/5i \$pc >> gdb_capture.log" \
    -ex "  printf \\n >> gdb_capture.log" \
    -ex "  x/32xb \$sp >> gdb_capture.log" \
    -ex "  printf \\n >> gdb_capture.log" \
    -ex "  x/64xb 0x7c00 >> gdb_capture.log" \
    -ex "  printf \\n >> gdb_capture.log" \
    -ex "  x/80xb 0xb8000 >> gdb_capture.log" \
    -ex "  printf \\n >> gdb_capture.log" \
    -ex "  dump binary memory mem_snapshot_\$(date +%s).bin 0x0 0x100000" \
    -ex "  printf === STATE_CAPTURED ===\\n\\n >> gdb_capture.log" \
    -ex "end" \
    -ex "define run_and_capture" \
    -ex "  set \$count = 0" \
    -ex "  while \$count < 10" \
    -ex "    si" \
    -ex "    capture_state" \
    -ex "    set \$count = \$count + 1" \
    -ex "  end" \
    -ex "end" \
    -ex "run_and_capture" \
    -ex "quit"

# Give QEMU time to finish and kill it
sleep 1
kill $QEMU_PID 2>/dev/null

# Parse results
echo "Parsing results..."
python3 parse_gdb_output.py 2>/dev/null || echo "Python script failed - check if dependencies are installed"

echo "Debug session complete! Check gdb_capture.log and gdb_analysis.json"