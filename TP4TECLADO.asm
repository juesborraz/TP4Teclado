LIST P=16F887
    INCLUDE <P16F887.INC>

    __CONFIG _CONFIG1, _XT_OSC & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF
    
;Guardamos variables
    CBLOCK 0x20       ;a partir de la direccion 0x20
        VAL_DSPL_1    ;guarda el numero a mostrar en display 1 
        VAL_DSPL_2    ;guarda el numero a mostrar en display 2 
        VAL_DSPL_3    ;guarda el numero a mostrar en display 3
        VAL_DSPL_4    ;guarda el numero a mostrar en display 4
        CONT_NTECL    ;puntero, en que display se carga la proxima tecla
        NTECL         ;guarda que tecla se apreto 
        W_TEMP        ;guarda W para contexto
        STATUS_TEMP   ;guarda STATUS para contexto
        CONT1 
        CONT2         ;contadores para esperas 
    ENDC

    ORG 0x000
    GOTO INICIO       ;programa 

    ORG 0x004
    GOTO ISR_INICIO   ;interrupcion 

INICIO:
    
;Configuración de pines 
    ;DIGITAL
    BANKSEL ANSEL     ;banco de registro ANSEL  
    CLRF    ANSEL
    CLRF    ANSELH    ;desactivo entradas analogicas 

    ;COMPARADORES
    BANKSEL CM1CON0
    CLRF    CM1CON0
    CLRF    CM2CON0   ;desactivo comparadores ya que sino estaria malgastando pines

    ;PINES RA0 RA3 PARA MULTIPLEXADO DE 4 DISPLAYS 
    BANKSEL TRISA     ;banco donde está TRIS del puerto A 
    MOVLW   b'11110000'
    MOVWF   TRISA     ;bit 0 a 3 salidas (Multiplexado) , bit 4 a 7 entradas 
    ;PIN RB0 INTERRUPCION EXTERNA 
    ;PINES RB1 A RB4 ENTRADAS, COLUMNAS DEL TECLADO 
    ;PIBES RB5 A RB7 SALIDAS, FILAS DEL TECLADO 
    MOVLW   b'00011111'
    MOVWF   TRISB
    ;PIN RC1 ME FALTABA UNA SALIDA DEL TECLADO (por rb0 int)
    MOVLW   b'11111101'
    MOVWF   TRISC
    ;PUERTO D COMPLETO, SALIDAS, SON LOS SEGMENTOS DE LOS DISPLAYS 
    CLRF    TRISD
    ;RESISTENCIAS PULL UP PARA RB0-RB4 
    MOVLW   b'00011111'
    MOVWF   WPUB
    ;ACTIVO RESISTENCIA PULL UP GLOBAL 
    BANKSEL OPTION_REG
    BCF     OPTION_REG, 7      ; nRBPU = 0
    ;INT EXTERNA POR FLANCO DESCENDENTE EN RB0
    BCF     OPTION_REG, 6      ; INTEDG = 0

;Inicializacion de pines
    ;TODOS LOS DISPLAY ARRANCAN APAGADOS, para prender necesito poner un 0 asi circula corriente (anodo comun, Vcc)
    BANKSEL PORTA
    MOVLW   b'00001111'   ;el nipple bajo eran los displays 
    MOVWF   PORTA
    ;TODOS LOS SEGMENTOS ARRANCAN APAGADOS 
    BANKSEL PORTD
    MOVLW   b'11111111'
    MOVWF   PORTD
    ;TODAS LAS FILAS DEL TECLADO ESTÁN EN BAJO 
    BANKSEL PORTB
    BCF     PORTB, 5
    BCF     PORTB, 6
    BCF     PORTB, 7
    BANKSEL PORTC
    BCF     PORTC, 1

    ;estado inicial: ----
    MOVLW   0x10       ;EN LA TABLA ES UN GUION
    MOVWF   VAL_DSPL_1
    MOVWF   VAL_DSPL_2
    MOVWF   VAL_DSPL_3
    MOVWF   VAL_DSPL_4

    MOVLW   0x01
    MOVWF   CONT_NTECL ;PROXIMA TECLA SE MOSTRARA EN 1

    ;limpio bandera de interrupcion externa
    BANKSEL INTCON
    BCF     INTCON, INTF

    ;habilito interrupcion externa 
    BSF     INTCON, INTE

    ;habilito interrupciones globales 
    BSF     INTCON, GIE

