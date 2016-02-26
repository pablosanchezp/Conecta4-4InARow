;**************************************************************************
; Autor: Pablo Sanchez Perez
; El programa ira pidiendo al jugar 1 y al jugador la insercion de una ficha en una de las columnas.
; El juego acaba si se da una de estas 2 condiciones:
; 	-El jugador 1 o 2 consigue 4 fichas seguidas (vertical, horizontal o diagonal).
;	-Se llena toda la matriz sin que sea posible continuar.
;**************************************************************************


; DEFINICION DEL SEGMENTO DE DATOS
DATOS SEGMENT
	FILAS 		EQU 6									; Numero de filas del tablero. Esta pensado para 6 filas y 7 columnas
	COLUMNAS 	EQU 7
	COLUMNAS2	EQU COLUMNAS*2
	COLUMNAS3	EQU COLUMNAS*3							; Numero de columnas del tablero
	INDICE_FILA	EQU (FILAS-1)*COLUMNAS
	MATRIZ 		DB FILAS*COLUMNAS DUP (30H)				; Matriz de CONECTA
	CLR_PANT 	DB 	1BH,"[2","J$"						; borra la pantallas
	FIN			DB 	0Dh, 0Ah, 24H						; Fin de linea
	INVALIDO 	DB "Numero introducido no es valido $"
	CASILLA1	DB "JUGADOR 1: Introduzca la columna donde poner la ficha $"
	CASILLA2	DB "JUGADOR 2: Introduzca la columna donde poner la ficha $"
	NUMERO		DB 30,0,30 dup (0H)
	GANADOR1	DB "El ganador es el jugador 1 $"
	GANADOR2	DB "El ganador es el jugador 2 $"
	POSICION	DB 0H									;La posicion de la ficha
	CASILLA_INV DB "Esta casilla es invalida $"				
	ESPACIO		DB " $"									;Cadena del espacio
	FLAG_GANADORA	DB 0H							;4 en raya 4 que comprobar
	JUGADOR_ACTUAL  DB 0H							;Variable que indica que jugador esta actualmente en juego
	;Variables utilizadas para la interrupcion periodica
	TIEMPO_SOBREPASADO DB "Has consumido el tiempo limite $"
	TIEMPO_ESPERA	DW 300	;Tiempo limite para poner la ficha
	NUM_INT		equ	1CH								;Instruccion periodica
	DIR 		equ 	4*NUM_INT
	OLDINT1C	DW	0H							;Variables que almacena la anterior int 1CH
	OLDINT1C2	DW	0H
	CONTADOR	DW 0H							;Utilizada para el contador de espera del tiempo
	FLAG_LIMITE	DB 0H							;Utilizada para marcar si estamos en modo aleatorio
	PRESENTACION DB "Juego de 4 en raya. El juego acaba cuando 1 jugador consigue 4 en raya o la matriz se queda sin huecos libres $"
	EMPATE	DB "Empate $"
DATOS ENDS

;**************************************************************************
; DEFINICION DEL SEGMENTO DE PILA
PILA SEGMENT STACK "STACK"
	DB 40H DUP (0) ;ejemplo de inicialización, 64 bytes inicializados a 0
PILA ENDS


;**************************************************************************
; DEFINICION DEL SEGMENTO EXTRA
EXTRA SEGMENT
	RESULT DW 0,0 ;ejemplo de inicialización. 2 PALABRAS (4 BYTES)
EXTRA ENDS


;**************************************************************************
; DEFINICION DEL SEGMENTO DE CODIGO
CODE SEGMENT
	ASSUME CS: CODE, DS: DATOS, ES: EXTRA, SS: PILA
; COMIENZO DEL PROCEDIMIENTO PRINCIPAL
INICIO PROC


