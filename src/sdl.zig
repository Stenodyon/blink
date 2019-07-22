const c = @import("c.zig");
const vec = @import("vec.zig");

pub const INIT_VIDEO = c.SDL_INIT_VIDEO;

pub const Init = c.SDL_Init;
pub const GetError = c.SDL_GetError;
pub const Quit = c.SDL_Quit;
pub const Delay = c.SDL_Delay;

// Windows
pub const Window = ?*c.struct_SDL_Window;
pub const Surface = ?*c.struct_SDL_Surface;

pub const WINDOWPOS_UNDEFINED = c.SDL_WINDOWPOS_UNDEFINED_MASK | 0;

pub const WINDOW_FULLSCREEN = c.SDL_WINDOW_FULLSCREEN;
pub const WINDOW_FULLSCREEN_DESKTOP = c.SDL_WINDOW_FULLSCREEN_DESKTOP;
pub const WINDOW_OPENGL = c.SDL_WINDOW_OPENGL;
pub const WINDOW_SHOWN = c.SDL_WINDOW_SHOWN;
pub const WINDOW_HIDDEN = c.SDL_WINDOW_HIDDEN;
pub const WINDOW_BORDERLESS = c.SDL_WINDOW_BORDERLESS;
pub const WINDOW_RESIZABLE = c.SDL_WINDOW_RESIZABLE;
pub const WINDOW_MINIMIZED = c.SDL_WINDOW_MINIMIZED;
pub const WINDOW_MAXIMIZED = c.SDL_WINDOW_MAXIMIZED;
pub const WINDOW_INPUT_GRABBED = c.SDL_WINDOW_INPUT_GRABBED;
pub const WINDOW_INPUT_FOCUS = c.SDL_WINDOW_INPUT_FOCUS;
pub const WINDOW_MOUSE_FOCUS = c.SDL_WINDOW_MOUSE_FOCUS;
pub const WINDOW_FOREIGN = c.SDL_WINDOW_FOREIGN;
pub const WINDOW_ALLOW_HIGHDPI = c.SDL_WINDOW_ALLOW_HIGHDPI;
pub const WINDOW_MOUSE_CAPTURE = c.SDL_WINDOW_MOUSE_CAPTURE;
pub const WINDOW_ALWAYS_ON_TOP = c.SDL_WINDOW_ALWAYS_ON_TOP;
pub const WINDOW_SKIP_TASKBAR = c.SDL_WINDOW_SKIP_TASKBAR;
pub const WINDOW_UTILITY = c.SDL_WINDOW_UTILITY;
pub const WINDOW_TOOLTIP = c.SDL_WINDOW_TOOLTIP;
pub const WINDOW_POPUP_MENU = c.SDL_WINDOW_POPUP_MENU;

pub fn FreeSurface(surface: Surface) void {
    c.SDL_FreeSurface(@ptrCast(?[*]c.struct_SDL_Surface, surface));
}

pub const CreateWindow = c.SDL_CreateWindow;
pub const DestroyWindow = c.SDL_DestroyWindow;

pub const GetWindowSurface = c.SDL_GetWindowSurface;
pub const UpdateWindowSurface = c.SDL_UpdateWindowSurface;

// Renderers
pub const Renderer = ?*c.struct_SDL_Renderer;
pub const Texture = ?*c.struct_SDL_Texture;

pub const RENDERER_ACCELERATED = c.SDL_RENDERER_ACCELERATED;
pub const RENDERER_PRESENT_VSYNC = c.SDL_RENDERER_PRESENTVSYNC;

pub const CreateRenderer = c.SDL_CreateRenderer;
pub const DestroyRenderer = c.SDL_DestroyRenderer;

pub const CreateTexture = c.SDL_CreateTexture;
pub fn CreateTextureFromSurface(renderer: Renderer, surface: Surface) Texture {
    return c.SDL_CreateTextureFromSurface(
        renderer,
        @ptrCast(?[*]c.struct_SDL_Surface, surface),
    );
}
pub const DestroyTexture = c.SDL_DestroyTexture;

