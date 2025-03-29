//! Lower Intermediate Representation.
//! This IR have 1:1 correspondence with machine instructions,
//! while keeping instruction encoding unknown.
//! The purpose is to keep the lowering process unaware of instruction format.

const std = @import("std");
const expectEqual = std.testing.expectEqual;

const Instruction = @import("Instruction.zig");
const bits = @import("bits.zig");
const Register = bits.Register;

pub const Inst = struct {
    tag: Instruction.OpCode,
    ops: [4]Operand,

    pub const Operand = union(enum) {
        none,
        reg: Register,
        imm: i32,
    };

    pub fn fillData(format: Instruction.Format, ops: [4]Operand) Instruction.Data {
        inline for (@typeInfo(Instruction.Format).@"enum".fields) |fmt| {
            if (fmt.value == @intFromEnum(format)) {
                const dataType = @FieldType(Instruction.Data, fmt.name);
                const dataTypeInfo = @typeInfo(dataType);
                switch (dataTypeInfo) {
                    .void => return .EMPTY,
                    .@"struct" => |structInfo| {
                        var data = @as(dataType, undefined);
                        // fill in data
                        inline for (structInfo.fields, 0..) |field, op_i| {
                            const op = ops[op_i];
                            if (field.type == Register) {
                                // register slot
                                @field(data, field.name) = op.reg;
                            } else {
                                switch (@typeInfo(field.type)) {
                                    .int => {
                                        // immediate slot
                                        @field(data, field.name) = @as(field.type, @intCast(op.imm));
                                    },
                                    else => unreachable,
                                }
                            }
                        }
                        // assert other slots are none
                        inline for (ops[structInfo.fields.len..]) |op| _ = op.none;
                        return @unionInit(Instruction.Data, fmt.name, data);
                    },
                    else => unreachable,
                }
            }
        }
        unreachable;
    }

    pub fn encode(inst: Inst) u32 {
        const opcode, const format = inst.tag.enc();
        const instruction = Instruction{
            .opcode = opcode,
            .data = Inst.fillData(format, inst.ops),
        };
        return instruction.enc();
    }
};

test "instruction encoding" {
    try expectEqual(0x02c02808, (Inst{ .tag = .addi_d, .ops = .{
        .{ .reg = .r8 },
        .{ .reg = .r0 },
        .{ .imm = 10 },
        .none,
    } }).encode());
    try expectEqual(0x01140841, (Inst{ .tag = .fabs_d, .ops = .{
        .{ .reg = .f1 },
        .{ .reg = .f2 },
        .none,
        .none,
    } }).encode());
    try expectEqual(0x002a0000, (Inst{ .tag = .@"break", .ops = .{
        .{ .imm = 0 },
        .none,
        .none,
        .none,
    } }).encode());
    try expectEqual(0x00160c41, (Inst{ .tag = .orn, .ops = .{
        .{ .reg = .r1 },
        .{ .reg = .r2 },
        .{ .reg = .r3 },
        .none,
    } }).encode());
}
