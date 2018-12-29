const sdl = @import("sdl.zig");

fn Vec2(comptime ValType: type) type
{
    return struct
    {
        x: ValType,
        y: ValType,

        const Self = @This();

        pub fn new(_x: ValType, _y: ValType) Self
        {
            return Self
            {
                .x = _x,
                .y = _y,
            };
        }

        pub fn equals(a: Self, b: Self) bool
        {
            return a.x == b.x and a.y == b.y;
        }

        pub fn hash(vec: Self) u32
        {
            var seed: u32 = 2;
            seed ^= @bitCast(u32, vec.x) +% 0x9e3779b9 +% (seed << 6) +% (seed >> 2);
            seed ^= @bitCast(u32, vec.y) +% 0x9e3779b9 +% (seed << 6) +% (seed >> 2);
            return seed;
        }
    };
}

pub const Vec2i = Vec2(i32);
pub const Vec2f = Vec2(f64);

pub const Rect = struct
{
    pos: Vec2i,
    size: Vec2i,

    pub fn new(_pos: Vec2i, _size: Vec2i) Rect
    {
        return Rect 
        {
            .pos = _pos,
            .size = _size,
        };
    }

    pub fn contains(self: *Rect, point: Vec2i) bool
    {
        return point.x >= self.pos.x
            and point.x < (self.pos.x + self.size.x)
            and point.y >= self.pos.y
            and point.y < (self.pos.y + self.size.y);
    }

    pub fn to_sdl(self: Rect) sdl.Rect
    {
        return sdl.Rect
        {
            .x = self.pos.x,
            .y = self.pos.y,
            .w = self.size.x,
            .h = self.size.y,
        };
    }
};
