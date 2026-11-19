const std = @import("std");
const generics = @import("generics.zig");
const presets = @import("presets.zig");

pub const Arc = generics.Arc;
pub const AnyArc = presets.AnyArc;
pub const Interface = @import("Interface.zig");

pub const super_flag = "__super__";

/// 判断任意输入（类型或值，如数字）是否为 Arc。
pub fn isArc(comptime input: anytype) bool {
    // 输入本身是类型就直接使用，否则取值的类型（数字等值会落到非 struct 分支）
    const T = if (@TypeOf(input) == type) input else @TypeOf(input);

    // 只有 struct 才可能是 Arc，其余一律返回 false（@hasDecl 对数字等类型会编译报错）
    if (@typeInfo(T) != .@"struct") return false;

    return @hasDecl(T, super_flag) and @field(T, super_flag) == .arc;
}

const testing = std.testing;

test {
    try testing.expect(isArc(struct {
        pub const __super__ = .arc;
    }));
    try testing.expect(!isArc(enum {}));
    try testing.expect(!isArc(union {}));
    try testing.expect(!isArc(union(enum) {}));
    try testing.expect(!isArc(struct {}));
    try testing.expect(!isArc(1));
    try testing.expect(!isArc(u32));
    try testing.expect(!isArc(@as(f32, 1.5)));

    _ = generics;
    _ = presets;
}
