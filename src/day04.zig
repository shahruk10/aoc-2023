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
};

const PointsCounter = struct {
    data: []const u8,

    points: u32 = 0,
    total_cards_won: u32 = 0,

    want_numbers_buffer: List(u16) = undefined,
    got_numbers_buffer: List(u16) = undefined,
    card_num_matches: Map(u16, u16) = undefined,
    card_num_copies: Map(u16, u32) = undefined,
    max_card_number: u16 = 0,

    pub fn run(self: *PointsCounter) !void {
        var lines = tokenizeAny(u8, self.data, "\n");

        self.want_numbers_buffer = List(u16).init(gpa);
        self.got_numbers_buffer = List(u16).init(gpa);
        self.card_num_matches = Map(u16, u16).init(gpa);
        self.card_num_copies = Map(u16, u32).init(gpa);

        const max_numbers = 100;
        const max_cards = 500;

        try self.want_numbers_buffer.ensureTotalCapacity(max_numbers);
        try self.got_numbers_buffer.ensureTotalCapacity(max_numbers);
        try self.card_num_matches.ensureTotalCapacity(max_cards);
        try self.card_num_copies.ensureTotalCapacity(max_cards);

        defer self.want_numbers_buffer.deinit();
        defer self.got_numbers_buffer.deinit();
        defer self.card_num_matches.deinit();
        defer self.card_num_copies.deinit();

        self.points = 0;
        self.total_cards_won = 0;

        while (lines.next()) |line| {
            try self.parseLine(line);
        }

        try self.tallyCards();
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

        if (card_number > self.max_card_number) {
            self.max_card_number = card_number;
        }

        const want_numbers_str = line[a.? + 2 .. b.? - 1];
        const got_numbers_str = line[b.? + 2 ..];

        try self.update(card_number, want_numbers_str, got_numbers_str);
    }

    pub fn update(self: *PointsCounter, card_number: u16, want_numbers_str: []const u8, got_numbers_str: []const u8) !void {
        try self.parseNumbersFromStr(want_numbers_str, &self.want_numbers_buffer);
        try self.parseNumbersFromStr(got_numbers_str, &self.got_numbers_buffer);

        var num_matches: u16 = 0;

        for (self.want_numbers_buffer.items) |want_num| {
            for (self.got_numbers_buffer.items) |got_num| {
                if (want_num == got_num) {
                    num_matches += 1;
                    break;
                }
            }
        }

        try self.card_num_matches.put(card_number, num_matches);

        if (num_matches > 0) {
            self.points += std.math.pow(u32, 2, @as(u32, @intCast(num_matches)) - 1);
        }
    }

    pub fn tallyCards(self: *PointsCounter) !void {
        for (0..self.max_card_number + 1) |card| {
            const i = @as(u16, @intCast(card));
            const num_matches = self.card_num_matches.get(i);

            // Card number is not valid.
            if (num_matches == null) {
                continue;
            }

            try self.addCopyOfCard(i);

            // If we didn't win any cards off of card # i, we move on to the next card.
            if (num_matches == 0) {
                continue;
            }

            // For each copy of card # i, we add a copy of the card we won off of card # i.
            for (0..self.card_num_copies.get(i).?) |_| {
                var j = i + 1;
                const b = j + num_matches.?;

                while (j < b) : (j += 1) {
                    try self.addCopyOfCard(j);
                }
            }
        }

        var cards = self.card_num_copies.keyIterator();

        while (cards.next()) |card| {
            const i = card.*;
            const num_copies = self.card_num_copies.get(i).?;
            const num_matches = self.card_num_matches.get(i).?;

            print(" - Card {d}\tmatching_numbers={d}\tcopies={d}\n", .{ i, num_matches, num_copies });

            self.total_cards_won += num_copies;
        }
    }

    pub fn addCopyOfCard(self: *PointsCounter, card_num: u16) !void {
        const num_copies = self.card_num_copies.get(card_num) orelse 0;
        try self.card_num_copies.put(card_num, num_copies + 1);
    }

    pub fn parseNumbersFromStr(self: *PointsCounter, str: []const u8, number_list: *List(u16)) !void {
        _ = self;

        number_list.clearRetainingCapacity();

        var numbers = splitSeq(u8, str, " ");

        while (numbers.next()) |num_str| {
            const num_str_trimmed = trim(u8, num_str, " ");
            if (num_str_trimmed.len == 0) {
                continue;
            }

            try number_list.append(try std.fmt.parseUnsigned(u16, num_str_trimmed, 10));
        }
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
