usingnamespace @cImport({
    @cInclude("lodepng.h");
    @cInclude("epoxy/gl.h");
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_ttf.h");
    @cInclude("SDL2/SDL_opengl.h");
    @cInclude("freetype2.h");

    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cInclude("stdio.h");
});
