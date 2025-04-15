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
            for (paths.items) |item| {
                @constCast(&item).deinit();
            }
            paths.deinit();
        }

        var initial_edges = try self.fromNode(start);
        defer initial_edges.deinit();

        for (initial_edges.items) |edge| {
            var path = Path.init(self.allocator);
            try path.addEdge(edge);
            try paths.append(path);
            if (std.mem.eql(u8, edge.to, end)) {
                return path;
            }
        }

        while (paths.items.len > 0) {
            var new_paths = std.ArrayList(Path).init(self.allocator);
            defer new_paths.deinit();

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
                        return new_path;
                    }
                    try new_paths.append(new_path);
                }
            }

            for (paths.items) |item| {
                @constCast(&item).deinit();
            }
            paths.deinit();
            paths = new_paths;
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
    try tree.addEdge(Edge{ .from = "New York", .to = "Los Angeles" });
    try tree.addEdge(Edge{ .from = "Los Angeles", .to = "Houston" });
    try tree.addEdge(Edge{ .from = "Chicago", .to = "Tokyo" });

    const result = try tree.findPath("New York", "Tokyo");
    if (result) |path| {
        defer @constCast(&path).deinit();
        // std.log.debug("Path found: ", .{});
        for (path.edges.items, 0..) |edge, i| {
            // std.log.debug("[{s} -> {s}] ", .{ edge.from, edge.to });
            if (i == 0) {
                try std.testing.expectEqualStrings("New York", edge.from);
            } else if (i == 1) {
                try std.testing.expectEqualStrings("Chicago", edge.from);
            }
        }
        // std.log.debug("\n", .{});
        try std.testing.expect(path.edges.items.len == 2);
    } else {
        // std.log.err("No path found.\n", .{});
        try std.testing.expect(false);
    }
}
