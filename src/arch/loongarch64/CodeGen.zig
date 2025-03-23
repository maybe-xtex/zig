const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

const codegen = @import("../../codegen.zig");
const link = @import("../../link.zig");
const log = std.log.scoped(.codegen);
const tracking_log = std.log.scoped(.tracking);
const wip_mir_log = std.log.scoped(.wip_mir);

const Air = @import("../../Air.zig");
const Liveness = @import("../../Liveness.zig");
const Mir = @import("Mir.zig");
const Zcu = @import("../../Zcu.zig");
const Module = @import("../../Package/Module.zig");
const InternPool = @import("../../InternPool.zig");
const Type = @import("../../Type.zig");
const Value = @import("../../Value.zig");

const abi = @import("abi.zig");
const bits = @import("bits.zig");
const Instruction = @import("Instruction.zig");

const Register = bits.Register;
const RegisterManager = abi.RegisterManager;
const RegisterLock = RegisterManager.RegisterLock;
const FrameIndex = bits.FrameIndex;

const InnerError = codegen.CodeGenError || error{OutOfRegisters};

gpa: Allocator,
pt: Zcu.PerThread,
air: Air,
liveness: Liveness,
bin_file: *link.File,
debug_output: link.File.DebugInfoOutput,
target: *const std.Target,
owner: Owner,
inline_func: InternPool.Index,
mod: *Module,
fn_type: Type,

src_loc: Zcu.LazySrcLoc,

/// MIR Instructions
mir_instructions: std.MultiArrayList(Mir.Inst) = .empty,

/// Byte offset within the source file of the ending curly.
end_di_line: u32,
end_di_column: u32,

inst_tracking: InstTrackingMap = .empty,

// Key is the block instruction
blocks: std.AutoHashMapUnmanaged(Air.Inst.Index, BlockData) = .empty,

register_manager: RegisterManager = .{},

/// Generation of the current scope, increments by 1 for every entered scope.
scope_generation: u32 = 0,

frame_allocs: std.MultiArrayList(FrameAlloc) = .empty,
free_frame_indices: std.AutoArrayHashMapUnmanaged(FrameIndex, void) = .empty,
frame_locs: std.MultiArrayList(Mir.FrameLoc) = .empty,

const Owner = union(enum) {
    nav_index: InternPool.Nav.Index,
    lazy_sym: link.File.LazySymbol,

    fn getSymbolIndex(owner: Owner, ctx: *CodeGen) !u32 {
        const pt = ctx.pt;
        switch (owner) {
            .nav_index => |nav_index| if (ctx.bin_file.cast(.elf)) |elf_file| {
                return elf_file.zigObjectPtr().?.getOrCreateMetadataForNav(pt.zcu, nav_index);
            } else unreachable,
            .lazy_sym => |lazy_sym| if (ctx.bin_file.cast(.elf)) |elf_file| {
                return elf_file.zigObjectPtr().?.getOrCreateMetadataForLazySymbol(elf_file, pt, lazy_sym) catch |err|
                    ctx.fail("{s} creating lazy symbol", .{@errorName(err)});
            } else unreachable,
        }
    }
};

const InstTrackingMap = std.AutoArrayHashMapUnmanaged(Air.Inst.Index, InstTracking);
