pub const Direction = enum
{
    UP,
    DOWN,
    LEFT,
    RIGHT
};

pub const Entity = union(enum)
{
    Block,
    Laser: Direction,
};
