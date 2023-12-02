const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const Map = std.AutoHashMap;
const StrMap = std.StringHashMap;
const BitSet = std.DynamicBitSet;

const util = @import("util.zig");
const gpa = util.gpa;

const data = @embedFile("data/day01.txt");

pub fn getCalibrationVal(str: []const u8, check_text: bool) u32 {
    const digits_text = [_][]const u8{
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
    };

    var first_digit: ?u8 = null;
    var last_digit: ?u8 = null;

    for (str, 0..) |c, offset| {
        if (std.ascii.isDigit(c)) {
            last_digit = (c - '0');
            first_digit = first_digit orelse last_digit;

            continue;
        }

        if (!check_text) {
            continue;
        }

        for (digits_text, 0..) |digit_text, digit| {
            if (offset + digit_text.len > str.len) {
                continue;
            }

            if (std.mem.startsWith(u8, str[offset..], digit_text)) {
                last_digit = @as(u8, @intCast(digit));
                first_digit = first_digit orelse last_digit;

                break;
            }
        }
    }

    return (first_digit orelse 0) * 10 + (last_digit orelse 0);
}

pub fn main() !void {
    var lines = tokenizeAny(u8, data, "\n");

    var sum_part1: u32 = 0;
    var sum_part2: u32 = 0;

    while (lines.next()) |line| {
        sum_part1 += getCalibrationVal(line, false);
        sum_part2 += getCalibrationVal(line, true);
    }

    print("part 1: sum[calibration values]={d}\n", .{sum_part1});
    print("part 2: sum[calibration values from digit and text]={d}\n", .{sum_part2});
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
