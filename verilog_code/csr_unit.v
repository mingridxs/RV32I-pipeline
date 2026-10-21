// ============================================================================
// csr_unit — CSRs de modo máquina (Control and Status Registers)
// Parte 1: registradores e instruções Zicsr (csrrw, csrrs, csrrc e versões "i").
// Fica no estágio EX do pipeline.
// ============================================================================
module csr_unit (
    input  wire        clk,
    input  wire        rst,
    input  wire        csr_en,      // há uma instrução CSR válida em EX
    input  wire [ 2:0] funct3,      // 001 RW, 010 RS, 011 RC, 101 RWI, 110 RSI, 111 RCI
    input  wire [11:0] csr_addr,    // instr[31:20]: o NÚMERO do CSR acessado
    input  wire [ 4:0] rs1_field,   // instr[19:15]: índice de rs1 ou o zimm
    input  wire [31:0] rs1_val,     // valor de rs1 (já com forwarding)
    output reg  [31:0] csr_rdata,   // valor ANTIGO do CSR -> rd
    output wire        illegal_csr  // acesso inválido
);

    // ------------------------------------------------------------
    // BLOCO 1 — endereços e registradores
    // ------------------------------------------------------------
    // Machine Trap Setup
    localparam CSR_MSTATUS = 12'h300;
    localparam CSR_MTVEC = 12'h305;
    // Machine Trap Handling
    localparam CSR_MSCRATCH = 12'h340;
    localparam CSR_MEPC = 12'h341;
    localparam CSR_MCAUSE = 12'h342;
    // Machine Information Registers
    localparam CSR_MHARTID = 12'hF14;  // Hardware thread ID

    reg mstatus_mie;  // Machine Interrupt Enable
    reg mstatus_mpie;  // Machine Previous Interrupt Enable
    reg [31:0] mtvec;  // Machine Trap-Vector Base-Address Register
    reg [31:0] mscratch;  // Machine Scratch Register
    reg [31:0] mepc;  // Machine Exception Program Counter
    reg [31:0] mcause;  // Machine Cause Register

    wire [31:0] mstatus_val = {
        19'b0,  // bits 31..13
        2'b11,  // bits 12..11  MPP (sempre M-mode)
        3'b0,  // bits 10..8
        mstatus_mpie,  // bit  7       MPIE
        3'b0,  // bits 6..4
        mstatus_mie,  // bit  3       MIE
        3'b0  // bits 2..0
    };

    // ------------------------------------------------------------
    // BLOCO 2 — leitura (combinacional)
    // ------------------------------------------------------------
    reg csr_exists;  // 1 se csr_addr é um CSR conhecido

    always @(*) begin
        csr_exists = 1'b1;
        csr_rdata  = 32'b0;
        case (csr_addr)
            CSR_MSTATUS:  csr_rdata = mstatus_val;
            CSR_MTVEC:    csr_rdata = mtvec;
            CSR_MSCRATCH: csr_rdata = mscratch;
            CSR_MEPC:     csr_rdata = mepc;
            CSR_MCAUSE:   csr_rdata = mcause;
            CSR_MHARTID:  csr_rdata = 32'b0;  // somente-leitura, vale 0
            default: begin
                // endereço inválido: não existe CSR com esse número
                csr_rdata  = 32'b0;
                csr_exists = 1'b0;
            end
        endcase
    end

    // ------------------------------------------------------------
    // BLOCO 3 — decidir se escreve, e se é ilegal (combinacional)
    // ------------------------------------------------------------
    // RW/RWI sempre escrevem; RS/RC só se o CAMPO rs1 não for x0 (ou zimm = 0)
    wire is_rw = (funct3[1:0] == 2'b01);
    wire wants_wr = (rs1_field != 5'b0) || is_rw;

    // CSRs com csr_addr[11:10] == 2'b11 são somente-leitura
    wire read_only = (csr_addr[11:10] == 2'b11);

    // ilegal: csr_en E (não existe OU (quer escrever E somente-leitura))
    assign illegal_csr = csr_en && (!csr_exists || (wants_wr && read_only));

    wire do_write = csr_en && wants_wr && !illegal_csr;

    // ------------------------------------------------------------
    // BLOCO 4 — calcular o novo valor (combinacional)
    // ------------------------------------------------------------
    // operando: imediato de 5 bits (versões "i") ou o valor de rs1
    wire [31:0] csr_src = funct3[2] ? {27'b0, rs1_field} : rs1_val;

    reg [31:0] csr_wdata;  // valor que será escrito no CSR
    always @(*) begin
        case (funct3[1:0])
            2'b01:   csr_wdata = csr_src;  // RW -> só a fonte
            2'b10:   csr_wdata = csr_rdata | csr_src;  // RS -> antigo OU fonte
            2'b11:   csr_wdata = csr_rdata & ~csr_src;  // RC -> antigo E (NÃO fonte)
            default: csr_wdata = csr_rdata;  // não deve acontecer
        endcase
    end

    // ------------------------------------------------------------
    // BLOCO 5 — escrita na borda de clock (sequencial)
    // ------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mstatus_mie  <= 1'b0;
            mstatus_mpie <= 1'b0;
            mtvec        <= 32'b0;
            mscratch     <= 32'b0;
            mepc         <= 32'b0;
            mcause       <= 32'b0;
        end else if (do_write) begin
            case (csr_addr)
                CSR_MSTATUS: begin
                    mstatus_mie  <= csr_wdata[3];  // bit 3
                    mstatus_mpie <= csr_wdata[7];  // bit 7
                end
                CSR_MTVEC:    mtvec <= csr_wdata;
                CSR_MSCRATCH: mscratch <= csr_wdata;
                // endereço de instrução: múltiplo de 4, os 2 bits de baixo ficam 0
                CSR_MEPC:     mepc <= {csr_wdata[31:2], 2'b00};
                CSR_MCAUSE:   mcause <= csr_wdata;
                default:      ;  // mhartid e endereços inválidos: nada é gravado
            endcase
        end
    end

endmodule
