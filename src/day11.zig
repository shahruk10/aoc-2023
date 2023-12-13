const std = @import("std");

const data = @embedFile("data/day11.txt");

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();

    var o = try Observatory.init(alloc.allocator(), data);
    o.run(data);

    std.debug.print("total time = {}\n", .{std.fmt.fmtDuration(timer.read())});
    std.debug.print("part 1: sum of distances between galaxies = {d}\n", .{o.sum_of_dist_part1});
    std.debug.print("part 2: sum of distances between galaxies = {d}\n", .{o.sum_of_dist_part2});
}

const Coordinate = struct {
    x: usize,
    y: usize,

    pub fn distance_from(self: @This(), other: Coordinate) usize {
        const x = if (self.x > other.x) self.x - other.x else other.x - self.x;
        const y = if (self.y > other.y) self.y - other.y else other.y - self.y;

        return x + y;
    }
};

const Galaxy = struct {
    original_coordinate: Coordinate,
    corrected_coordinate: Coordinate,
};

const ObservatoryError = error{
    UniverseHasNoEdge,
};

const Observatory = struct {
    sum_of_dist_part1: usize = 0,
    sum_of_dist_part2: usize = 0,

    original_universe_width: usize,
    original_universe_length: usize,
    galaxies: std.ArrayList(Galaxy),

    pub fn init(alloc: std.mem.Allocator, universe_str: []const u8) !*Observatory {
        var o = try alloc.create(Observatory);
        o.sum_of_dist_part1 = 0;
        o.sum_of_dist_part2 = 0;
        o.galaxies = std.ArrayList(Galaxy).init(alloc);

        try o.scanForGalaxies(universe_str);

        return o;
    }

    pub fn run(self: *Observatory, universe_str: []const u8) void {
        var expansion_factor: usize = 2;
        self.adjustCoordinatesForCosmicExpansion(universe_str, expansion_factor, expansion_factor);
        self.compute_distances_between_galaxies(&self.sum_of_dist_part1);

        expansion_factor = 1e6;
        self.resetCorrectedCoordinates();
        self.adjustCoordinatesForCosmicExpansion(universe_str, expansion_factor, expansion_factor);
        self.compute_distances_between_galaxies(&self.sum_of_dist_part2);
    }

    fn scanForGalaxies(self: *Observatory, universe_str: []const u8) !void {
        const first_line_break: ?usize = std.mem.indexOfScalar(u8, universe_str, '\n');
        if (first_line_break == null) {
            return ObservatoryError.UniverseHasNoEdge;
        }

        self.original_universe_width = first_line_break.?;
        self.original_universe_length = first_line_break.?;

        const approx_num_galaxies = (self.original_universe_width * self.original_universe_length) / 5;
        self.galaxies.clearRetainingCapacity();
        try self.galaxies.ensureTotalCapacity(approx_num_galaxies);

        for (0..self.original_universe_length) |y| {
            for (0..self.original_universe_width) |x| {
                // +1 for \n chars at the end of each row.
                const c = universe_str[x + y * (self.original_universe_width + 1)];

                if (c == '#') {
                    try self.galaxies.append(.{
                        .original_coordinate = .{
                            .x = x,
                            .y = y,
                        },
                        .corrected_coordinate = .{
                            .x = x,
                            .y = y,
                        },
                    });
                }
            }
        }
    }

    fn adjustCoordinatesForCosmicExpansion(
        self: *Observatory,
        universe_str: []const u8,
        x_expansion_factor: usize,
        y_expansion_factor: usize,
    ) void {
        var galaxies = self.galaxies.items;

        // Correction value to compensate for the expansion of the universe vertically.
        const y_expansion_delta = y_expansion_factor - 1;
        var y_correction: usize = 0;

        for (0..self.original_universe_length) |y| {
            var no_galaxies_in_row: bool = true;

            for (0..self.original_universe_width) |x| {
                // +1 for \n chars at the end of each row.
                const c = universe_str[x + y * (self.original_universe_width + 1)];

                if (c == '#') {
                    no_galaxies_in_row = false;
                    break;
                }
            }

            if (no_galaxies_in_row) {
                for (0..galaxies.len) |i| {
                    if (galaxies[i].corrected_coordinate.y < (y + y_correction)) {
                        continue;
                    }

                    galaxies[i].corrected_coordinate.y += y_expansion_delta;
                }

                y_correction += y_expansion_delta;
            }
        }

        // Correction value to compensate for the expansion of the universe horizontally.
        const x_expansion_delta = x_expansion_factor - 1;
        var x_correction: usize = 0;

        for (0..self.original_universe_width) |x| {
            var no_galaxies_in_col: bool = true;

            for (0..self.original_universe_length) |y| {
                // +1 for \n chars at the end of each row.
                const c = universe_str[x + y * (self.original_universe_width + 1)];

                if (c == '#') {
                    no_galaxies_in_col = false;
                    break;
                }
            }

            if (no_galaxies_in_col) {
                for (0..galaxies.len) |i| {
                    if (galaxies[i].corrected_coordinate.x < (x + x_correction)) {
                        continue;
                    }

                    galaxies[i].corrected_coordinate.x += x_expansion_delta;
                }

                x_correction += x_expansion_delta;
            }
        }
    }

    fn resetCorrectedCoordinates(self: *Observatory) void {
        var galaxies = self.galaxies.items;

        for (0..galaxies.len) |i| {
            galaxies[i].corrected_coordinate.x = galaxies[i].original_coordinate.x;
            galaxies[i].corrected_coordinate.y = galaxies[i].original_coordinate.y;
        }
    }

    fn compute_distances_between_galaxies(self: *Observatory, sum: *usize) void {
        const galaxies = self.galaxies.items;

        for (0..galaxies.len) |i| {
            for (i + 1..galaxies.len) |j| {
                sum.* += galaxies[i].corrected_coordinate.distance_from(galaxies[j].corrected_coordinate);
            }
        }
    }
};

// Generated from template/template.zig.
// Run `zig build generate` to update.
// Only unmodified days will be updated.
