const std = @import("std");

const data = @embedFile("data/day16.txt");

const max_beams = 1024;
const max_num_tiles = 128 * 128;

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();

    var bt = try BeamTracer.init(alloc.allocator(), data);
    defer bt.deinit();

    const part_1_ans = try bt.trace(Beam{ .x = 0, .y = 0, .dir = Direction.Right });

    bt.genBeamCandidates();

    var part_2_ans = part_1_ans;

    while (bt.beam_candidates.items.len > 0) {
        try checkBeam(bt, &part_2_ans, bt.beam_candidates.pop());
    }

    std.debug.print("total time = {}\n", .{std.fmt.fmtDuration(timer.read())});
    std.debug.print("part 1: num energized tiles = {d}\n", .{part_1_ans});
    std.debug.print("part 2: max num energized tiles = {d}\n", .{part_2_ans});
}

pub fn checkBeam(bt: *BeamTracer, max_energy: *usize, initial_beam: Beam) !void {
    bt.resetTiles();
    const energy = try bt.trace(initial_beam);

    if (energy > max_energy.*) {
        max_energy.* = energy;
    }
}

pub fn MatrixWrapper(comptime T: type) type {
    return struct {
        const Self = @This();

        buffer: []T,
        rows: usize,
        cols: usize,

        pub fn init(buf: []T, num_rows: usize, num_cols: usize) Self {
            return .{
                .buffer = buf,
                .rows = num_rows,
                .cols = num_cols,
            };
        }

        pub fn get(self: *const Self, x: usize, y: usize) ?*T {
            const n = x + self.cols * y;
            return if (n < self.buffer.len) &self.buffer[n] else null;
        }
    };
}

const TracerError = error{
    EmptyLayout,
};

