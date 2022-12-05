ExitProcess    PROTO
HeapAlloc      PROTO
HeapReAlloc    PROTO
GetProcessHeap PROTO
OpenFile       PROTO
ReadFile       PROTO
CloseHandle    PROTO
GetFileSize    PROTO
GetLastError   PROTO
StrToIntA      PROTO
lstrlenA       PROTO

EXIT_SUCCESS      equ 0
EXIT_FAILURE      equ 1
OF_READ           equ 0
HFILE_ERROR       equ -1
STD_OUTPUT_HANDLE equ -11

INVALID_HANDLE_VALUE   equ -1
ATTACH_PARENT_PROCESS  equ -1

_OFSTRUCT STRUCT
    cBytes BYTE ?
    fFixedDisk BYTE ?
    nErrCode WORD ?
    Reserved1 WORD ?
    Reserved2 WORD ?
    szPathName BYTE 128 DUP (?)
_OFSTRUCT ENDS

SHADOW_STACK_SPACE equ 20h
LINE_FEED          equ 10
CARRIAGE_RETURN    equ 13
NULL               equ 0
PAIRS_LENGTH       equ 4
STACK_REALLOC_SIZE equ 10

NUMBER_OF_COLUMNS equ 9

STACK STRUCT
    pElements QWORD ?
    nPosition QWORD ?
    nCapacity QWORD ?
STACK ENDS

.data

FILE_NAME db 'day5_full.txt', 0

.code

shadowcall MACRO fn
    sub rsp, SHADOW_STACK_SPACE
    call fn
    add rsp, SHADOW_STACK_SPACE
ENDM

debugexit MACRO reg
    mov rcx, reg
    call ExitProcess
ENDM

; nCapacity
Stack_Create PROC
    LOCAL hProcessHeap: QWORD
    LOCAL nCapacity: QWORD
    LOCAL pStack: QWORD

    sub rsp, 8 ; align stack

    mov nCapacity, rcx

    shadowcall GetProcessHeap
    mov hProcessHeap, rax

    mov rcx, rax
    xor rdx, rdx
    mov r8, SIZEOF STACK

    shadowcall HeapAlloc
    mov pStack, rax
    cmp rax, 0
    je stack_create_fail

    mov rbx, nCapacity
    mov (STACK PTR [rax]).nCapacity, rbx
    mov (STACK PTR [rax]).nPosition, 0 

    mov rcx, hProcessHeap
    xor rdx, rdx
    lea r8, [rbx * 8] ; nCapacity
    shadowcall HeapAlloc
    cmp rax, 0
    je stack_create_fail

    mov rbx, pStack
    mov (STACK PTR [rbx]).pElements, rax

    mov rax, pStack
    add rsp, 8 ; align stack
stack_create_fail:
    ret
Stack_Create ENDP

; pStack, qwData
Stack_Push PROC
    LOCAL hProcessHeap: QWORD
    LOCAL pStack: QWORD
    LOCAL qwData: QWORD

    sub rsp, 8 ; align

    mov pStack, rcx
    mov qwData, rdx

    shadowcall GetProcessHeap
    mov hProcessHeap, rax

    mov rbx, (STACK PTR [rcx]).nPosition
    cmp (STACK PTR [rcx]).nCapacity, rbx
    jle allocate_more_space
allocate_space_set_data:
    mov rcx, pStack
    mov rax, (STACK PTR [rcx]).nPosition
    mov rdx, (STACK PTR [rcx]).pElements
    lea rbx, [rdx + rax * 8]
    mov r8, qwData
    mov QWORD PTR [rbx], r8
    inc (STACK PTR [rcx]).nPosition

allocate_more_space_fail:
    add rsp, 8 ; align
    ret

allocate_more_space:
    mov r8, (STACK PTR[rcx]).pElements
    mov r9, (STACK PTR [rcx]).nCapacity
    add r9, STACK_REALLOC_SIZE
    mov rcx, hProcessHeap
    xor rdx, rdx

    shadowcall HeapReAlloc
    cmp rax, 0
    je allocate_more_space_fail

    mov rbx, pStack
    mov (STACK PTR[rbx]).pElements, rax
    add (STACK PTR [rbx]).nCapacity, STACK_REALLOC_SIZE
    jmp allocate_space_set_data
Stack_Push ENDP

