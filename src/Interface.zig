const std = @import("std");
const Allocator = std.mem.Allocator;
const helper = @import("helper.zig");
const Self = @This();

/// 由数据的适配者提供：如何深克隆、如何释放这类数据。
pub const VTable = struct {
    /// 深克隆 `src`，返回新数据的指针。内存由这个函数用 allocator 自行分配。
    clone: *const fn (allocator: Allocator, src: *const anyopaque) Allocator.Error!*anyopaque,
    /// 释放一份由 `clone` 产出的数据（数据持有的资源 + 数据本体的内存）。
    release: *const fn (allocator: Allocator, data: *anyopaque) void,

    /// 输入 T 自动生成 VTable。
    pub fn from(comptime T: type) *const VTable {
        comptime helper.requireCloneable(T);

        const Impl = struct {
            fn clone(allocator: Allocator, src: *const anyopaque) Allocator.Error!*anyopaque {
                const self: *const T = @ptrCast(@alignCast(src));
                const dst = try allocator.create(T);
                errdefer allocator.destroy(dst);
                dst.* = try self.clone(allocator);
                return dst;
            }

            fn release(allocator: Allocator, data: *anyopaque) void {
                const self: *T = @ptrCast(@alignCast(data));
                self.release(allocator);
                allocator.destroy(self);
            }
        };
        const vtable: VTable = .{ .clone = Impl.clone, .release = Impl.release };

        return &vtable;
    }
};

ptr: *const anyopaque,
vtable: *const VTable,

pub fn clone(self: *const Self, allocator: Allocator) Allocator.Error!Self {
    return .{
        .ptr = try self.vtable.clone(allocator, self.ptr),
        .vtable = self.vtable,
    };
}

pub fn release(self: *Self, allocator: Allocator) void {
    self.vtable.release(allocator, @constCast(self.ptr));
}