BUCLEPRINCIPAL:
    CALL    REFRESH_DSPL    ;subrutina que enciende un display,lo apaga y pasa al siguiente(multiplexado)
    GOTO    BUCLEPRINCIPAL  ;continuamente haciendo refresh

    
;RUTINA DE INTERRUPCION
ISR_INICIO:
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP    ;guardo contexto

    BANKSEL INTCON
    BTFSS   INTCON, INTF
    GOTO    ISR_FIN        ;si la interrupcion no fue por RB0, FIN

    CALL    ISR_TECL       ;si la interrupcion fue por RB0, me voy a una subrutina 

    BANKSEL INTCON
    BCF     INTCON, INTF  ;bajo bandera, siempre, ya que luego del call regreso acá 

ISR_FIN:
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE                ;recupero contexto y vuelvo, siempre 


ISR_TECL:
    CALL    TECL_DELAY

;primer fila activa, hago RB7=1,RB6=1,RB5=0, RC1=1
    BANKSEL PORTB
    MOVLW   b'11000000'
    MOVWF   PORTB
    BANKSEL PORTC
    BSF     PORTC, 1

    NOP
    NOP

    BANKSEL PORTB
    BTFSS   PORTB, 1   
    GOTO    TECLA_1   ;Si esta en 1 no hay tecla presionada, salteo. Si está en 0, esta presionada, subrutina de esa tecla 
    BTFSS   PORTB, 2 
    GOTO    TECLA_2
    BTFSS   PORTB, 3
    GOTO    TECLA_3
    BTFSS   PORTB, 4
    GOTO    TECLA_A

;segunda fila activa (RB6=0)
    MOVLW   b'10100000'
    MOVWF   PORTB
    BANKSEL PORTC
    BSF     PORTC, 1

    NOP
    NOP

    BANKSEL PORTB
    BTFSS   PORTB, 1 ;voy viendo las columnas, a ver si alguna tecla esta presionada 
    GOTO    TECLA_4
    BTFSS   PORTB, 2
    GOTO    TECLA_5
    BTFSS   PORTB, 3
    GOTO    TECLA_6
    BTFSS   PORTB, 4
    GOTO    TECLA_B

;fila 3 activa(RB7=0)
    MOVLW   b'01100000'
    MOVWF   PORTB
    BANKSEL PORTC
    BSF     PORTC, 1

    NOP
    NOP

    BANKSEL PORTB
    BTFSS   PORTB, 1
    GOTO    TECLA_7
    BTFSS   PORTB, 2
    GOTO    TECLA_8
    BTFSS   PORTB, 3
    GOTO    TECLA_9
    BTFSS   PORTB, 4
    GOTO    TECLA_C

;cuarta fila activa (RC1=0)
    MOVLW   b'11100000'
    MOVWF   PORTB
    BANKSEL PORTC
    BCF     PORTC, 1

    NOP
    NOP

    BANKSEL PORTB
    BTFSS   PORTB, 1
    GOTO    TECLA_E       
    BTFSS   PORTB, 2
    GOTO    TECLA_0
    BTFSS   PORTB, 3
    GOTO    TECLA_F      
    BTFSS   PORTB, 4
    GOTO    TECLA_D

    GOTO    TECL_RST

;VALORES DE TECLA 
TECLA_0:
    MOVLW   0x00
    GOTO    GUARDAR_TECLA

TECLA_1:
    MOVLW   0x01
    GOTO    GUARDAR_TECLA

TECLA_2:
    MOVLW   0x02
    GOTO    GUARDAR_TECLA

TECLA_3:
    MOVLW   0x03
    GOTO    GUARDAR_TECLA

TECLA_4:
    MOVLW   0x04
    GOTO    GUARDAR_TECLA

TECLA_5:
    MOVLW   0x05
    GOTO    GUARDAR_TECLA

TECLA_6:
    MOVLW   0x06
    GOTO    GUARDAR_TECLA

TECLA_7:
    MOVLW   0x07
    GOTO    GUARDAR_TECLA

TECLA_8:
    MOVLW   0x08
    GOTO    GUARDAR_TECLA

