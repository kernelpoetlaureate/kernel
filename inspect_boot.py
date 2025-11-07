#!/usr/bin/env python3
import os, sys, subprocess, time, tempfile, pathlib

QEMU = os.environ.get("QEMU_BIN", "qemu-system-i386")
GDB  = os.environ.get("GDB_BIN", "gdb")

GDB_SCRIPT = r"""
set pagination off
set confirm off

# Connect first (accept whatever QEMU reports)
target remote :1234

# Use linear address breakpoint (0x7C00) instead of segment:offset
break *0x7C00
continue

# Now try to set i8086 for disassembly after we're connected and stopped
set architecture i8086
set disassemble-next-line on

info registers

python
import os
import gdb

outdir = os.environ.get("BOOT_DUMP_DIR", "dumps")
os.makedirs(outdir, exist_ok=True)

def seg_off_to_linear(seg, off):
    return ((seg & 0xFFFF) << 4) + (off & 0xFFFF)

def read_mem(addr, size):
    inf = gdb.selected_inferior()
    return bytes(inf.read_memory(addr, size))

def dump_file(path, data):
    with open(path, "wb") as f:
        f.write(data)

def hex_dump(data, width=16):
    lines=[]
    for i in range(0, len(data), width):
        chunk=data[i:i+width]
        hexs=' '.join(f'{b:02x}' for b in chunk)
        asci=''.join(chr(b) if 32<=b<127 else '.' for b in chunk)
        lines.append(f'{i:08x}  {hexs:<{width*3}}  {asci}')
    return '\n'.join(lines)

def get_regs_text():
    return gdb.execute("info registers", to_string=True)

def dump_real_mode_context(prefix="step0"):
    regs = get_regs_text()
    with open(os.path.join(outdir, f"{prefix}_regs.txt"), "w") as f:
        f.write(regs)

    try:
        cs = int(gdb.parse_and_eval("$cs")) & 0xFFFF
        ip = int(gdb.parse_and_eval("$eip")) & 0xFFFF
        ds = int(gdb.parse_and_eval("$ds")) & 0xFFFF
        es = int(gdb.parse_and_eval("$es")) & 0xFFFF
        ss = int(gdb.parse_and_eval("$ss")) & 0xFFFF
    except:
        # Fallback if segment registers not available
        cs = 0
        ip = int(gdb.parse_and_eval("$eip")) & 0xFFFF
        ds = 0
        es = 0
        ss = 0

    # Disassemble from current PC
    try:
        dis = gdb.execute("x/24i $pc", to_string=True)
    except:
        dis = "Disassembly failed\n"
    
    with open(os.path.join(outdir, f"{prefix}_disasm.txt"), "w") as f:
        f.write(dis)

    # Dump segments if available
    def dump_seg(seg, name):
        if seg == 0:
            return
        base = seg_off_to_linear(seg, 0)
        size = 2048
        try:
            data = read_mem(base, size)
            dump_file(os.path.join(outdir, f"{prefix}_{name}_seg_{seg:04x}_lin_{base:05x}.bin"), data)
            with open(os.path.join(outdir, f"{prefix}_{name}_seg_{seg:04x}_lin_{base:05x}.hex"), "w") as f:
                f.write(hex_dump(data))
        except gdb.error as e:
            with open(os.path.join(outdir, f"{prefix}_{name}_error.txt"), "w") as f:
                f.write(str(e))

    dump_seg(cs, "code")
    dump_seg(ds, "data")
    dump_seg(es, "extra")
    dump_seg(ss, "stack")

    # Boot sector dump at linear 0x7C00
    try:
        bs = read_mem(0x7C00, 512)
        dump_file(os.path.join(outdir, f"{prefix}_phys_00007C00_0200.bin"), bs)
        with open(os.path.join(outdir, f"{prefix}_phys_00007C00_0200.hex"), "w") as f:
            f.write(hex_dump(bs))
    except gdb.error as e:
        with open(os.path.join(outdir, f"{prefix}_phys_read_error.txt"), "w") as f:
            f.write(str(e))

dump_real_mode_context("entry")

# Single-step and capture
for i in range(3):
    gdb.execute("si")
    dump_real_mode_context(f"step{i+1}")

print(f"[+] Dumps written to: {outdir}")
end

# QEMU monitor dumps
monitor pmemsave 0x00000 0x10000 dumps/pmem_00000_10000.bin
monitor pmemsave 0x07C00 0x0200  dumps/pmem_07C00_0200.bin

quit
"""

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 inspect_boot.py boot.bin")
        sys.exit(1)

    image = os.path.abspath(sys.argv[1])
    dumps = os.path.abspath("dumps")
    pathlib.Path(dumps).mkdir(parents=True, exist_ok=True)

    qemu_cmd = [
        QEMU,
        "-M", "pc",
        "-cpu", "qemu32",
        "-m", "64M",
        "-nodefaults",
        "-no-reboot",
        "-no-shutdown",
        "-drive", f"file={image},index=0,if=floppy,format=raw",
        "-S", "-s",
        "-monitor", "stdio",
        "-serial", "none",
        "-display", "none",
    ]

    env = os.environ.copy()
    env["BOOT_DUMP_DIR"] = dumps

    qemu = subprocess.Popen(
        qemu_cmd,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=env,
    )

    time.sleep(0.5)

    with tempfile.NamedTemporaryFile(mode="w", delete=False, suffix=".gdb") as tf:
        tf.write(GDB_SCRIPT)
        gdb_script_path = tf.name

    gdb_cmd = [GDB, "-nx", "-q", "-batch", "-x", gdb_script_path]

    try:
        gdb_proc = subprocess.run(gdb_cmd, capture_output=True, text=True, env=env)
        with open(os.path.join(dumps, "gdb_session.log"), "w") as f:
            f.write(gdb_proc.stdout or "")
            f.write("\n[stderr]\n")
            f.write(gdb_proc.stderr or "")
        print(gdb_proc.stdout)
        if gdb_proc.stderr:
            print("STDERR:", gdb_proc.stderr)
    finally:
        try:
            qemu.terminate()
            qemu.wait(timeout=2)
        except:
            try:
                qemu.kill()
            except:
                pass
        try:
            os.unlink(gdb_script_path)
        except:
            pass

    print(f"\nDumps written to: {dumps}")
    print("Check dumps/gdb_session.log for full output")

if __name__ == "__main__":
    main()
