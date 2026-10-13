verify_handler:      
            CALL    OPEN_FILE_4READ_CHECK 
            RET     z 
            
            LD HL, (TVC256_FILEHANDLE)
            LD (TVC256_INPUT_AREA), HL
            LD HL, (TVC256_FILEHANDLE+2)
            LD (TVC256_INPUT_AREA+2), HL
            ; read only 1 byte of data
            LD HL, 1
            LD (TVC256_INPUT_AREA+4),HL

.verify_loop:
            PUSH    BC 
            PUSH    DE

            call quick_read

            POP     DE 
            or      a
            JR      nz,READ_FAILED 
            LD      L,C 
            LD      A,(DE) 
            CP      L 
            JR      nz,VERIFY_FAILED 

            INC     DE 
            POP     BC 
            DEC     BC 
            LD      A,B 
            OR      C
            JR      nz,.verify_loop 
            XOR     A 
            RET      
VERIFY_FAILED:       
            POP     BC 
            LD      a,$F0 
            OR      A 
            RET
READ_FAILED:
            POP     BC 
            LD      a,$F1 
            OR      A 
            RET