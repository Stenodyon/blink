const c = @import("c.zig");

pub const Library = c.FT_Library;
pub const Face = c.FT_Face;

pub const InitFreeType = c.FT_Init_FreeType;
pub const DoneFreeType = c.FT_Done_FreeType;
pub const ErrorString = c.FT_Error_String;

pub const NewFace = c.FT_New_Face;