const BeamTracer = struct {
    beams: std.ArrayList(Beam),
    beam_candidates: std.ArrayList(Beam),

    tiles_buffer: std.BoundedArray(Tile, max_num_tiles),
    tiles: MatrixWrapper(Tile),

    length_x: usize,
    length_y: usize,

    pub fn init(alloc: std.mem.Allocator, layout: []const u8) !*BeamTracer {
        var t = try alloc.create(BeamTracer);

        t.length_x = std.mem.indexOf(u8, layout, "\n") orelse 0;
        t.length_y = (layout.len) / (t.length_x + 1);

        const num_tiles = t.length_x * t.length_y;
        if (num_tiles == 0) {
            return TracerError.EmptyLayout;
        }

        t.beams = std.ArrayList(Beam).init(alloc);
        t.beam_candidates = std.ArrayList(Beam).init(alloc);
        t.tiles_buffer = try std.BoundedArray(Tile, max_num_tiles).init(0);

        try t.beams.ensureTotalCapacity(max_beams);
        try t.beam_candidates.ensureTotalCapacity(2 * (t.length_x + t.length_y));

        var lines = std.mem.tokenizeAny(u8, layout, "\n");

        while (lines.next()) |line| {
            for (line) |c| {
                const k: TileKind = @enumFromInt(c);
                t.tiles_buffer.appendAssumeCapacity(.{
                    .kind = k,
                    .energized = [_]bool{false} ** 4,
                });
            }
        }

        t.tiles = MatrixWrapper(Tile).init(t.tiles_buffer.slice(), t.length_y, t.length_x);

        return t;
    }

    pub fn deinit(self: *BeamTracer) void {
        self.beams.deinit();
        self.beam_candidates.deinit();
    }

    pub fn resetTiles(self: *BeamTracer) void {
        for (0..self.tiles_buffer.len) |i| {
            self.tiles_buffer.buffer[i].reset();
        }
    }

    pub fn trace(self: *BeamTracer, initial_beam: Beam) !usize {
        self.beams.clearRetainingCapacity();
        self.beams.appendAssumeCapacity(initial_beam);

        var i: usize = 0;

        while (self.beams.items.len > 0) : (i += 1) {
            // std.debug.print(">> propagating beam {d} / {d}\n", .{ i + 1, self.beams.items.len });
            var b = self.beams.popOrNull() orelse continue;
            try self.propagate(&b);
        }

        // Count number of energied tiles.
        var num_energized: usize = 0;
        for (self.tiles_buffer.slice()) |e| {
            if (e.isEnergized()) {
                num_energized += 1;
            }
        }

        return num_energized;
    }

    fn printTiles(self: *BeamTracer) void {
        for (self.tiles_buffer.slice(), 0..) |e, k| {
            if (k % self.length_x == 0) {
                std.debug.print("\n", .{});
            }

            if (e.isEnergized()) {
                std.debug.print("#", .{});
            } else {
                std.debug.print(".", .{});
            }
        }

        std.debug.print("\n\n", .{});
    }

    fn propagate(self: *BeamTracer, beam: *Beam) !void {
        loop: while (true) {
            const tile = self.tiles.get(beam.x, beam.y).?;

            // Check tile at beam position and update its direction accordingly.
            // May terminate current beam or spawn a new beam from splitters.
            beam.dir = self.redirectBeam(beam, tile) orelse break :loop;

            // Advance beam.
            switch (beam.dir) {
                Direction.Up => {
                    if (beam.y == 0) break :loop else beam.y -= 1;
                },
                Direction.Down => {
                    if (beam.y == self.length_y - 1) break :loop else beam.y += 1;
                },
                Direction.Left => {
                    if (beam.x == 0) break :loop else beam.x -= 1;
                },
                Direction.Right => {
                    if (beam.x == self.length_x - 1) break :loop else beam.x += 1;
                },
            }
        }
    }

    fn newBeam(self: *BeamTracer, x: usize, y: usize, dir: Direction) void {
        self.beams.appendAssumeCapacity(.{ .x = x, .y = y, .dir = dir });
    }

    fn redirectBeam(
        self: *BeamTracer,
        b: *Beam,
        t: *Tile,
    ) ?Direction {
        if (t.kind != TileKind.Empty and t.isEnergizedDir(b.dir)) {
            return null;
        }

        t.energizeDir(b.dir);

        switch (t.kind) {
            TileKind.Empty => {
                return b.dir;
            },
            TileKind.MirrorSlantedLeft => {
                switch (b.dir) {
                    Direction.Up => return Direction.Left,
                    Direction.Right => return Direction.Down,
                    Direction.Down => return Direction.Right,
                    Direction.Left => return Direction.Up,
                }
            },
            TileKind.MirrorSlantedRight => {
                switch (b.dir) {
                    Direction.Up => return Direction.Right,
                    Direction.Right => return Direction.Up,

                    Direction.Down => return Direction.Left,
                    Direction.Left => return Direction.Down,
                }
            },
            TileKind.SplitterVertical => {
                switch (b.dir) {
                    Direction.Up => return Direction.Up,
                    Direction.Down => return Direction.Down,
                    Direction.Right => {
                        self.newBeam(b.x, b.y, Direction.Up);
                        return Direction.Down;
                    },
                    Direction.Left => {
                        self.newBeam(b.x, b.y, Direction.Down);
                        return Direction.Up;
                    },
                }
            },
            TileKind.SplitterHorizontal => {
                switch (b.dir) {
                    Direction.Left => return Direction.Left,
                    Direction.Right => return Direction.Right,
                    Direction.Up => {
                        self.newBeam(b.x, b.y, Direction.Right);
                        return Direction.Left;
                    },
                    Direction.Down => {
                        self.newBeam(b.x, b.y, Direction.Left);
                        return Direction.Right;
                    },
                }
            },
        }
    }

    pub fn genBeamCandidates(self: *BeamTracer) void {
        self.beam_candidates.clearRetainingCapacity();

        // Top Left Corner
        self.appendBeamStartPos(0, 0, Direction.Down);
        self.appendBeamStartPos(0, 0, Direction.Right);

        // Top Right Corner.
        self.appendBeamStartPos(self.length_x - 1, 0, Direction.Down);
        self.appendBeamStartPos(self.length_x - 1, 0, Direction.Left);

        // Botton Left Corner.
        self.appendBeamStartPos(0, self.length_y - 1, Direction.Up);
        self.appendBeamStartPos(0, self.length_y - 1, Direction.Right);

        // Botting Right Corner.
        self.appendBeamStartPos(self.length_x - 1, self.length_y - 1, Direction.Up);
        self.appendBeamStartPos(self.length_x - 1, self.length_y - 1, Direction.Left);

        // Remaning Top Edge, Beams going down.
        for (1..self.length_x - 1) |x| {
            self.appendBeamStartPos(x, 0, Direction.Down);
        }

        // Remaning Bottom Edge, Beams going up.
        for (1..self.length_x - 1) |x| {
            self.appendBeamStartPos(x, self.length_y - 1, Direction.Up);
        }

        // Remaining Left Edge, Beams going right.
        for (1..self.length_y - 1) |y| {
            self.appendBeamStartPos(0, y, Direction.Right);
        }

        // Remaining Right Edge, Beams going left.
        for (1..self.length_y - 1) |y| {
            self.appendBeamStartPos(self.length_x - 1, y, Direction.Left);
        }
    }

    fn appendBeamStartPos(self: *BeamTracer, x: usize, y: usize, dir: Direction) void {
        const e = self.tiles.get(x, y).?;

        // Checking energization state coming from the opposite direction.
        // If already energized, we can skip this starting position.
        if (e.isEnergizedDir(dir.reverse())) {
            return;
        }

        self.beam_candidates.appendAssumeCapacity(.{
            .x = x,
            .y = y,
            .dir = dir,
        });
    }
};