; INICIALIZA LOS REGISTROS DE SEGMENTO CON SU VALOR
MOV AX, DATOS
MOV DS, AX
MOV AX, PILA
MOV SS, AX
MOV AX, EXTRA
MOV ES, AX
MOV SP, 64 ; CARGA EL PUNTERO DE PILA CON EL VALOR MAS ALTO
; FIN DE LAS INICIALIZACIONES

	;Primero, salvamos la interrupcion anterior de 1CH, para volver a dejar el sistema tal y como estaba.
	MOV AX, 0H
	MOV ES, AX
	MOV AX, ES:[DIR]
	MOV WORD PTR OLDINT1C, AX			;Guardamos el valor de la interrupcion 1ch en la variable OLDINT1C
	MOV AX, ES:[DIR+2]
	MOV WORD PTR OLDINT1C2, AX			;Guardamos la segunda parte en OLDINT1C2
	
	;Instalacion de interrupcion de 1CH con la funcion de sumador
	CLI
	MOV word ptr ES:[DIR], OFFSET SUMADOR		;Metemos ahora en 1CH nuestra funcion de SUMADOR
	MOV word ptr ES:[DIR+2], CS			;Primero el OFFSET y luego el segmento, que es CS
	STI
	
	MOV AH, 9H
	MOV DX, OFFSET CLR_PANT				; Limpiamos la pantalla para presentar el programa
	INT 21H
	
	MOV AH, 9H
	MOV DX, OFFSET PRESENTACION
	INT 21H
	
	MOV AH, 9H
	MOV DX, OFFSET FIN					 ; Fin de linea
	INT 21H

; COMIENZO DEL PROGRAMA
	
	;Cada el bucle se ejecuta SIEMPRE
	JUEGO:
		MOV CONTADOR, 0H
		CALL IMPRIME
		;Primero es el jugador 1
		JUGADOR1:
			MOV CONTADOR, 0H
			MOV AH, 9H
			MOV DX, OFFSET CASILLA1		; Pregunta para pedir la casilla al jugador 1
			INT 21H	
		
			MOV AH, 0Ah				;Leemos la casilla del jugador 1
			MOV DX, OFFSET NUMERO
			CALL MATRIZ_LLENA		; Funcion para comprobar si la matriz esta llena o no. Si lo esta, acaba
			CALL LLAMADA			; Llamada para obtener la columna para meter la ficha. La columna se deja en AL
			MOV CONTADOR, 0H			


			MOV AH, 9H
			MOV DX, OFFSET FIN
			INT 21H

			MOV AH, 0H
			MOV CX, 1H				; En CX metemos el jugador a modificar
			CALL MODIFICA_MATRIZ	; Funcion para meter la ficha
			CMP BX, 1H				; Si la funcion devuelve 1 entonces error y se le vuelve a pedir ficha al jugador
			JE JUGADOR1
			CALL GANADOR			; Comprobamos si hay ganbador despues de insertar la ficha
			CMP AX, 1H
			JE FIN_CONECTA
			CALL IMPRIME			; Despues de meter la ficha del jugar 1 imprimimos de nuevos
		
		;Procedemos ahora para el jugador2
		
		JUGADOR2:
			MOV CONTADOR, 0H
			MOV AH, 9H
			MOV DX, OFFSET CASILLA2		; Pedimos la casilla al jugador 2
			INT 21H	
		
			MOV AH, 0Ah					;Leemos la casilla del jugador 2
			MOV DX, OFFSET NUMERO
			CALL MATRIZ_LLENA			; Comprobamos si la matriz esta llena
			MOV CONTADOR, 0H
			CALL LLAMADA				;Llamada se encarga de leer la tecla introducida por el usuario.

			MOV AH, 9H
			MOV DX, OFFSET FIN
			INT 21H

			MOV AH, 0H
			MOV CX, 2H
			CALL MODIFICA_MATRIZ	;Funcion para meter la ficha
			CALL GANADOR			; Comprobamos de nuevo el ganador
			CMP AX, 1H
			JE FIN_CONECTA
			CMP BX, 1H	
			JE JUGADOR2
			
		MOV AH, 9H
		MOV DX, OFFSET CLR_PANT
		INT 21H
		JMP JUEGO


FIN_CONECTA:

	;Restructuracion de la anterior interrupcion 1CH
	MOV AX, 0	
	MOV ES, AX
	CLI
	MOV AX, WORD PTR OLDINT1C
	MOV ES:[DIR], AX
	MOV AX, WORD PTR OLDINT1C2
	MOV ES:[DIR+2], AX
	STI
MOV AH, 9H
MOV DX, OFFSET FIN
INT 21H
CALL IMPRIME
; FIN DEL PROGRAMA
MOV AX, 4C00H
INT 21H
INICIO ENDP


