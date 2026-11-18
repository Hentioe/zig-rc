const std = @import("std");
const Allocator = std.mem.Allocator;
const Arc = @import("generics.zig").Arc;
pub const Interface = @import("Interface.zig");
pub const VTable = Interface.VTable;

pub const AnyArc = struct {
    rc: Arc(Interface),

    /// 深克隆 `src`，内部 Arc 拥有数据拷贝。初始计数为 `1`。
    pub fn new(allocator: Allocator, ptr: anytype) Allocator.Error!AnyArc {
        const P = @TypeOf(ptr);
        const info = @typeInfo(P);

        comptime {
            if (info != .pointer or info.pointer.size != .one) {
                @compileError("AnyArc.new expects a single-item pointer (*T or *const T), found '" ++ @typeName(P) ++ "'");
            }
        }

        const T = info.pointer.child;
        const interface = Interface{
            .ptr = ptr,
            .vtable = Interface.VTable.from(T),
        };
        return .{
            .rc = try Arc(Interface).new(allocator, &interface),
        };
    }

    /// 增加共享引用计数；如需多个句柄，调用方可以自行复制。
    pub fn retain(self: *const AnyArc) void {
        self.rc.retain();
    }

    /// 将引用释放操作委托给内部通用 Rc。
    pub fn release(self: *const AnyArc, allocator: Allocator) void {
        self.rc.release(allocator);
    }

    /// 查询内部 Arc 的共享引用数。
    pub fn strongCount(self: *const AnyArc) usize {
        return self.rc.strongCount();
    }

    /// 查询内部 Arc 是否拥有克隆后的接口值。
    pub fn isOwned(self: *const AnyArc) bool {
        return self.rc.isOwned();
    }

    /// 按创建接口值时对应的具体类型取回只读指针。
    pub fn get(self: *const AnyArc, comptime T: type) *const T {
        return @ptrCast(@alignCast(self.rc.get().ptr));
    }
};

// -- tests --
const testing = std.testing;

/// 持有堆内存的示例类型，用来验证深克隆与释放。
const Person = struct {
    name: []u8,
    age: u32,

    fn init(allocator: Allocator, name: []const u8, age: u32) !Person {
        return .{ .name = try allocator.dupe(u8, name), .age = age };
    }

    pub fn clone(self: *const Person, allocator: Allocator) Allocator.Error!Person {
        return .{ .name = try allocator.dupe(u8, self.name), .age = self.age };
    }

    pub fn release(self: *Person, allocator: Allocator) void {
        allocator.free(self.name);
    }
};

test "AnyArc delegates ownership and reference counting to Arc" {
    const allocator = testing.allocator;
    var p1 = try Person.init(allocator, "Eve", 28);
    const shared_p1 = try AnyArc.new(allocator, &p1);
    try testing.expectEqual(@as(usize, 1), shared_p1.strongCount());
    // retain 只增加计数，复制后的结构体共享同一块内部数据。
    shared_p1.retain();
    const shared_p2 = shared_p1;

    p1.release(allocator);

    try testing.expectEqualStrings("Eve", shared_p2.get(Person).name);
    try testing.expectEqual(@as(usize, 2), shared_p1.strongCount());
    shared_p1.release(allocator);
    try testing.expectEqual(@as(usize, 1), shared_p2.strongCount());
    try testing.expectEqualStrings("Eve", shared_p2.get(Person).name);
    shared_p2.release(allocator);
}
