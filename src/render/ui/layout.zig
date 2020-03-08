const std = @import("std");
const testing = std.testing;

usingnamespace @import("../../vec.zig");

pub const Order = enum {
    Row,
    Column,
};

pub const Node = struct {
    loc: Recti = undefined,
    weight: usize = 1,

    childrenOrder: Order = .Row,
    children: []*Node = &[_]*Node{},
};

pub fn compute(node: *Node, window: Recti) void {
    node.loc = window;

    const totalWeight = blk: {
        var total: usize = 0;
        for (node.children) |child| {
            total += child.weight;
        }
        break :blk total;
    };

    var offset: i32 = 0;
    for (node.children) |child| {
        var newWindow = window;

        if (node.childrenOrder == .Row) {
            newWindow.pos.x += offset;

            newWindow.size.x *= @intCast(i32, child.weight);
            newWindow.size.x = @divTrunc(
                newWindow.size.x,
                @intCast(i32, totalWeight),
            );

            offset += newWindow.size.x;
        }

        if (node.childrenOrder == .Column) {
            newWindow.pos.y += offset;

            newWindow.size.y *= @intCast(i32, child.weight);
            newWindow.size.y = @divTrunc(
                newWindow.size.y,
                @intCast(i32, totalWeight),
            );

            offset += newWindow.size.y;
        }

        compute(child, newWindow);
    }
}

test "filling window" {
    var root = Node{};
    compute(&root, Recti.box(50, 100, 250, 800));

    testing.expectEqual(@as(i32, 50), root.loc.pos.x);
    testing.expectEqual(@as(i32, 100), root.loc.pos.y);
    testing.expectEqual(@as(i32, 250), root.loc.size.x);
    testing.expectEqual(@as(i32, 800), root.loc.size.y);
}

test "row half and half" {
    var child1 = Node{};
    var child2 = Node{};
    var root = Node{
        .childrenOrder = .Row,
        .children = &[_]*Node{ &child1, &child2 },
    };
    compute(&root, Recti.box(0, 0, 200, 100));

    testing.expectEqual(@as(i32, 0), child1.loc.pos.x);
    testing.expectEqual(@as(i32, 0), child1.loc.pos.y);
    testing.expectEqual(@as(i32, 100), child1.loc.size.x);
    testing.expectEqual(@as(i32, 100), child1.loc.size.y);

    testing.expectEqual(@as(i32, 100), child2.loc.pos.x);
    testing.expectEqual(@as(i32, 0), child2.loc.pos.y);
    testing.expectEqual(@as(i32, 100), child2.loc.size.x);
    testing.expectEqual(@as(i32, 100), child2.loc.size.y);
}

test "column half and half" {
    var child1 = Node{};
    var child2 = Node{};
    var root = Node{
        .childrenOrder = .Column,
        .children = &[_]*Node{ &child1, &child2 },
    };
    compute(&root, Recti.box(0, 0, 100, 200));

    testing.expectEqual(@as(i32, 0), child1.loc.pos.x);
    testing.expectEqual(@as(i32, 0), child1.loc.pos.y);
    testing.expectEqual(@as(i32, 100), child1.loc.size.x);
    testing.expectEqual(@as(i32, 100), child1.loc.size.y);

    testing.expectEqual(@as(i32, 0), child2.loc.pos.x);
    testing.expectEqual(@as(i32, 100), child2.loc.pos.y);
    testing.expectEqual(@as(i32, 100), child2.loc.size.x);
    testing.expectEqual(@as(i32, 100), child2.loc.size.y);
}

test "weights" {
    var child1 = Node{};
    var child2 = Node{};
    var child3 = Node{ .weight = 2 };
    var root = Node{
        .childrenOrder = .Row,
        .children = &[_]*Node{ &child1, &child2, &child3 },
    };
    compute(&root, Recti.box(0, 0, 200, 100));

    testing.expectEqual(@as(i32, 0), child1.loc.pos.x);
    testing.expectEqual(@as(i32, 0), child1.loc.pos.y);
    testing.expectEqual(@as(i32, 50), child1.loc.size.x);
    testing.expectEqual(@as(i32, 100), child1.loc.size.y);

    testing.expectEqual(@as(i32, 50), child2.loc.pos.x);
    testing.expectEqual(@as(i32, 0), child2.loc.pos.y);
    testing.expectEqual(@as(i32, 50), child2.loc.size.x);
    testing.expectEqual(@as(i32, 100), child2.loc.size.y);

    testing.expectEqual(@as(i32, 100), child3.loc.pos.x);
    testing.expectEqual(@as(i32, 0), child3.loc.pos.y);
    testing.expectEqual(@as(i32, 100), child3.loc.size.x);
    testing.expectEqual(@as(i32, 100), child3.loc.size.y);
}
