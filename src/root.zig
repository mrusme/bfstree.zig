const std = @import("std");
const Allocator = std.mem.Allocator;

// Edge struct
pub const Edge = struct {
    from: []const u8,
    to: []const u8,
};

// BFSTree struct
pub const BFSTree = struct {
    edges: std.ArrayList(Edge),

    pub fn init(allocator: Allocator) BFSTree {
        return BFSTree{
            .edges = std.ArrayList(Edge).init(allocator),
        };
    }

    pub fn addEdge(self: *BFSTree, edge: Edge) !void {
        try self.edges.append(edge);
    }

    pub fn fromNode(self: *BFSTree, start: []const u8, allocator: Allocator) !std.ArrayList(Edge) {
        var result = std.ArrayList(Edge).init(allocator);
        for (self.edges.items) |e| {
            if (std.mem.eql(u8, e.from, start)) {
                try result.append(e);
            }
        }
        return result;
    }
};

// Path struct
pub const Path = struct {
    edges: std.ArrayList(Edge),

    pub fn init(allocator: Allocator) Path {
        return Path{
            .edges = std.ArrayList(Edge).init(allocator),
        };
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

// BFS Path Finding
pub fn findPath(tree: *BFSTree, start: []const u8, end: []const u8, allocator: Allocator) !?Path {
    var paths = std.ArrayList(Path).init(allocator);
    defer paths.deinit();

    var initial_edges = try tree.fromNode(start, allocator);
    defer initial_edges.deinit();

    for (initial_edges.items) |edge| {
        var path = Path.init(allocator);
        try path.addEdge(edge);
        try paths.append(path);
        if (std.mem.eql(u8, edge.to, end)) {
            return path;
        }
    }

    while (paths.items.len > 0) {
        var new_paths = std.ArrayList(Path).init(allocator);
        defer new_paths.deinit();

        for (paths.items) |*path| {
            const last_edge = path.edges.items[path.edges.items.len - 1];
            var children = try tree.fromNode(last_edge.to, allocator);
            defer children.deinit();

            for (children.items) |child| {
                if (path.isCircular(child)) continue;

                var new_path = Path.init(allocator);
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

        paths.deinit();
        paths = new_paths;
    }
    return null;
}

test "BFS Path Finding" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var tree = BFSTree.init(allocator);
    defer tree.edges.deinit();

    try tree.addEdge(Edge{ .from = "New York", .to = "Chicago" });
    try tree.addEdge(Edge{ .from = "New York", .to = "Los Angeles" });
    try tree.addEdge(Edge{ .from = "Los Angeles", .to = "Houston" });
    try tree.addEdge(Edge{ .from = "Chicago", .to = "Tokyo" });

    const result = try findPath(&tree, "New York", "Tokyo", allocator);
    if (result) |path| {
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
