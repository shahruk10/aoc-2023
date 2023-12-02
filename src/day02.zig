const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day02.txt");

const TurnStat = struct {
    num_red: u32,
    num_green: u32,
    num_blue: u32,

    pub fn initFomLine(line: []const u8) !*TurnStat {
        var ball_counts = tokenizeSeq(u8, line, ", ");

        var turn = try gpa.create(TurnStat);
        turn.num_red = 0;
        turn.num_green = 0;
        turn.num_blue = 0;

        while (ball_counts.next()) |ball_count| {
            var c = trim(u8, ball_count, " ");

            if (endsWith(u8, c, "red")) {
                turn.num_red = try parseUnsigned(u32, c[0 .. c.len - 4], 10);
            } else if (endsWith(u8, c, "green")) {
                turn.num_green = try parseUnsigned(u32, c[0 .. c.len - 6], 10);
            } else if (endsWith(u8, c, "blue")) {
                turn.num_blue = try parseUnsigned(u32, c[0 .. c.len - 5], 10);
            }
        }

        return turn;
    }

    pub fn isNotPossible(self: TurnStat, total_red: u32, total_green: u32, total_blue: u32) bool {
        if (self.num_red > total_red) {
            return true;
        }

        if (self.num_green > total_green) {
            return true;
        }

        if (self.num_blue > total_blue) {
            return true;
        }

        return false;
    }
};

const GameStat = struct {
    id: u32 = undefined,
    turns: ArrayList(*TurnStat) = undefined,

    pub fn initFomLine(line: []const u8) !*GameStat {
        var turns = tokenizeAny(u8, line, ":;");

        var game = try gpa.create(GameStat);

        if (turns.next()) |game_id_str| {
            game.id = try parseUnsigned(u32, trim(u8, game_id_str, "Game "), 10);
        }

        game.turns = ArrayList(*TurnStat).init(gpa);

        while (turns.next()) |turn| {
            try game.turns.append(try TurnStat.initFomLine(turn));
        }

        return game;
    }

    pub fn isNotPossible(self: *GameStat, total_red: u32, total_green: u32, total_blue: u32) bool {
        for (self.turns.items) |turn| {
            if (turn.isNotPossible(total_red, total_green, total_blue)) {
                return true;
            }
        }

        return false;
    }

    pub fn powerOfMinSet(self: *GameStat, total_red: u32, total_green: u32, total_blue: u32) u32 {
        var num_red: u32 = 0;
        var num_green: u32 = 0;
        var num_blue: u32 = 0;

        for (self.turns.items) |turn| {
            if (turn.num_red > num_red) {
                num_red = turn.num_red;
            }

            if (turn.num_green > num_green) {
                num_green = turn.num_green;
            }

            if (turn.num_blue > num_blue) {
                num_blue = turn.num_blue;
            }
        }

        var p: u32 = 1;
        p *= if (num_red > 0) num_red else total_red;
        p *= if (num_green > 0) num_green else total_green;
        p *= if (num_blue > 0) num_blue else total_blue;

        return p;
    }

    pub fn describe(self: *GameStat) void {
        print("game_id={d}\n", .{self.id});

        for (self.turns.items, 1..) |turn, i| {
            print("  - Turn {d}\tnum_red={d}\tnum_green={d}\tnum_blue={d}\n", .{ i, turn.num_red, turn.num_green, turn.num_blue });
        }
    }
};

pub fn main() !void {
    var lines = tokenizeAny(u8, data, "\n");

    const total_red: u32 = 12;
    const total_green: u32 = 13;
    const total_blue: u32 = 14;

    var sum_of_ids: u32 = 0;
    var sum_of_powers: u32 = 0;

    while (lines.next()) |line| {
        const game = try GameStat.initFomLine(line);
        game.describe();

        var is_possible = !game.isNotPossible(total_red, total_green, total_blue);
        var power_of_min_set = game.powerOfMinSet(total_red, total_green, total_blue);

        print("  > possible={}\t> power_of_min_set={}\n", .{ is_possible, power_of_min_set });
        print("\n", .{});

        if (is_possible) {
            sum_of_ids += game.id;
        }

        sum_of_powers += power_of_min_set;
    }

    print("part 1: sum[ids for possible games]={d}\n", .{sum_of_ids});
    print("part 2: sum[power of minimum set]={d}\n", .{sum_of_powers});
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
const endsWith = std.mem.endsWith;

const parseInt = std.fmt.parseInt;
const parseFloat = std.fmt.parseFloat;
const parseUnsigned = std.fmt.parseUnsigned;

const print = std.debug.print;
const assert = std.debug.assert;

const sort = std.sort.block;
const asc = std.sort.asc;
const desc = std.sort.desc;

const ArrayList = std.ArrayList;

const maxInt = std.math.maxInt;

// Generated from template/template.zig.
// Run `zig build generate` to update.
// Only unmodified days will be updated.
