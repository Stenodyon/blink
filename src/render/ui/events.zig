pub const MouseButton = enum {
    Left,
    Right,
    Middle,
    // TODO: More?
};

pub const Event = union(enum) {
    MouseClick: MouseClickEvent,
    MouseMovement: MouseMovementEvent,
    MouseEnter,
    MouseExit,

    pub const MouseClickEvent = struct {
        x: i32,
        y: i32,
        button: MouseButton,
    };

    pub const MouseMovementEvent = struct {
        newX: i32,
        newY: i32,
        prevX: i32,
        prevY: i32,
    };
};
