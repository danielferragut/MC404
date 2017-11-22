@							Trabalho 2
@	Nome:Daniel Pereira Ferragut	Nome:Gabriel Ryo Hioki
@	RA:169488						RA:172434
@
@ Ultima modificao: 15:31, 21 de novembro 2017
.org 0x0
.section .iv,"a"

_start:

interrupt_vector:
    b RESET_HANDLER
.org 0x08
	b SVC_HANDLER
.org 0x18
    b IRQ_HANDLER


@ Alocacao de memoria fica aqui
.data
CONTADOR: .skip 4    @ Variavel que vai acumular interrupcoes

IRQ_STACK: .skip 1024
IRQ_STACK_START: .skip 4

SVC_STACK: .skip 4096
SVC_STACK_START: .skip 4

USER_STACK: .skip 4096
USER_STACK_START: .skip 4

@ Um vetor de structs com seu counter, cada elemento tem 12 bytes
@ 4 bytes para ponteiro de funcao que precisa retornar e outros 4 para a informacao necessario
CALLBACK_COUNTER: .word 0
CALLBACK_ARRAY: .skip 96

@ Um vetor de structs com seu counter, cada elemento tem 8 bytes
@ 4 bytes para ponteiro de funcao que precisa retornar e outros 4 para a informacao necessario
ALARM_COUNTER: .word 0
ALARM_ARRAY: .skip 64

.text
.org 0x100

@Constantes usadas no sistema em geral
.set USER_CODE, 0x77812000
.set TIME_SZ,	200			@ Valor que o timer ira contar, suposto a testes e mudancas
.set MAX_CALLBACKS, 8
.set MAX_ALARMS, 8

@Constantes usadas no sistema em geral
RESET_HANDLER:

    @ Zera o contador
    ldr r2, =CONTADOR  @lembre-se de declarar esse contador em uma secao de dados!
    mov r0, #0
    str r0, [r2]

    @ Faz o registrador que aponta para a tabela de interrupções apontar para a tabela interrupt_vector
    ldr r0, =interrupt_vector
    mcr p15, 0, r0, c12, c0, 0

SET_GPT:

