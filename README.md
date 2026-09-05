# Processador RISC-V RV32I/M Pipelined com Predição Dinâmica de Desvios (BTB)

Este repositório contém a implementação em Verilog de um processador baseado na arquitetura **RISC-V (RV32I)** com suporte estendido para multiplicações (**M-extension**), utilizando um pipeline de 5 estágios, unidade de detecção de riscos (hazards), unidade de encaminhamento (forwarding) e predição dinâmica de desvios através de um **Branch Target Buffer (BTB)**.

Além do processador físico em Verilog, o projeto inclui um tradutor/assembler escrito em Python para compilar código assembly RISC-V simplificado diretamente em instruções binárias prontas para simulação.

---

## 🚀 Principais Recursos do Processador

- **Pipeline de 5 Estágios**: Divisão clássica de processamento dividida em:
  1. **IF (Instruction Fetch)**: Busca de instrução na memória com base no Program Counter (PC).
  2. **ID (Instruction Decode)**: Decodificação da instrução, leitura do Banco de Registradores, geração de imediatos e predição de branches.
  3. **EX (Execute)**: Execução de operações na ULA (Unidade Lógica e Aritmética) ou multiplicação no pipeline dedicado de multiplicação.
  4. **MEM (Memory Access)**: Leitura/Escrita na memória de dados principal.
  5. **WB (Write Back)**: Escrita dos resultados de volta no banco de registradores.
- **Predição Dinâmica de Desvios (BTB)**: Implementação de um *Branch Target Buffer* no estágio de busca (IF) que prevê a direção e o endereço de destino de desvios para reduzir penalidades de ciclos (stalls/flushes).
- **Tratamento de Conflitos (Hazards)**:
  - **Forwarding Unit (Encaminhamento)**: Evita stalls desnecessários ao encaminhar dados diretamente das saídas dos estágios EX/MEM e MEM/WB para as entradas da ULA e do estágio de decodificação.
  - **Hazard Detection Unit (HDU)**: Detecta dependências de dados inevitáveis (como leitura de dados da memória seguida imediatamente por uso) e insere "bolhas" (stalls) no pipeline, além de limpar o pipeline (flushes) em caso de desvios tomados incorretamente.
- **Multiplicador Pipeline Integrado (`MulPipelined32Bits`)**: Unidade dedicada que realiza multiplicações de 32 bits de forma segmentada para alto desempenho, suportando operações com sinal e sem sinal.

---

## 📂 Estrutura de Diretórios

O projeto está organizado da seguinte forma:

```text
├── verilog_code/           # Código-fonte Verilog do Processador e Componentes
│   ├── RV32i.v             # Módulo Top-Level do Processador
│   ├── PC.v                # Program Counter
│   ├── IF_ID.v             # Registrador de Pipeline IF/ID
│   ├── ID_EX.v             # Registrador de Pipeline ID/EX
│   ├── EX_MEM.v            # Registrador de Pipeline EX/MEM
│   ├── MEM_WB.v            # Registrador de Pipeline MEM/WB
│   ├── control.v           # Unidade de Controle Principal
│   ├── register_bank.v     # Banco de Registradores (x0 - x31)
│   ├── ULA.v               # Unidade Lógica e Aritmética
│   ├── Ula_controler.v     # Decodificador de controle para a ULA
│   ├── BTB.v               # Branch Target Buffer (Preditor)
│   ├── Branch_Decider.v    # Decisor de Branch (estágio ID)
│   ├── forward_unit.v      # Unidade de Encaminhamento
│   ├── hazard_detection_unit.v # Unidade de Detecção de Riscos
│   ├── FullMultiplierPipelinedFunctionalUS.sv  # Multiplicador pipelined interno
│   ├── main_memory.v       # Memória Principal (Dados/Instruções separadas no Testbench)
│   ├── instruction_memory.v# Memória de Instruções
│   └── synth.ys            # Script de Síntese Yosys para verificação/análise
│
├── Makefile                # Automação da simulação com Icarus Verilog
│
├── testBenchs/             # Testbenches para Simulação
│   ├── tb_RV32i.v          # Testbench principal do processador completo
│   ├── binarios/           # Arquivos .bin com instruções montadas para testes
│   └── tb_[modulo].v       # Testbenches individuais de componentes (ULA, registradores, etc.)
│
├── geradorBinario/         # Ferramenta Assembler (Python)
│   ├── riscvtranslator.py  # Tradutor de Assembly RISC-V para código de máquina legível
│   ├── instructions.txt    # Arquivo de entrada para instruções assembly a serem compiladas
│   ├── binary_instructions.txt # Arquivo gerado com instruções binárias correspondentes
│   ├── fatorial.txt        # Exemplo de programa de Fatorial
│   └── fibonnaci.txt       # Exemplo de programa de Fibonacci
│
└── R232i.qpf / .qsf        # Arquivos de projeto do Intel Altera Quartus
```

