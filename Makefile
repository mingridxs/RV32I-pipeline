# Simulação com Icarus Verilog
# uso: make            -> compila e roda tb_RV32i
#      make PROG=testBenchs/binarios/Branchs/blt.bin
#      make TB=tb_ID_EX
#      make wave        -> gera sim.vcd (requer $dumpvars no testbench)
#      make clean

TB      ?= tb_RV32i
# Programa e memória de dados carregados pelo testbench (plusargs, sem recompilar)
PROG    ?= testBenchs/binarios/mul/mul_big.bin
MEM     ?= testBenchs/binarios/memoria.bin
IVFLAGS := -g2012

# Todos os fontes menos as netlists sintetizadas (duplicam módulos)
SRCS := $(filter-out verilog_code/convertido.v verilog_code/netlist_mapeada.v verilog_code/tb_ULA.v, \
          $(wildcard verilog_code/*.v) $(wildcard verilog_code/*.sv))
SRCS += testBenchs/$(TB).v

all: run

VVP := sim_$(TB).vvp

$(VVP): $(SRCS)
	iverilog $(IVFLAGS) -o $@ -s $(TB) $(SRCS)

run: $(VVP)
	vvp $(VVP) +prog=$(PROG) +mem=$(MEM)

wave: run
	gtkwave sim.vcd

clean:
	rm -f sim_*.vvp sim.vcd

.PHONY: all run wave clean
