const c = @cImport({
    @cInclude("SDL2/SDL_image.h");
});

pub const INIT_PNG = c.IMG_INIT_PNG;

pub const Init = c.IMG_Init;
pub const GetError = c.IMG_GetError;

pub const Load = c.IMG_Load;
