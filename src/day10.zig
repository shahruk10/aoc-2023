const std = @import("std");

const data = @embedFile("data/day10.txt");

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();

    var maze = try Maze.init(alloc.allocator(), data);
    try maze.run();

    std.debug.print("total time = {}\n", .{std.fmt.fmtDuration(timer.read())});
    std.debug.print("part 1: farthest distance = {d}\n", .{maze.farthest_distance_from_start});
    // std.debug.print("part 2: number of steps = {d}\n", .{maze.steps_required_part2});
}

const NavError = error{
    GroundTileCantHaveConnections,
    MoreOrLessThan2Connections,
    NoStartTile,
};

const TileKind = enum(u8) {
    Ground = '.',
    Start = 'S',
    NE = 'L',
    SE = 'F',
    NW = 'J',
    SW = '7',
    NS = '|',
    EW = '-',
};

const Tile = struct {
    x: usize,
    y: usize,
    kind: TileKind,

    north: ?*Tile = null,
    south: ?*Tile = null,
    east: ?*Tile = null,
    west: ?*Tile = null,

    dist: ?usize = null,
    visited: bool = false,

    pub fn init(alloc: std.mem.Allocator, x: usize, y: usize, kind: TileKind) !*Tile {
        var t = try alloc.create(Tile);
        t.kind = kind;
        t.x = x;
        t.y = y;
        t.dist = null;
        t.visited = false;

        return t;
    }

    pub fn connect(self: *Tile, north: ?*Tile, south: ?*Tile, east: ?*Tile, west: ?*Tile) void {
        self.north = north;
        self.south = south;
        self.east = east;
        self.west = west;
    }
};

const Maze = struct {
    main_loop_perimeter: usize = 0,
    farthest_distance_from_start: usize = 0,

    tiles: std.ArrayList(*Tile) = undefined,
    rows: usize = undefined,
    cols: usize = undefined,
    start_x: usize = undefined,
    start_y: usize = undefined,

    pub fn init(alloc: std.mem.Allocator, maze_str: []const u8) !*Maze {
        const min_num_tiles = 32768;

        var m = try alloc.create(Maze);
        m.main_loop_perimeter = 0;
        m.farthest_distance_from_start = 0;

        m.tiles = std.ArrayList(*Tile).init(alloc);
        try m.tiles.ensureTotalCapacity(min_num_tiles);

        var lines = std.mem.tokenizeAny(u8, maze_str, "\n");

        var y: usize = 0;

        while (lines.next()) |row| : (y += 1) {
            for (row, 0..) |c, x| {
                const k: TileKind = @enumFromInt(c);

                if (k == TileKind.Start) {
                    m.start_x = x;
                    m.start_y = y;
                }

                try m.tiles.append(try Tile.init(alloc, x, y, k));
            }
        }

        if (m.start_x == undefined) {
            return NavError.NoStartTile;
        }

        m.rows = y;
        m.cols = m.tiles.items.len / m.rows;

        try m.connectTiles();

        return m;
    }

    pub fn run(self: *Maze) !void {
        // Going through all the tiles in the main loop, starting at the start.
        // The total steps around the loop will be the max steps to neighbouring
        // tiles of the start tile.
        //
        //                  -- visit tiles -->
        //                                   |
        //                      S--------7   |
        //  main-loop-length -> |        |   v
        //                      L--------J
        //
        const t = self.getStartTile();
        self.visitTile(t, 0);

        for ([_]?*Tile{ t.north, t.south, t.east, t.west }) |t_neighbour| {
            if (t_neighbour) |t_next| {
                self.main_loop_perimeter = @max(t_next.dist orelse 0, self.main_loop_perimeter);
            }
        }

        // Add one more step to arrive back at the start tile.
        self.main_loop_perimeter += 1;

        // Farthest distance is half way around the loop.
        self.farthest_distance_from_start = self.main_loop_perimeter / 2;
    }

    fn connectTiles(self: *Maze) !void {
        for (0..self.rows) |y| {
            for (0..self.cols) |x| {
                var t = self.getTile(x, y);

                const north = if (y > 0) self.getTile(x, y - 1) else null;
                const south = if (y < self.rows - 1) self.getTile(x, y + 1) else null;
                const east = if (x < self.cols - 1) self.getTile(x + 1, y) else null;
                const west = if (x > 0) self.getTile(x - 1, y) else null;

                switch (t.kind) {
                    TileKind.NE => t.connect(north, null, east, null),
                    TileKind.SE => t.connect(null, south, east, null),
                    TileKind.NW => t.connect(north, null, null, west),
                    TileKind.SW => t.connect(null, south, null, west),
                    TileKind.NS => t.connect(north, south, null, null),
                    TileKind.EW => t.connect(null, null, east, west),
                    TileKind.Start => t.connect(north, south, east, west),
                    TileKind.Ground => {},
                }
            }
        }

        try self.fixStartTile();
    }

    fn getTile(self: *Maze, x: usize, y: usize) *Tile {
        return self.tiles.items[x + (y * self.rows)];
    }

    fn getStartTile(self: *Maze) *Tile {
        return self.getTile(self.start_x, self.start_y);
    }

    fn fixStartTile(self: *Maze) !void {
        const t = self.getStartTile();

        if (t.north) |north_of_t| {
            t.north = if (north_of_t.south == null) null else north_of_t;
        }

        if (t.south) |south_of_t| {
            t.south = if (south_of_t.north == null) null else south_of_t;
        }

        if (t.east) |east_of_t| {
            t.east = if (east_of_t.west == null) null else east_of_t;
        }

        if (t.west) |west_of_t| {
            t.west = if (west_of_t.east == null) null else west_of_t;
        }
    }

    fn visitTile(self: *Maze, t: *Tile, dist: usize) void {
        if (t.visited) {
            return;
        }

        t.visited = true;
        t.dist = dist;

        for ([_]?*Tile{ t.north, t.east, t.south, t.west }) |t_neighbor| {
            if (t_neighbor) |t_next| {
                self.visitTile(t_next, dist + 1);
            }
        }
    }

    fn countTilesWithinMainLoop(self: *Maze) void {
        _ = self;
    }
};

// Generated from template/template.zig.
// Run `zig build generate` to update.
// Only unmodified days will be updated.
