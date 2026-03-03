       IDENTIFICATION DIVISION.
       PROGRAM-ID. BENCH-LOGIC.

       DATA DIVISION.
       WORKING-STORAGE SECTION.
       01 WS-VALID-FLAG    PIC 9 VALUE 0.

       LINKAGE SECTION.
       01 LS-ID             PIC 9(10).
       01 LS-RESULT         PIC 9.
       01 LS-NAME           PIC X(256).
       01 LS-NAME-LEN       PIC 9(4) COMP.
       01 LS-OUT            PIC X(256).
       01 LS-OUT-LEN        PIC 9(4) COMP.

       PROCEDURE DIVISION.

       ENTRY "cobol_validate_id" USING LS-ID LS-RESULT.
           IF LS-ID > 0
               MOVE 1 TO LS-RESULT
           ELSE
               MOVE 0 TO LS-RESULT
           END-IF.
           GOBACK.

       ENTRY "cobol_process_name" USING LS-NAME LS-NAME-LEN
                                        LS-OUT LS-OUT-LEN.
           MOVE LS-NAME(1:LS-NAME-LEN) TO LS-OUT
           MOVE LS-NAME-LEN TO LS-OUT-LEN
           GOBACK.

       STOP RUN.
