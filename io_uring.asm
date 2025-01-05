section .rodata

db 'IO_URING Library by Douglas Maieski. MIT License.'
db 0x00


section .text

global rings_setup
global rings_submit
global rings_reap

rings_setup:
  ; RDI -> ctx
  ; RSI -> entry count
  push rbp
  push rbx
  push r12
  push r13
  push r14
  push r15
  sub rsp,136 ; io_uring_params

  mov rbp,rdi
  mov rbx,rsi

  mov rcx,8
  xor rax,rax
  pxor xmm0,xmm0
  .zero_mem:
    movdqu [rsp+rax],xmm0
    add rax,16
    loop .zero_mem

  mov dword [rsp+8],0x2
  mov dword [rsp+12],0x0
  mov dword [rsp+16],1000 * 10

  mov rax,425
  mov rdi,rbx
  mov rsi,rsp
  syscall
  cmp rax,0
  jl .err0

  mov [rbp+7*8],eax
  mov [rbp+15*8],eax

  mov esi,[rsp]
  shl esi,2
  add esi,[rsp+40+24] ; array location
  mov r12,rsi ; size

  mov rax,9;mmap
  xor rdi,rdi
  ;; rsi has the size
  mov rdx,0x3 ; read/write
  mov r10,0x1 ; map_shared
  mov r8d,[rbp+7*8];fd
  xor r9,r9 ; offset
  syscall

  cmp rax,0xffffffffffffffff
  je .err1

  mov r13,rax ; map addr

  mov r14d,[rsp+80+20] ; cq offset entry count
  add r14d,[rsp+4] ; cq entries
  shl r14,0x4 ; sizeof io_uring_cqe

  mov rax,9;mmap
  xor rdi,rdi
  mov rsi,r14
  mov rdx,0x3 ;read/write
  mov r10,0x800001 ;map shared
  mov r8d,[rbp+7*8] ;fd
  mov r9,0x8000000 ; ioring_off_cq_ring
  syscall

  cmp rax,0xffffffffffffffff
  je .err2

  mov r15,rax ; addr

  mov rax,r13 ; sq map
  mov ebx,[rsp+40]
  add rax,rbx ; head
  mov [rbp],rax ;head

  mov rax,r13
  mov ebx,[rsp+44]
  add rax,rbx ;tail
  mov [rbp+8],rax

  ; mask
  mov rax,[r13]
  mov rax,r13       ; sq map
  mov ebx,[rsp+48]  ; _u32 ring_mask_offset
  add rax,rbx       ; mask
  mov ebx,[rax]
  mov [rbp+60],ebx

  ; entries
  mov rax,r13 
  mov ebx,[rsp+52]
  add rax,rbx
  mov [rbp+16],rax

  ; flags
  mov rax,r13 
  mov ebx,[rsp+56]
  add rax,rbx
  mov [rbp+24],rax

  ; dropped
  mov rax,r13 
  mov ebx,[rsp+60]
  add rax,rbx
  mov [rbp+32],rax

  ; array
  mov rax,r13 
  mov ebx,[rsp+64]
  add rax,rbx
  mov [rbp+40],rax

  ; head
  mov rax,r15
  mov ebx,[rsp+80]
  add rax,rbx
  mov [rbp+64],rax

  ; tail
  mov rax,r15
  mov ebx,[rsp+84]
  add rax,rbx
  mov [rbp+72],rax

  ; mask
  mov rax,r15
  mov ebx,[rsp+88]
  add rax,rbx
  mov ebx,[rax]
  mov [rbp+124],ebx

  ; entries
  mov rax,r15
  mov ebx,[rsp+92]
  add rax,rbx
  mov [rbp+80],rax

  ; overflow
  mov rax,r15
  mov ebx,[rsp+96]
  add rax,rbx
  mov [rbp+88],rax

  ; cqes
  mov rax,r15
  mov ebx,[rsp+100]
  add rax,rbx
  mov [rbp+104],rax

  mov esi,[rsp] ; sq_entries count
  shl rsi,6 ; 64 bits each

  mov rax,9 ; mmap
  xor rdi,rdi
  ; rsi has the size
  mov rdx,3 ;read/write
  mov r10,0x800001 ;map shared
  mov r8d,[rbp+7*8] ;fd
  mov r9,0x10000000 ; ioring_off_sqes
  syscall

  cmp rax,0xffffffffffffffff
  je .err3

  mov [rbp+6*8],rax

  add rsp,136
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  pop rbp

  xor rax,rax
  inc rax
  ret

