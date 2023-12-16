const std = @import("std");

const data = @embedFile("data/day15.txt");

const num_boxes = 256;
const max_slots_per_box = 32;

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var seq = std.mem.tokenizeAny(
        u8,
        std.mem.trim(u8, data, " \n"),
        ",",
    );

    var boxes: [num_boxes]std.BoundedArray(Lens, max_slots_per_box) =
        [_]std.BoundedArray(Lens, max_slots_per_box){
        try std.BoundedArray(Lens, max_slots_per_box).init(0),
    } ** num_boxes;

    var lens = Lens{ .label = undefined, .power = undefined };

    var part_1_ans: usize = 0;
    var part_2_ans: usize = 0;

    read_loop: while (seq.next()) |step| {
        part_1_ans += @as(usize, @intCast(hash(step)));

        var parts = std.mem.tokenizeAny(u8, step, "=-");

        if (parts.next()) |label| {
            lens.label = label;
        } else {
            return ParseError.MissingLensLabel;
        }

        const k = hash(lens.label);
        var slots = boxes[k].slice();

        if (parts.next()) |power| {
            // Put operation.
            lens.power = try std.fmt.parseUnsigned(u8, power, 10);

            for (slots, 0..) |s, i| {
                if (std.mem.eql(u8, s.label, lens.label)) {
                    slots[i].power = lens.power;
                    continue :read_loop;
                }
            }

            boxes[k].appendAssumeCapacity(lens);
        } else {
            // Delete operation.
            var slot_to_delete: ?usize = null;

            for (slots, 0..) |s, i| {
                if (std.mem.eql(u8, s.label, lens.label)) {
                    slot_to_delete = i;
                    break;
                }
            }

            if (slot_to_delete) |i| {
                for (i..slots.len) |j| {
                    slots[j] = slots[j + 1];
                }

                _ = boxes[k].pop();
            }
        }
    }

    for (boxes, 1..) |b, i| {
        const slots = b.slice();
        for (slots, 1..) |s, j| {
            part_2_ans += i * j * s.power;
        }
    }

    std.debug.print("total time = {}\n", .{std.fmt.fmtDuration(timer.read())});
    std.debug.print("part 1: sum of hash values = {d}\n", .{part_1_ans});
    std.debug.print("part 2: sum of focusing power = {d}\n", .{part_2_ans});
}

const ParseError = error{
    MissingLensLabel,
};

const Box = struct {
    slots: std.BoundedArray(Lens, max_slots_per_box),
};

const Lens = struct {
    label: []const u8,
    power: u8,
};

pub fn hash(str: []const u8) u8 {
    var value: u16 = 0;

    for (str) |c| {
        value += c;
        value = (value * 17) % 256;
    }

    return @as(u8, @intCast(value));
}

// Generated from template/template.zig.
// Run `zig build generate` to update.
// Only unmodified days will be updated.
