const std   = @import("std");
const sdl   = @import("sdl.zig");

const State = @import("state.zig").State;
const vec   = @import("vec.zig");
const Vec2i = vec.Vec2i;
const Rect  = vec.Rect;

pub const SCREEN_WIDTH  = 640;
pub const SCREEN_HEIGHT = 480;

pub const GUI_Element = struct
{
    draw: fn(self: *GUI_Element, renderer: sdl.Renderer) void,
    resize: fn(self: *GUI_Element) void,
    screen_area: Rect,

    hovered: bool,

    pub fn compute_hovered(self: *GUI_Element, mouse_x: i32, mouse_y: i32) void
    {
        self.hovered = self.screen_area.contains(
            Vec2i{.x = mouse_x, .y = mouse_y});
    }
};

pub const GUI_Button = struct
{
    base: GUI_Element,

    pub fn new() GUI_Button
    {
        return GUI_Button
        {
            .base = GUI_Element
            {
                .draw = GUI_Button.draw,
                .resize = GUI_Button.resize,
                .screen_area = Rect
                {
                    .pos = Vec2i.new(10, 20),
                    .size = Vec2i.new(100, 50),
                },
                .hovered = false,
            },
        };
    }

    fn draw(base: *GUI_Element, renderer: sdl.Renderer) void
    {
        var self = @fieldParentPtr(GUI_Button, "base", base);

        _ = sdl.SetRenderDrawColor(renderer, 0x7F, 0x7F, 0x7F, 0xFF);
        _ = sdl.RenderFillRect(renderer, base.screen_area);
    }

    fn resize(base: *GUI_Element) void
    {
        var self = @fieldParentPtr(GUI_Button, "base", base);
    }
};

pub var g_gui: *GUI_Element = undefined;

pub fn render(renderer: sdl.Renderer, state: *const State) void
{
    _ = sdl.SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xFF);
    _ = sdl.RenderClear(renderer);

    g_gui.draw(g_gui, renderer);

    sdl.RenderPresent(renderer);
}

pub fn on_mouse_motion(x: i32, y: i32, x_rel: i32, y_rel: i32) void
{
    g_gui.compute_hovered(x, y);
}

pub fn on_mouse_button_up(button: u8, x: i32, y: i32) void
{
}

pub fn on_mouse_button_down(button: u8, x: i32, y: i32) void
{
}
