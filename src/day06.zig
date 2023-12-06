const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day06.txt");

const max_digits = 16;

const ParseError = error{
    MissingLineRaceTimes,
    MissingLineRaceDistances,
    MissingValueRaceTime,
    MissingValueRaceDistance,
    NumberOfDigitsExceedMaximumAllowed,
};

const RaceComputer = struct {
    data: []const u8,
    acceleration: u32,

    num_ways_win_part1: u32 = 1,
    num_ways_win_part2: u32 = 1,

    t_str: [max_digits]u8 = undefined,
    t_str_index: u8 = 0,

    d_str: [max_digits]u8 = undefined,
    d_str_index: u8 = 0,

    pub fn run(self: *RaceComputer) !void {
        self.num_ways_win_part1 = 1;
        self.num_ways_win_part2 = 1;

        self.t_str = [_]u8{0} ** max_digits;
        self.d_str = [_]u8{0} ** max_digits;
        self.t_str_index = 0;
        self.d_str_index = 0;

        try self.processRaceData();
    }

    fn processRaceData(self: *RaceComputer) !void {
        var lines = std.mem.tokenizeAny(u8, self.data, "\n");

        const race_times_str = lines.next();
        if (race_times_str == null) {
            return ParseError.MissingLineRaceTimes;
        }

        const race_dists_str = lines.next();
        if (race_dists_str == null) {
            return ParseError.MissingLineRaceDistances;
        }

        var iter_times = std.mem.tokenizeAny(u8, race_times_str.?, " ");
        var iter_dists = std.mem.tokenizeAny(u8, race_dists_str.?, " ");

        // Consume row name.
        var t = iter_times.next();
        var d = iter_dists.next();

        while (true) {
            t = iter_times.next();
            d = iter_dists.next();

            if (t == null and d == null) {
                break;
            } else if (t == null) {
                return ParseError.MissingValueRaceTime;
            } else if (d == null) {
                return ParseError.MissingValueRaceDistance;
            }

            // Append digits to form the single number for time and distance.
            if (((t.?.len + self.t_str_index) >= max_digits) or ((d.?.len + self.d_str_index) >= max_digits)) {
                return ParseError.NumberOfDigitsExceedMaximumAllowed;
            }

            for (t.?) |c| {
                self.t_str[self.t_str_index] = c;
                self.t_str_index += 1;
            }

            for (d.?) |c| {
                self.d_str[self.d_str_index] = c;
                self.d_str_index += 1;
            }

            const total_race_time = try std.fmt.parseFloat(f32, t.?);
            const record_race_dist = try std.fmt.parseFloat(f32, d.?);
            self.updateNumWaysToWin(f32, total_race_time, record_race_dist, &self.num_ways_win_part1);
        }

        // For Part 2.
        const total_race_time = try std.fmt.parseFloat(f64, self.t_str[0..self.t_str_index]);
        const record_race_dist = try std.fmt.parseFloat(f64, self.d_str[0..self.d_str_index]);
        self.updateNumWaysToWin(f64, total_race_time, record_race_dist, &self.num_ways_win_part2);
    }

    fn updateNumWaysToWin(self: *RaceComputer, comptime T: type, total_race_time: T, record_race_dist: T, count: *u32) void {
        // Let,
        //  a = accleration
        //  t = total_race_time
        //  D = record_race_dist + 1
        //  tₐ = time_for_acceleration
        //  tₘ = time_for_moving
        //  d = actual_distance_travelled
        //
        // We have,
        //  T = tₐ + t_m => tₘ = (T - tₐ)
        //
        //  d = (a * tₐ) * tₘ
        //    = (a * tₐ) * (T - tₐ)
        //    = -a * tₐ² + a * T * tₐ
        //
        // where d = f(tₐ) is a quadratic with a maximum.
        //
        // The roots of f(tₐ) = D gives us the values of tₐ, between which,
        // d will be greater or equal to D.
        //
        // tₐ = ( aT ± sqrt( (aT)² - 4aD ) ) / 2
        //    = ( aT ± det ) / 2
        //
        // where det = sqrt( (aT)² - 4aD )
        //
        // =>  t1 = (aT - det) / 2
        // and t2 = (aT + det) / 2
        //
        // The number of ways to win is the number of valid integer time values
        // between the two roots = ceil(t1) - floor(t2) + 1.
        const a = @as(T, @floatFromInt(self.acceleration));
        const t = total_race_time;
        const D = record_race_dist + 0.5;

        const at = a * t;
        const det = std.math.sqrt(at * at - 4 * a * D);

        const t1 = std.math.ceil((at - det) / 2);
        const t2 = std.math.floor((at + det) / 2);
        const n = t2 - t1 + 1;

        count.* *= @as(u32, @intFromFloat(n));
    }
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var c = RaceComputer{
        .data = data,
        .acceleration = 1,
    };

    try c.run();

    std.debug.print("total time={}\n", .{std.fmt.fmtDuration(timer.read())});
    std.debug.print("part 1: number of ways to win={d}\n", .{c.num_ways_win_part1});
    std.debug.print("part 2: number of ways to win={d}\n", .{c.num_ways_win_part2});
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
