ExitProcess    PROTO
HeapAlloc      PROTO
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

.data

FILE_NAME db 'day4_full.txt', 0

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

main PROC
    LOCAL reOpenBuff: _OFSTRUCT
    LOCAL hProcessHeap: QWORD
    LOCAL hFileHandle: QWORD
    LOCAL cbFileLength: QWORD
    LOCAL pszFileContent: QWORD

    sub rsp, 8 ; align stack

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
    call FindOverlappingPairs
    mov rbx, rax

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
FindOverlappingPairs PROC
    LOCAL pszFileContent: QWORD
    LOCAL qwFileLength: QWORD
    LOCAL pqwPairs[PAIRS_LENGTH]: QWORD
    LOCAL qwPairsContained: QWORD

    sub rsp, 8 ; align stack

    mov qwPairsContained, 0
    mov pszFileContent, rcx
    mov qwFileLength, rdx

    ; preserve nonvolatile registers
    push r12
    push r13
    push r14
    push r15

    xor rbx, rbx
    xor rax, rax
replace_characters_with_null_loop:
    mov al, BYTE PTR [rcx + rbx]
    cmp BYTE PTR [rcx + rbx], '-'
    je replace_with_null
    cmp BYTE PTR [rcx + rbx], ','
    je replace_with_null
    cmp BYTE PTR [rcx + rbx], LINE_FEED
    je replace_with_null

replace_characters_with_null_continue:
    cmp rbx, qwFileLength
    jge replace_characters_with_null_loop_finish
    inc rbx
    jmp replace_characters_with_null_loop

replace_with_null:
    mov BYTE PTR [rcx + rbx], NULL
    jmp replace_characters_with_null_continue

replace_characters_with_null_loop_finish:
    xor r12, r12 ; pszFileContent + r12
    xor r13, r13 ; qwLastStringLength
    xor r14, r14 ; qwCurrentTupleIndex

collect_pairs_loop:
    mov rcx, pszFileContent
    add rcx, r12 ; rcx = &pszFileContent[r12]
    shadowcall lstrlenA
    mov r13, rax

    mov rcx, pszFileContent
    add rcx, r12
    shadowcall StrToIntA
    lea r15, pqwPairs
    mov QWORD PTR [r15 + r14 * 8], rax

    cmp r12, qwFileLength
    jge collect_pairs_loop_finish
    lea r12, [r12 + r13 + 1]

    inc r14
    cmp r14, PAIRS_LENGTH
    je compare_pairs
    jmp collect_pairs_loop
compare_pairs:
    xor r14, r14

    lea rax, pqwPairs
    mov rdx, QWORD PTR [rax]
    mov r15, QWORD PTR [rax + 16]
    cmp rdx, r15 ; if (pqwPairs[0] > pqwPairs[2])
    jg left_pair_larger_test_first_part
    je pair_is_contained

    lea rax, pqwPairs
    mov rdx, QWORD PTR [rax]
    mov r15, QWORD PTR [rax + 16]
    cmp rdx, r15 ; if (pqwPairs[0] < pqwPairs[2])
    jle right_pair_larger_test_first_part
    je pair_is_contained

    jmp collect_pairs_loop

left_pair_larger_test_first_part:
    mov rdx, QWORD PTR [rax + 8]
    mov r15, QWORD PTR [rax + 24]
    cmp rdx, r15 ; if (pqwPairs[1] <= pqwPairs[3])
    jle pair_is_contained
    jmp collect_pairs_loop

right_pair_larger_test_first_part:
    mov rdx, QWORD PTR [rax + 8]
    mov r15, QWORD PTR [rax + 24]
    cmp rdx, r15 ; if (pqwPairs[1] >= pqwPairs[3])
    jge pair_is_contained
    jmp collect_pairs_loop

pair_is_contained:
    inc qwPairsContained
    jmp collect_pairs_loop

collect_pairs_loop_finish:
    pop r15
    pop r14
    pop r13
    pop r12

    add rsp, 8 ; align stack
    mov rax, qwPairsContained
    ret
FindOverlappingPairs ENDP

END