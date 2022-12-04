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
LINE_FEED equ       10
CARRIAGE_RETURN equ 13
NULL equ 0

.data

FILE_NAME db 'day1_full_test.txt', 0

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
    LOCAL hConsoleHandle: QWORD

    sub rsp, ((SIZEOF QWORD) * 5 + sizeof(_OFSTRUCT)) MOD 16

    mov rax, 0
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
    mov rdx, 0
    shadowcall GetFileSize

    mov cbFileLength, rax

    cmp eax, HFILE_ERROR
    je fail

    mov rcx, hProcessHeap
    mov rdx, 0

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
    mov r9, 0
    push 0
    sub rsp, 8
    shadowcall ReadFile
    add rsp, 16

    cmp rax, 0
    je fail

    mov rcx, pszFileContent
    mov rdx, cbFileLength
    call find_max_elf_total_calories
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

; char *pszFileContent, size_t cbFileLength 
find_max_elf_total_calories PROC
    LOCAL qwMaxCaloriesSeen: QWORD
    LOCAL qwCurrentCaloriesSeen: QWORD
    LOCAL pszFileContent: QWORD
    LOCAL cbFileLength: QWORD
    LOCAL cbLastStringLength: QWORD

    sub rsp, 8

    mov qwMaxCaloriesSeen, 0
    mov qwCurrentCaloriesSeen, 0
    mov cbLastStringLength, 0
    mov pszFileContent, rcx
    mov cbFileLength, rdx

    mov rbx, pszFileContent
    mov rcx, 0
replace_new_line_loop:
    cmp BYTE PTR [rbx + rcx], LINE_FEED
    jne replace_new_line_continue

    mov BYTE PTR [rbx + rcx], NULL
replace_new_line_continue:
    inc rcx
    cmp rcx, cbFileLength
    jl replace_new_line_loop

    mov r11, 0
    mov rbx, pszFileContent
elf_collection_loop:
    mov rcx, pszFileContent
    lea rcx, [rcx + r11]
    shadowcall lstrlenA
    mov cbLastStringLength, rax
    cmp rax, 0
    je elf_collection_loop_new_elf

    mov rcx, pszFileContent
    lea rcx, [rcx + r11]
    shadowcall StrToIntA
    add qwCurrentCaloriesSeen, rax
    mov rax, qwCurrentCaloriesSeen

elf_collection_loop_continue:
    add r11, cbLastStringLength
    inc r11
    cmp r11, cbFileLength
    jl elf_collection_loop
    jmp elf_collection_loop_end

elf_collection_loop_new_elf:
    lea rcx, qwMaxCaloriesSeen
    lea rdx, qwCurrentCaloriesSeen
    shadowcall set_if_bigger

    mov qwCurrentCaloriesSeen, 0
    jmp elf_collection_loop_continue

elf_collection_loop_end:
    lea rcx, qwMaxCaloriesSeen
    lea rdx, qwCurrentCaloriesSeen
    shadowcall set_if_bigger

    mov rax, qwMaxCaloriesSeen
    add rsp, 8
    ret
find_max_elf_total_calories ENDP

; pqwMax, pqwCurrent
set_if_bigger PROC
    mov rax, qword ptr [rcx]
    cmp rax, qword ptr [rdx]
    jg set_if_bigger_greater_than

    mov rax, qword ptr [rdx]
    mov qword ptr [rcx], rax
set_if_bigger_greater_than:
    ret
set_if_bigger ENDP

END