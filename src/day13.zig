const std = @import("std");

const data = @embedFile("data/day13.txt");

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();

    var patterns = std.mem.tokenizeSequence(u8, data, "\n\n");

    var p = try Pattern(u8).init(alloc.allocator(), '#');
    var part_1_ans: usize = 0;
    var part_2_ans: usize = 0;

    while (patterns.next()) |pattern_str| {
        try p.read(pattern_str);

        p.findMirrorLine(0) catch {
            std.debug.print("part 1: no mirror line in pattern:\n\n{s}\n\n", .{pattern_str});
        };

        if (p.mirror_line_x) |x| {
            part_1_ans += @as(usize, @intCast(x + 1));
        }

        if (p.mirror_line_y) |y| {
            part_1_ans += 100 * @as(usize, @intCast(y + 1));
        }

        p.findMirrorLine(1) catch {
            std.debug.print("part 2: no mirror line in pattern:\n\n{s}\n\n", .{pattern_str});
        };

        if (p.mirror_line_x) |x| {
            part_2_ans += @as(usize, @intCast(x + 1));
        }

        if (p.mirror_line_y) |y| {
            part_2_ans += 100 * @as(usize, @intCast(y + 1));
        }
    }

    std.debug.print("total time = {}\n", .{std.fmt.fmtDuration(timer.read())});
    std.debug.print("part 1: sum(cols on left + 100 * rows above) = {d}\n", .{part_1_ans});
    std.debug.print("part 2: sum(cols on left + 100 * rows above) = {d}\n", .{part_2_ans});
}

const PatternError = error{
    Empty,
    NoMirror,
};

fn Pattern(comptime T: type) type {
    return struct {
        const Self = @This();

        symbol: u8,
        points: std.AutoHashMap(Coordinate(T), bool),
        length_x: T,
        length_y: T,

        mirror_line_x: ?T,
        mirror_line_y: ?T,

        pub fn init(alloc: std.mem.Allocator, symbol: u8) !*Pattern(T) {
            var p = try alloc.create(Self);

            p.symbol = symbol;
            p.points = std.AutoHashMap(Coordinate(T), bool).init(alloc);
            p.length_x = 0;
            p.length_y = 0;

            p.mirror_line_x = null;
            p.mirror_line_y = null;

            return p;
        }

        pub fn read(self: *Self, pattern_str: []const u8) !void {
            // Resetting.
            self.length_x = 0;
            self.length_y = 0;
            self.mirror_line_x = null;
            self.mirror_line_y = null;

            var lines = std.mem.tokenize(u8, pattern_str, "\n");

            var n_cols: usize = 0;
            var n_rows: usize = 0;

            if (lines.peek()) |l| {
                n_cols = l.len;
                n_rows = l.len;
            }

            self.length_x = @as(T, @intCast(n_cols));
            self.length_y = @as(T, @intCast(n_cols));
            self.points.clearRetainingCapacity();
            try self.points.ensureTotalCapacity(@as(u32, @intCast(2 * n_cols * n_cols)));

            var y: T = 0;

            while (lines.next()) |line| : (y += 1) {
                var x: T = 0;

                for (line) |c| {
                    if (c == self.symbol) {
                        self.points.putAssumeCapacityNoClobber(.{
                            .x = x,
                            .y = y,
                        }, true);
                    }

                    x += 1;
                }
            }

            if (self.points.count() == 0) {
                return PatternError.Empty;
            }

            self.length_y = y;
        }

        pub fn findMirrorLine(self: *Self, max_smudges: T) !void {
            if (self.points.count() == 0) {
                return PatternError.Empty;
            }

            const prev_mirror_x = self.mirror_line_x;
            const prev_mirror_y = self.mirror_line_y;

            self.mirror_line_x = null;
            self.mirror_line_y = null;

            // Checking vertical lines.
            var x: T = 0;

            while (x < self.length_x - 1) : (x += 1) {
                if (prev_mirror_x) |prev_x| {
                    if (prev_x == x) {
                        continue;
                    }
                }

                if (self.isMirrorLine(x, max_smudges, true)) {
                    self.mirror_line_x = x;
                    break;
                }
            }

            // Checking horizontal lines.
            var y: T = 0;

            while (y < self.length_y - 1) : (y += 1) {
                if (prev_mirror_y) |prev_y| {
                    if (prev_y == y) {
                        continue;
                    }
                }

                if (self.isMirrorLine(y, max_smudges, false)) {
                    self.mirror_line_y = y;
                    break;
                }
            }

            if (self.mirror_line_x == null and self.mirror_line_y == null) {
                return PatternError.NoMirror;
            }
        }

        pub fn isMirrorLine(self: *Self, c: T, max_smudges: T, vert: bool) bool {
            // Checking if mirror is between c and c + 1.

            // Anaylzing only points within the min(num points on one side of mirror vs other side).
            const L = if (vert) self.length_x else self.length_y;
            const context = @min(c + 1, L - (c + 1));
            const c_min = (c + 1) - context;
            const c_max = c + context;

            var points = self.points.keyIterator();
            var num_smudges: T = 0;
            var mirror_p = Coordinate(T){ .x = undefined, .y = undefined };

            while (points.next()) |p| {
                if (vert) {
                    if (p.x < c_min or p.x > c_max) {
                        continue;
                    }

                    mirror_p.x = 2 * c + 1 - p.x;
                    mirror_p.y = p.y;
                } else {
                    if (p.y < c_min or p.y > c_max) {
                        continue;
                    }

                    mirror_p.x = p.x;
                    mirror_p.y = 2 * c + 1 - p.y;
                }

                if (!self.points.contains(mirror_p)) {
                    num_smudges += 1;
                    if (num_smudges > max_smudges) {
                        return false;
                    }
                }
            }

            return true;
        }
    };
}

fn Coordinate(comptime T: type) type {
    return struct {
        x: T,
        y: T,
    };
}

// Generated from template/template.zig.
// Run `zig build generate` to update.
// Only unmodified days will be updated.
