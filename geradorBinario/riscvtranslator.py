typeR = ["ADD", "SUB", "XOR", "OR", "AND", "SLL", "SRL", "MUL", "MULH", "MULHSU", "MULU"]

funct3R = ["000", "000", "100", "110", "111", "001", "101", "000", "001", "010", "011"]

typeI = ["ADDI", "XORI","ORI", "ANDI", "SLI", "SRI", "LH", "LB", "LW", "JALR"]

funct3I = ["000", "100", "110", "111", "001", "101", "000", "001", "010", "000"]

typeS = ["SW", "SH", "SB"]

typeB = ["BEQ", "BNE", "BLT", "BGE", "BLTU", "BGEU"]

typeJ = "JAL"

typeU = ["LUI", "AUIPC"]

instructions = typeR + typeI + typeS + typeB + [typeJ] + typeU

def get_imm_bin(val_str, bits):
    val = int(val_str)
    if val < 0:
        val = (1 << bits) + val
    return format(val, f'0{bits}b')

def getOpcode(instruction):
    if instruction in typeR:
        return "0110011"
    elif instruction in typeI:
        if instruction in ["LW", "LH", "LB", "JALR"]:
            return "0000011" if instruction in ["LW", "LH", "LB"] else "1100111"
        else:
            return "0010011"
    elif instruction in typeS:
        return "0100011"
    elif instruction in typeB:
        return "1100011"
    elif instruction == typeJ:
        return "1101111"
    elif instruction in typeU:
        if instruction == "LUI":
              return "0110111"
        else:
            return "0010111"
    elif instruction == "HALT":
        return "HALT"
    elif instruction == "NOP":
        return "NOP"
    else:
        return "UNKNOWN"

def getFullInstruction(instruction):
    args = instruction.split()
    print(f"Args: {args}")
    opcode = getOpcode(args[0])
    if opcode == "UNKNOWN":
        return "INVALID"
    if opcode == "HALT": #retorna 32 bits 1
        return "1" * 32
    if opcode == "NOP": #retorna 32 bits 0
        return '0' * 32
    if opcode == "0110011":  # R-type
        funct3 = funct3R[typeR.index(args[0])]
        #LER PARA A RS1 e RS2 a string que representa o binário do registrador
        rs1 = format(int(args[2]), '05b')
        rs2 = format(int(args[3]), '05b')
        rd = format(int(args[1]), '05b')
        if args[0] == "SUB":
            funct7 = "0100000"
        elif args[0] in ["MUL", "MULH", "MULHSU", "MULHU"]:
            funct7 = typeR.index(args[0]) % 7
        else:
            funct7 = "0000000"
        return str(funct7) + '_' + rs2 + '_' + rs1 + '_' + funct3 + '_' + rd + '_' + opcode
    
    if opcode == "0010011" or opcode == "0000011" or opcode == "1100111":  # I-type
        rd = format(int(args[1]), '05b')
        rs1 = format(int(args[2]), '05b')
        imm = get_imm_bin(args[3], 12)
        funct3 = funct3I[typeI.index(args[0])]

        return imm + '_' + rs1 + '_' + funct3 + '_' + rd + '_' + opcode
    
    if opcode == "0100011":  # S-type
        rs2 = format(int(args[2]), '05b')
        rs1 = format(int(args[1]), '05b')
        imm = get_imm_bin(args[3], 12)
        funct3 = "000" if args[0] == "SB" else "001" if args[0] == "SH" else "010"
        imm_high = imm[11:4:-1]
        imm_low = imm[4:-1:-1]
        return imm_high + '_' + rs2 + '_' + rs1 + '_' + funct3 + '_' + imm_low + '_' + opcode

    if opcode == "1100011":  # B-type
        rs1 = format(int(args[1]), '05b')
        rs2 = format(int(args[2]), '05b')
        imm = get_imm_bin(args[3], 13)  # 13 bits for B-type immediate
        funct3 = "000" if args[0] == "BEQ" else "001" if args[0] == "BNE" else "100" if args[0] == "BLT" else "101" if args[0] == "BGE" else "110" if args[0] == "BLTU" else "111"
        imm_12 = imm[0]
        imm_10_5 = imm[10:4:-1]
        imm_4_1 = imm[4:0:-1]
        imm_11 = imm[11]
        #printar o tamanho de cada imm para debugar
        print(f"imm_12: {len(imm_12)}, imm_10_5: {len(imm_10_5)}, imm_4_1: {len(imm_4_1)}, imm_11: {len(imm_11)}")
        return imm_12 + '_' + imm_10_5 + '_' + rs2 + '_' + rs1 + '_' + funct3 + '_' + imm_4_1 + '_' + imm_11 + '_' +  opcode
    
    
    if opcode == "1101111":  # J-type
        rd = format(int(args[1]), '05b')
        imm = get_imm_bin(args[2], 21)
        imm_20 = imm[0]
        imm_10_1 = imm[10:0:-1]
        imm_11 = imm[11]
        imm_19_12 = imm[19:11:-1]
        return imm_20 + '_' + imm_10_1 + '_' + imm_11 + '_' + imm_19_12 + '_' + rd + '_' + opcode
    
if __name__ == '__main__':

    with open('instructions.txt', 'r') as file:
        lines = file.readlines()
    for line in lines:
        line = line.strip()
        binary_instruction = getFullInstruction(line)
        print(f"{line} -> {binary_instruction}")
        print(f"Length: {len(binary_instruction)} bits")

    with open('binary_instructions.txt', 'w') as file:
        for line in lines:
            line = line.strip()
            binary_instruction = getFullInstruction(line)
            file.write(f"{binary_instruction}\n")
