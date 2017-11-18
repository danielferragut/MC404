@							Trabalho 2
@	Nome:Daniel Pereira Ferragut	Nome:Gabriel Ryo Hioki
@	RA:169488						RA:172434
@
@ Ultima modificao: 16:55, 15 de novembro 2017

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
@TODO: O professor mudou o endereco de memoria pra 12000, nao ha problema de memoria
.data
CONTADOR: .skip 4    @ Variavel que vai acumular interrupcoes

IRQ_STACK: .skip 1024
IRQ_STACK_START: .skip 4

SVC_STACK: .skip 4096
SVC_STACK_START: .skip 4

USER_STACK: .skip 4096
USER_STACK_START: .skip 4

@TODO: Verificar se valores estao corretos
@ Dois vetores de structs com seus counters, cada elemento tem 8 bytes
@ 4 bytes para ponteiro de funcao que precisa retornar e outros 4 para a informacao necessario
CALLBACK_COUNTER: .word 0
CALLBACK_ARRAY: .skip 64

ALARM_COUNTER: .word 0
ALARM_ARRAY: .skip 64

.text
.org 0x100
@Constantes usadas no sistema em geral
.set USER_CODE, 0x77812000
.set TIME_SZ,	200			@ Valor que o timer ira contar, suposto a testes e mudancas
.set MAX_CALLBACKS, 8
.set MAX_ALARMS, 8

@Constantes para a configuracao do GPT
.set GPT_CR,	0x53FA0000
.set GPT_PR,	0x53FA0004
.set GPT_SR,	0x53FA0008
.set GPT_IR,	0x53FA000C
.set GPT_OCR1,	0x53FA0010

RESET_HANDLER:

    @ Zera o contador
    ldr r2, =CONTADOR  @lembre-se de declarar esse contador em uma secao de dados!
    mov r0, #0
    str r0, [r2]

    @ Faz o registrador que aponta para a tabela de interrupções apontar para a tabela interrupt_vector
    ldr r0, =interrupt_vector
    mcr p15, 0, r0, c12, c0, 0

    SET_GPT:
    @ Configuracao do General Purpose Timer(GPT)
    mov r0, #0x41
    ldr r1, =GPT_CR
    str r0, [r1]

    @ Zerar o prescaler
    mov r0, #0
    ldr r1, =GPT_PR
    str r0, [r1]

    @ Valor que ele vai contar
    ldr r0,=TIME_SZ
    ldr r0, [r0]
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
    msr CPSR_c, #0x13

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
    msr CPSR_c, #0x10
    @ Ajusta a pilha do usuario
    ldr sp, =USER_STACK_START
    bx r0

@Handler de Supervisor Calls
SVC_HANDLER:
	@ Primeiro se ajusta a pilha para o endereco de SVC_STACK_START
	ldr sp, =SVC_STACK_START
	@TODO: Ver quais registradores usou e tirar os que nao usardido
	push {r0-r12}
	@SVC vai receber um codigo em R7, indicando o que esta sendo pedido
	@Codigo: 16 - read_sonar
	@Codigo: 17 - register_proximity_callback
	@Codigo: 18 - set_motor_speed
	@Codigo: 19 - set_motors_speed
	@Codigo: 20 - get_time
	@Codigo: 21 - set_time
	@Codigo: 22 - set_alarm
	cmp r7, #16
	beq read_sonar

	cmp r7, #17
	beq register_proximity_callback

	cmp r7, #18
	beq set_motor_speed

	cmp r7, #19
	beq set_motors_speed

	cmp r7, #20
	beq get_time

	cmp r7, #21
	beq set_time

	cmp r7, #22
	beq set_alarm

	@TODO: If codigo desconhecido, erro talvez?

