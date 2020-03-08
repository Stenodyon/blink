const std = @import("std");
const Allocator = std.mem.Allocator;

const layout = @import("layout.zig");
usingnamespace @import("../../vec.zig");

// TODO: move that and Event to its own file
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

pub const Widget = struct {
    node: layout.Node,

    renderFn: fn (*Widget) void,
    handleEventFn: fn (*Widget, *Event) void,

    pub fn setChildren(
        self: *Widget,
        allocator: *Allocator,
        children: []*Widget,
    ) !void {
        try allocator.alloc(Node, children.len);
        for (children) |child, i| {
            self.node.children[i] = &child.node;
        }
    }

    pub fn computeLayout(self: *Widget, window: Rect(usize)) void {
        layout.compute(&self.node, window);
    }

    pub fn render(self: *Widget) void {
        self.renderFn(self);

        for (self.node.children) |child| {
            const childWidget = @fieldParentPtr(Widget, "node", child);
            childWidget.render();
        }
    }

    // TODO: filter events (allow widgets to filter events before them being
    // sent to children and allow children to capture events that won't be
    // captured by parents).
    pub fn handleEvent(self: *Widget, event: *Event) void {
        for (self.node.children) |child| {
            const childWidget = @fieldParentPtr(Widget, "node", child);
            childWidget.handleEvent(event);
        }

        self.handleEventFn(self, event);
    }
};