; pStack, out pqwData -> bEmpty
Stack_Pop PROC
    mov rbx, (STACK PTR[rcx]).pElements
    mov r8, (STACK PTR[rcx]).nPosition
    cmp r8, 0
    je stack_empty

    dec (STACK PTR[rcx]).nPosition
    dec r8
    mov rax, QWORD PTR [rbx + r8 * 8]
    mov QWORD PTR [rdx], rax

    mov rax, 0
    ret
stack_empty:
    mov rax, 1
    ret
Stack_Pop ENDP

main PROC
    LOCAL reOpenBuff: _OFSTRUCT
    LOCAL hProcessHeap: QWORD
    LOCAL hFileHandle: QWORD
    LOCAL cbFileLength: QWORD
    LOCAL pszFileContent: QWORD

    sub rsp, 8 ;

    xor rax, rax
    mov hProcessHeap, rax
    mov hFileHandle, rax
    mov cbFileLength, rax

    shadowcall GetProcessHeap
    mov hProcessHeap, rax

    test rax, rax
    jz fail

    lea rcx, FILE_NAME
    lea rdx, reOpenBuff
    mov r8, OF_READ
    shadowcall OpenFile

    mov hFileHandle, rax

    cmp eax, HFILE_ERROR
    je fail

    mov rcx, hFileHandle
    xor rdx, rdx
    shadowcall GetFileSize

    mov cbFileLength, rax

    cmp eax, HFILE_ERROR
    je fail

    mov rcx, hProcessHeap
    xor rdx, rdx

    mov rax, SIZEOF BYTE
    mov r8, cbFileLength
    inc r8
    imul r8, rax

    shadowcall HeapAlloc

    mov r8, cbFileLength
    mov BYTE PTR [rax + r8], 0
    mov pszFileContent, rax

    cmp rax, 0
    je fail

    mov rcx, hFileHandle
    mov rdx, pszFileContent
    mov r8, cbFileLength
    xor r9, r9
    push 0
    sub rsp, 8
    shadowcall ReadFile
    add rsp, 16

    cmp rax, 0
    je fail

    mov rcx, pszFileContent
    mov rdx, cbFileLength
    shadowcall FindTopCrates

    debugexit rax

    mov rcx, hFileHandle
    shadowcall CloseHandle

    mov rcx, rbx
    jmp exit

get_last_error:
    shadowcall GetLastError
    mov rcx, rax
    call ExitProcess
fail:
    mov rcx, EXIT_FAILURE
exit:

    call ExitProcess
    ret
main ENDP

; char *pszFileContent, size_t qwFileLength 
FindTopCrates PROC
    LOCAL pszFileContent: QWORD
    LOCAL qwFileLength: QWORD
    LOCAL aStacks[NUMBER_OF_COLUMNS]: QWORD
    LOCAL qwData: QWORD

    push r12 ; preserve nonvolatile registers
    push r13
    push r14
    push r15

    mov pszFileContent, rcx
    mov qwFileLength, rdx

; create column stacks
    
    xor r12, r12
create_column_stacks:
    mov rcx, STACK_REALLOC_SIZE
    shadowcall Stack_Create

    lea rbx, aStacks          ; rbx = &aStacks[0]
    mov [rbx + r12 * 8], rax  ; aStacks[r11] = rax

    inc r12
    cmp r12, NUMBER_OF_COLUMNS
    je create_column_stacks_finish
    jmp create_column_stacks

create_column_stacks_finish:
    xor r12, r12 ; nCurrentColumn
    xor r13, r13 ; nCurrentRow
    lea r15, aStacks
    mov r14, pszFileContent

parse_crate_row:
    mov rcx, QWORD PTR [r15 + r12 * 8]
    xor rdx, rdx
    mov dl, BYTE PTR [r14 + r12 * 4 + 1]
    cmp dl, ' '
    je parse_next_column

    shadowcall Stack_Push

parse_next_column:
    inc r12
    cmp r12, NUMBER_OF_COLUMNS
    je parse_crate_row_finished
    jmp parse_crate_row

parse_crate_row_finished:
    xor r12, r12
    add r14, 36
    inc r13
    cmp r13, 8
    je parse_crate_diagram_finished
    jmp parse_crate_row

parse_crate_diagram_finished:
    pop r15
    pop r14
    pop r13
    pop r12 ; preserve nonvolatile registers

    ret
FindTopCrates ENDP

END