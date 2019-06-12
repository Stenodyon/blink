const std = @import("std");
const math = std.math;
const assert = std.debug.assert;

const sdl = @import("sdl.zig");

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

pub fn key_value(keycode: i32) i32 {
    return keycode - sdl.K_0;
}

pub fn slot_value(keycode: i32) i32 {
    return @mod(key_value(keycode) - 1, 10);
}

pub fn c_to_slice(cstring: [*]const u8) []const u8 {
    var count: usize = 0;
    while (cstring[count] != 0) count += 1;
    return cstring[0..count];
}
