const generics = @import("generics.zig");
const presets = @import("presets.zig");

pub const Arc = generics.Arc;
pub const AnyArc = presets.AnyArc;
pub const Interface = @import("Interface.zig");

test {
    _ = generics;
    _ = presets;
}
