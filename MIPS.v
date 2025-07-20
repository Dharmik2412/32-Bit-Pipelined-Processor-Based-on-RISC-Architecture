module MIPS( 
input clk1,  
input clk2, 
input reset, 
input [31:0] instruction_in, 
output reg [31:0] result_out 
); 
// Define pipeline registers 
reg [31:0] PC=0, IF_ID_IR, IF_ID_NPC; 
reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_Imm; 
reg [31:0] EX_MEM_IR, EX_MEM_ALUOut, EX_MEM_B; 
reg [31:0] MEM_WB_IR, MEM_WB_ALUOut, MEM_WB_LMD; 

reg [31:0] Reg [0:31]; 
reg [31:0] Mem [0:1023]; 
reg [2:0] ID_EX_type, EX_MEM_type, MEM_WB_type; 
reg HALTED=0, TAKEN_BRANCH=0; 
parameter ADD = 6'b000000, SUB = 6'b000001, AND = 6'b000010, OR = 6'b000011, 
SLT = 6'b000100, MUL = 6'b000101, HLT = 6'b111111, LW = 6'b001000, 
SW = 6'b001001, ADDI = 6'b001010, SUBI = 6'b001011, SLTI = 6'b001100, 
BNEQZ = 6'b001101, BEQZ = 6'b001110; 
parameter RR_ALU = 3'b000, RM_ALU = 3'b001, LOAD = 3'b010, STORE = 3'b011, 
BRANCH = 3'b100, HALT = 3'b101; 
always @(posedge clk1 or posedge reset) // IF Stage 
if (reset) begin 
PC <= 0; 
end else if (!HALTED) begin 
IF_ID_IR <= instruction_in; 
IF_ID_NPC <= PC + 1; 
PC <= PC + 1; 
end 
integer i; 
initial begin 
for (i = 0; i < 32; i = i + 1) begin 
Reg[i] = 0; 
end 
end 
always @(posedge clk2 or posedge reset) // ID Stage 
if (reset) begin 
ID_EX_IR <= 0; 
ID_EX_A <= 0; 
ID_EX_B <= 0; 
ID_EX_NPC <= 0; 
ID_EX_Imm <= 0; 
ID_EX_type <= 0; 
end else if (!HALTED) begin 
ID_EX_A <= Reg[IF_ID_IR[25:21]]; 
ID_EX_B <= Reg[IF_ID_IR[20:16]]; 
ID_EX_NPC <= IF_ID_NPC; 
ID_EX_IR <= IF_ID_IR; 
ID_EX_Imm <= {{16{IF_ID_IR[15]}}, IF_ID_IR[15:0]}; 

case (IF_ID_IR[31:26]) 
ADD, SUB, AND, OR, SLT, MUL: ID_EX_type <= RR_ALU; 
ADDI, SUBI, SLTI: ID_EX_type <= RM_ALU; 
LW: ID_EX_type <= LOAD; 
SW: ID_EX_type <= STORE; 
BNEQZ, BEQZ: ID_EX_type <= BRANCH; 
HLT: ID_EX_type <= HALT; 
endcase 
end 
always @(posedge clk1 or posedge reset) // EX Stage 
if (reset) begin 
EX_MEM_IR <= 0; 
EX_MEM_ALUOut <= 0; 
EX_MEM_B <= 0; 
end else if (!HALTED) begin 
EX_MEM_type <= ID_EX_type; 
EX_MEM_IR <= ID_EX_IR; 
case (ID_EX_type) 
RR_ALU: begin 
case (ID_EX_IR[31:26]) 
ADD: EX_MEM_ALUOut <= ID_EX_A + ID_EX_B; 
SUB: EX_MEM_ALUOut <= ID_EX_A - ID_EX_B; 

AND: EX_MEM_ALUOut <= ID_EX_A & ID_EX_B; 
OR:  EX_MEM_ALUOut <= ID_EX_A | ID_EX_B; 
SLT: EX_MEM_ALUOut <= (ID_EX_A < ID_EX_B); 
MUL: EX_MEM_ALUOut <= ID_EX_A * ID_EX_B; 
endcase 
end 
RM_ALU: begin 
case (ID_EX_IR[31:26]) 
ADDI: EX_MEM_ALUOut <= ID_EX_A + ID_EX_Imm; 
SUBI: EX_MEM_ALUOut <= ID_EX_A - ID_EX_Imm; 
SLTI: EX_MEM_ALUOut <= (ID_EX_A < ID_EX_Imm); 
endcase 
end 
LOAD, STORE: EX_MEM_ALUOut <= ID_EX_A + ID_EX_Imm; 
BRANCH: begin 
EX_MEM_ALUOut <= ID_EX_NPC + ID_EX_Imm; 
TAKEN_BRANCH <= (ID_EX_A == 0); 
end 
endcase 
end 
always @(posedge clk2 or posedge reset) // MEM Stage 
if (reset) begin 
 
MEM_WB_IR <= 0; 
MEM_WB_ALUOut <= 0; 
MEM_WB_LMD <= 0; 
end else if (!HALTED) begin 
MEM_WB_type <= EX_MEM_type; 
MEM_WB_IR <= EX_MEM_IR; 
case (EX_MEM_type) 
LOAD: MEM_WB_LMD <= Mem[EX_MEM_ALUOut]; 
STORE: if (!TAKEN_BRANCH) Mem[EX_MEM_ALUOut] <= EX_MEM_B; 
default: MEM_WB_ALUOut <= EX_MEM_ALUOut; 
endcase 
end 
always @(posedge clk1 or posedge reset) // WB Stage 
if (reset) begin 
result_out <= 0; 
HALTED <= 0; 
end else if (!HALTED) begin 
case (MEM_WB_type) 
RR_ALU: Reg[MEM_WB_IR[15:11]] <= MEM_WB_ALUOut; 
RM_ALU: Reg[MEM_WB_IR[20:16]] <= MEM_WB_ALUOut; 
LOAD: Reg[MEM_WB_IR[20:16]] <= MEM_WB_LMD; 
HALT: HALTED <= 1; 

endcase 
result_out <= MEM_WB_ALUOut; 
end 
endmodule 