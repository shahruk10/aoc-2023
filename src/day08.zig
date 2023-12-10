const std = @import("std");

const data = @embedFile("data/day08.txt");

const max_start_nodes = 128;
const max_instruction_len = 512;

const ParseError = error{
    MissingInstructionsLine,
    MissingNodeName,
    MissingNodeOnTheLeft,
    MissingNodeOnTheRight,
    UnknownInstruction,
};

const Instruction = enum {
    Left,
    Right,
};

const Node = struct {
    name: []const u8,
    left: *const Node = undefined,
    right: *const Node = undefined,

    pub fn init(alloc: std.mem.Allocator, name: []const u8, left: ?*const Node, right: ?*const Node) !*Node {
        var n = try alloc.create(Node);

        n.name = name;
        n.left = left orelse undefined;
        n.right = right orelse undefined;

        return n;
    }
};

const Network = struct {
    alloc: std.mem.Allocator,

    steps_required_part1: usize = undefined,
    steps_required_part2: usize = undefined,

    instructions: std.BoundedArray(Instruction, max_instruction_len) = undefined,
    nodes: std.StringHashMap(*Node) = undefined,
    current_paths: std.BoundedArray(*Node, max_start_nodes) = undefined,

    pub fn run(self: *Network, network_str: []const u8) !void {
        self.instructions = try std.BoundedArray(Instruction, max_instruction_len).init(0);
        self.current_paths = try std.BoundedArray(*Node, max_start_nodes).init(0);
        self.nodes = std.StringHashMap(*Node).init(self.alloc);

        try self.readNetwork(network_str);

        self.steps_required_part1 = self.countStepsPart1();
        self.steps_required_part2 = self.countStepsPart2();
    }

    fn readNetwork(self: *Network, network_str: []const u8) !void {
        var lines = std.mem.tokenizeAny(u8, network_str, "\n");

        if (lines.next()) |instructions| {
            for (std.mem.trim(u8, instructions, " ")) |c| {
                try self.instructions.append(switch (c) {
                    'L' => Instruction.Left,
                    'R' => Instruction.Right,
                    else => return ParseError.UnknownInstruction,
                });
            }
        } else {
            return ParseError.MissingInstructionsLine;
        }

        while (lines.next()) |line| {
            try self.readNode(line);
        }
    }

    fn readNode(self: *Network, node_str: []const u8) !void {
        var parts = std.mem.tokenizeAny(u8, node_str, " =(,)");

        const from = parts.next();
        if (from == null) {
            return ParseError.MissingNodeName;
        }

        const left = parts.next();
        if (left == null) {
            return ParseError.MissingNodeOnTheLeft;
        }

        const right = parts.next();
        if (right == null) {
            return ParseError.MissingNodeOnTheRight;
        }

        const left_node = try self.getOrAddNode(left.?, null, null);
        const right_node = try self.getOrAddNode(right.?, null, null);
        const from_node = try self.getOrAddNode(from.?, left_node, right_node);

        // Nodes that end with A are starting nodes.
        if (self.isStartingNode(from.?)) {
            try self.current_paths.append(from_node);
        }
    }

    fn getOrAddNode(self: *Network, name: []const u8, left: ?*const Node, right: ?*const Node) !*Node {
        const n = try self.nodes.getOrPut(name);

        if (n.found_existing) {
            const node = n.value_ptr.*;

            if (left != null) {
                node.left = left.?;
            }

            if (right != null) {
                node.right = right.?;
            }

            return node;
        }

        n.value_ptr.* = try Node.init(self.alloc, name, left, right);

        return n.value_ptr.*;
    }

    fn countStepsPart1(self: *Network) usize {
        var steps: usize = 0;

        const instructions = self.instructions.slice();
        const to = "ZZZ";

        var current: *const Node = self.nodes.get("AAA").?;

        while (!std.mem.eql(u8, current.name, to) or steps == 0) : (steps += 1) {
            const inst = instructions[steps % instructions.len];

            current = switch (inst) {
                Instruction.Left => current.left,
                Instruction.Right => current.right,
            };
        }

        return steps;
    }

    fn countStepsPart2(self: *Network) usize {
        const instructions = self.instructions.slice();

        // Each path ends in an ending node, that ultimately loops back:
        //
        // [][]A ->  LoopStartNode -> ... Nodes ... -> [][]Z -> LoopStartNode
        //
        // This allows to find the number of steps required for LoopStartNode ->
        // [][]Z -> LoopStartNode for each path independently, and computing the
        // least common multiple between them to get the common number of steps
        // for all to reach [][]Z.
        //
        // Node that the number of steps for LoopStartNode -> [][]Z ->
        // LoopStartNode is equivalent to the number of steps for [][]A ->
        // [][]Z.
        var steps_common_multiple: usize = 1;

        for (self.current_paths.slice()) |n| {
            var current: *const Node = n;
            var steps: usize = 0;

            while (!self.isEndingNode(current.name)) : (steps += 1) {
                const inst = instructions[steps % instructions.len];

                current = switch (inst) {
                    Instruction.Left => current.left,
                    Instruction.Right => current.right,
                };
            }

            steps_common_multiple = self.lcm(steps_common_multiple, steps);
        }

        return steps_common_multiple;
    }

    fn isStartingNode(_: *Network, name: []const u8) bool {
        return name[name.len - 1] == 'A';
    }

    fn isEndingNode(_: *Network, name: []const u8) bool {
        return name[name.len - 1] == 'Z';
    }

    fn lcm(_: *Network, a: usize, b: usize) usize {
        var gcd = a;
        var y = b;

        while (y != 0) {
            const tmp = gcd;
            gcd = y;
            y = tmp % y;
        }

        return (a * b) / gcd;
    }
};

pub fn main() !void {
    var timer = try std.time.Timer.start();

    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();

    var net = Network{ .alloc = alloc.allocator() };
    try net.run(data);

    std.debug.print("total time = {}\n", .{std.fmt.fmtDuration(timer.read())});
    std.debug.print("part 1: number of steps = {d}\n", .{net.steps_required_part1});
    std.debug.print("part 2: number of steps = {d}\n", .{net.steps_required_part2});
}

// Generated from template/template.zig.
// Run `zig build generate` to update.
// Only unmodified days will be updated.
