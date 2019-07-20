const c = @import("c.zig");

pub const Init = c.TTF_Init;
pub const GetError = c.TTF_GetError;
pub const Quit = c.TTF_Quit;

pub const Font = ?*c.TTF_Font;
pub const OpenFont = c.TTF_OpenFont;
pub const CloseFont = c.TTF_CloseFont;

pub const RenderText_Solid = c.TTF_RenderText_Solid;
