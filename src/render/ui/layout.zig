const std = @import("std");
const testing = std.testing;

usingnamespace @import("../../vec.zig");

pub const Order = enum {
    Row,
    Column,
};

pub const Node = struct {
    loc: Rect(usize) = undefined,
    weight: usize = 1,

    marginTop: usize = 0,
    marginBottom: usize = 0,
    marginLeft: usize = 0,
    marginRight: usize = 0,
    paddingTop: usize = 0,
    paddingBottom: usize = 0,
    paddingLeft: usize = 0,
    paddingRight: usize = 0,

    childrenOrder: Order = .Row,
    children: []*Node = &[_]*Node{},
};

pub fn compute(node: *Node, window: Rect(usize)) void {
    node.loc = Rect(usize).box(
        window.pos.x + node.marginLeft,
        window.pos.y + node.marginTop,
        window.size.x - node.marginLeft - node.marginRight,
        window.size.y - node.marginTop - node.marginBottom,
    );

    const totalWeight = blk: {
        var total: usize = 0;
        for (node.children) |child| {
            total += child.weight;
        }
        break :blk total;
    };

    const paddedWindow = Rect(usize).box(
        node.loc.pos.x + node.paddingLeft,
        node.loc.pos.y + node.paddingTop,
        node.loc.size.x - node.paddingLeft - node.paddingRight,
        node.loc.size.y - node.paddingTop - node.paddingBottom,
    );

    var offset: usize = 0;
    for (node.children) |child| {
        var newWindow = paddedWindow;

        if (node.childrenOrder == .Row) {
            newWindow.pos.x += offset;

            newWindow.size.x *= child.weight;
            newWindow.size.x = @divTrunc(newWindow.size.x, totalWeight);

            offset += newWindow.size.x;
        }

        if (node.childrenOrder == .Column) {
            newWindow.pos.y += offset;

            newWindow.size.y *= child.weight;
            newWindow.size.y = @divTrunc(newWindow.size.y, totalWeight);

            offset += newWindow.size.y;
        }

        compute(child, newWindow);
    }
}

test "filling window" {
    var root = Node{};
    compute(&root, Rect(usize).box(50, 100, 250, 800));

    testing.expectEqual(@as(usize, 50), root.loc.pos.x);
    testing.expectEqual(@as(usize, 100), root.loc.pos.y);
    testing.expectEqual(@as(usize, 250), root.loc.size.x);
    testing.expectEqual(@as(usize, 800), root.loc.size.y);
}

test "row half and half" {
    var child1 = Node{};
    var child2 = Node{};
    var root = Node{
        .childrenOrder = .Row,
        .children = &[_]*Node{ &child1, &child2 },
    };
    compute(&root, Rect(usize).box(0, 0, 200, 100));

    testing.expectEqual(@as(usize, 0), child1.loc.pos.x);
    testing.expectEqual(@as(usize, 0), child1.loc.pos.y);
    testing.expectEqual(@as(usize, 100), child1.loc.size.x);
    testing.expectEqual(@as(usize, 100), child1.loc.size.y);

    testing.expectEqual(@as(usize, 100), child2.loc.pos.x);
    testing.expectEqual(@as(usize, 0), child2.loc.pos.y);
    testing.expectEqual(@as(usize, 100), child2.loc.size.x);
    testing.expectEqual(@as(usize, 100), child2.loc.size.y);
}

test "column half and half" {
    var child1 = Node{};
    var child2 = Node{};
    var root = Node{
        .childrenOrder = .Column,
        .children = &[_]*Node{ &child1, &child2 },
    };
    compute(&root, Rect(usize).box(0, 0, 100, 200));

    testing.expectEqual(@as(usize, 0), child1.loc.pos.x);
    testing.expectEqual(@as(usize, 0), child1.loc.pos.y);
    testing.expectEqual(@as(usize, 100), child1.loc.size.x);
    testing.expectEqual(@as(usize, 100), child1.loc.size.y);

    testing.expectEqual(@as(usize, 0), child2.loc.pos.x);
    testing.expectEqual(@as(usize, 100), child2.loc.pos.y);
    testing.expectEqual(@as(usize, 100), child2.loc.size.x);
    testing.expectEqual(@as(usize, 100), child2.loc.size.y);
}

test "weights" {
    var child1 = Node{};
    var child2 = Node{};
    var child3 = Node{ .weight = 2 };
    var root = Node{
        .childrenOrder = .Row,
        .children = &[_]*Node{ &child1, &child2, &child3 },
    };
    compute(&root, Rect(usize).box(0, 0, 200, 100));

    testing.expectEqual(@as(usize, 0), child1.loc.pos.x);
    testing.expectEqual(@as(usize, 0), child1.loc.pos.y);
    testing.expectEqual(@as(usize, 50), child1.loc.size.x);
    testing.expectEqual(@as(usize, 100), child1.loc.size.y);

    testing.expectEqual(@as(usize, 50), child2.loc.pos.x);
    testing.expectEqual(@as(usize, 0), child2.loc.pos.y);
    testing.expectEqual(@as(usize, 50), child2.loc.size.x);
    testing.expectEqual(@as(usize, 100), child2.loc.size.y);

    testing.expectEqual(@as(usize, 100), child3.loc.pos.x);
    testing.expectEqual(@as(usize, 0), child3.loc.pos.y);
    testing.expectEqual(@as(usize, 100), child3.loc.size.x);
    testing.expectEqual(@as(usize, 100), child3.loc.size.y);
}

test "filling window margin" {
    var root = Node{
        .marginTop = 12,
        .marginBottom = 22,
        .marginLeft = 4,
        .marginRight = 25,
    };
    compute(&root, Rect(usize).box(50, 100, 250, 800));

    testing.expectEqual(@as(usize, 54), root.loc.pos.x);
    testing.expectEqual(@as(usize, 112), root.loc.pos.y);
    testing.expectEqual(@as(usize, 221), root.loc.size.x);
    testing.expectEqual(@as(usize, 766), root.loc.size.y);
}

test "row half and half padding" {
    var child1 = Node{};
    var child2 = Node{};
    var root = Node{
        .paddingTop = 12,
        .paddingBottom = 22,
        .paddingLeft = 25,
        .paddingRight = 50,

        .childrenOrder = .Row,
        .children = &[_]*Node{ &child1, &child2 },
    };
    compute(&root, Rect(usize).box(0, 0, 225, 100));

    testing.expectEqual(@as(usize, 25), child1.loc.pos.x);
    testing.expectEqual(@as(usize, 12), child1.loc.pos.y);
    testing.expectEqual(@as(usize, 75), child1.loc.size.x);
    testing.expectEqual(@as(usize, 66), child1.loc.size.y);

    testing.expectEqual(@as(usize, 100), child2.loc.pos.x);
    testing.expectEqual(@as(usize, 12), child2.loc.pos.y);
    testing.expectEqual(@as(usize, 75), child2.loc.size.x);
    testing.expectEqual(@as(usize, 66), child2.loc.size.y);
}
