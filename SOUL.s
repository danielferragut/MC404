@							Trabalho 2
@	Nome:Daniel Pereira Ferragut	Nome:Gabriel Ryo Hioki
@	RA:169488						RA:??????							
@
@Ultima modificao: 12:15, 10 de novembro 2017

.org 0x0
.section .iv,"a"

_start:		

interrupt_vector:

    b RESET_HANDLER

.org 0x08
	b SUPERVISOR_HANDLER
.org 0x18
    b IRQ_HANDLER


@Alocacao de memoria fica aqui
@TODO: O professor mudou o endereco de memoria pra 12000, nao ha problema de memoria
.data
CONTADOR: .skip 4    @Variavel que vai acumular interrupcoes

IRQ_STACK: .skip 52
IRQ_STACK_START: .skip 4

SVC_STACK: .skip 52
SVC_STACK_START: .skip 4

USER_STACK: .skip 4096
USER_STACK_START: .skip 4

.text
.org 0x100

.set GPT_CR, 0x53FA0000
.set GPT_PR, 0x53FA0004
.set GPT_SR, 0x53FA0008
.set GPT_IR, 0x53FA000C
.set GPT_OCR1, 0x53FA0010
@TODO: Checar se 200 eh bom valor
.set TIME_SZ, 200			@Valor que o timer ira contar, suposto a testes e mudancas
.set USER_CODE 0x77812000

