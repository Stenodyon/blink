const std = @import("std");
const math = std.math;
const assert = std.debug.assert;

// Ensures a < b
pub fn min_order(a: var, b: @typeOf(a)) void {
    if (b.* < a.*) {
        const tmp = b.*;
        b.* = a.*;
        a.* = tmp;
    }
}

test "min_order <" {
    var a: i32 = 2;
    var b: i32 = 5;
    min_order(&a, &b);
    assert(a == 2);
    assert(b == 5);
}

test "min_order >" {
    var a: i32 = 5;
    var b: i32 = 2;
    min_order(&a, &b);
    assert(a == 2);
    assert(b == 5);
}

pub fn clamp(comptime T: type, value: *T, min: T, max: T) void {
    value.* = math.max(min, math.min(max, value.*));
}
