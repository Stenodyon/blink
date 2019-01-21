const assert = @import("std").debug.assert;

// Ensures a < b
pub fn min_order(a: var, b: @typeOf(a)) void
{
    if (b.* < a.*)
    {
        const tmp = b.*;
        b.* = a.*;
        a.* = tmp;
    }
}

test "min_order <"
{
    var a: i32 = 2;
    var b: i32 = 5;
    min_order(&a, &b);
    assert(a == 2);
    assert(b == 5);
}

test "min_order >"
{
    var a: i32 = 5;
    var b: i32 = 2;
    min_order(&a, &b);
    assert(a == 2);
    assert(b == 5);
}

pub fn min(a: var, b: @typeOf(a)) @typeOf(a)
{
    return if (a < b) a else b;
}

pub fn max(a: var, b: @typeOf(a)) @typeOf(a)
{
    return if (a > b) a else b;
}

test "min"
{
    assert(min(2, 5) == 2);
    assert(min(5, 2) == 2);
}

test "max"
{
    assert(max(2, 5) == 5);
    assert(max(5, 2) == 5);
}
