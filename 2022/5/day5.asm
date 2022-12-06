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

WriteConsoleA PROTO
AttachConsole PROTO
GetStdHandle PROTO

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
    mov r8, (STACK PTR [rcx]).pElements
    mov r9, (STACK PTR [rcx]).nCapacity
    add r9, STACK_REALLOC_SIZE
    imul r9, 8
    mov rcx, hProcessHeap
    xor rdx, rdx

    shadowcall HeapReAlloc
    cmp rax, 0
    je allocate_more_space_fail

    mov rbx, pStack
    mov (STACK PTR [rbx]).pElements, rax
    add (STACK PTR [rbx]).nCapacity, STACK_REALLOC_SIZE
    jmp allocate_space_set_data
Stack_Push ENDP

; pStack, out pqwData -> bEmpty
Stack_Pop PROC
    mov rbx, (STACK PTR [rcx]).pElements
    mov r8, (STACK PTR [rcx]).nPosition
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

; STACK *pStack
Stack_Reverse PROC
    mov rdx, (STACK PTR [rcx]).pElements
    mov r8, (STACK PTR [rcx]).nPosition
    cmp r8, 2
    jle single_element_stack

    xor r9, r9 ; i
reverse_stack:
    mov rax, QWORD PTR [rdx + r9 * 8]

    dec r8
    mov rbx, QWORD PTR [rdx + r8 * 8]
    mov QWORD PTR [rdx + r9 * 8], rbx
    mov QWORD PTR [rdx + r8 * 8], rax
    inc r9
    cmp r9, r8
    jl reverse_stack
single_element_stack:
    ret
Stack_Reverse ENDP

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
    LOCAL apStacks[NUMBER_OF_COLUMNS]: QWORD
    LOCAL qwData: QWORD
    LOCAL qwFromStack: QWORD
    LOCAL qwToStack: QWORD
    LOCAL qwAmount: QWORD
    LOCAL qwCratesMoved: QWORD

    push r12 ; preserve nonvolatile registers
    push r13
    push r14
    push r15

    mov qwCratesMoved, 0
    mov pszFileContent, rcx
    mov qwFileLength, rdx

; create column stacks
    
    xor r12, r12
create_column_stacks:
    mov rcx, STACK_REALLOC_SIZE
    shadowcall Stack_Create

    lea rbx, apStacks          ; rbx = &aStacks[0]
    mov [rbx + r12 * 8], rax  ; aStacks[r11] = rax

    inc r12
    cmp r12, NUMBER_OF_COLUMNS
    je create_column_stacks_finish
    jmp create_column_stacks

create_column_stacks_finish:
    xor r12, r12 ; nCurrentColumn
    xor r13, r13 ; nCurrentRow
    lea r15, apStacks
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

    xor r12, r12
    lea r15, apStacks
reverse_all_stacks:
    mov rcx, QWORD PTR [r15 + r12 * 8]
    shadowcall Stack_Reverse
    inc r12
    cmp r12, NUMBER_OF_COLUMNS
    jne reverse_all_stacks

    mov rcx, pszFileContent
    add rcx, 36 * NUMBER_OF_COLUMNS ; move past diagram
    xor rax, rax
    xor r8, r8
find_start_of_moves:
    inc rcx
    mov al, BYTE PTR [rcx]
    cmp al, 'm' ; first letter m in move
    jne find_start_of_moves

    xor r12, r12 ; iRowIndex
    mov r13, rcx ; pszFileContents_modified
    xor r14, r14 ; nLastStringLength
    lea r15, apStacks
    xor rax, rax
parse_moves_row:
replace_move_row_nulls:
    xor rax, rax
    mov al, BYTE PTR [r13 + r12]
    cmp al, ' '
    je replace_with_null
    cmp al, LINE_FEED
    je replace_move_row_nulls_finished
    inc r12
    jmp replace_move_row_nulls
replace_with_null:
    mov BYTE PTR [r13 + r12], NULL
    jmp replace_move_row_nulls
replace_move_row_nulls_finished:
    add r13, 5
    mov rcx, r13

    shadowcall lstrlenA
    mov r14, rax

    mov rcx, r13
    shadowcall StrToIntA
    mov qwAmount, rax

    xor rbx, rbx
    xor rdx, rdx
    mov bl, BYTE PTR [r13 + r14 + 6]
    sub rbx, 49
    mov qwFromStack, rbx
    mov dl, BYTE PTR [r13 + r14 + 11]
    sub rdx, 49
    mov qwToStack, rdx

move_crates:
    mov rbx, qwFromStack
    mov rcx, QWORD PTR [r15 + rbx * 8] ; pStack

    lea rdx, qwData
    shadowcall Stack_Pop
    

    mov rbx, qwToStack
    mov rcx, QWORD PTR [r15 + rbx * 8] ; pStack
    mov rdx, qwData
    shadowcall Stack_Push

    inc qwCratesMoved
    mov rax, qwCratesMoved
    cmp rax, qwAmount
    jne move_crates

    mov qwCratesMoved, 0
    lea r13, [r13 + r14 + 13]
    xor r12, r12

    mov rax, r13
    mov rbx, pszFileContent
    sub rax, rbx
    cmp rax, qwFileLength
    jl parse_moves_row

    mov rcx, -1
    shadowcall AttachConsole

    mov rcx, STD_OUTPUT_HANDLE
    shadowcall GetStdHandle
    mov r13, rax

    xor r12, r12
print_top_of_stacks:
    mov rcx, QWORD PTR [r15 + r12 * 8]
    lea rdx, qwData
    shadowcall Stack_Pop

    mov rcx, r13
    lea rdx, qwData
    mov r8, 1
    mov r9, 0
    push 0
    push 0
    shadowcall WriteConsoleA

    inc r12
    cmp r12, NUMBER_OF_COLUMNS 
    jne print_top_of_stacks
    
    pop r15
    pop r14
    pop r13
    pop r12 ; preserve nonvolatile registers

    ret
FindTopCrates ENDP

END