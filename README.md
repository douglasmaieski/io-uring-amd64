# IO_URING AMD64

This is a tiny amd64 library for IO_URING.

I've tried to test it extensively, but it might contain bugs. Be sure to test it before using it.

You can build the object file using `nasm`:
```bash
nasm -felf64 io_uring.asm -o io_uring.o
```

Then you can link it with your C program using:
```bash
gcc main.c io_uring.o -o out
```

You can use the included header in your project.
