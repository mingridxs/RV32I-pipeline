`timescale 1ns/1ps
// ============================================================================
// tb_csr_unit.v — testbench do csr_unit (parte 1: CSRs e instruções Zicsr)
//
// Como rodar (da raiz do repositório):
//   iverilog -g2012 -o tb_csr verilog_code/csr_unit.v testBenchs/tb_csr_unit.v && vvp tb_csr
//
// Cada teste simula UMA instrução CSR no estágio EX:
//   1. na borda de DESCIDA do clock, coloca a instrução nas entradas;
//   2. confere o que sai ANTES da borda de subida (csr_rdata = valor antigo,
//      illegal_csr);
//   3. espera a borda de SUBIDA (é quando o CSR é escrito);
//   4. lê o CSR de novo e confere o valor novo.
// ============================================================================
module tb_csr_unit;

    // ---------------- sinais ligados ao módulo ----------------
    reg         clk = 0;
    reg         rst = 1;
    reg         csr_en = 0;
    reg  [2:0]  funct3 = 0;
    reg  [11:0] csr_addr = 0;
    reg  [4:0]  rs1_field = 0;
    reg  [31:0] rs1_val = 0;
    wire [31:0] csr_rdata;
    wire        illegal_csr;

    csr_unit dut (
        .clk(clk), .rst(rst), .csr_en(csr_en), .funct3(funct3),
        .csr_addr(csr_addr), .rs1_field(rs1_field), .rs1_val(rs1_val),
        .csr_rdata(csr_rdata), .illegal_csr(illegal_csr)
    );

    always #5 clk = ~clk;   // período de 10 ns

    // ---------------- constantes para deixar os testes legíveis ----------------
    localparam MSTATUS  = 12'h300;
    localparam MTVEC    = 12'h305;
    localparam MSCRATCH = 12'h340;
    localparam MEPC     = 12'h341;
    localparam MCAUSE   = 12'h342;
    localparam MHARTID  = 12'hF14;

    localparam CSRRW  = 3'b001;
    localparam CSRRS  = 3'b010;
    localparam CSRRC  = 3'b011;
    localparam CSRRWI = 3'b101;
    localparam CSRRSI = 3'b110;
    localparam CSRRCI = 3'b111;

    // ---------------- conferência ----------------
    integer erros = 0;

    task check(input [8*40-1:0] nome, input [31:0] obtido, input [31:0] esperado);
        begin
            if (obtido !== esperado) begin
                $display("FALHOU  %0s: obtido %h, esperado %h", nome, obtido, esperado);
                erros = erros + 1;
            end else
                $display("ok      %0s = %h", nome, obtido);
        end
    endtask

    // ---------------- executa uma instrução CSR ----------------
    // Guarda o que o módulo mostrou antes da borda de clock:
    reg [31:0] antigo;   // csr_rdata durante a instrução (valor ANTIGO)
    reg        ilegal;   // illegal_csr durante a instrução

    task exec(input [2:0] f3, input [11:0] addr, input [4:0] campo, input [31:0] valor);
        begin
            @(negedge clk);                 // muda as entradas longe da borda de subida
            csr_en    = 1;
            funct3    = f3;
            csr_addr  = addr;
            rs1_field = campo;
            rs1_val   = valor;
            #1;                             // deixa a lógica combinacional atualizar
            antigo = csr_rdata;
            ilegal = illegal_csr;
            @(posedge clk);                 // aqui o CSR é escrito (se for o caso)
            #1;
            csr_en = 0;                     // fim da instrução
        end
    endtask

    // ---------------- só lê um CSR (sem instrução, sem escrita) ----------------
    reg [31:0] lido;

    task ler(input [11:0] addr);
        begin
            csr_en   = 0;
            csr_addr = addr;
            #1;
            lido = csr_rdata;
        end
    endtask

    // ========================================================================
    initial begin
        $dumpfile("tb_csr.vcd");            // formas de onda: gtkwave tb_csr.vcd
        $dumpvars(0, tb_csr_unit);

        #12 rst = 0;

        // ---------------- caso 1: valores após o reset ----------------
        $display("\n--- caso 1: reset ---");
        ler(MTVEC);    check("mtvec apos reset",            lido, 32'h0000_0000);
        ler(MSTATUS);  check("mstatus apos reset (MPP=11)", lido, 32'h0000_1800);
        ler(MHARTID);  check("mhartid",                     lido, 32'h0000_0000);
        ler(12'h7C0);  check("CSR inexistente le 0",        lido, 32'h0000_0000);

        // ---------------- caso 2: csrrw troca os valores ----------------
        $display("\n--- caso 2: csrrw x5, mtvec, x7  (x7 = 0x100) ---");
        exec(CSRRW, MTVEC, 5'd7, 32'h0000_0100);
        check("rd recebe o valor antigo", antigo, 32'h0000_0000);
        check("nao e ilegal",             ilegal, 1'b0);
        ler(MTVEC);  check("mtvec depois", lido, 32'h0000_0100);

        exec(CSRRW, MTVEC, 5'd7, 32'h0000_0200);
        check("2o csrrw: rd recebe 0x100", antigo, 32'h0000_0100);
        ler(MTVEC);  check("mtvec depois", lido, 32'h0000_0200);

        // ---------------- caso 3: csrrs liga bits ----------------
        $display("\n--- caso 3: csrrs x0, mstatus, x7  (x7 = 0x8, liga MIE) ---");
        exec(CSRRS, MSTATUS, 5'd7, 32'h0000_0008);
        check("rd recebe o valor antigo", antigo, 32'h0000_1800);
        ler(MSTATUS);  check("mstatus com MIE = 1", lido, 32'h0000_1808);

        // ---------------- caso 4: csrrc desliga bits ----------------
        $display("\n--- caso 4: csrrc x0, mstatus, x7  (x7 = 0x8, desliga MIE) ---");
        exec(CSRRC, MSTATUS, 5'd7, 32'h0000_0008);
        check("rd recebe o valor antigo", antigo, 32'h0000_1808);
        ler(MSTATUS);  check("mstatus com MIE = 0", lido, 32'h0000_1800);

        // ---------------- caso 5: csrrwi usa o imediato ----------------
        // rs1_val tem lixo de propósito: nas versões com "i" ele deve ser ignorado.
        $display("\n--- caso 5: csrrwi x0, mscratch, 5  (rs1_val = lixo) ---");
        exec(CSRRWI, MSCRATCH, 5'd5, 32'hDEAD_BEEF);
        ler(MSCRATCH);  check("mscratch = 5 (nao 0xDEADBEEF)", lido, 32'h0000_0005);

        // ---------------- caso 6: mepc zera os 2 bits de baixo ----------------
        $display("\n--- caso 6: csrrw x0, mepc, x7  (x7 = 0x203) ---");
        exec(CSRRW, MEPC, 5'd7, 32'h0000_0203);
        ler(MEPC);  check("mepc alinhado", lido, 32'h0000_0200);

        // ---------------- caso 7: csrr em somente-leitura é permitido ----------------
        $display("\n--- caso 7: csrr x5, mhartid  (= csrrs x5, mhartid, x0) ---");
        exec(CSRRS, MHARTID, 5'd0, 32'h0000_0000);
        check("nao e ilegal", ilegal, 1'b0);
        check("le 0",         antigo, 32'h0000_0000);

        // ---------------- caso 8: escrever em somente-leitura é ilegal ----------------
        $display("\n--- caso 8: csrrw x0, mhartid, x7  (x7 = 1) ---");
        exec(CSRRW, MHARTID, 5'd7, 32'h0000_0001);
        check("e ilegal", ilegal, 1'b1);
        ler(MHARTID);  check("mhartid continua 0", lido, 32'h0000_0000);

        // mesmo com o VALOR zero, x7 não é x0: a instrução tenta escrever -> ilegal
        $display("\n--- caso 8b: csrrs x5, mhartid, x7  (x7 = 0, mas nao e x0) ---");
        exec(CSRRS, MHARTID, 5'd7, 32'h0000_0000);
        check("e ilegal (olha o campo, nao o valor)", ilegal, 1'b1);

        // ---------------- caso 9: CSR inexistente ----------------
        $display("\n--- caso 9: csrr x5, 0x7C0  (nao existe) ---");
        exec(CSRRS, 12'h7C0, 5'd0, 32'h0000_0000);
        check("e ilegal", ilegal, 1'b1);

        // ---------------- caso 10: csrrs com rs1 = x0 não escreve ----------------
        $display("\n--- caso 10: csrrs x5, mscratch, x0  (rs1_val = 0xF0 por engano) ---");
        exec(CSRRS, MSCRATCH, 5'd0, 32'h0000_00F0);
        ler(MSCRATCH);  check("mscratch continua 5", lido, 32'h0000_0005);

        // ---------------- caso 11: csrw com x0 ZERA o CSR ----------------
        $display("\n--- caso 11: csrw mscratch, x0  (= csrrw x0, mscratch, x0) ---");
        exec(CSRRW, MSCRATCH, 5'd0, 32'h0000_0000);
        ler(MSCRATCH);  check("mscratch zerado (RW sempre escreve)", lido, 32'h0000_0000);

        // ---------------- caso 12: versões com imediato, RS e RC ----------------
        $display("\n--- caso 12: csrrsi x0, mstatus, 8  /  csrrci x0, mstatus, 0 ---");
        exec(CSRRSI, MSTATUS, 5'd8, 32'hFFFF_FFFF);
        ler(MSTATUS);  check("csrrsi liga MIE", lido, 32'h0000_1808);
        exec(CSRRCI, MSTATUS, 5'd0, 32'hFFFF_FFFF);
        ler(MSTATUS);  check("csrrci com 0 nao escreve", lido, 32'h0000_1808);
        exec(CSRRCI, MSTATUS, 5'd8, 32'h0000_0000);
        ler(MSTATUS);  check("csrrci desliga MIE", lido, 32'h0000_1800);

        // ---------------- caso 13: só bits implementados do mstatus ----------------
        $display("\n--- caso 13: csrrw mstatus com todos os bits em 1 ---");
        exec(CSRRW, MSTATUS, 5'd7, 32'hFFFF_FFFF);
        ler(MSTATUS);  check("so MIE, MPIE e MPP aparecem", lido, 32'h0000_1888);

        // ---------------- caso 14: mcause guarda 32 bits ----------------
        $display("\n--- caso 14: csrrw x0, mcause, x7  (x7 = 0x8000000B) ---");
        exec(CSRRW, MCAUSE, 5'd7, 32'h8000_000B);
        ler(MCAUSE);  check("mcause", lido, 32'h8000_000B);

        // ---------------- caso 15: sem csr_en, nada acontece ----------------
        $display("\n--- caso 15: entradas de csrrw, mas csr_en = 0 ---");
        @(negedge clk);
        funct3 = CSRRW; csr_addr = MTVEC; rs1_field = 5'd7; rs1_val = 32'h0000_0FFF;
        #1;
        check("illegal_csr = 0 sem instrucao", illegal_csr, 1'b0);
        @(posedge clk); #1;
        ler(MTVEC);  check("mtvec nao mudou", lido, 32'h0000_0200);

        // ---------------- caso 16: reset no meio ----------------
        $display("\n--- caso 16: reset zera tudo ---");
        rst = 1; #1; rst = 0;
        ler(MTVEC);    check("mtvec",    lido, 32'h0000_0000);
        ler(MCAUSE);   check("mcause",   lido, 32'h0000_0000);
        ler(MSTATUS);  check("mstatus",  lido, 32'h0000_1800);

        // ---------------- resultado ----------------
        $display("");
        if (erros == 0) $display("PASSOU: todos os testes");
        else            $display("%0d teste(s) falharam", erros);
        $finish;
    end

endmodule