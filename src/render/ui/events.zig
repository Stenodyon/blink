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
        x: usize,
        y: usize,
        button: MouseButton,
    };

    pub const MouseMovementEvent = struct {
        newX: usize,
        newY: usize,
        prevX: usize,
        prevY: usize,
    };
};
