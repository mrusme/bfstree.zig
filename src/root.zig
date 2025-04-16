const std = @import("std");

// Edge struct
pub const Edge = struct {
    from: []const u8,
    to: []const u8,
};

// BFSTree struct
pub const BFSTree = struct {
    allocator: std.mem.Allocator,
    edges: std.ArrayList(Edge),

    pub fn init(allocator: std.mem.Allocator) BFSTree {
        return BFSTree{
            .allocator = allocator,
            .edges = std.ArrayList(Edge).init(allocator),
        };
    }

    pub fn deinit(self: *BFSTree) void {
        self.edges.deinit();
    }

    pub fn addEdge(self: *BFSTree, edge: Edge) !void {
        try self.edges.append(edge);
    }

    pub fn fromNode(self: *BFSTree, start: []const u8) !std.ArrayList(Edge) {
        var result = std.ArrayList(Edge).init(self.allocator);
        for (self.edges.items) |e| {
            if (std.mem.eql(u8, e.from, start)) {
                try result.append(e);
            }
        }
        return result;
    }

    pub fn findPath(self: *BFSTree, start: []const u8, end: []const u8) !?Path {
        var paths = std.ArrayList(Path).init(self.allocator);
        defer {
            for (paths.items) |*path| {
                path.deinit();
            }
            paths.deinit();
        }

        const initial_edges = try self.fromNode(start);
        defer initial_edges.deinit();

        for (initial_edges.items) |edge| {
            var path = Path.init(self.allocator);
            try path.addEdge(edge);
            try paths.append(path);
            if (std.mem.eql(u8, edge.to, end)) {
                var result = Path.init(self.allocator);
                for (path.edges.items) |path_edge| {
                    try result.addEdge(path_edge);
                }
                return result;
            }
        }

        while (paths.items.len > 0) {
            var new_paths = std.ArrayList(Path).init(self.allocator);
            defer {
                for (new_paths.items) |*path| {
                    path.deinit();
                }
                new_paths.deinit();
            }

            for (paths.items) |*path| {
                const last_edge = path.edges.items[path.edges.items.len - 1];
                var children = try self.fromNode(last_edge.to);
                defer children.deinit();

                for (children.items) |child| {
                    if (path.isCircular(child)) continue;

                    var new_path = Path.init(self.allocator);
                    for (path.edges.items) |path_edge| {
                        try new_path.addEdge(path_edge);
                    }
                    try new_path.addEdge(child);

                    if (std.mem.eql(u8, child.to, end)) {
                        var result = Path.init(self.allocator);
                        for (new_path.edges.items) |path_edge| {
                            try result.addEdge(path_edge);
                        }
                        new_path.deinit();
                        return result;
                    }
                    try new_paths.append(new_path);
                }
            }

            for (paths.items) |*path| {
                path.deinit();
            }
            paths.clearRetainingCapacity();

            while (new_paths.pop()) |path| {
                try paths.append(path);
            }
        }
        return null;
    }
};

// Path struct
pub const Path = struct {
    edges: std.ArrayList(Edge),

    pub fn init(allocator: std.mem.Allocator) Path {
        return Path{
            .edges = std.ArrayList(Edge).init(allocator),
        };
    }

    pub fn deinit(self: *Path) void {
        self.edges.deinit();
    }

    pub fn addEdge(self: *Path, edge: Edge) !void {
        try self.edges.append(edge);
    }

    pub fn isCircular(self: *Path, edge: Edge) bool {
        for (self.edges.items) |e| {
            if (std.mem.eql(u8, e.from, edge.to) or std.mem.eql(u8, e.to, edge.to)) {
                return true;
            }
        }
        return false;
    }
};

test "BFS Path Finding" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            @panic("LEAK");
        }
    }
    const allocator = gpa.allocator();

    var tree = BFSTree.init(allocator);
    defer tree.deinit();

    try tree.addEdge(Edge{ .from = "New York", .to = "Chicago" });
    try tree.addEdge(Edge{ .from = "Chicago", .to = "Dallas" });
    try tree.addEdge(Edge{ .from = "New York", .to = "Los Angeles" });
    try tree.addEdge(Edge{ .from = "Los Angeles", .to = "Houston" });
    try tree.addEdge(Edge{ .from = "Chicago", .to = "Miami" });
    try tree.addEdge(Edge{ .from = "Houston", .to = "Tokyo" });

    const result = try tree.findPath("New York", "Tokyo");
    if (result) |path| {
        defer @constCast(&path).deinit();
        try std.testing.expectEqual(3, path.edges.items.len);
        for (path.edges.items, 0..) |edge, i| {
            if (i == 0) {
                try std.testing.expectEqualStrings("New York", edge.from);
                try std.testing.expectEqualStrings("Los Angeles", edge.to);
            } else if (i == 1) {
                try std.testing.expectEqualStrings("Los Angeles", edge.from);
                try std.testing.expectEqualStrings("Houston", edge.to);
            } else if (i == 2) {
                try std.testing.expectEqualStrings("Houston", edge.from);
                try std.testing.expectEqualStrings("Tokyo", edge.to);
            }
        }
    } else {
        try std.testing.expect(false);
    }
}