TECLA_9:
    MOVLW   0x09
    GOTO    GUARDAR_TECLA

TECLA_A:
    MOVLW   0x0A
    GOTO    GUARDAR_TECLA

TECLA_B:
    MOVLW   0x0B
    GOTO    GUARDAR_TECLA

TECLA_C:
    MOVLW   0x0C
    GOTO    GUARDAR_TECLA

TECLA_D:
    MOVLW   0x0D
    GOTO    GUARDAR_TECLA

TECLA_E:
    MOVLW   0x0E
    GOTO    GUARDAR_TECLA

TECLA_F:
    MOVLW   0x0F
    GOTO    GUARDAR_TECLA

GUARDAR_TECLA:
    MOVWF   NTECL        ;se guarda el valor de W en NTECL 
    GOTO    TECL_LOAD    ;subrutina que carga en display 

TECL_RST:
;FILAS TODAS EN 0, MODO ESPERA. Las columnas estan en 1 hasta que se aprete alguna tecla 
    BANKSEL PORTB
    BCF     PORTB, 5
    BCF     PORTB, 6
    BCF     PORTB, 7
    BANKSEL PORTC
    BCF     PORTC, 1

    RETURN

;subrutina que carga tecla en display, comparo el valor con 1,2,3,4 para cargar en el display correcto
TECL_LOAD:
    MOVF    CONT_NTECL, W
    XORLW   0x01
    BTFSC   STATUS, Z    ;si habia que guardar en 1, son iguales y z=1
    GOTO    LOAD_1

    MOVF    CONT_NTECL, W
    XORLW   0x02
    BTFSC   STATUS, Z
    GOTO    LOAD_2

    MOVF    CONT_NTECL, W
    XORLW   0x03
    BTFSC   STATUS, Z
    GOTO    LOAD_3

    GOTO    LOAD_4      ;si no son las anteriores es la última 

LOAD_1: ;para cargar en display numero 1 
    MOVF    NTECL, W
    MOVWF   VAL_DSPL_1  ;la tecla apretada la cargo en esta variable 

    MOVLW   0x10
    MOVWF   VAL_DSPL_2
    MOVWF   VAL_DSPL_3
    MOVWF   VAL_DSPL_4  ;pongo guiones - en los otros display 

    MOVLW   0x02
    MOVWF   CONT_NTECL  ;ahora la proxima tecla se cargara en el display 2 
    GOTO    FIN_LOAD    

LOAD_2:
    MOVF    NTECL, W
    MOVWF   VAL_DSPL_2  ;pongo el valor a mostrar en esta variable 

    MOVLW   0x10
    MOVWF   VAL_DSPL_1
    MOVWF   VAL_DSPL_3
    MOVWF   VAL_DSPL_4  ;pongo guiones en los otros displays 

    MOVLW   0x03
    MOVWF   CONT_NTECL  ;proxima tecla se muestra en el display 3 
    GOTO    FIN_LOAD

LOAD_3:
    MOVF    NTECL, W
    MOVWF   VAL_DSPL_3

    MOVLW   0x10
    MOVWF   VAL_DSPL_1
    MOVWF   VAL_DSPL_2
    MOVWF   VAL_DSPL_4

    MOVLW   0x04
    MOVWF   CONT_NTECL
    GOTO    FIN_LOAD

LOAD_4:
    MOVF    NTECL, W
    MOVWF   VAL_DSPL_4

    MOVLW   0x10
    MOVWF   VAL_DSPL_1
    MOVWF   VAL_DSPL_2
    MOVWF   VAL_DSPL_3

    MOVLW   0x01
    MOVWF   CONT_NTECL
    GOTO    FIN_LOAD

FIN_LOAD:
;pongo todas las filas en 0 POR? 
    BANKSEL PORTB
    BCF     PORTB, 5
    BCF     PORTB, 6
    BCF     PORTB, 7
    BANKSEL PORTC
    BCF     PORTC, 1

    RETURN