pub const SetRenderDrawColor = c.SDL_SetRenderDrawColor;
pub const RenderClear = c.SDL_RenderClear;
pub const RenderDrawLine = c.SDL_RenderDrawLine;

pub fn RenderCopy(
    renderer: Renderer,
    texture: Texture,
    dest: ?vec.Rect,
    src: ?vec.Rect,
) c_int {
    const sdl_dest = if (dest) |r| r.to_sdl() else null;
    const sdl_src = if (src) |r| r.to_sdl() else null;
    return c.SDL_RenderCopy(
        renderer,
        texture,
        @ptrCast(?[*]const Rect, &sdl_dest),
        @ptrCast(?[*]const Rect, &sdl_src),
    );
}

pub fn RenderCopyEx(
    renderer: Renderer,
    texture: Texture,
    dest: ?vec.Rect,
    src: ?vec.Rect,
    angle: f64,
    center: ?*vec.Vec2i,
    flip: RendererFlip,
) c_int {
    const sdl_dest = if (dest) |r| r.to_sdl() else null;
    const sdl_src = if (src) |r| r.to_sdl() else null;
    const sdl_center = if (center) |p| p.to_sdl() else null;
    return c.SDL_RenderCopyEx(
        renderer,
        texture,
        @ptrCast(?[*]const Rect, &sdl_dest),
        @ptrCast(?[*]const Rect, &sdl_src),
        angle,
        @ptrCast(?[*]const Point, &sdl_center),
        flip,
    );
}

pub fn RenderFillRect(renderer: Renderer, rect: ?vec.Rect) c_int {
    const sdl_rect: ?Rect = if (rect) |r| r.to_sdl() else null;
    return c.SDL_RenderFillRect(
        renderer,
        @ptrCast(?[*]const Rect, &sdl_rect),
    );
}

pub fn RenderDrawRect(renderer: Renderer, rect: ?vec.Rect) c_int {
    const sdl_rect: ?Rect = if (rect) |r| r.to_sdl() else null;
    return c.SDL_RenderDrawRect(
        renderer,
        @ptrCast(?[*]const Rect, &sdl_rect),
    );
}

pub const RenderPresent = c.SDL_RenderPresent;

// Events
pub const Event = c.union_SDL_Event;
pub const WindowEvent = c.struct_SDL_WindowEvent;
pub const MouseMotionEvent = c.struct_SDL_MouseMotionEvent;
pub const MouseButtonEvent = c.struct_SDL_MouseButtonEvent;
pub const MouseWheelEvent = c.struct_SDL_MouseWheelEvent;
pub const KeyboardEvent = c.struct_SDL_KeyboardEvent;

//      Event types
pub const QUIT = c.SDL_QUIT;

pub const WINDOWEVENT = c.SDL_WINDOWEVENT;

pub const KEYDOWN = c.SDL_KEYDOWN;
pub const KEYUP = c.SDL_KEYUP;

pub const MOUSEBUTTONUP = c.SDL_MOUSEBUTTONUP;
pub const MOUSEBUTTONDOWN = c.SDL_MOUSEBUTTONDOWN;
pub const MOUSEMOTION = c.SDL_MOUSEMOTION;
pub const MOUSEWHEEL = c.SDL_MOUSEWHEEL;

//      Window event types

