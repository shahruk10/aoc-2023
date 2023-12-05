const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day05.txt");

const max_seeds = 100;

const ParseError = error{
    MissingLineSeedNumbers,
    LineTooShortSeedNumbers,
    NumberOfSeedsExceedMaximumAllowed,
};

const MappedRange = struct {
    destination_start: u64,
    source_start: u64,
    range: u64,

    pub fn get(self: *MappedRange, i: u64) ?u64 {
        if (i < self.source_start or i >= self.source_start + self.range) {
            return null;
        }

        return self.destination_start + (i - self.source_start);
    }
};

const Seed = struct {
    number: u64 = undefined,
    mapped: ?u64 = null,
};

const AlmanacReader = struct {
    data: []const u8,

    seeds: [max_seeds]Seed = undefined,
    num_seeds: u64 = 0,

    pub fn run(self: *AlmanacReader) !void {
        self.seeds = [_]Seed{Seed{}} ** max_seeds;

        var lines = tokenizeAny(u8, data, "\n");

        const seeds_str = lines.next();
        if (seeds_str == null) {
            return ParseError.MissingLineSeedNumbers;
        }

        try self.readSeedNumbers(seeds_str.?);

        var num_maps: u64 = 0;

        while (lines.next()) |line| {
            const str = trim(u8, line, " ");

            if (str.len == 0) {
                continue;
            }

            // Lines that begin a new map = "seed-to-soil map:"
            if (std.mem.eql(u8, str[str.len - 4 ..], "map:")) {
                // Updating seed number to be the mapped number found in the
                // previous map, and resetting mapped number.
                if (num_maps > 0) {
                    try self.updateSeedNumbers();
                }

                num_maps += 1;

                print(">> mapping using {s}\n", .{str});

                continue;
            }

            // All other lines belong to a map. The maps are assumed to be provied in the following order:
            // 1. seed-to-soil map
            // 2. soil-to-fertilizer map
            // 3. fertilizer-to-water map
            // 4. water-to-light map
            // 5. light-to-temperature map
            // 6. temperature-to-humidity map
            // 7. humidity-to-location map

            var range_parts = tokenizeAny(u8, line, " ");

            var mapped_range = MappedRange{
                .destination_start = try std.fmt.parseUnsigned(u64, range_parts.next().?, 10),
                .source_start = try std.fmt.parseUnsigned(u64, range_parts.next().?, 10),
                .range = try std.fmt.parseUnsigned(u64, range_parts.next().?, 10),
            };

            for (0..self.num_seeds) |i| {
                // Already mapped.
                if (self.seeds[i].mapped != null) {
                    continue;
                }

                // Mapping number if present in range.
                if (mapped_range.get(self.seeds[i].number)) |number| {
                    self.seeds[i].mapped = number;
                }
            }
        }

        // Updating seed numbers for the final time after the last map.
        try self.updateSeedNumbers();
    }

    pub fn readSeedNumbers(self: *AlmanacReader, seeds_str: []const u8) !void {
        if (seeds_str.len < 7) {
            return ParseError.LineTooShortSeedNumbers;
        }

        // seeds_str = "seed: N1 N2 ..."
        var seeds = tokenizeAny(u8, seeds_str[6..], " ");

        self.num_seeds = 0;
        while (seeds.next()) |seed| {
            self.num_seeds += 1;
            if (self.num_seeds >= max_seeds) {
                return ParseError.NumberOfSeedsExceedMaximumAllowed;
            }

            self.seeds[self.num_seeds - 1] = Seed{
                .number = try std.fmt.parseUnsigned(u64, trim(u8, seed, " "), 10),
            };
        }

        print(">> read {d} seed numbers\n", .{self.num_seeds});
    }

    pub fn updateSeedNumbers(self: *AlmanacReader) !void {
        // print(">> {any}\n", .{self.seeds[0..self.num_seeds]});

        for (0..self.num_seeds) |i| {
            // If number was mapped, it is self-mapping.
            if (self.seeds[i].mapped == null) {
                continue;
            }

            self.seeds[i].number = self.seeds[i].mapped.?;
            self.seeds[i].mapped = null;
        }
    }

    pub fn getLowestSeedNumber(self: *AlmanacReader) u64 {
        var min_number: u64 = std.math.maxInt(u64);

        for (0..self.num_seeds) |i| {
            if (self.seeds[i].number < min_number) {
                min_number = self.seeds[i].number;
            }
        }

        return min_number;
    }
};

pub fn main() !void {
    var reader = AlmanacReader{ .data = data };
    try reader.run();

    print("part 1: lowest location number={d}\n", .{reader.getLowestSeedNumber()});
}

// Useful stdlib functions
const tokenizeAny = std.mem.tokenizeAny;
const tokenizeSeq = std.mem.tokenizeSequence;
const tokenizeSca = std.mem.tokenizeScalar;
const splitAny = std.mem.splitAny;
const splitSeq = std.mem.splitSequence;
const splitSca = std.mem.splitScalar;
const indexOf = std.mem.indexOfScalar;
const indexOfAny = std.mem.indexOfAny;
const indexOfStr = std.mem.indexOfPosLinear;
const lastIndexOf = std.mem.lastIndexOfScalar;
const lastIndexOfAny = std.mem.lastIndexOfAny;
const lastIndexOfStr = std.mem.lastIndexOfLinear;
const trim = std.mem.trim;
const sliceMin = std.mem.min;
const sliceMax = std.mem.max;

const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;

const print = std.debug.print;
const assert = std.debug.assert;

const sort = std.sort.block;
const asc = std.sort.asc;
const desc = std.sort.desc;

// Generated from template/template.zig.
// Run `zig build generate` to update.
// Only unmodified days will be updated.
