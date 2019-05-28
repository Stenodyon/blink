pub const Direction = enum
{
    UP,
    DOWN,
    LEFT,
    RIGHT
};

pub const clockwise_directions = []Direction{
    .UP,
    .RIGHT,
    .DOWN,
    .LEFT,
};

pub fn clockwise_index(direction: Direction) i32 {
    switch (direction) {
        .UP    => return 0,
        .RIGHT => return 1,
        .DOWN  => return 2,
        .LEFT  => return 3,

    }
}

pub fn dir_angle(direction: Direction) f64
{
    switch (direction)
    {
        .UP    => return 270,
        .DOWN  => return 90,
        .LEFT  => return 180,
        .RIGHT => return 0,
    }
}

pub const Entity = union(enum)
{
    Block,
    Laser: Direction,
};