pub const WINDOWEVENT_SHOWN = c.SDL_WINDOWEVENT_SHOWN;
pub const WINDOWEVENT_HIDDEN = c.SDL_WINDOWEVENT_HIDDEN;
pub const WINDOWEVENT_EXPOSED = c.SDL_WINDOWEVENT_EXPOSED;
pub const WINDOWEVENT_MOVED = c.SDL_WINDOWEVENT_MOVED;
pub const WINDOWEVENT_RESIZED = c.SDL_WINDOWEVENT_RESIZED;
pub const WINDOWEVENT_SIZE_CHANGED = c.SDL_WINDOWEVENT_SIZE_CHANGED;
pub const WINDOWEVENT_MINIMIZED = c.SDL_WINDOWEVENT_MINIMIZED;
pub const WINDOWEVENT_MAXIMIZED = c.SDL_WINDOWEVENT_MAXIMIZED;
pub const WINDOWEVENT_RESTORED = c.SDL_WINDOWEVENT_RESTORED;
pub const WINDOWEVENT_ENTER = c.SDL_WINDOWEVENT_ENTER;
pub const WINDOWEVENT_LEAVE = c.SDL_WINDOWEVENT_LEAVE;
pub const WINDOWEVENT_FOCUS_GAINED = c.SDL_WINDOWEVENT_FOCUS_GAINED;
pub const WINDOWEVENT_FOCUS_LOST = c.SDL_WINDOWEVENT_FOCUS_LOST;
pub const WINDOWEVENT_CLOSE = c.SDL_WINDOWEVENT_CLOSE;
pub const WINDOWEVENT_TAKE_FOCUS = c.SDL_WINDOWEVENT_TAKE_FOCUS;
pub const WINDOWEVENT_HIT_TEST = c.SDL_WINDOWEVENT_HIT_TEST;

//      Button types
pub const BUTTON_LEFT = c.SDL_BUTTON_LEFT;
pub const BUTTON_MIDDLE = c.SDL_BUTTON_MIDDLE;
pub const BUTTON_RIGHT = c.SDL_BUTTON_RIGHT;
pub const BUTTON_X1 = c.SDL_BUTTON_X1;
pub const BUTTON_X2 = c.SDL_BUTTON_X2;

pub const Keysym = c.struct_SDL_Keysym;
pub const Keycode = c.SDL_Keycode;
pub const Scancode = c.SDL_Scancode;

pub const K_0 = c.SDLK_0;
pub const K_1 = c.SDLK_1;
pub const K_2 = c.SDLK_2;
pub const K_3 = c.SDLK_3;
pub const K_4 = c.SDLK_4;
pub const K_5 = c.SDLK_5;
pub const K_6 = c.SDLK_6;
pub const K_7 = c.SDLK_7;
pub const K_8 = c.SDLK_8;
pub const K_9 = c.SDLK_9;

pub const K_a = c.SDLK_a;
pub const K_b = c.SDLK_b;
pub const K_c = c.SDLK_c;
pub const K_d = c.SDLK_d;
pub const K_e = c.SDLK_e;
pub const K_f = c.SDLK_f;
pub const K_g = c.SDLK_g;
pub const K_h = c.SDLK_h;
pub const K_i = c.SDLK_i;
pub const K_j = c.SDLK_j;
pub const K_k = c.SDLK_k;
pub const K_l = c.SDLK_l;
pub const K_m = c.SDLK_m;
pub const K_n = c.SDLK_n;
pub const K_o = c.SDLK_o;
pub const K_p = c.SDLK_p;
pub const K_q = c.SDLK_q;
pub const K_r = c.SDLK_r;
pub const K_s = c.SDLK_s;
pub const K_t = c.SDLK_t;
pub const K_u = c.SDLK_u;
pub const K_v = c.SDLK_v;
pub const K_w = c.SDLK_w;
pub const K_x = c.SDLK_x;
pub const K_y = c.SDLK_y;
pub const K_z = c.SDLK_z;

pub const K_SPACE = c.SDLK_SPACE;
pub const K_DELETE = c.SDLK_DELETE;
pub const K_ESCAPE = c.SDLK_ESCAPE;

