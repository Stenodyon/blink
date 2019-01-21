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

        pub fn add(a: Self, b: Self) Self
        {
            return Self.new(a.x + b.x, a.y + b.y);
        }

        pub fn addi(a: *Self, b: Self) Self
        {
            a.x += b.x;
            a.y += b.y;
            return a.*;
        }

        pub fn sub(a: Self, b: Self) Self
        {
            return Self.new(a.x - b.x, a.y - b.y);
        }

        pub fn subi(a: *Self, b: Self) Self
        {
            a.x -= b.x;
            a.y -= b.y;
            return a.*;
        }

        pub fn neg(a: Self) Self
        {
            return Self.new(-a.x, -a.y);
        }

        pub fn mul(self: Self, scalar: i32) Self
        {
            return Vec2i.new(self.x * scalar, self.y * scalar);
        }

        pub fn muli(self: *Self, scalar: i32) Self
        {
            self.x *= scalar;
            self.y *= scalar;
            return self.*;
        }

        pub fn div(self: Self, scalar: i32) Self
        {
            return Vec2i.new(
                @divFloor(self.x, scalar),
                @divFloor(self.y, scalar));
        }

        pub fn divi(self: Self, scalar: i32) Self
        {
            self.x = @divFloor(self.x, scalar);
            self.y = @divFloor(self.y, scalar);
            return self;
        }

        pub fn mod(self: Self, scalar: i32) Self
        {
            return Vec2i.new(
                    @mod(self.x, scalar),
                    @mod(self.y, scalar));
        }

        pub fn modi(self: *Self, scalar: i32) Self
        {
            self.x = @mod(self.x, scalar);
            self.y = @mod(self.y, scalar);
            return self.*;
        }

        pub fn negi(a: Self) Self
        {
            a.x = -a.x;
            a.y = -a.y;
            return a;
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

    pub fn translate(self: *Rect, vec: Vec2i) Rect
    {
        self.pos.addi(vec);
        return self;
    }

    pub fn translated(self: *const Rect, vec: Vec2i) Rect
    {
        return Rect
        {
            .pos = self.pos.add(vec),
            .size = self.size,
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