.err3:
  mov rax,11;munmap
  mov rdi,r15 ;addr
  mov rsi,r14 ;length
  syscall

.err2:
  mov rax,11 ;munmap
  mov rdi,r13 ; addr
  mov rsi,r12 ; length
  syscall

.err1:
  mov edi,[rbp+7*8]
  mov rax,3
  syscall

  
.err0:
  add rsp,136
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  pop rbp

  xor rax,rax
  ret


rings_submit:
  ; RDI -> rings
  ; RSI -> io_uring_sqe

  mov r10d,[rdi+60] ;mask

  mov rdx,[rdi+8] ; tail
  mov edx,[rdx]

  ; head
  mov rax,[rdi]
  mov eax,[rax]
  inc edx
  cmp edx,eax ; check if ring is full
  je .err

  dec edx
  mov rax,[rdi+48] ; sqes
  mov r9d,edx
  and r9d,r10d
  shl r9,6
  add rax,r9       ; sqes + idx

  movdqu xmm0,[rsi]
  movdqu xmm1,[rsi+16]
  movdqu xmm2,[rsi+32]
  movdqu xmm3,[rsi+48]
  movdqu [rax],xmm0
  movdqu [rax+16],xmm1
  movdqu [rax+32],xmm2
  movdqu [rax+48],xmm3

  ; add index to array
  mov r9d,edx
  and r9d,r10d

  shl r9,2
  mov rax,[rdi+40]  ; array
  add rax,r9        ; array[idx]

  mov r8d,edx
  and r8d,r10d
  mov [rax],r8d     ; array[idx] = idx

  ; advance tail
  inc edx
  mov rax,[rdi+8]
  mov [rax],edx

  mov rax,[rdi+24]
  mov eax,[rax]
  cmp eax,1
  je .wake_up

  test edx,r10d
  jz .wake_up

  xor rax,rax
  inc rax
  ret

.wake_up:
  sub rsp,8

  mov rax,426
  mov edi,[rdi+56]
  xor rsi,rsi
  xor rdx,rdx
  mov r10,0x2
  xor r8,r8
  syscall

  add rsp,8

  xor rax,rax
  inc rax
  ret

.err:
  xor rax,rax
  ret


rings_reap:
  ; RDI -> rings
  ; RSI -> io_uring_cqe
  ; RDX -> max_count
  push rbx
  push r12

.setup:
  mov rcx,rdx       ; max count
  mov rbx,[rdi+64]  ; head ptr
  mov ebx,[rbx]     ; head u32
  mov r9d,[rdi+124] ; mask
  xor rax,rax

  mov r12,.ready
  test ebx,r9d
  jz .wake_up

.ready:
  mov r10d,ebx

  mov r12,[rdi+72]; tail ptr
  cmp r10d,[r12]  ; tail u32 vs head
  je .done

  .reap:
    mov r12,.after_wake_up
    test ebx,r9d
    jz .wake_up

  .after_wake_up:
    mov r10d,ebx    ; head
    mov r12,[rdi+72]; tail ptr
    cmp r10d,[r12]  ; tail u32 vs head
    je .done

    and r10d,r9d      ; idx in range
    shl r10,4         ; idx scaled
    mov r11,[rdi+104] ; cqes ptr
    add r11,r10       ; cqes[idx]

    ; copy the cqe
    movdqu xmm0,[r11]
    movdqu [rsi],xmm0

    inc rax         ; n
    inc ebx         ; head
    add rsi,16

    mov r12,[rdi+64]
    mov [r12],ebx

    loop .reap

.done:
  pop r12
  pop rbx

  ret

.wake_up:
  push rax
  push rbx
  push r9
  push rdi
  push rsi
  push rdx
  push r10
  push rcx

  mov rax,426
  mov edi,[rdi+7*8]
  xor rsi,rsi
  xor rdx,rdx
  mov r10,0x2
  xor r8,r8
  syscall

  pop rcx
  pop r10
  pop rdx
  pop rsi
  pop rdi
  pop r9
  pop rbx
  pop rax
  jmp r12