RESET_HANDLER:

    @ Zera o contador
    ldr r2, =CONTADOR  @lembre-se de declarar esse contador em uma secao de dados! 
    mov r0, #0
    str r0, [r2]

    @Faz o registrador que aponta para a tabela de interrupções apontar para a tabela interrupt_vector
    ldr r0, =interrupt_vector
    mcr p15, 0, r0, c12, c0, 0
    
    SET_GPT:
    @Configuracao do General Purpose Timer(GPT)
    mov r0, #0x41
    ldr r1, =GPT_CR
    str r0, [r1]

    @Zerar o prescaler
    mov r0, #0
    ldr r1, =GPT_PR
    str r0, [r1]
    
    @Valor que ele vai contar
    mov r0, TIME_SZ
    ldr r1, =GPT_OCR1
    str r0, [r1]

    @Habilitacao das interrupcoes do GPT
    mov r0, #1
    ldr r1, =GPT_IR
    str r0, [r1]

    @Configuracao do GPIO
    SET_GPIO:
    .set GPIO_BASE, 0x53F84000
    .set GPIO_DR, 0x0
    .set GPIO_GDIR, 0x4
    .set GPIO_PSR, 0x8
    .set GPIO_GDIR_MASK, #0xFFFC003E

    ldr r1, =GPIO_BASE

    @Coloca as definicoes de entrada e saida no registrador GDIR
    ldr r0, GPIO_GDIR_MASK @Mascara com as entradas corretas
    str r0, [r1, #GPIO_GDIR]

    @Muda pra supervisor
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

    @Trecho de codigo que ira mudar para o codigo do usuario
    ldr lr, =USER_CODE
    msr CPSR_C, #0x10
    @Ajusta a pilha do usuario
    ldr sp, =USER_STACK_START
    mov pc, lr

@Handler de Supervisor Calls
SVC_HANDLER:
	@Primeiro se ajusta a pilha para o endereco de SVC_STACK_START
	ldr sp, =SVC_STACK_START
	@TODO: Ver quais registradores usou e tirar os que nao usar
	push {r0-r12}

	@TODO: Talvez os nomes dos rotulos possam interfereir
	@TODO: Tratar cada uma dessas interrupcoes
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

    @Checar se a velocidade eh valida
    @Como o parametro no LoCo e BiCo eh unsigned char, o valor nunca vai ser negativo
    cmp r4, #0b111111
    movhi r0, #-2
    bhi SVC_fim
    @Se nao pular, velocidade eh valida

    @Trecho de codigo que ve qual motor ter velocidade alterada
    cmp r5, #0
    beq SVC_motor_speed_0
    cmp r5, #1
    beq SVC_motor_speed_1
    @Caso nenhum dos dois, motor invalido
    mov r0, #-1
    b SVC_fim

@Se entrar nesse rotulo, ira mudar os bits [19,24] para a velocidade e o bit 18 para escrever
SVC_motor_speed_0:
    @Velocidade sendo escrita nos bits
    mov r0, r5, lsl #19      @Pra velocidade comecar no bit 19
    ldr r1, =GPIO_BASE
    ldr r2, [r1, #GPIO_DR]   @Pega o DR atual
    and r0, r0, r2           @Atualiza o DR
    str r0, [r1, #GPIO_DR]   @Escreve ele de volta
   
    @Write sendo setado
    mov r0, #0
    mov r0, lsl #18          @Leva para o bit 18
    
    @Atualiza DR
    ldr r2, [r1, #GPIO_DR]   @Pega o DR atual
    and r0, r0, r2           @Atualiza o DR
    str r0, [r1, #GPIO_DR]   @Escreve ele de volta

    @TODO: Talvez setar 1 de novo
@    @Write sendo setado
@    mov r0, #0
@    mov r0, lsl #18          @Leva para o bit 18
    
    @Para de escrever a velocidade
@    ldr r2, [r1, #GPIO_DR]   @Pega o DR atual
@    and r0, r0, r2           @Atualiza o DR
@    str r0, [r1, #GPIO_DR]   @Escreve ele de volta
    b SVC_fim

@Se entrar nesse rotulo, ira mudar os bits [26,31] para a velocidade e o bit 25
SVC_motor_speed_1:
    mov r0, r5, lsl #26      @Pra velocidade comecar no bit 19
    ldr r1, =GPIO_BASE
    ldr r2, [r1, #GPIO_DR]   @Pega o DR atual
    and r0, r0, r2           @Atualiza o DR
    str r0, [r1, #GPIO_DR]   @Escreve ele de volta
   
    @Write sendo setado
    mov r0, #0
    mov r0, lsl #25          @Leva para o bit 18
    
    @Atualiza DR
    ldr r2, [r1, #GPIO_DR]   @Pega o DR atual
    and r0, r0, r2           @Atualiza o DR
    str r0, [r1, #GPIO_DR]   @Escreve ele de volta

    @TODO: Talvez setar 1 de novo
@    @Write sendo setado
@    mov r0, #0
@    mov r0, lsl #25          @Leva para o bit 18
    
    @Para de escrever a velocidade
@    ldr r2, [r1, #GPIO_DR]   @Pega o DR atual
@    and r0, r0, r2           @Atualiza o DR
@    str r0, [r1, #GPIO_DR]   @Escreve ele de volta
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
 
    @Vai escrever as velocidades nos dois motores
    @Velocidade sendo escrita nos bits
    mov r0, r5, lsl #19      @Pra velocidade comecar no bit 19
    ldr r1, =GPIO_BASE
    ldr r2, [r1, #GPIO_DR]   @Pega o DR atual
    and r0, r0, r2           @Atualiza o DR
    str r0, [r1, #GPIO_DR]   @Escreve ele de volta
   
    @Write sendo setado
    mov r0, #0
    mov r0, lsl #18          @Leva para o bit 18
    
    @Atualiza DR
    ldr r2, [r1, #GPIO_DR]   @Pega o DR atual
    and r0, r0, r2           @Atualiza o DR
    str r0, [r1, #GPIO_DR]   @Escreve ele de volta

    @TODO: Talvez setar 1 de novo
@    @Write sendo setado
@    mov r0, #0
@    mov r0, lsl #18          @Leva para o bit 18
    
    @Para de escrever a velocidade
@    ldr r2, [r1, #GPIO_DR]   @Pega o DR atual
@    and r0, r0, r2           @Atualiza o DR
@    str r0, [r1, #GPIO_DR]   @Escreve ele de volta

    mov r0, r5, lsl #26      @Pra velocidade comecar no bit 19
    ldr r1, =GPIO_BASE
    ldr r2, [r1, #GPIO_DR]   @Pega o DR atual
    and r0, r0, r2           @Atualiza o DR
    str r0, [r1, #GPIO_DR]   @Escreve ele de volta
   
    @Write sendo setado
    mov r0, #0
    mov r0, lsl #25          @Leva para o bit 18
    
    @Atualiza DR
    ldr r2, [r1, #GPIO_DR]   @Pega o DR atual
    and r0, r0, r2           @Atualiza o DR
    str r0, [r1, #GPIO_DR]   @Escreve ele de volta

    @TODO: Talvez setar 1 de novo
@    @Write sendo setado
@    mov r0, #0
@    mov r0, lsl #25          @Leva para o bit 18
    
    @Para de escrever a velocidade
@    ldr r2, [r1, #GPIO_DR]   @Pega o DR atual
@    and r0, r0, r2           @Atualiza o DR
@    str r0, [r1, #GPIO_DR]   @Escreve ele de volta
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
 
    push {r0,r1,r2}
    @Sinalizacao para GPT que a interrupcao foi tratada
    mov r0, #1
    ldr r1, =GPT_SR
    str r0, [r1]

    @Acrescimo de um ao contador
    mov r0, #1
    ldr r2, =CONTADOR
    ldr r1, [r2]
    add r0, r0, r1
    str r0, [r2]

    sub lr, lr, #4
    pop {r0,r1, r2}
    movs pc, lr
