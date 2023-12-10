const std = @import("std");

const data = @embedFile("data/day09.txt");

const max_data_length = 64;
const max_diff_order = 32;

const ExtrapolationDirection = enum {
    Forward,
    Backward,
};

const Extrapolator = struct {
    sum_part1: i64 = 0,
    sum_part2: i64 = 0,

    buf1: std.BoundedArray(i32, max_data_length) = undefined,
    buf2: std.BoundedArray(i32, max_data_length) = undefined,
    edge_values: std.BoundedArray(i32, max_diff_order) = undefined,

    pub fn run(self: *Extrapolator, data_str: []const u8) !void {
        self.buf1 = try std.BoundedArray(i32, max_data_length).init(0);
        self.buf1 = try std.BoundedArray(i32, max_data_length).init(0);
        self.edge_values = try std.BoundedArray(i32, max_diff_order).init(0);

        self.sum_part1 = 0;

        var lines = std.mem.tokenizeAny(u8, data_str, "\n");

        while (lines.next()) |line| {
            try self.loadValuesIntoBuffer(line);

            self.sum_part1 += try self.extrapolateBufferContents(ExtrapolationDirection.Forward);
            self.sum_part2 += try self.extrapolateBufferContents(ExtrapolationDirection.Backward);
        }
    }

    fn loadValuesIntoBuffer(self: *Extrapolator, values_str: []const u8) !void {
        try self.buf1.resize(0);

        var values = std.mem.tokenizeAny(u8, values_str, " ");

        while (values.next()) |v_str| {
            try self.buf1.append(try std.fmt.parseInt(i32, v_str, 10));
        }
    }

    fn extrapolateBufferContents(self: *Extrapolator, direction: ExtrapolationDirection) !i32 {
        try self.edge_values.resize(0);
        try self.buf2.resize(0);

        // Copying data from buf1 into buf2, where it will be modified.
        for (self.buf1.slice()) |v| {
            self.buf2.appendAssumeCapacity(v);
        }

        while (self.bufValuesAreNotZero()) {
            try self.computeFiniteDiff(direction);
        }

        // Summing edge values in each set of differences to get extrapolated value.
        const edge_values = self.edge_values.slice();
        var value: i32 = 0;
        var i: usize = self.edge_values.len;

        switch (direction) {
            ExtrapolationDirection.Forward => {
                while (i > 0) {
                    i -= 1;
                    value += edge_values[i];
                }
            },
            ExtrapolationDirection.Backward => {
                while (i > 0) {
                    i -= 1;
                    value = edge_values[i] - value;
                }
            },
        }

        return value;
    }

    fn computeFiniteDiff(self: *Extrapolator, direction: ExtrapolationDirection) !void {
        const vector_len = std.simd.suggestVectorSize(i32) orelse 8;
        var i: usize = 1;
        var values = self.buf2.slice();

        // Store last value in buf for later when extrpolating.
        try self.edge_values.append(switch (direction) {
            ExtrapolationDirection.Forward => values[values.len - 1],
            ExtrapolationDirection.Backward => values[0],
        });

        while ((i + vector_len) < values.len) : (i += vector_len) {
            // Taking finite diff between successive elements.
            const a: @Vector(vector_len, i32) = values[i - 1 ..][0..vector_len].*;
            const b: @Vector(vector_len, i32) = values[i..][0..vector_len].*;
            const delta = b - a;

            // Copying results out to buf.
            for (0..vector_len) |j| {
                values[i - 1 + j] = delta[j];
            }
        }

        // Handle remainder.
        for (i..values.len) |j| {
            values[j - 1] = values[j] - values[j - 1];
        }

        // Shorten buf to only valid values.
        _ = self.buf2.pop();
    }

    fn bufValuesAreNotZero(self: *Extrapolator) bool {
        for (self.buf2.slice()) |v| {
            if (v != 0) {
                return true;
            }
        }

        return false;
    }
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var e = Extrapolator{};
    try e.run(data);

    std.debug.print("total time = {}\n", .{std.fmt.fmtDuration(timer.read())});
    std.debug.print("part 1: sum = {d}\n", .{e.sum_part1});
    std.debug.print("part 2: sum = {d}\n", .{e.sum_part2});
}

// Generated from template/template.zig.
// Run `zig build generate` to update.
// Only unmodified days will be updated.
