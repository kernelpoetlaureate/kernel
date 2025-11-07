nasm -f bin boot.asm -o boot.bin
python3 inspect_boot.py boot.bin
