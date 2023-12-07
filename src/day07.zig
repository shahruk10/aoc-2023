const std = @import("std");

const data = @embedFile("data/day07.txt");

const max_hands = 1024;

const ParseError = error{
    HandMissing,
    BidMidding,
    InvalidNumberOfCardsInHand,
};

const HandType = enum(u4) {
    HighCard,
    OnePair,
    TwoPair,
    ThreeOfAKind,
    FullHouse,
    FourOfAKind,
    FiveOfAkind,
};

const joker = 9;

const Hand = struct {
    bid: u32,
    cards: [5]u4,
    hand_type: HandType,
    hand_type_with_joker: HandType,
};

pub fn compareHands(ctx: void, a: Hand, b: Hand) bool {
    _ = ctx;

    if (a.hand_type != b.hand_type) {
        return @intFromEnum(a.hand_type) < @intFromEnum(b.hand_type);
    }

    for (a.cards[0..], b.cards[0..]) |card_a, card_b| {
        if (card_a == card_b) {
            continue;
        }

        return card_a < card_b;
    }

    return false;
}

pub fn compareHandsWithJoker(ctx: void, a: Hand, b: Hand) bool {
    _ = ctx;

    if (a.hand_type_with_joker != b.hand_type_with_joker) {
        return @intFromEnum(a.hand_type_with_joker) < @intFromEnum(b.hand_type_with_joker);
    }

    for (a.cards[0..], b.cards[0..]) |card_a, card_b| {
        if (card_a == card_b) {
            continue;
        }

        if (card_a == joker) {
            return true;
        } else if (card_b == joker) {
            return false;
        }

        return card_a < card_b;
    }

    return false;
}

const CamelCardsComputer = struct {
    data: []const u8,

    hands: std.BoundedArray(Hand, max_hands) = undefined,
    winnings: u32 = 0,
    winnings_with_joker: u32 = 0,

    pub fn run(self: *CamelCardsComputer) !void {
        self.hands = try std.BoundedArray(Hand, max_hands).init(0);
        self.winnings = 0;

        var lines = std.mem.tokenizeAny(u8, self.data, "\n");

        // Reading hands.
        while (lines.next()) |line| {
            try self.readHand(line);
        }

        // Computing total winnings.
        self.updateWinnings();
    }

    fn readHand(self: *CamelCardsComputer, hand_str: []const u8) !void {
        var parts = std.mem.splitAny(u8, hand_str, " ");

        const cards_str = parts.next();
        if (cards_str == null) {
            return ParseError.HandMissing;
        }

        const bid_str = parts.next();
        if (bid_str == null) {
            return ParseError.BidMidding;
        }

        try self.hands.append(Hand{
            .bid = try std.fmt.parseUnsigned(u32, bid_str.?, 10),
            .cards = [_]u4{0} ** 5,
            .hand_type = undefined,
            .hand_type_with_joker = undefined,
        });

        try self.parseCards(cards_str.?, &self.hands.buffer[self.hands.len - 1]);
    }

    fn parseCards(self: *CamelCardsComputer, cards_str: []const u8, h: *Hand) !void {
        if (cards_str.len != 5) {
            return ParseError.InvalidNumberOfCardsInHand;
        }

        // Used for determining hand type.
        var num_unique_cards: u4 = 0;
        var card_counts = [_]u4{0} ** 13;

        for (cards_str, 0..) |c, i| {
            const card: u4 = switch (c) {
                'A' => 12,
                'K' => 11,
                'Q' => 10,
                'J' => joker,
                'T' => 8,
                else => @as(u4, @intCast(c - '2')),
            };

            h.cards[i] = card;

            // Incrementing count of card.
            card_counts[card] += 1;

            // Checking if card is unique in hand.
            var is_unique = true;

            for (0..i) |j| {
                if (card == h.cards[j]) {
                    is_unique = false;
                    break;
                }
            }

            if (is_unique) {
                num_unique_cards += 1;
            }
        }

        // Finding cards with the top two counts.
        var card_with_max_count: u4 = 0;
        var card_with_2nd_max_count: u4 = 0;
        var i: u4 = 0;

        for (card_counts) |count| {
            if (count > card_counts[card_with_max_count]) {
                card_with_2nd_max_count = card_with_max_count;
                card_with_max_count = i;
            } else if (count > card_counts[card_with_2nd_max_count]) {
                card_with_2nd_max_count = i;
            }

            i += 1;
        }

        var max_card_count = card_counts[card_with_max_count];

        // Determining hand type.
        h.hand_type = self.getHandType(num_unique_cards, max_card_count);

        // No joker in hand.
        if (card_counts[joker] == 0) {
            h.hand_type_with_joker = h.hand_type;
            return;
        }

        // Card with most count is the joker. Convert jokers into card with next highest count.
        if (card_with_max_count == joker) {
            max_card_count = card_counts[card_with_2nd_max_count] + card_counts[joker];
            num_unique_cards -= 1;
            h.hand_type_with_joker = self.getHandType(num_unique_cards, max_card_count);

            return;
        }

        // Convert jokers into card with highest count.
        max_card_count += card_counts[joker];
        num_unique_cards -= 1;
        h.hand_type_with_joker = self.getHandType(num_unique_cards, max_card_count);
    }

    fn getHandType(self: *CamelCardsComputer, num_unique_cards: u4, max_card_count: u4) HandType {
        _ = self;

        return switch (num_unique_cards) {
            5 => HandType.HighCard,
            4 => HandType.OnePair,
            3 => if (max_card_count == 2) HandType.TwoPair else HandType.ThreeOfAKind,
            2 => if (max_card_count == 3) HandType.FullHouse else HandType.FourOfAKind,
            else => HandType.FiveOfAkind,
        };
    }

    fn updateWinnings(self: *CamelCardsComputer) void {
        // Sorting hands without using joker rule.
        std.sort.block(Hand, self.hands.buffer[0..self.hands.len], {}, compareHands);

        var rank: u32 = 1;
        for (self.hands.slice()) |hand| {
            self.winnings += (rank * hand.bid);
            rank += 1;
        }

        // Sorting hands without using joker rule.
        std.sort.block(Hand, self.hands.buffer[0..self.hands.len], {}, compareHandsWithJoker);

        rank = 1;
        for (self.hands.slice()) |hand| {
            self.winnings_with_joker += (rank * hand.bid);
            rank += 1;
        }
    }
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var c = CamelCardsComputer{
        .data = data,
    };

    try c.run();

    std.debug.print("total time={}\n", .{std.fmt.fmtDuration(timer.read())});
    std.debug.print("part 1: total winnings={d}\n", .{c.winnings});
    std.debug.print("part 2: total winnings with joker rule={d}\n", .{c.winnings_with_joker});
}

// Generated from template/template.zig.
// Run `zig build generate` to update.
// Only unmodified days will be updated.
