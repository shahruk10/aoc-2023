const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day05.txt");

const max_seed_ranges = 1024;

const ParseError = error{
    MissingLineSeedNumbers,
    LineTooShortSeedNumbers,
    NumberOfSeedRangesExceedMaximumAllowed,
    IncompleteSeedRangeSpecifier,
};

const MappedRange = struct {
    destination_start: u64,
    source_start: u64,
    range: u64,

    pub fn get(self: *MappedRange, i: u64) ?u64 {
        // print(">> range.get({d})\trange.start={d}\trange.end={d}\n", .{ i, self.source_start, self.source_start + self.range });

        if (i < self.source_start or i >= (self.source_start + self.range)) {
            return null;
        }

        return self.destination_start + (i - self.source_start);
    }
};

const SeedRange = struct {
    start: u64 = undefined,
    end: u64 = undefined,
    mapped_start: ?u64 = null,
    mapped_end: ?u64 = null,
};

const AlmanacReader = struct {
    data: []const u8,
    seed_numbers_are_ranges: bool,

    seeds: [max_seed_ranges]SeedRange = undefined,
    num_seeds: u64 = 0,

    pub fn run(self: *AlmanacReader) !void {
        self.seeds = [_]SeedRange{SeedRange{}} ** max_seed_ranges;

        var lines = tokenizeAny(u8, data, "\n");

        const seeds_str = lines.next();
        if (seeds_str == null) {
            return ParseError.MissingLineSeedNumbers;
        }

        try self.readSeedNumbers(seeds_str.?, self.seed_numbers_are_ranges);

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

            var i: usize = 0;

            while (i < self.num_seeds) : (i += 1) {
                // Already mapped.
                if (self.seeds[i].mapped_start != null) {
                    continue;
                }

                // Mapping if overlaps with range. If paritally overlaps,
                // non-overlapping region appened as a new range to self.seeds.
                try self.mapSeedRange(i, &mapped_range);
            }

            try self.mergeSeedRanges();
        }

        // Updating seed numbers for the final time after the last map.
        try self.updateSeedNumbers();
    }

    fn readSeedNumbers(self: *AlmanacReader, seeds_str: []const u8, as_range: bool) !void {
        if (as_range) {
            try self.readSeedRanges(seeds_str);
        } else {
            try self.readRawSeedNumbers(seeds_str);
        }

        print(">> read {d} seed ranges\n", .{self.num_seeds});
    }

    fn readRawSeedNumbers(self: *AlmanacReader, seeds_str: []const u8) !void {
        if (seeds_str.len < 7) {
            return ParseError.LineTooShortSeedNumbers;
        }

        // seeds_str = "seed: N1 N2 ..."
        var seeds = tokenizeAny(u8, seeds_str[6..], " ");

        self.num_seeds = 0;

        while (seeds.next()) |v| {
            self.num_seeds += 1;
            if (self.num_seeds >= max_seed_ranges) {
                return ParseError.NumberOfSeedRangesExceedMaximumAllowed;
            }

            const seed_number = try std.fmt.parseUnsigned(u64, trim(u8, v, " "), 10);

            self.seeds[self.num_seeds - 1] = SeedRange{
                .start = seed_number,
                .end = seed_number + 1,
            };
        }
    }

    fn readSeedRanges(self: *AlmanacReader, seeds_str: []const u8) !void {
        if (seeds_str.len < 7) {
            return ParseError.LineTooShortSeedNumbers;
        }

        // seeds_str = "seed: N1 L1 N2 L2 ..."
        var seeds = tokenizeAny(u8, seeds_str[6..], " ");

        self.num_seeds = 0;
        var start: ?u64 = null;
        var end: ?u64 = null;

        while (seeds.next()) |v| {
            if (start == null) {
                start = try std.fmt.parseUnsigned(u64, trim(u8, v, " "), 10);
                continue;
            }

            if (end == null) {
                end = start.? + try std.fmt.parseUnsigned(u64, trim(u8, v, " "), 10);
            }

            if (start != null and end != null) {
                try self.addSeedRange(start.?, end.?);
                start = null;
                end = null;
            }
        }

        if (start != null or end != null) {
            return ParseError.IncompleteSeedRangeSpecifier;
        }
    }

    fn addSeedRange(self: *AlmanacReader, start: u64, end: u64) !void {
        self.num_seeds += 1;
        if (self.num_seeds >= max_seed_ranges) {
            return ParseError.NumberOfSeedRangesExceedMaximumAllowed;
        }

        self.seeds[self.num_seeds - 1] = SeedRange{
            .start = start,
            .end = end,
        };
    }

    fn updateSeedNumbers(self: *AlmanacReader) !void {
        // print(">> {any}\n", .{self.seeds[0..self.num_seeds]});

        for (0..self.num_seeds) |i| {
            // If number was mapped, it is self-mapping.
            if (self.seeds[i].mapped_start == null) {
                continue;
            }

            self.seeds[i].start = self.seeds[i].mapped_start.?;
            self.seeds[i].end = self.seeds[i].mapped_end.?;

            self.seeds[i].mapped_start = null;
            self.seeds[i].mapped_end = null;
        }
    }

    fn mapSeedRange(self: *AlmanacReader, seed_range_index: usize, mapped_range: *MappedRange) !void {
        const seed_range = &self.seeds[seed_range_index];

        const seed_range_start = seed_range.start;
        const seed_range_end = seed_range.end;
        const mapped_range_start = mapped_range.source_start;
        const mapped_range_end = mapped_range_start + mapped_range.range;

        // print(">> seed_range_start={d}\tseed_range_end={d}\n", .{ seed_range_start, seed_range_end });

        // Fully overlaps.
        if (seed_range_start >= mapped_range_start and seed_range_end <= mapped_range_end) {
            seed_range.mapped_start = mapped_range.get(seed_range_start).?;
            seed_range.mapped_end = 1 + mapped_range.get(seed_range_end - 1).?;

            return;
        }

        // No overlap at all.
        if (seed_range_end <= mapped_range_start or seed_range_start >= mapped_range_end) {
            return;
        }

        // Partial overlap in the middle of the seed range.
        if (seed_range_start < mapped_range_start and seed_range_end > mapped_range_end) {
            seed_range.mapped_start = mapped_range.get(mapped_range_start).?;
            seed_range.mapped_end = 1 + mapped_range.get(mapped_range_end - 1).?;

            // Adding non-overlapping region as a new range.
            try self.addSeedRange(seed_range_start, mapped_range_start);
            try self.addSeedRange(mapped_range_end, seed_range_end);

            return;
        }

        // Partial overlap near the end of seed range.
        if (seed_range_start < mapped_range_start and seed_range_end <= mapped_range_end) {
            seed_range.mapped_start = mapped_range.get(mapped_range_start).?;
            seed_range.mapped_end = 1 + mapped_range.get(seed_range_end - 1).?;

            // Adding non-overlapping region as a new range.
            try self.addSeedRange(seed_range_start, mapped_range_start);

            return;
        }

        // Partial overlap near the start of the seed range
        if (seed_range_start < mapped_range_end and seed_range_end > mapped_range_end) {
            seed_range.mapped_start = mapped_range.get(seed_range_start).?;
            seed_range.mapped_end = 1 + mapped_range.get(mapped_range_end - 1).?;

            // Adding non-overlapping region as a new range.
            try self.addSeedRange(mapped_range_end, seed_range_end);

            return;
        }
    }

    fn mergeSeedRanges(self: *AlmanacReader) !void {
        _ = self;
    }

    pub fn getLowestSeedNumber(self: *AlmanacReader) u64 {
        var min_number: u64 = std.math.maxInt(u64);

        for (0..self.num_seeds) |i| {
            if (self.seeds[i].start < min_number) {
                min_number = self.seeds[i].start;
            }
        }

        return min_number;
    }
};

pub fn main() !void {
    var reader = AlmanacReader{
        .data = data,
        .seed_numbers_are_ranges = false,
    };

    try reader.run();

    print("part 1: lowest location number={d}\n", .{reader.getLowestSeedNumber()});

    reader = AlmanacReader{
        .data = data,
        .seed_numbers_are_ranges = true,
    };

    try reader.run();

    print("part 2: lowest location number={d}\n", .{reader.getLowestSeedNumber()});
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