pub const K_F1 = c.SDLK_F1;
pub const K_F2 = c.SDLK_F2;
pub const K_F3 = c.SDLK_F3;
pub const K_F4 = c.SDLK_F4;
pub const K_F5 = c.SDLK_F5;
pub const K_F6 = c.SDLK_F6;
pub const K_F7 = c.SDLK_F7;
pub const K_F8 = c.SDLK_F8;
pub const K_F9 = c.SDLK_F9;
pub const K_F11 = c.SDLK_F11;
pub const K_F12 = c.SDLK_F12;
pub const K_F13 = c.SDLK_F13;
pub const K_F14 = c.SDLK_F14;
pub const K_F15 = c.SDLK_F15;
pub const K_F16 = c.SDLK_F16;
pub const K_F17 = c.SDLK_F17;
pub const K_F18 = c.SDLK_F18;
pub const K_F19 = c.SDLK_F19;
pub const K_F21 = c.SDLK_F21;
pub const K_F22 = c.SDLK_F22;
pub const K_F23 = c.SDLK_F23;
pub const K_F24 = c.SDLK_F24;

pub const KMOD_NONE: c_int = c.KMOD_NONE;
pub const KMOD_LSHIFT: c_int = c.KMOD_LSHIFT;
pub const KMOD_RSHIFT: c_int = c.KMOD_RSHIFT;
pub const KMOD_LCTRL: c_int = c.KMOD_LCTRL;
pub const KMOD_RCTRL: c_int = c.KMOD_RCTRL;
pub const KMOD_LALT: c_int = c.KMOD_LALT;
pub const KMOD_RALT: c_int = c.KMOD_RALT;
pub const KMOD_LGUI: c_int = c.KMOD_LGUI;
pub const KMOD_RGUI: c_int = c.KMOD_RGUI;
pub const KMOD_NUM: c_int = c.KMOD_NUM;
pub const KMOD_CAPS: c_int = c.KMOD_CAPS;
pub const KMOD_MODE: c_int = c.KMOD_MODE;
pub const KMOD_RESERVED: c_int = c.KMOD_RESERVED;

pub fn PollEvent(event: *Event) c_int {
    return c.SDL_PollEvent(@ptrCast(?[*]c.union_SDL_Event, event));
}

// Misc
pub const Point = c.struct_SDL_Point;
pub const Rect = c.struct_SDL_Rect;
pub const Color = c.struct_SDL_Color;

pub const RendererFlip = c.SDL_RendererFlip;
pub const FLIP_NONE = @intToEnum(RendererFlip, c.SDL_FLIP_NONE);
pub const FLIP_HORIZONTAL = @intToEnum(RendererFlip, c.SDL_FLIP_HORIZONTAL);
pub const FLIP_VERTICAL = @intToEnum(RendererFlip, c.SDL_FLIP_VERTICAL);

pub const GetTicks = c.SDL_GetTicks;
pub const MapRGB = c.SDL_MapRGB;
pub const FillRect = c.SDL_FillRect;

pub fn GetModState() c_int {
    return @enumToInt(c.SDL_GetModState());
}

pub fn GetMouseState(x: *i32, y: *i32) u32 {
    return c.SDL_GetMouseState(
        @ptrCast(?[*]c_int, x),
        @ptrCast(?[*]c_int, y),
    );
}

// OpenGL
pub const GLContext = c.SDL_GLContext;

pub const GLattr = c.SDL_GLattr;
pub const GL_CONTEXT_PROFILE_MASK = @intToEnum(GLattr, c.SDL_GL_CONTEXT_PROFILE_MASK);
pub const GL_CONTEXT_PROFILE_CORE = @intToEnum(GLattr, c.SDL_GL_CONTEXT_PROFILE_CORE);
pub const GL_CONTEXT_MAJOR_VERSION = @intToEnum(GLattr, c.SDL_GL_CONTEXT_MAJOR_VERSION);
pub const GL_CONTEXT_MINOR_VERSION = @intToEnum(GLattr, c.SDL_GL_CONTEXT_MINOR_VERSION);
pub const GL_STENCIL_SIZE = @intToEnum(GLattr, c.SDL_GL_STENCIL_SIZE);

pub const GL_SetAttribute = c.SDL_GL_SetAttribute;
pub const GL_CreateContext = c.SDL_GL_CreateContext;
pub const GL_DeleteContext = c.SDL_GL_DeleteContext;
pub const GL_SwapWindow = c.SDL_GL_SwapWindow;