;___________________________________________________________________ 
; SUBRUTINA PARA IMPRIMIR LA MATRIZ
; IMPRIMIRA LA MATRIZ EN FORMA DE TABLERO.
;__________________________________________________________________ 
IMPRIME PROC
	PUSH SI BX CX DX AX			;Guardamos los registros
	MOV BX, 0H			;Movemos SI y BX a 0 nos servira para movernos en las filas y las columnas.
	MOV SI, 0H
	MOV CX, 0H			;Contador de las filas
	MOV AH, 02H
	
	BUCLE:
		MOV DX, 0H
		MOV AH, 02H
		CMP BX, COLUMNAS		;BX nos indica las columnas, cuando llegue al valor de las columnas, entonces acaba
		JE FUERA
		MOV DL, MATRIZ[SI][BX]	;Por cada valor de la matriz, imprimimos un espacio para mayor claridad.
		INT 21H
		MOV AH, 9H
		MOV DX, OFFSET ESPACIO
		INT 21H
		INC BX
		JMP BUCLE
		FUERA:
			INC CX
			ADD SI, COLUMNAS		;Mientras que BX solo tiene de 0 a 6 SI tiene de 7 en 7 para imprimir la totalidad de la matriz.
			MOV BX, 0H
			MOV AH, 9H
			MOV DX, OFFSET FIN
			INT 21H
			CMP CX, FILAS			;Cuando CX haya llegado al final de las filas, acabara el bucle. Cx se incrementa de 1 en 1 hasta FILAS
			JE FIN_IMPRE
			JMP BUCLE			
	FIN_IMPRE:
	POP AX DX CX BX SI
	RET
IMPRIME ENDP