@Constantes para a configuracao do GPT
.set GPT_CR,	0x53FA0000
.set GPT_PR,	0x53FA0004
.set GPT_SR,	0x53FA0008
.set GPT_IR,	0x53FA000C
.set GPT_OCR1,	0x53FA0010

    @ Configuracao do General Purpose Timer(GPT)
    mov r0, #0x41
    ldr r1, =GPT_CR
    str r0, [r1]

    @ Zerar o prescaler
    mov r0, #0
    ldr r1, =GPT_PR
    str r0, [r1]

    @ Valor que ele vai contar
    ldr r0, =TIME_SZ
    ldr r1, =GPT_OCR1
    str r0, [r1]

    @ Habilitacao das interrupcoes do GPT
    mov r0, #1
    ldr r1, =GPT_IR
    str r0, [r1]

    @ Configuracao do GPIO
    SET_GPIO:
    .set GPIO_BASE,			0x53F84000
    .set GPIO_DR,			0x0
    .set GPIO_GDIR,			0x4
    .set GPIO_PSR,			0x8
    .set GPIO_GDIR_MASK,	0xFFFC003E
    .set GPIO_DR_MASK,		0x02040000

    ldr r1, =GPIO_BASE

    @ Coloca as definicoes de entrada e saida no registrador GDIR
    ldr r0, =GPIO_GDIR_MASK @Mascara com as entradas corretas
    str r0, [r1, #GPIO_GDIR]

    ldr r0, =GPIO_DR_MASK
    str r0, [r1, #GPIO_DR]

    @ Muda pra supervisor
    @msr CPSR_c, #0x13

    SET_TZIC:
    @ Constantes para os enderecos do TZIC
    .set TZIC_BASE,             0x0FFFC000
    .set TZIC_INTCTRL,          0x0
    .set TZIC_INTSEC1,          0x84
    .set TZIC_ENSET1,           0x104
    .set TZIC_PRIOMASK,         0xC
    .set TZIC_PRIORITY9,        0x424

    @ Liga o controlador de interrupcoes
    @ R1 <= TZIC_BASE

    ldr	r1, =TZIC_BASE

    @ Configura interrupcao 39 do GPT como nao segura
    mov	r0, #(1 << 7)
    str	r0, [r1, #TZIC_INTSEC1]

    @ Habilita interrupcao 39 (GPT)
    @ reg1 bit 7 (gpt)

    mov	r0, #(1 << 7)
    str	r0, [r1, #TZIC_ENSET1]

    @ Configure interrupt39 priority as 1
    @ reg9, byte 3

    ldr r0, [r1, #TZIC_PRIORITY9]
    bic r0, r0, #0xFF000000
    mov r2, #1
    orr r0, r0, r2, lsl #24
    str r0, [r1, #TZIC_PRIORITY9]

    @ Configure PRIOMASK as 0
    eor r0, r0, r0
    str r0, [r1, #TZIC_PRIOMASK]

    @ Habilita o controlador de interrupcoes
    mov	r0, #1
    str	r0, [r1, #TZIC_INTCTRL]

    @ Trecho de codigo que ira mudar para o codigo do usuario
    ldr r0, =USER_CODE
    mrs r1,CPSR
    bic r1, r1, #0b10011111
    orr r1, r1, #0b00010000             @TODO: Ativar interrupcoes IRQ
    msr CPSR, r1
    
    @ Ajusta a pilha do usuario
    ldr sp, =USER_STACK_START
    bx r0

@Handler de Supervisor Calls
SVC_HANDLER:
	@ Primeiro se ajusta a pilha para o endereco de SVC_STACK_START
	ldr sp, =SVC_STACK_START
	push {r7, lr}
	@SVC vai receber um codigo em R7, indicando o que esta sendo pedido
	@Codigo: 16 - read_sonar
	@Codigo: 17 - register_proximity_callback
	@Codigo: 18 - set_motor_speed
	@Codigo: 19 - set_motors_speed
	@Codigo: 20 - get_time
	@Codigo: 21 - set_time
	@Codigo: 22 - set_alarm
	@Codigo: 23 - change_back_to_IRQ_mode
	cmp r7, #16
	bleq read_sonar

	cmp r7, #17
	bleq register_proximity_callback

	cmp r7, #18
	bleq set_motor_speed

	cmp r7, #19
	bleq set_motors_speed

	cmp r7, #20
	bleq get_time

	cmp r7, #21
	bleq set_time

	cmp r7, #22
	bleq set_alarm

	cmp r7, #23
	bleq change_back_to_IRQ_mode

    @Retorna pro codigo do usuario
    pop {r7, lr}
	movs pc, lr

@read_sonar
@ Parametros:
@	R0: Identificador do sonar (valores válidos: 0 a 15).
@
@ Retorno:
@R0: Valor obtido na leitura dos sonares; -1 caso o identificador do sonar seja inválido.
read_sonar:
	push {r4,lr}

    cmp r0, #15
	movhi r0, #-1
	pophi {r4,pc}				@Se o sonar for maior que 15, ele é inválido, portanto, erro

	ldr r1, =GPIO_BASE
	ldr r4, [r1, #GPIO_DR]

	bic r4, r4, #0b111110       @ Zera o sonar_mux para colocar o valor desejado e zera o trigger.
    add r4, r4, r0, lsl #2

	str r4, [r1, #GPIO_DR]		@ Escreve em DR o sonar e o trigger

	@ Primeira espera do trigger.
    mov r2, #0
read_sonar_loop_1:
    add r2, r2, #1
    cmp r2, #200
    bne read_sonar_loop_1

    @ Apos 10 ms aprox, setar o trigger para 1.
	orr r4, r4, #0b10			@ Seta o TRIGGER para 1.
	str r4, [r1, #GPIO_DR]		@ Escreve em DR o sonar e o trigger

	@ Segunda espera do trigger.
	mov r2, #0
read_sonar_loop_2:
    add r2, r2, #1
    cmp r2, #200
    bne read_sonar_loop_2

	@ Apos 10 ms aprox, setar o trigger para 0.
	bic r4, r4, #0b10       	@ Zera o trigger.
	str r4, [r1, #GPIO_DR]		@ Escreve em DR o sonar e o trigger

@ Laco(for) para esperar os sonares atualizarem(Esperar FLAG ficar = 1).
read_sonar_wait:
	mov r2, #0
read_sonar_loop_3:
	add r2, r2, #1
	cmp r2, #200
	blt read_sonar_loop_3

	@ Carrega e verifica o valor da FLAG(Le a flag do DR pois senao ela nao muda)
	ldr r4, [r1, #GPIO_DR]
	and r0, r4, #1
	cmp r0, #1
	bne read_sonar_wait			@ Se for diferente de 0, volta ao laco para esperar.
	ldr r0, [r1, #GPIO_PSR]


    @ As operacoes a seguir fazem com que so SONAR_DATA[0 - 11] fique em r0 (comecando no bit 0)
    mov r0, r0, lsl #14
    mov r0, r0, lsr #20
read_sonar_end:
	pop {r4, pc}

@register_proximity_callback
@ Parametros:
@	R0: Identificador do sonar (valores válidos: 0 a 15).
@	R1: Limiar de distância.
@	R2: ponteiro para função a ser chamada na ocorrência do alarme.
@
@Retorno:
@R0: -1 caso o número de callbacks máximo ativo no sistema seja maior do que MAX_CALLBACKS.
@	 -2 caso o identificador do sonar seja inválido.
@	 Caso contrário retorna 0.
register_proximity_callback:
	push {r4-r7,lr}
	mov r4, r0					@Coloca identificador do sonar em R4
	mov r5, r1					@Limiar de distancia desejado em R5
	mov r6, r2					@Coloca o ponteiro da funcao que é pra retornar em R6

	@Verifica se o id do sonar existe(entre 0 e 15)
	cmp r0, #15
	movhi r0, #-2
	pophi {r4-r7, pc}

	@Verifica se ha espaco para mais um callback
	ldr r2, =CALLBACK_COUNTER
	ldr r1, =MAX_CALLBACKS
	ldr r0, [r2]
	cmp r1, r0
	moveq r0, #-1				@Se o numero for igual, ele nao pode *adicionar* mais callbacks, portanto erro
	popeq {r4-r7, pc}

	@Colocar novo callback no vetor de structs de callbacks
	mov r7, r0					@R0 possuia o valor de CALLBACK_COUNTER, agora tambem R7 o contém
	ldr r1, =CALLBACK_ARRAY		@Carrega o comeco do vetor de structs em R1
	@TODO: Talvez desse modo seja melhor.
	@ mov r0, r0, lsl #3			@Coloca R0 em 4 bytes atras do ultimo elemento da struct
	@ add r0, r0, #4				@Complementa esses 4 bytes, chegando no final do array
	mov r0, #12
	mul r0, r7, r0
	str r4, [r1, r0]			@Coloca o identificador de sonar na struct
	add r0, r0, #4
	str r5, [r1, r0]			@Armazena o limiar de distancia no meio da struct
	add r0, r0, #4
	str r6, [r1, r0]			@Armazena o ponteiro da funcao que é pra retornar no fim da função

	add r7, r7, #1				@Apos a adicao do novo elemento no vetor, o CALLBACK_COUNTER sobe
	str r7, [r2]				@Atualiza CALLBACK_COUNTER
	mov r0, #0					@Operacao feita com sucesso, retorna R0=0
	pop {r4-r7,pc}
@set_motor_speed
@ Parametros:
@	R0: Identificador do motor (valores válidos 0 ou 1).
@	R1: Velocidade.
@
@ Retorna:
@R0: -1 caso o identificador do motor seja inválido
@	 -2 caso a velocidade seja inválida
@	  0 caso Ok.
set_motor_speed:
	push {r4,r5,lr}
    mov r4, r0
    mov r5, r1

    @ Checar se a velocidade eh valida
    @ Como o parametro no LoCo e BiCo eh unsigned char, o valor nunca vai ser negativo
    cmp r5, #0b111111
    movhi r0, #-2
	pophi {r4,r5,pc}
    @ Se nao pular, velocidade eh valida

    @ Trecho de codigo que ve qual motor tem velocidade alterada
    cmp r4, #0
    beq SVC_motor_speed_0
    cmp r4, #1
    beq SVC_motor_speed_1
    @ Caso nenhum dos dois, motor invalido
    mov r0, #-1
	pop {r4,r5,pc}
@ Se entrar nesse rotulo, ira mudar os bits [19,24] para a velocidade e o bit 18 para escrever
SVC_motor_speed_0:

    @ Velocidade sendo escrita nos bits
    ldr r1, =GPIO_BASE
    ldr r2, [r1, #GPIO_DR]   @ Pega o DR atual
    ldr r3, =0x01FC0000      @ Mascara para zerar os bits [18,24]
    bic r0, r2, r3           @ Zera os bits de DR nas posicoes [18,24]
    mov r3, r5, lsl #19      @ Move o primeiro bit da velocidade para o bit 19
    orr r0, r0, r3           @ Escreve a velocidade em DR
    str r0, [r1, #GPIO_DR]   @ Escreve ele em DR
	b SVC_motor_speed_fim
    @TODO:Write esta como 0, talvez voltar pra 1?

@Se entrar nesse rotulo, ira mudar os bits [26,31] para a velocidade e o bit 25
SVC_motor_speed_1:
    ldr r1, =GPIO_BASE
    ldr r2, [r1, #GPIO_DR]   @ Pega o DR atual
    ldr r3, =0xFE000000      @ Mascara para zerar os bits [25,31]
    bic r0, r2, r3           @ Zera os bits de DR nas posicoes [25,31]
    mov r3, r5, lsl #26      @ Move o primeiro bit da velocidade para o bit 26
    orr r0, r0, r3           @ Escreve a velocidade em DR
    str r0, [r1, #GPIO_DR]   @ Escreve ele em DR
	@TODO: Wrote como 0 ou 1

SVC_motor_speed_fim:
	mov r0, #0
	pop {r4,r5,pc}

@set_motors_speed
@ Parametros:
@R0: Velocidade para o motor 0.
@R1: Velocidade para o motor 1.
@
@ Retorna:
@R0: -1 caso a velocidade para o motor 0 seja inválida,
@	 -2 caso a velocidade para o motor 1 seja inválida,
@	  0 caso Ok.
set_motors_speed:
	push {r4,r5,lr}
    mov r4, r0
    mov r5, r1

	cmp r4, #0b111111
    movhi r0, #-1
	pophi {r4,r5,pc}

	cmp r5, #0b111111
    movhi r0, #-2
	pophi {r4,r5,pc}

	ldr r1, =GPIO_BASE
    ldr r2, [r1, #GPIO_DR]   @ Pega o DR atual
    ldr r3, =0xFFFC0000      @ Mascara para zerar os bits [18,31]
    bic r0, r2, r3           @ Zera os bits de DR nas posicoes [18,31]
    mov r3, r4, lsl #19      @ Move o primeiro bit da velocidade para o bit 19
    orr r0, r0, r3           @ Escreve a velocidade do motor0 em DR
	mov r3, r5, lsl #26      @ Move o primeiro bit da velocidade para o bit 26
    orr r0, r0, r3           @ Escreve a velocidade do motor1 em DR
    str r0, [r1, #GPIO_DR]   @ Escreve ele em DR

    @TODO: Wrote como 0 ou 1
	mov r0, #0
	pop {r4,r5,pc}

@get_time
@ Parametros:
@	R0: Ponteiro de unsigned int
get_time:
	push {lr}
    ldr r1, =CONTADOR
    ldr r2, [r1]
	str r2, [r0]
	pop {pc}

@ set_time
@ Parametros:
@	R0: Tempo a ser setado
set_time:
	push {lr}
    ldr r1, =CONTADOR
    str r0, [r1]
	pop {pc}

@ set_alarm
@ Parametros:
@	R0: ponteiro para função a ser chamada na ocorrência do alarme.
@	R1: tempo do sistema.
@
@ Retorno:
@R0: -1 caso o número de alarmes máximo ativo no sistema seja maior do que MAX_ALARMS.
@	 -2 caso o tempo seja menor do que o tempo atual do sistema.
@	  0 caso contrário.
set_alarm:
	push {r4-r6, lr}
	mov r4, r0					@Ponteiro da funcao em R4
	mov r5, r1					@Tempo do sistema desejado em R5

	@Verifica se o tempo do sistema é maior que o pedido
	ldr r2, =CONTADOR			@Endero de contador vai pra R2
	ldr r0, [r2]				@Coloca o valor de contador em R0
	cmp r0, r5
	movlo r0, #-2				@Se o tempo pedido é menor que o do sistema ele retorna.
	poplo {r4-r6, pc}

	@Verifica se ha espaco para mais um alarme
	ldr r2, =ALARM_COUNTER
	ldr r1, =MAX_ALARMS
	ldr r0, [r2]
	cmp r1, r0
	moveq r0, #-1
	popeq {r4-r6, pc}

	@Colocar novo alarme no vetor de structs de alarm
	@R0 possui ALARM_COUNTER
	ldr r1, =ALARM_ARRAY		@Carrega o comeco do vetor de structs em R1
	mov r6, r0					@R0 contém ALARM_COUNTER, agora R6 também
	mov r0, r0, lsl #3			@Coloca em R0 a posicao do ponteiro armazenado
	str r4, [r1, r0]			@Coloca o ponteiro na struct
	add r0, r0, #4				@Avanca 4 Bytes da posicao
	str r5, [r1, r0]			@Armazena o tempo do sistema no final da struct

	add r6, r6, #1				@Apos a adicao do novo elemento no vetor, o ALARM_COUNTER sobe
	str r6, [r2]				@Atualiza o valor de ALARM_COUNTER
	mov r0, #0					@Operacao feita com sucesso, retorna R0=0
	pop {r4-r6, pc}

@change_back_to_IRQ_mode:
@ Paramentros:
@	R0: Endereco da posicao que quer voltar
change_back_to_IRQ_mode:
	@O código esta no modo supervisor, para mudar para o modo IRQ, precisa restaurar a pilha pro modo original
	@Apos o pop, r0 tera o endereco de memoria do IRQ
	pop {r7, lr}                @Como esta saindo do modo supervisor, precisa dar pop das coisas pushadas na pilha
	msr CPSR_c, #0x12			@Coloca no modo IRQ
	bx r0                       @Volta pro codigo em IRQ

IRQ_HANDLER:
    @Move a pilha para a memoria alocada
    ldr sp, =IRQ_STACK_START

    push {r0-r12, lr}
    @Sinalizacao para GPT que a interrupcao foi tratada
	@TODO: Isso daqui eh vital pra alguma coisa, descobrir o que
    mov r0, #1
    ldr r1, =GPT_SR
    str r0, [r1]

    @Acrescimo de um ao contador
    ldr r1, =CONTADOR
    ldr r0, [r1]
    add r0, r0, #1
    str r0, [r1]

	@Verificar se algum alarme ativou
	mov r4, r0					@R4 tera o valor do tempo atual do sistema(CONTADOR)
	ldr r5, =ALARM_ARRAY		@R5 tera o valor do endereco de array
	ldr r0, =ALARM_COUNTER
	ldr r6, [r0]				@R6 tera o contador de elementos do array
	mov r7, #0					@R0 sera a variavel de inducao do for
IRQ_alarm_for_start:
	cmp r7, r6
	beq IRQ_alarm_for_end
	mov r1, r7, lsl #3			@Coloca em r1 o numero de bytes que precisa pular pra chegar no ponteiro do elemento
	add r2, r1, #4				@Coloca em r2 o numero de bytes para chegar no tempo do sistema do elemento
	ldr r3, [r5, r2]			@Carrega em r3 o tempo do sistema necessario
	cmp r3, r4					@Compara o tempo do elemento com o tempo atual do sistema
	bne IRQ_alarm_for_continue	@Senao for igual, continua o for

	@Se o codigo chegar aqui, achou um alarme legitimo
	@TODO: Garantir que nao ha interrupcoes no meio de outra
	ldr r0, [r5, r1]			@Carrega valor do ponteiro da funcao que eh pra retornar em r7
    msr CPSR_c, #0x10			@Muda pra usuario       @TODO: interrupcoes?
	blx r0

    push {r7}
    mov r7, #23					@R7 tera codigo do register_proximity_call
	add r0, pc, #8				@R0 tera o endereço depois de SVC 0x0, mudando de User pra IRQ
	svc 0x0
    pop {r7}

	@Parte que remove o alarme
    sub r6, r6, #1
	sub r2, r6, r7                  @R2 Vai ter a quantidade de elementos a serem ajustados
    mov r0, #2
    mul r2, r0, r2                  @Quantidade de palavras(4 bytes) presentes nos elementos restantes
	mov r8, r7, lsl #3
    add r9, r8, #8                  @Vai pro proximo
    mov r0, #0                      @R0 sera a variavel de inducao do proximo for
@For que ira de 4 a bytes sobreescrevendo o elemento a ser eliminado, e arrumando o array
IRQ_remove_alarm_loop:
	cmp r0, r2
	beq IRQ_remove_alarm_loop_fim

	ldr r1, [r5, r9]                @R9 tem a primeira informacao o proximo elemento, sendo R5 o comeco do array
	str r1, [r5, r8]                @
	add r8, r8, #4
	add r9, r9, #4

	add r0, r0, #1
	b IRQ_remove_alarm_loop
IRQ_remove_alarm_loop_fim:
	ldr r0, =ALARM_COUNTER
	str r6, [r0]
    sub r7, r7, #1                  @Um elemento foi tirado do array, variavel de inducao precisa ser ajustada

IRQ_alarm_for_continue:
	add r7, r7 , #1
	b IRQ_alarm_for_start
IRQ_alarm_for_end:

	@Verificar se algum callback foi ativado
	ldr r5, =CALLBACK_ARRAY			@R5 tera o valor do endereco de array
	ldr r0, =CALLBACK_COUNTER
	ldr r6, [r0]					@R6 tera o contador de elementos do array
	mov r7, #0						@R7 sera a variavel de inducao do for
IRQ_callback_for_start:
	cmp r7, r6
	beq IRQ_callback_for_end

	mov r0, #12
	mul r8, r7, r0
	add r9, r8, #4					@R9 tera o endereco do limiar do elemento
	add r10, r9, #4					@R10 tera o endereco do ponteiro da funcao que é pra ser retornada

	ldr r0, [r5, r8]				@Carrega em R0 o sonar que ira ser analisado
	bl read_sonar
	ldr r1, [r5, r9]				@Carrega em R1 o valor do limiar
	cmp r0, r1
	bne IRQ_callback_for_continue	@Senao for igual, continua o for

	@Se o codigo chegar aqui, achou um callback legitimo
	@TODO: Tirar callback do array, consertar array para que o elemento retirado nao interfira
	ldr r0, [r5, r10]				@Carrega valor do ponteiro da funcao que eh pra retornar em R0
    msr CPSR_c, #0x10				@Muda pra usuario
	blx r0

    push {r7}
	mov r7, #23						@R7 tera codigo do register_proximity_call
	add r0, pc, #8					@R0 tera o endereço depois de SVC 0x0, mudando de User pra IRQ
	svc 0x0
	pop {r7}

	@Parte que remove o callback
    sub r6, r6, #1                  @Tira um elemento da quantidade de callbacks
	sub r2, r6, r7                  @Quantidade de elementos na frente do elemento a ser eliminado
    mov r0, #3                      @Cada elemento tem 3 palavras de 4 bytes
    mul r2, r0, r2                  @Quantidade de palavras(4 bytes) presentes nos elementos restantes
    mov r0, #12
	mul r8, r7, r0                  @Vai pro elemento atual a ser eliminado
	add r9, r8, r0                  @Vai pro proximo
    mov r0, #0                      @R0 sera a variavel de inducao do proximo for
@For que ira de 4 a bytes sobreescrevendo o elemento a ser eliminado, e arrumando o array
IRQ_remove_callback_loop:
	cmp r0, r2
	beq IRQ_remove_callback_loop_fim

    @Copia 4 bytes de um dado de um elemento para 12 bytes atras no array
	ldr r1, [r5, r9]
	str r1, [r5, r8]
	add r8, r8, #4
	add r9, r9, #4

	add r0, r0, #1
	b IRQ_remove_callback_loop
IRQ_remove_callback_loop_fim:

	ldr r0, =CALLBACK_COUNTER
	str r6, [r0]
    sub r7, r7, #1                   @Como um elemento foi retirado do array, variavel de inducao precisa ser ajustada

IRQ_callback_for_continue:
	add r7, r7 , #1
	b IRQ_callback_for_start
IRQ_callback_for_end:

    pop {r0-r12, lr}
    sub lr, lr, #4
    movs pc, lr
