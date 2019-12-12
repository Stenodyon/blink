const State = @import("state.zig").State;
const Rectf = @import("vec.zig").Rectf;

pub const MouseClickEvent = struct {
    button: u8,
    x: i32,
    y: i32,
};

pub const UIEvent = union(enum) {
    MouseClick: MouseClickEvent,
    MouseEnter,
    MouseExit,
};

// Convention: each UI widget has a `widget` field that contains the Widget
pub const Widget = struct {
    area: Rectf,
    handle_eventFn: fn (self: *Widget, state: *State, event: *UIEvent) void,
    updateFn: fn (self: *Widget, state: *State) void,
    paintFn: fn (self: *Widget, state: *State) void,
};

pub const Frame = struct {
    widget: Widget,
    child: ?*Widget,

    pub fn new(x: f32, y: f32, width: f32, height: f32, child: ?*Widget) Frame {
        return Frame{
            .widget = Widget{
                .area = Rectf.new(x, y, width, height),
                .handle_eventFn = handle_event,
                .updateFn = update,
                .paintFn = paint,
            },
            .child = child,
        };
    }

    fn handle_event(widget: *Widget, state: *State, event: *UIEvent) void {
        var self = @fieldParentPtr(Frame, "widget", widget);
    }

    fn update(widget: *Widget, state: *State) void {
        var self = @fieldParentPtr(Frame, "widget", widget);
    }

    fn paint(widget: *Widget, state: *State) void {
        var self = @fieldParentPtr(Frame, "widget", widget);
    }
};
