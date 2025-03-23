//! Machine Intermediate Representation.
//! This data is produced by CodeGen.zig

const Mir = @This();
const std = @import("std");
const IntegerBitSet = std.bit_set.IntegerBitSet;

const bits = @import("bits.zig");
const Register = bits.Register;
const Lir = @import("Lir.zig");
const Instruction = @import("Instruction.zig");
const InternPool = @import("../../InternPool.zig");

instructions: std.MultiArrayList(Inst).Slice,
frame_locs: std.MultiArrayList(FrameLoc).Slice,

pub const Inst = struct {
    tag: Tag,
    /// The meaning of this depends on `tag`.
    data: Data,

    pub const Index = u32;

    pub const Tag = enum {
        /// Generic machine instruction, uses `inst` payload.
        inst,
        /// Conditional jumps, uses `condbr` payload.
        beq,
        bne,
        blt,
        bgt,
        bltu,
        bgtu,
        /// Unconditional in-function jumps, uses `mir_ref` payload.
        jump,
        /// Inter-function calls, uses `func_ref` payload.
        call,
        /// Spills general-purpose registers, uses `reg_list` payload.
        spill_gp_regs,
        /// Restores general-purpose registers, uses `reg_list` payload.
        restore_gp_regs,
    };

    pub const Data = union(enum) {
        none,
        /// Generic machine instruction.
        inst: Lir.Inst,
        /// Reference to another MIR instruction.
        mir_ref: Inst.Index,
        /// Reference to another function.
        func_ref: InternPool.Index,
        /// Register list.
        reg_list: Mir.RegisterList,
        /// Conditional jumps.
        condbr: struct {
            rj: Register,
            rd: Register,
            inst: Inst.Index,
        },
        /// Debug line and column position.
        line_column: struct {
            line: u32,
            column: u32,
        },
    };

    pub fn inst(opcode: Instruction.OpCode, ops: [4]Lir.Inst.Operand) Inst {
        return .{ .tag = .inst, .data = .{ .inst = Lir.Inst{ .tag = opcode, .ops = ops } } };
    }
};

pub fn deinit(mir: *Mir, gpa: std.mem.Allocator) void {
    mir.instructions.deinit(gpa);
    mir.frame_locs.deinit(gpa);
    mir.* = undefined;
}

pub const FrameLoc = struct {
    base: Register,
    offset: i32,
};

pub fn resolveFrameAddr(mir: Mir, frame_addr: bits.FrameAddr) bits.RegisterOffset {
    const frame_loc = mir.frame_locs.get(@intFromEnum(frame_addr.index));
    return .{ .reg = frame_loc.base, .off = frame_loc.disp + frame_addr.off };
}

/// Used in conjunction with payload to transfer a list of used registers in a compact manner.
pub const RegisterList = struct {
    bitset: BitSet,

    const BitSet = IntegerBitSet(32);
    const Self = @This();

    pub const empty: RegisterList = .{ .bitset = .initEmpty() };

    fn getIndexForReg(registers: []const Register, reg: Register) BitSet.MaskInt {
        for (registers, 0..) |cpreg, i| {
            if (reg.id() == cpreg.id()) return @intCast(i);
        }
        unreachable; // register not in input register list!
    }

    pub fn push(self: *Self, registers: []const Register, reg: Register) void {
        const index = getIndexForReg(registers, reg);
        self.bitset.set(index);
    }

    pub fn isSet(self: Self, registers: []const Register, reg: Register) bool {
        const index = getIndexForReg(registers, reg);
        return self.bitset.isSet(index);
    }

    pub fn iterator(self: Self, comptime options: std.bit_set.IteratorOptions) BitSet.Iterator(options) {
        return self.bitset.iterator(options);
    }

    pub fn count(self: Self) i32 {
        return @intCast(self.bitset.count());
    }

    pub fn size(self: Self, target: *const std.Target) i32 {
        return @intCast(self.bitset.count() * @as(u4, switch (target.cpu.arch) {
            else => unreachable,
            .loongarch32 => 4,
            .loongarch64 => 8,
        }));
    }
};