---

## 🎛️ Conjunto de Instruções Suportadas

O processador é capaz de decodificar e processar as seguintes instruções:

| Tipo | Instruções | Opcode (Binário) | Descrição / Operandos |
| :---: | :--- | :---: | :--- |
| **Tipo R** | `ADD`, `SUB`, `XOR`, `OR`, `AND`, `SLL`, `SRL` | `0110011` | Operações lógicas/aritméticas entre registradores |
| **Multiplicação (M)** | `MUL`, `MULH`, `MULHSU`, `MULU` | `0110011` | Multiplicações de 32 bits (com e sem sinal) |
| **Tipo I** | `ADDI`, `XORI`, `ORI`, `ANDI`, `SLI`, `SRI` | `0010011` | Operações imediatas com registradores |
| **Memória (Tipo I)** | `LW`, `LH`, `LB`, `JALR` | `0000011` / `1100111` | Carregamento da memória e desvio indireto |
| **Tipo S** | `SW`, `SH`, `SB` | `0100011` | Salvamento na memória de dados |
| **Tipo B (Branch)** | `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU` | `1100111` | Desvios condicionais |
| **Tipo U** | `LUI`, `AUIPC` | `0110111` / `0010111` | Carregar imediato superior ou somar ao PC |
| **Tipo J** | `JAL` | `1101111` | Desvio incondicional e link |
| **Especial** | `NOP` / `HALT` | `0000...` / `1111...` | Instruções de parada da simulação e não-operação |

---

## 🛠️ Como Utilizar o Projeto

### 1. Escrever e Traduzir Programas Assembly

Escreva seu código assembly no arquivo `geradorBinario/instructions.txt` utilizando o formato de registradores inteiros (ex: `0` para `x0`, `2` para `x2`). 

**Exemplo de programa (`instructions.txt`):**
```text
ADDI 2 0 7     # x2 = 7
ADDI 3 0 1     # x3 = 1
ADDI 4 0 1     # x4 = 1
MUL 4 4 2      # x4 = x4 * x2
ADDI 2 2 -1    # x2 = x2 - 1
BEQ 2 3 -4     # se x2 != x3 (1), desvia para a multiplicação (ADDI 2 2 -1 é a instrução em PC - 4 relative)
HALT           # Finaliza a execução
```

Execute o tradutor Python para gerar o arquivo de binários formatados:
```bash
python geradorBinario/riscvtranslator.py
```
Isso gerará as instruções traduzidas no arquivo `geradorBinario/binary_instructions.txt` com a formatação adequada de barramentos para leitura direta por testbenches do ModelSim/Verilog.

---

### 2. Simulação no ModelSim / Quartus

