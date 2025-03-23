/// ABI related stuff for LoongArch64.
const std = @import("std");
const assert = std.debug.assert;
const bits = @import("bits.zig");
const Register = bits.Register;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;
const Type = @import("../../Type.zig");
const Zcu = @import("../../Zcu.zig");

pub const RegisterClass = enum {
    /// Basic integer registers
    int,
    /// FP/LSX/LASX registers
    fp_vec,
};

pub const Registers = struct {
    pub const all_allocatable_regs = Integer.all_regs ++ FpVec.all_regs;
    pub const all_temporary = Integer.temporary_regs ++ FpVec.temporary_regs;
    pub const all_static = Integer.static_regs ++ FpVec.static_regs;

    pub const Integer = struct {
        pub const all_regs = ret_addr_regs ++ function_arg_regs ++ temporary_regs ++ static_regs;

        pub const ret_addr_regs = [_]Register{.r1};
        pub const function_arg_regs = [_]Register{ .r4, .r5, .r6, .r7, .r8, .r9, .r10, .r11 };
        pub const function_ret_regs = [_]Register{ .r4, .r5 };
        pub const temporary_regs = [_]Register{ .r12, .r13, .r14, .r15, .r16, .r17, .r18, .r19, .r20 };
        pub const static_regs = [_]Register{ .r22, .r23, .r24, .r25, .r26, .r27, .r28, .r29, .r30, .r31 };
    };

    pub const FpVec = struct {
        pub const all_regs = function_arg_regs ++ temporary_regs ++ static_regs;

        pub const function_arg_regs = [_]Register{ .x0, .x1, .x2, .x3, .x4, .x5, .x6, .x7 };
        pub const function_ret_regs = [_]Register{ .x0, .x1 };
        // zig fmt: off
        pub const temporary_regs = [_]Register{
            .x8, .x9, .x10, .x11, .x12, .x13, .x14, .x15,
            .x16, .x17, .x18, .x19, .x20, .x21, .x22, .x23,
        };
        // zig fmt: on
        pub const static_regs = [_]Register{ .x24, .x25, .x26, .x27, .x28, .x29, .x30, .x31 };
    };
};

pub const RegisterManager = RegisterManagerFn(@import("CodeGen.zig"), Register, &Registers.all_allocatable_regs);