;___________________________________________________________________ 
; SUBRUTINA PARA CALCULAR SI ALGUNO DE LOS 2 ES EL GANADOR
; RECIBE EN CX EL JUGADOR A COMPROBAR
; DEVUELVE EN AX 1 si hay ganador 0 si no lo hay
;__________________________________________________________________ 
GANADOR PROC
	PUSH DX BX CX DX SI DI
	MOV DX, 0H
	mov FLAG_GANADORA, 0H
	MOV DI, 0H
	MOV SI, 0H				;BX lo utilizaremos para ir por las filas y SI en cada posicion
	MOV BX, 0H
	CMP CX, 1H
	JE GANA1
		MOV JUGADOR_ACTUAL, 32H
		JMP HORIZONTAL
	GANA1:
		MOV JUGADOR_ACTUAL, 31H
	HORIZONTAL:
		CMP DI, FILAS
		JE FIN_HORIZ
			HORIZONTAL2:
				CMP SI, COLUMNAS-3				; si hay 7 columnas, solo vamos a movernos de 0 a 3
				JE SALTO_HORIZ
				MOV AL, JUGADOR_ACTUAL			; En AL se guarda el jugador actual
				CMP MATRIZ[BX+SI]+0, AL			; Horizontal se comprueba el actual y los 4 siguientes
				JNE SIG1
					CALL SUMA_FLAG_GANADORA
				SIG1:
				CMP MATRIZ[BX+SI]+1, AL
				JNE SIG2
					CALL SUMA_FLAG_GANADORA
				SIG2:
				CMP MATRIZ[BX+SI]+2, AL
				JNE SIG3
					CALL SUMA_FLAG_GANADORA
				SIG3:
				CMP MATRIZ[BX+SI]+3, AL
				JNE SIG4
					CALL SUMA_FLAG_GANADORA
				SIG4:
				INC SI
				CMP FLAG_GANADORA, 4H			; Si la flag vale 4 entonces es ganador. Salimos de la funcion indicando la flag de ganador
				JE GANADOR_ENCONTRADO
				MOV FLAG_GANADORA, 0H			; En el caso de que la flag ganadora no es 4 entonces se resetea a 0
				VUELTA: JMP HORIZONTAL2
					GANADOR_ENCONTRADO:
						CMP JUGADOR_ACTUAL, 31H			; Si se activa la flag hay que comprobar si el jugador es el 1 o el 2 para mostrar el mensaje
						JE IMPRIME_GAN1
							MOV AH, 9H
							MOV DX, OFFSET GANADOR2
							INT 21H
							JMP SALIR_GANADOR
						IMPRIME_GAN1:
							MOV AH, 9H
							MOV DX, OFFSET GANADOR1
							INT 21H
						SALIR_GANADOR:
						MOV AX, 1H					;AX 1 indica que hay un ganador encontrado. Acabamos el programa
						POP DI SI DX CX BX DX
						RET
		SALTO_HORIZ:
		MOV FLAG_GANADORA, 0H
		ADD BX, COLUMNAS
		INC DI
		MOV SI, 0H
		JMP HORIZONTAL
	FIN_HORIZ:
	; FIN DE LAS COMPROBACIONES DE LINEAS HORIZONTALES
	; Procedemos a comprobar las lineas verticales
	MOV FLAG_GANADORA, 0H
	MOV BX, 0H	; Utilizado para moverse en las columnas (0-7)
	MOV DI, 0H	; Utilizado para el contador de posiciones
	MOV SI, 0H	; Utilizado para moverse en las filas
	VERTICAL:
		CMP BX, COLUMNAS
		JE FIN_VERTICAL
		VERTICAL2:
				CMP DI, FILAS-3h				; si hay 7 columnas, solo vamos a movernos de 0 a 3. Comprobamos al actual y los 4 por debajo siguientes
				JE SALTO_VERT
				MOV AL, JUGADOR_ACTUAL
				CMP MATRIZ[BX+SI], AL
				JNE SIG1V
					CALL SUMA_FLAG_GANADORA
				SIG1V:
				CMP MATRIZ[BX+SI]+COLUMNAS, AL
				JNE SIG2V
					CALL SUMA_FLAG_GANADORA
				SIG2V:
				CMP MATRIZ[BX+SI]+COLUMNAS2, AL
				JNE SIG3V
					CALL SUMA_FLAG_GANADORA
				SIG3V:
				CMP MATRIZ[BX+SI]+COLUMNAS3, AL
				JNE SIG4V
					CALL SUMA_FLAG_GANADORA
				SIG4V:
				INC DI
				ADD SI, COLUMNAS			;Si almacenamos las sucesivas columnas en las que vamos moviendonos. Despues de comprobar una columna entera, se resetea
				CMP FLAG_GANADORA, 4H
				JE GANADOR_ENCONTRADO
				MOV FLAG_GANADORA, 0H
				VUELTA_VERT: JMP VERTICAL2
		SALTO_VERT:
		MOV DI, 0H
		MOV FLAG_GANADORA, 0H
		INC BX					;Di se resetea pero BX se incrementa
		MOV SI, 0H
		JMP VERTICAL

	FIN_VERTICAL:
	;FIN DE LAS COMPROBACIONES EN VERTICAL.
	;INICIO DIAGONAL HACIA DERECHA
	MOV FLAG_GANADORA, 0H
	MOV BX, 0H	; Utilizado para moverse en las columnas (0-7)
	MOV DI, 0H	; Utilizado para el contador de posiciones
	MOV SI, 0H	; Utilizado para moverse en las filas
	MOV CL, FILAS-3	; Veces que recorreremos las diagonales	
	MOV DL, FILAS-3	; Nos vamos a mover 3 por debajo de la primera casilla y 3 por la derecha
	MOV CH, FILAS	; Contador total de veces que vamos a mirar en la matriz
	
	DIAGONAL_DERECHA:
		CMP CH, 0H
		JE FIN_DIAGONAL
		DIAGONAL_DERECHA2:
				CMP CL, 0H
				JE SALTO_DIAGONAL
				MOV AL, JUGADOR_ACTUAL
				CMP MATRIZ[BX+SI], AL			;Comprobamos la casilla actual y la siguente hacia abajo a la derecha. Es decir, ACTUAL+ COLUMNAS+1
				JNE SIG1DD
					CALL SUMA_FLAG_GANADORA
				SIG1DD:
				CMP MATRIZ[BX+SI]+COLUMNAS+1, AL
				JNE SIG2DD
					CALL SUMA_FLAG_GANADORA
				SIG2DD:
				CMP MATRIZ[BX+SI]+COLUMNAS2+2, AL
				JNE SIG3DD
					CALL SUMA_FLAG_GANADORA
				SIG3DD:
				CMP MATRIZ[BX+SI]+COLUMNAS3+3, AL
				JNE SIG4DD
					CALL SUMA_FLAG_GANADORA
				SIG4DD:
				ADD SI, COLUMNAS+1				;Hay que incrementar SI con COLUNAS +1 porque cada uno de ellos es el siguiente a comprobar.
				DEC CL
				CMP FLAG_GANADORA, 4H
				JE GANADOR_ENCONTRADO_DIAGON
				MOV FLAG_GANADORA, 0H
				VUELTA_DIAGON: JMP DIAGONAL_DERECHA2
					GANADOR_ENCONTRADO_DIAGON:
						CMP JUGADOR_ACTUAL, 31H
						JE IMPRIME_GAN1_DIAGON
							MOV AH, 9H
							MOV DX, OFFSET GANADOR2
							INT 21H
							JMP SALIR_GANADOR
						IMPRIME_GAN1_DIAGON:
							MOV AH, 9H
							MOV DX, OFFSET GANADOR1
							INT 21H
							JMP SALIR_GANADOR

		SALTO_DIAGONAL:
		DEC DL					;Restamos 1 para iterar las que nos falten.
		MOV SI, 0H				;Vamos a comprobar por 2 sitios las diagonasles. Hacia abajo y hacia la derecha.
		DEC CH	
		CMP CH, 3H
		JE CAMBIO
		JL CAMBIO2
			MOV CL, DL
			ADD BX, COLUMNAS
			JMP VUELTA_DIAGONAL
		CAMBIO:
			MOV DL, CH	
			MOV CL, DL
			MOV BX, 0H
		CAMBIO2:				;CAMBIO2 Se ejecuta cuando se han comprobado las de abajo. Es decir de la casilla 00 a la columna 1 fila 4
			MOV CL, DL
			INC BX
		VUELTA_DIAGONAL:
			JMP DIAGONAL_DERECHA		
	FIN_DIAGONAL:
	MOV FLAG_GANADORA, 0H
	MOV BX, 0H	; Utilizado para moverse en las columnas (0-7)
	MOV DI, 0H	; Utilizado para el contador de posiciones
	MOV SI, 0H	; Utilizado para moverse en las filas
	MOV CL, FILAS-3	; Veces que recorreremos las diagonales	
	MOV DL, FILAS-3	; Nos vamos a mover 3 por debajo de la primera casilla y 3 por la derecha
	MOV CH, FILAS	; Contador total de veces que vamos a mirar en la matriz
	ADD BX, COLUMNAS-1
	DIAGONAL_IZQUIERDA:
		CMP CH, 0H
		JE FIN_DIAGONAL_IZQ
		DIAGONAL_IZQUIERDA2:
				CMP CL, 0H
				JE SALTO_DIAGONAL_IZQ
				MOV AL, JUGADOR_ACTUAL				;Para la izquiera comprobamos la casilla actual junto con las suvcesivas diagonales a la iaquierda. Es decir, ACTUAL+COLUMNAS-X siendo X la fila a comprobar
				CMP MATRIZ[BX+SI], AL
				JNE SIG1DI
					CALL SUMA_FLAG_GANADORA
				SIG1DI:
				CMP MATRIZ[BX+SI]+COLUMNAS-1, AL
				JNE SIG2DI
					CALL SUMA_FLAG_GANADORA
				SIG2DI:
				CMP MATRIZ[BX+SI]+COLUMNAS2-2, AL
				JNE SIG3DI
					CALL SUMA_FLAG_GANADORA
				SIG3DI:
				CMP MATRIZ[BX+SI]+COLUMNAS3-3, AL
				JNE SIG4DI
					CALL SUMA_FLAG_GANADORA
				SIG4DI:
				ADD SI, COLUMNAS-1
				DEC CL
				CMP FLAG_GANADORA, 4H
				JE GANADOR_ENCONTRADO_DIAGON_IZQ
				MOV FLAG_GANADORA, 0H
				VUELTA_DIAGON_IZQ: JMP DIAGONAL_IZQUIERDA2
					GANADOR_ENCONTRADO_DIAGON_IZQ:
						CMP JUGADOR_ACTUAL, 31H
						JE IMPRIME_GAN1_DIAGON_IZQ
							MOV AH, 9H
							MOV DX, OFFSET GANADOR2
							INT 21H
							JMP SALIR_GANADOR
						IMPRIME_GAN1_DIAGON_IZQ:
							MOV AH, 9H
							MOV DX, OFFSET GANADOR1
							INT 21H
							JMP SALIR_GANADOR

		SALTO_DIAGONAL_IZQ:
		DEC DL					;Restamos 1 para iterar las que nos falten.
		MOV SI, 0H
		DEC CH	
		CMP CH, 3H
		JE CAMBIO_IZQ
		JL CAMBIO2_IZQ
			MOV CL, DL
			ADD BX, COLUMNAS
			JMP VUELTA_DIAGONAL_IZQ
		CAMBIO_IZQ:
			MOV DL, CH
			MOV CL, DL
			MOV BX, 0H
		CAMBIO2_IZQ:
			MOV CL, DL		;El cambio2 se ejecuta por igual que en la derecha. primero vamos por abajo y luego a la izquierda.
			INC BX
		VUELTA_DIAGONAL_IZQ:
			JMP DIAGONAL_IZQUIERDA
	FIN_DIAGONAL_IZQ:	
	
	FINFUNCION:
	MOV AX, 0H
	POP DI SI DX CX BX DX
	RET