const Beam = struct {
    x: usize,
    y: usize,
    dir: Direction,

    pub fn init(alloc: std.mem.Allocator, x: usize, y: usize, dir: Direction) !*Beam {
        var b = try alloc.create(Beam);
        b.x = x;
        b.y = y;
        b.dir = dir;

        return b;
    }
};

const Tile = struct {
    kind: TileKind,
    energized: [4]bool,

    pub fn energize(self: *Tile) void {
        self.energized = [_]bool{true} ** 4;
    }

    pub fn energizeDir(self: *Tile, dir: Direction) void {
        self.energized[self.directionIndex(dir)] = true;
    }

    pub fn isEnergized(self: *const Tile) bool {
        var is_energized: bool = false;

        for (self.energized) |e| {
            is_energized = is_energized or e;
        }

        return is_energized;
    }

    pub fn isEnergizedDir(self: *const Tile, dir: Direction) bool {
        return self.energized[self.directionIndex(dir)];
    }

    pub fn reset(self: *Tile) void {
        self.energized = [_]bool{false} ** 4;
    }

    fn directionIndex(_: *const Tile, dir: Direction) usize {
        return switch (dir) {
            Direction.Right => 0,
            Direction.Down => 1,
            Direction.Left => 2,
            Direction.Up => 3,
        };
    }
};

const TileKind = enum(u8) {
    Empty = '.',
    MirrorSlantedLeft = '\\',
    MirrorSlantedRight = '/',
    SplitterHorizontal = '-',
    SplitterVertical = '|',
};

const Direction = enum {
    Up,
    Right,
    Down,
    Left,

    pub fn reverse(self: Direction) Direction {
        return switch (self) {
            Direction.Up => Direction.Down,
            Direction.Down => Direction.Up,
            Direction.Left => Direction.Right,
            Direction.Right => Direction.Left,
        };
    }
};

// Generated from template/template.zig.
// Run `zig build generate` to update.
// Only unmodified days will be updated.
