const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day04.txt");

const ParseError = error{
    LineTooShort,
    CardNumberExceedsMax,
};

const max_card_number = 256;

const PointsCounter = struct {
    data: []const u8,

    points: u32 = 0,
    total_cards_won: u32 = 0,

    card_num_copies: [max_card_number + 1]u32 = undefined,

    pub fn run(self: *PointsCounter) !void {
        var lines = tokenizeAny(u8, self.data, "\n");

        self.points = 0;
        self.total_cards_won = 0;
        self.card_num_copies = [_]u32{0} ** (max_card_number + 1); // Card numbers start from 1.

        while (lines.next()) |line| {
            try self.parseLine(line);
        }

        self.tallyCards();
    }

    pub fn parseLine(self: *PointsCounter, line: []const u8) !void {
        if (line.len < 4) {
            return ParseError.LineTooShort;
        }

        var a: ?usize = null;
        var b: ?usize = null;

        // Finding positions of ':' and '|' which indicates where each list of
        // numbers begin:
        //
        // 'Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53'
        //
        for (line, 0..) |c, i| {
            if (c == ':') {
                a = i;
                continue;
            }

            if (c == '|') {
                b = i;
                break;
            }
        }

        const card_number_str = trim(u8, line[4..a.?], " ");
        const card_number = try std.fmt.parseUnsigned(u16, card_number_str, 10);

        if (card_number > max_card_number) {
            return ParseError.CardNumberExceedsMax;
        }

        const want_numbers_str = line[a.? + 2 .. b.? - 1];
        const got_numbers_str = line[b.? + 2 ..];

        try self.update(card_number, want_numbers_str, got_numbers_str);
    }

    pub fn update(self: *PointsCounter, card_number: u16, want_numbers_str: []const u8, got_numbers_str: []const u8) !void {
        self.addCopyOfCard(card_number, 1);

        var want_numbers = tokenizeSeq(u8, want_numbers_str, " ");
        var got_numbers = tokenizeSeq(u8, got_numbers_str, " ");

        var num_matches: u16 = 0;

        while (got_numbers.next()) |got_num| {
            want_numbers.reset();

            while (want_numbers.next()) |want_num| {
                if (std.mem.eql(u8, want_num, got_num)) {
                    num_matches += 1;
                }
            }
        }

        if (num_matches == 0) {
            return;
        }

        // Update points sum for given number of matches.
        self.points += std.math.pow(u32, 2, @as(u32, @intCast(num_matches)) - 1);

        // For each copy of card # i, we add a copy of the card we won off of card # i.
        const num_copies = self.card_num_copies[card_number];

        var j = card_number + 1;
        const b = j + num_matches;

        while (j < b) : (j += 1) {
            self.addCopyOfCard(j, num_copies);
        }
    }

    pub fn tallyCards(self: *PointsCounter) void {
        for (self.card_num_copies) |num_copies| {
            self.total_cards_won += num_copies;
        }
    }

    pub fn addCopyOfCard(self: *PointsCounter, card_num: u16, num_copies: u32) void {
        self.card_num_copies[card_num] += num_copies;
    }
};

pub fn main() !void {
    var counter = PointsCounter{ .data = data };
    try counter.run();

    print("part 1: sum[points]={d}\n", .{counter.points});
    print("part 2: total cards won={d}\n", .{counter.total_cards_won});
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