GANADOR ENDP


;___________________________________________________________________ 
; SUBRUTINA PARA MODIFICAR LA MATRIZ
; ENTRADA: AX la columna
;	   CX EL JUGADOR, ES DECIR EL JUGADOR 1 O EL 2
; SALIDA: BX 0 si se ha llevado correctamente o 1 si ha habido algun fallo (casilla ocupada o fuera de rango)
;__________________________________________________________________ 
MODIFICA_MATRIZ PROC
	PUSH AX DX CX SI
	MOV SI, INDICE_FILA
	MOV BX, AX
	CMP AX, 0H
	JL FALLO1
	CMP AX, COLUMNAS-1				;Si la casilla es superior al tamanio de la matriz, entonces error
	JG FALLO1	
	;Bucle de la gravedad de la posicion de la ficha
	BUCLE_COL:
		CMP MATRIZ[SI+BX], 30H			;Comprobamos que la fila indicada por Si esta vacia. Si lo esta insertamos en esa columna
		JE FIN_BUCLE_COL
		SUB SI, COLUMNAS
		CMP SI, 0H
		JL FALLO1
		JMP BUCLE_COL
	FIN_BUCLE_COL:
	CMP CX, 1H
	JE FICHA_JUGADOR1
	CMP CX, 2H
	JE FICHA_JUGADOR2
	JMP FIN_MODIF
	FICHA_JUGADOR1:
		MOV MATRIZ[SI+BX], 31H				;Si es el jugador 1, metemos en la matriz 1
		MOV BX, 0H
		JMP FIN_MODIF
	FICHA_JUGADOR2:
		MOV MATRIZ[SI+BX], 32H				;Si es el jugador 2, metemos en la matriz 2
		MOV BX, 0H
		JMP FIN_MODIF
	FALLO1:
		MOV BX, 1H
		MOV AH, 9H
		MOV DX, OFFSET CASILLA_INV				;Fallo es casilla invalida. Pide otra nueva.
		INT 21H
		
		MOV AH, 9H
		MOV DX, OFFSET FIN
		INT 21H
		
	FIN_MODIF:
	POP SI CX DX AX
	RET