O testbench principal está localizado em `testBenchs/tb_RV32i.v`. 
Para carregar seu programa na simulação:
1. Abra o arquivo [tb_RV32i.v](file:///c:/Users/davi5/UFPI/4_periodo/Topicos/Risc-v-R232I-pipeline-/testBenchs/tb_RV32i.v).
2. Configure a linha de leitura de memória apontando para o arquivo gerado (por exemplo, descomente a linha `geradorBinario/binary_instructions.txt` ou defina o caminho correto):
   ```verilog
   $readmemb("geradorBinario/binary_instructions.txt", dut.im.instruction_memory);
   ```
3. Execute a simulação. O testbench imprimirá detalhadamente no console o estado do processador ciclo a ciclo, incluindo o estado das unidades de Hazard, BTB, ULA e banco de registradores.

---

### 2. Simulação com Icarus Verilog

Requisitos: `iverilog` (versão 11 ou superior) e, opcionalmente, `gtkwave` para visualizar formas de onda.

```bash
# Arch / CachyOS
sudo pacman -S iverilog gtkwave
# Debian / Ubuntu
sudo apt install iverilog gtkwave
```

Um `Makefile` na raiz do repositório cuida da compilação e da execução. **Rode sempre a partir da raiz do projeto**, pois os caminhos dos arquivos de memória são relativos a ela.

```bash
make          # compila e executa o testbench principal (tb_RV32i)
make clean    # remove os artefatos gerados (sim_*.vvp, sim.vcd)
```

O `Makefile` coleta automaticamente todos os fontes de `verilog_code/`, exceto as netlists sintetizadas (`convertido.v`, `netlist_mapeada.v`) e o testbench isolado `tb_ULA.v`, que duplicariam definições de módulos. Arquivos novos adicionados ao diretório entram na compilação sem nenhuma alteração no `Makefile`.

Internamente, o alvo executa dois passos: `iverilog` compila os fontes em um bytecode (`sim_tb_RV32i.vvp`) e `vvp` executa esse bytecode. A flag `-g2012` é obrigatória, pois o multiplicador (`FullMultiplierPipelinedFunctionalUS.sv`) usa construções SystemVerilog.

#### Escolhendo o programa a executar

O testbench lê o programa e a memória de dados através de *plusargs*, de modo que trocar de programa **não exige recompilar**:

```bash
make PROG=testBenchs/binarios/Branchs/blt.bin
make PROG=testBenchs/binarios/BTB/teste_BTB.bin
make PROG=geradorBinario/binary_instructions.txt   # programa recém-montado
make MEM=testBenchs/binarios/memoria.bin           # memória de dados alternativa
```

Sem esses parâmetros, os padrões são `testBenchs/binarios/mul/mul_big.bin` (programa) e `testBenchs/binarios/memoria.bin` (memória de dados). O testbench imprime no início da execução quais arquivos foram carregados.

O mesmo pode ser feito chamando o simulador diretamente:

```bash
vvp sim_tb_RV32i.vvp +prog=testBenchs/binarios/Branchs/blt.bin +mem=testBenchs/binarios/memoria.bin
```

#### Simulando um módulo isolado

Os testbenches de componentes seguem o mesmo fluxo, bastando informar qual usar:

```bash
make TB=tb_IF_ID
make TB=tb_EX_MEM
make TB=tb_MEM_WB
```

Atenção: esses testbenches de componente não chamam `$finish`, então a simulação não termina sozinha — interrompa com `Ctrl+C`. Dois deles estão atualmente desatualizados em relação aos módulos e não compilam, pois referenciam portas que não existem mais: `tb_ID_EX` (`mux_res_ula_in`, `mux_res_ula_out`) e `hazard_detection_unit_tb` (`IFID_RegisterR1`, `IFID_RegisterR2`, `IDEX_RegisterRt`).

#### Formas de onda

Para gerar um arquivo VCD, adicione ao bloco `initial` do testbench:

```verilog
$dumpfile("sim.vcd");
$dumpvars(0, tb_RV32i);
```

Em seguida:

```bash
make wave     # executa a simulação e abre o gtkwave
```

#### Saída da simulação

O testbench imprime no console o estado completo do processador a cada ciclo: conteúdo dos registradores de pipeline (IF/ID, ID/EX, EX/MEM, MEM/WB), sinais das unidades de Hazard e Forwarding, estado do BTB, operandos e resultado da ULA, além do banco de registradores e da memória de dados ao final. A execução termina quando o processador encontra a instrução `HALT`.

Um aviso do tipo `$readmemb: Not enough words in the file for the requested range [0:1023]` é esperado e inofensivo: indica apenas que o programa é menor que a memória de instruções, cujas posições restantes permanecem indefinidas. Basta que o programa termine com `HALT`.

---

### 3. Simulação no ModelSim / Quartus

O mesmo testbench (`testBenchs/tb_RV32i.v`) roda no ModelSim. Compile todos os fontes de `verilog_code/` (novamente, sem as netlists sintetizadas) junto do testbench e execute `tb_RV32i`.

Para escolher o programa, use os mesmos *plusargs* na chamada do `vsim`:

```tcl
vsim tb_RV32i +prog=geradorBinario/binary_instructions.txt
```

Alternativamente, edite os valores padrão de `prog_file` e `mem_file` diretamente no testbench.

---

### 4. Síntese com Yosys
O repositório possui suporte básico para síntese lógica de verificação usando o Yosys. Você pode rodar a síntese a partir do diretório `verilog_code` usando o arquivo `synth.ys`:
```bash
yosys synth.ys
```
Isso executará a checagem de hierarquia, síntese lógica básica do módulo top-level `RV32i` e exibirá estatísticas de área e caminhos críticos.
