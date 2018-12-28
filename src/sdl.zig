const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const INIT_VIDEO = c.SDL_INIT_VIDEO;

pub const Init = c.SDL_Init;
pub const GetError = c.SDL_GetError;
pub const Quit = c.SDL_Quit;
pub const Delay = c.SDL_Delay;

// Windows
pub const Window = ?*c.struct_SDL_Window;

pub const WINDOWPOS_UNDEFINED = c.SDL_WINDOWPOS_UNDEFINED_MASK | 0;
pub const WINDOW_SHOWN = c.SDL_WINDOW_SHOWN;

pub const CreateWindow = c.SDL_CreateWindow;
pub const DestroyWindow = c.SDL_DestroyWindow;

pub const GetWindowSurface = c.SDL_GetWindowSurface;
pub const UpdateWindowSurface = c.SDL_UpdateWindowSurface;

// Renderers
pub const Renderer = ?*c.struct_SDL_Renderer;

pub const RENDERER_ACCELERATED = c.SDL_RENDERER_ACCELERATED;
pub const RENDERER_PRESENT_VSYNC = c.SDL_RENDERER_PRESENTVSYNC;

pub const CreateRenderer = c.SDL_CreateRenderer;
pub const DestroyRenderer = c.SDL_DestroyRenderer;

pub const SetRenderDrawColor = c.SDL_SetRenderDrawColor;
pub const RenderClear = c.SDL_RenderClear;
pub const RenderDrawLine = c.SDL_RenderDrawLine;
pub const RenderFillRect = c.SDL_RenderFillRect;
pub const RenderPresent = c.SDL_RenderPresent;

// Events
pub const Event = c.union_SDL_Event;

pub const QUIT = c.SDL_QUIT;

pub fn PollEvent(event: *Event) c_int
{
    return c.SDL_PollEvent(@ptrCast(?[*]c.union_SDL_Event, event));
}

// Misc
pub const GetTicks = c.SDL_GetTicks;
pub const MapRGB = c.SDL_MapRGB;
pub const FillRect = c.SDL_FillRect;