@read_sonar
@ Parametros:
@	R0: Identificador do sonar (valores válidos: 0 a 15).
@
@ Retorno:
@R0: Valor obtido na leitura dos sonares; -1 caso o identificador do sonar seja inválido.
read_sonar:
    cmp r0, #15
	bhi	read_sonar_error		@ So ha 16 sonares no Uoli, se o numero for maior que 15, sonar invalido
	ldr r1, =GPIO_BASE
	ldr r4, [r1, #GPIO_DR]

	bic r4, r4, #0b111100       @ Zera o sonar_mux para colocar o valor desejado.
    add r4, r4, r0, lsl #2
	orr r4, r4, #0b10			@ Seta o TRIGGER para 1.

	str r4, [r1, #GPIO_DR]		@ Escreve em DR o sonar e o trigger

    @ O trigger fica com 1 por 10 ms aprox, e dai eh mudado pra zero para que uma leitura do sonar seja feita
read_sonar_10_ms:
    mov r2, #0
read_sonar_10_ms_loop:
    add r2, r2, #1
    cmp r2, #200
    bne read_sonar_10_ms_loop

    @ Apos 10 ms aprox, o trigger volta pra zero
    ldr r4, [r1, #GPIO_DR]
	bic r4, r4, #0b10			@ Seta o TRIGGER para 0.
	str r4, [r1, #GPIO_DR]		@ Escreve em DR o sonar e o trigger


@ Laco(for) para esperar os sonares atualizarem.
read_sonar_wait:
	mov r2, #0
read_sonar_loop:
	add r2, r2, #1
	cmp r2, #200
	blt read_sonar_loop

	@ Carrega e verifica o valor da FLAG
	ldr r0, [r1, #GPIO_PSR]
	and r0, r0, #1
	cmp r0, #1
	bne read_sonar_wait			@ Se for diferente de 0, volta ao laco para esperar.

	ldr r0, [r1, #GPIO_PSR]		@ Carrega o valor atualizado em r0
	mov r4, r0

    @ As operacoes a seguir fazem com que so SONAR_DATA[0 - 11] fique em r0 (comecando no bit 0)
    mov r0, r0, lsl #14
    mov r0, r0, lsr #20

	b read_sonar_end

read_sonar_error:
	mov r0, #-1

read_sonar_end:
	b SVC_fim

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
	mov r4, r0					@Coloca identifador do sonar em R4
	mov r5, r1					@Limiar de distancia desejado em R5
	mov r6, r

	@Verifica se o tempo do sistema é maior que o pedido
	ldr r2, =CONTADOR			@Endero de contador vai pra R2
	ldr r0, [r2]				@Coloca o valor de contador em R0
	cmp r0, r5
	movhi r0, #-2
	bhi SVC_fim
	
	@Verifica se ha espaco para mais um alarme
	ldr r2, =ALARM_COUNTER
	ldr r3, =MAX_ALARMS
	ldr r0, [r2]
	ldr r1, [r3]
	cmp r1, r0
	moveq r0, #-1
	beq SVC_fim


	@Colocar novo alarme no vetor de structs de alarm
	@R0 possui ALARM_COUNTER
	ldr r1, =ALARM_ARRAY		@Carrega o comeco do vetor de structs em R1
	str r4, [r1, r0, lsl #3]	@Coloca o ponteiro na struct
	mov r4, r0					@R4 nao sera mais usado como ponteiro, agora eh ALARM_COUNTER
	mov r0, r0, lsl #3			@Coloca em R0 a posicao do ponteiro armazenado
	add r0, r0, #4				@Avanca 4 Bytes da posicao
	str r5, [r1, r0]			@Armazena o tempo do sistema no final da struct
	
	add r4, r4, #1				@Apos a adicao do novo elemento no vetor, o ALARM_COUNTER sobe
	mov r0, #0					@Operacao feita com sucesso, retorna R0=0	
	b SVC_fim
	b SVC_fim

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
    mov r4, r0
    mov r5, r1

    @ Checar se a velocidade eh valida
    @ Como o parametro no LoCo e BiCo eh unsigned char, o valor nunca vai ser negativo
    cmp r4, #0b111111
    movhi r0, #-2
    bhi SVC_fim
    @ Se nao pular, velocidade eh valida

    @ Trecho de codigo que ve qual motor tem velocidade alterada
    cmp r5, #0
    beq SVC_motor_speed_0
    cmp r5, #1
    beq SVC_motor_speed_1
    @ Caso nenhum dos dois, motor invalido
    mov r0, #-1
    b SVC_fim

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
	b SVC_motor_speed_fim
	@TODO: Wrote como 0 ou 1

SVC_motor_speed_fim:
	mov r0, #0
	b SVC_fim

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
    mov r4, r0
    mov r5, r1

    @Verifica as velocidades do motor 0 e 1
    cmp r4, #0b111111
    movhi r0, #-1
    bhi SVC_fim
    cmp r5, #0b111111
    movhi r1, #-2
    bhi SVC_fim

    @ Velocidade sendo escrita nos bits
    ldr r1, =GPIO_BASE
    ldr r2, [r1, #GPIO_DR]   @ Pega o DR atual
    ldr r3, =0x01FC0000      @ Mascara para zerar os bits [18,24]
    bic r0, r2, r3           @ Zera os bits de DR nas posicoes [18,24]
    mov r3, r4, lsl #19      @ Move o primeiro bit da velocidade para o bit 19
    orr r0, r0, r3           @ Escreve a velocidade em DR
    str r0, [r1, #GPIO_DR]   @ Escreve ele em DR
    @TODO:Write esta como 0, talvez voltar pra 1?

    ldr r2, [r1, #GPIO_DR]   @ Pega o DR atual
    ldr r3, =0xFE000000      @ Mascara para zerar os bits [25,31]
    bic r0, r2, r3           @ Zera os bits de DR nas posicoes [25,31]
    mov r3, r5, lsl #26      @ Move o primeiro bit da velocidade para o bit 26
    orr r0, r0, r3           @ Escreve a velocidade em DR
    str r0, [r1, #GPIO_DR]   @ Escreve ele em DR

    @TODO: Wrote como 0 ou 1
	mov r0, #0
	b SVC_fim

@get_time
@ Retorna:
@R0: o tempo do sistema
get_time:
    ldr r1, =CONTADOR
    ldr r0, [r1]
	b SVC_fim

@ set_time
@ Parametros:
@	R0: Tempo a ser setado
set_time:
    ldr r1, =CONTADOR
    str r0, [r1]
	b SVC_fim

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
	mov r4, r0					@Ponteiro da funcao em R4
	mov r5, r1					@Tempo do sistema desejado em R5

	@Verifica se o tempo do sistema é maior que o pedido
	ldr r2, =CONTADOR			@Endero de contador vai pra R2
	ldr r0, [r2]				@Coloca o valor de contador em R0
	cmp r0, r5
	movhi r0, #-2
	bhi SVC_fim
	
	@Verifica se ha espaco para mais um alarme
	ldr r2, =ALARM_COUNTER
	ldr r3, =MAX_ALARMS
	ldr r0, [r2]
	ldr r1, [r3]
	cmp r1, r0
	moveq r0, #-1
	beq SVC_fim


	@Colocar novo alarme no vetor de structs de alarm
	@R0 possui ALARM_COUNTER
	ldr r1, =ALARM_ARRAY		@Carrega o comeco do vetor de structs em R1
	str r4, [r1, r0, lsl #3]	@Coloca o ponteiro na struct
	mov r4, r0					@R4 nao sera mais usado como ponteiro, agora eh ALARM_COUNTER
	mov r0, r0, lsl #3			@Coloca em R0 a posicao do ponteiro armazenado
	add r0, r0, #4				@Avanca 4 Bytes da posicao
	str r5, [r1, r0]			@Armazena o tempo do sistema no final da struct
	
	add r4, r4, #1				@Apos a adicao do novo elemento no vetor, o ALARM_COUNTER sobe
	mov r0, #0					@Operacao feita com sucesso, retorna R0=0	
	b SVC_fim

	@Voltar para o estado original do codigo
	@TODO: Ver quais registradores usou
SVC_fim:
    @Retorna pro codigo do usuario
	pop {r0-r12}
	movs pc, lr

IRQ_HANDLER:
    @Move a pilha para a memoria alocada
    ldr sp, =IRQ_STACK_START

    push {r0-r12}
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
	mov r4, r0					@R4 tera o valor do tempo do sistema(CONTADOR)
	ldr r5, =ALARM_ARRAY		@R5 tera o valor do endereco de array
	ldr r0, =ALARM_COUNTER		
	ldr r6, [r0]				@R6 tera o contador de elementos do array
	mov r0, #0					@R0 sera a variavel de inducao do for
IRQ_alarm_for_start:
	cmp r0, r6
	beq IRQ_alarm_for_end
	mov r1, r0, lsl #3			@Coloca em r1 o numero de bytes que precisa pular pra chegar no ponteiro do elemento
	add r2, r1, #4				@Coloca em r2 o numero de bytes para chegar no tempo do sistema do elemento
	ldr r3, [r5, r2]			@Carrega em r3 o tempo do sistema necessario
	cmp r3, r5					@Compara o tempo do elemento com o tempo atual do sistema
	bne IRQ_alarm_for_continue	@Senao for igual, continua o for

	@Se o codigo chegar aqui, achou um alarme legitimo
	@TODO: Tirar alarme do array, consertar array para que o elemento retirado nao interfira
	ldr r7, [r5, r1]			@Carrega valor do ponteiro da funcao que eh pra retornar em r7

	@TODO: Processo delicado, precisamos voltar pra funcao do usuario
	@TODO: Para voltar pro usuario precisa mudar o modo pra usuario
	@TODO: Ou seja, no momento que mudar nao tem mais volta, nao vai dar pra mexer com coisas do S.O
	@TODO: Quando voltar pra funcao do usario, um dia a funcao vai acabar e no final vai ter um "mov pc, lr"
	@TODO: Esse lr, vai voltar aqui ou vai voltar pro user?
	@TODO: Acho que no momento que restaura o CPSR, o lr volta pro normal
	@TODO: Entao ele volta pro user, talvez?

	@TODO: Vou fazer no jeito mais head-on, talvez estea errado
	movs pc, r7

IRQ_alarm_for_contine:
	add r0, r0 , #1
IRQ_alarm_for_end:

    sub lr, lr, #4
    pop {r0 -r12}
    movs pc, lr
