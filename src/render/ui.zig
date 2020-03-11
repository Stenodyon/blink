pub usingnamespace @import("ui/renderer.zig");
pub usingnamespace @import("ui/layout.zig");
pub usingnamespace @import("ui/widgets.zig");
pub usingnamespace @import("ui/events.zig");

const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const NODE_PROPERTIES = [_][]const u8{
    "weight",
    "marginLeft",
    "marginRight",
    "marginTop",
    "marginBottom",
    "paddingLeft",
    "paddingRight",
    "paddingTop",
    "paddingBottom",
};

pub const Layout = struct {
    arena: ArenaAllocator,
    root: *Widget,

    pub fn fromJSON(allocator: *Allocator, filename: []const u8) !Layout {
        var self = Layout{
            .arena = ArenaAllocator.init(allocator),
            .root = undefined,
        };
        const arena = &self.arena.allocator;
        errdefer self.arena.deinit();

        const rawJSON = try std.io.readFileAlloc(allocator, filename);
        defer allocator.free(rawJSON);

        var parser = json.Parser.init(allocator, true);
        defer parser.deinit();

        var tree = try parser.parse(rawJSON);
        defer tree.deinit();

        self.root = try buildWidget(arena, &tree.root.Object);

        return self;
    }

    fn buildWidget(
        arena: *Allocator,
        jsonObject: *json.ObjectMap,
    ) Allocator.Error!*Widget {
        if (jsonObject.get("type")) |widgetTypeEntry| {
            const widgetType = widgetTypeEntry.value.String;
            var widget = blk: {
                if (std.mem.eql(u8, "FillerWidget", widgetType)) {
                    const filler = try arena.create(FillerWidget);
                    filler.* = FillerWidget.newDefault();
                    break :blk &filler.widget;
                } else if (std.mem.eql(u8, "FrameWidget", widgetType)) {
                    const frame = try arena.create(FrameWidget);
                    frame.* = FrameWidget.new();
                    break :blk &frame.widget;
                } else if (std.mem.eql(u8, "HBox", widgetType)) {
                    const hbox = try arena.create(HBox);
                    hbox.* = HBox.new();
                    break :blk &hbox.widget;
                } else if (std.mem.eql(u8, "VBox", widgetType)) {
                    const vbox = try arena.create(VBox);
                    vbox.* = VBox.new();
                    break :blk &vbox.widget;
                } else {
                    std.debug.panic("Invalid widget: \"{}\"\n", .{widgetType});
                }
            };

            inline for (NODE_PROPERTIES) |property| {
                if (jsonObject.get(property)) |propEntry| {
                    const value = @intCast(
                        @TypeOf(@field(&widget.node, property)),
                        propEntry.value.Integer,
                    );
                    @field(&widget.node, property) = value;
                }
            }

            if (jsonObject.get("children")) |childrenEntry| {
                const slice = childrenEntry.value.Array.toSlice();
                //TODO: find a more memory-efficient way to do that
                var childWidgets = try arena.alloc(*Widget, slice.len);
                for (slice) |*child, i| {
                    childWidgets[i] = try buildWidget(arena, &child.Object);
                }
                try widget.setChildren(arena, childWidgets);
            }

            return widget;
        } else {
            std.debug.panic("Layout JSON objects must have a type\n", .{});
        }
    }

    pub fn deinit(self: *const Layout) void {
        self.arena.deinit();
    }
};