MODIFICA_MATRIZ ENDP

;___________________________________________________________________ 
; SUBRUTINA INCREMENTAR LA FLAG DE GANADORA. INCREMENTARA EN 1 LA FLAG DE GANADOR
; ENTRADA: NINGUNA
; SALIDA: NINGUNA
;__________________________________________________________________ 
SUMA_FLAG_GANADORA PROC
	INC FLAG_GANADORA
	RET
SUMA_FLAG_GANADORA ENDP

;___________________________________________________________________ 
; SUBRUTINA SUSTITUTA DE 1CH
; ENTRADA: NINGUNA
; SALIDA: NINGUNA
;__________________________________________________________________ 
SUMADOR PROC
	PUSH DX AX
	INC CONTADOR
	MOV AX, TIEMPO_ESPERA	;Va sumando el contador con el tiempo total de espera. Si llega es que estamos en el limite.
	CMP CONTADOR, AX
	JL SAL_SUMADOR
		mov ah, 9h
		MOV DX, OFFSET FIN
		int 21h 
		mov ah, 9h
		MOV DX, OFFSET TIEMPO_SOBREPASADO
		int 21h
		MOV CONTADOR, 0H
		INC FLAG_LIMITE			;Cuando estemos en el limite del tiempo entonces subimos la flag para que la funcion llamada salte a tirada aleatoria.
		POP DX AX
		IRET
	SAL_SUMADOR:
	POP DX AX
	IRET
