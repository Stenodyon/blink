pub const Direction = enum
{
    UP,
    DOWN,
    LEFT,
    RIGHT
};

pub fn dir_angle(direction: Direction) f64
{
    switch (direction)
    {
        Direction.LEFT => return 0,
        Direction.DOWN => return 90,
        Direction.RIGHT => return 180,
        Direction.UP => return  270,
    }
}

pub const Entity = union(enum)
{
    Block,
    Laser: Direction,
};