;MULTIPLEXADO 
REFRESH_DSPL:
    ; DISPLAY 1
    BANKSEL PORTA
    MOVLW   b'00001111'      ;apago los 4 displays con "1" (ra0-ra3 son los displays)
    MOVWF   PORTA
    BANKSEL PORTD
    MOVLW   b'11111111'      ;apago los segmentos con "1"
    MOVWF   PORTD

    MOVF    VAL_DSPL_1, W    ;el valor que debo mostrar lo pongo en W para llamar a la tabla 
    CALL    TABLA_7SEG
    MOVWF   PORTD            ;ese valor se convirtio en una combinacion de segmentos prendidos y apagados 

    BANKSEL PORTA
    BCF     PORTA, 0         ;encindo ahora el display 1 
    CALL    DELAY_5MS        ;espera

    ; DISPLAY 2
    BANKSEL PORTA
    MOVLW   b'00001111'
    MOVWF   PORTA
    BANKSEL PORTD
    MOVLW   b'11111111'
    MOVWF   PORTD

    MOVF    VAL_DSPL_2, W
    CALL    TABLA_7SEG
    MOVWF   PORTD

    BANKSEL PORTA
    BCF     PORTA, 1         ;enciendo display 2 
    CALL    DELAY_5MS

    ; DISPLAY 3
    BANKSEL PORTA
    MOVLW   b'00001111'
    MOVWF   PORTA

    BANKSEL PORTD
    MOVLW   b'11111111'
    MOVWF   PORTD

    MOVF    VAL_DSPL_3, W
    CALL    TABLA_7SEG
    MOVWF   PORTD

    BANKSEL PORTA
    BCF     PORTA, 2         ;enciendo display 3 
    CALL    DELAY_5MS

    ; DISPLAY 4
    BANKSEL PORTA
    MOVLW   b'00001111'
    MOVWF   PORTA

    BANKSEL PORTD
    MOVLW   b'11111111'
    MOVWF   PORTD

    MOVF    VAL_DSPL_4, W
    CALL    TABLA_7SEG
    MOVWF   PORTD

    BANKSEL PORTA
    BCF     PORTA, 3         ;enciendo display 4 
    CALL    DELAY_5MS

    ;apago todo, tanto segmentos como displays 
    BANKSEL PORTA
    MOVLW   b'00001111'
    MOVWF   PORTA
    BANKSEL PORTD
    MOVLW   b'11111111'
    MOVWF   PORTD

    RETURN

;DELAY
TECL_DELAY:  
    MOVLW   d'20'
    MOVWF   CONT2

BUCLE_20MS:
    MOVLW   d'249'
    MOVWF   CONT1

BUCLE_1MS_A:
    NOP                 ;1useg
    DECFSZ  CONT1, F    ;1useg
    GOTO    BUCLE_1MS_A ;2useg
;249x4useg=996useg=1mseg
    DECFSZ  CONT2, F
    GOTO    BUCLE_20MS
;249x20x4useg=19,92mseg
    RETURN

DELAY_5MS:
    MOVLW   d'5'
    MOVWF   CONT2

BUCLE_5MS:
    MOVLW   d'249'
    MOVWF   CONT1

BUCLE_1MS_B:
    NOP
    DECFSZ  CONT1, F
    GOTO    BUCLE_1MS_B

    DECFSZ  CONT2, F
    GOTO    BUCLE_5MS
;249x4seg=1mseg
;249x5x4useg=5mseg
    RETURN

;TABLA DEL DISPLAY 
    ORG 0x300

TABLA_7SEG:
    MOVWF   CONT1                  ;guarda valor que estaba en W, en CONT1 
    MOVLW   HIGH TABLA_7SEG_DATOS  
    MOVWF   PCLATH
    MOVF    CONT1, W
    ADDWF   PCL, F                ;suma el valor de la tecla al contador del programa

TABLA_7SEG_DATOS:
    RETLW   b'11000000'  ; 0
    RETLW   b'11111001'  ; 1
    RETLW   b'10100100'  ; 2
    RETLW   b'10110000'  ; 3
    RETLW   b'10011001'  ; 4
    RETLW   b'10010010'  ; 5
    RETLW   b'10000010'  ; 6
    RETLW   b'11111000'  ; 7
    RETLW   b'10000000'  ; 8
    RETLW   b'10010000'  ; 9
    RETLW   b'10001000'  ; A
    RETLW   b'10000011'  ; B
    RETLW   b'11000110'  ; C
    RETLW   b'10100001'  ; D
    RETLW   b'10000110'  ; E
    RETLW   b'10001110'  ; F
    RETLW   b'10111111'  ; guion -

    END