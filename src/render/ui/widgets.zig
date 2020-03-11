const std = @import("std");
const Allocator = std.mem.Allocator;

const layout = @import("layout.zig");
const Event = @import("events.zig").Event;
const renderer = @import("renderer.zig");
usingnamespace @import("../../vec.zig");

pub const Widget = struct {
    const Error = error{OutOfMemory};

    node: layout.Node,
    renderFn: fn (*Widget) Error!void = noRender,
    handleEventFn: fn (*Widget, *const Event) void = noHandleEvent,

    mouseHovering: bool = false,

    pub fn setChildren(
        self: *Widget,
        allocator: *Allocator,
        children: []*Widget,
    ) !void {
        self.node.children = try allocator.alloc(*layout.Node, children.len);
        for (children) |child, i| {
            self.node.children[i] = &child.node;
        }
    }

    pub fn deinit(self: *const Widget, allocator: *Allocator) void {
        for (self.node.children) |child| {
            const child_widget = @fieldParentPtr(Widget, "node", child);
            child_widget.deinit();
        }
        allocator.free(self.node.children);
    }

    pub fn computeLayout(self: *Widget, window: Recti) void {
        layout.compute(&self.node, window);
    }

    pub fn render(self: *Widget) Error!void {
        try self.renderFn(self);

        for (self.node.children) |child| {
            const childWidget = @fieldParentPtr(Widget, "node", child);
            try childWidget.render();
        }
    }

    // TODO: filter events (allow widgets to filter events before them being
    // sent to children and allow children to capture events that won't be
    // captured by parents).
    pub fn handleEvent(self: *Widget, event: *const Event) void {
        switch (event.*) {
            .MouseEnter => {
                self.mouseHovering = true;
                return;
            },
            .MouseExit => {
                self.mouseHovering = false;
                return;
            },
            else => {},
        }

        for (self.node.children) |child| {
            var childWidget = @fieldParentPtr(Widget, "node", child);
            childWidget.handleEvent(event);

            switch (event.*) {
                .MouseMovement => |movement| {
                    const mouseInside = childWidget.node.loc.contains(
                        Vec2i.new(
                            movement.newX,
                            movement.newY,
                        ),
                    );

                    if (!childWidget.mouseHovering and mouseInside) {
                        const enterEvent: Event = .MouseEnter;
                        childWidget.handleEventFn(childWidget, &enterEvent);
                    }
                    if (childWidget.mouseHovering and !mouseInside) {
                        const exitEvent: Event = .MouseExit;
                        childWidget.handleEventFn(childWidget, &exitEvent);
                    }
                },
                else => {},
            }
        }

        self.handleEventFn(self, event);
    }

    fn noRender(self: *Widget) Error!void {}
    fn noHandleEvent(self: *Widget, event: *const Event) void {}
};

pub const FillerWidget = struct {
    widget: Widget,

    pub fn newDefault() FillerWidget {
        return .{
            .widget = .{
                .node = .{},
            },
        };
    }

    pub fn new(weight: i32) FillerWidget {
        return .{
            .widget = .{
                .node = .{
                    .weight = weight,
                },
                .renderFn = render,
                .handleEventFn = handleEvents,
            },
        };
    }
};

const Orientation = enum {
    Horizontal,
    Vertical,
};

fn LinearLayout(comptime orientation: Orientation) type {
    return struct {
        const Self = @This();

        widget: Widget,

        pub fn new() Self {
            return .{
                .widget = .{
                    .node = .{
                        .childrenOrder = switch (orientation) {
                            .Horizontal => .Row,
                            .Vertical => .Column,
                        },
                    },
                },
            };
        }

        pub fn setChildren(
            self: *Self,
            allocator: *Allocator,
            children: []*Widget,
        ) !void {
            try self.widget.setChildren(allocator, children);
        }
    };
}

pub const HBox = LinearLayout(.Horizontal);
pub const VBox = LinearLayout(.Vertical);

pub const FrameWidget = struct {
    widget: Widget,

    pub fn new() FrameWidget {
        return .{
            .widget = .{
                .node = .{},
                .renderFn = render,
            },
        };
    }

    fn render(self_widget: *Widget) !void {
        try renderer.queue_element(
            self_widget.node.loc.to_float(f32),
            if (self_widget.mouseHovering)
                renderer.id.background_hover
            else
                renderer.id.background,
        );
    }
};