SUMADOR ENDP


;___________________________________________________________________ 
; SUBRUTINA QUE CALCULA LA COLUMNAS INTRODUCIDA POR EL JUGADOR.
; ENTRADA: NINGUNA
; SALIDA: AL, el numero de la columna a modificar
;__________________________________________________________________ 
LLAMADA PROC
	PUSH ES BX 
	MOV AX, 0H
	MOV ES, AX
	ESPERA_ACTIVA:
	MOV AH, 1H		;La ah con 1H comprueba si hay un caracter en el teclado. Si lo hay dejamos de esperar
	int 16H
	JNZ FIN_ESPERA	
	CMP FLAG_LIMITE, 1h	;En el caso de que no se haya puesto el numero en el buffer hay que comprobar si se ha cumplido el limite. Si se ha hecho se pone una ficha aleatoria.
	je LIMITE_LLEGADO
	JMP ESPERA_ACTIVA 
	LIMITE_LLEGADO:
	;Caso de limite de tiempo, buscamos una columna vacia y metemos ahi la ficha
	MOV BX, 0H ;Lo utilizamos para las columnas y SI para las filas
	MOV FLAG_LIMITE, 0h
	BUCLE_ALEATORIO:	
		CMP MATRIZ[BX], 30H	;Vamos buscandocolumna a columna la que este libre para meter la ficha
		JE FIN_BUCLE_ALEATORIO
		INC BX
		JMP BUCLE_ALEATORIO 
	FIN_BUCLE_ALEATORIO:
	MOV AL, BL
	POP BX ES
	RET
	FIN_ESPERA:
	;Caso de numero
	mov ax, 0h	;En el caso de que el usuario haya metido una tecla, la int 16 con ah 1 no la limpia del teclado, para ello hay que usar la 16h con ah 00. Limpiamos, obteniendo el valor.
	int 16H
	SUB AL, 31H	;Podriamos restar 30 pero al restar 31 en vez de empezar por 0 empezamos por 1
	POP BX ES
	RET
LLAMADA ENDP

;___________________________________________________________________ 
; SUBRUTINA QUE CALCULA SIAL MATRIZ YA ESTA LLENA
; ENTRADA: NINGUNA
; SALIDA: NINGUNA
;__________________________________________________________________ 
MATRIZ_LLENA PROC
	PUSH AX BX SI
	MOV AX, 0H
	MOV BX, 0H
	MOV SI, 0H
	
	COMPROBACION_LLENA:
		CMP MATRIZ[BX+SI], 30H			;Comprobamos casilla a casilla donde hay una casilla vacia. 30H= 0 en ASCII
		JE FUERA_MATRIZ_LLENA
		INC SI
		CMP SI, COLUMNAS
		JE SALTO_LLENA
		JMP COMPROBACION_LLENA
		SALTO_LLENA:
			mov si, 0h
			ADD BX, COLUMNAS
			CMP BX, COLUMNAS*FILAS			
			JE LLENA
			jmp COMPROBACION_LLENA
	LLENA:	;Si la matriz esta llena entonces el programa acaba. Restauramos la int 1ch y salimos
	POP SI BX AX
	MOV AX, 0	
	MOV ES, AX
	CLI
	MOV AX, WORD PTR OLDINT1C
	MOV ES:[DIR], AX
	MOV AX, WORD PTR OLDINT1C2
	MOV ES:[DIR+2], AX
	STI
	MOV AH, 9H
	MOV DX, OFFSET FIN
	INT 21H
		MOV AH, 9H
	MOV DX, OFFSET EMPATE
	INT 21H
	MOV AX, 4C00H
	INT 21H
	FUERA_MATRIZ_LLENA:
	POP SI BX AX
	RET
MATRIZ_LLENA ENDP

; FIN DEL SEGMENTO DE CODIGO
CODE ENDS
; FIN DEL PROGRAMA INDICANDO DONDE COMIENZA LA EJECUCION
END INICIO
