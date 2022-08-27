const example = "{'descr': '<f8', 'fortran_order': False, 'shape': (99,), }";
const std = @import("std");
const mem = std.mem;

const MAX_DIM = 8;

const Parser = struct {
    pub const ParserState = enum {
        Start,
        ExpectKey,
        InKey,
        ExpectColon,
        ExpectVal,

        StringVal,

        FalseLiteral1,
        FalseLiteral2,
        FalseLiteral3,
        FalseLiteral4,

        TrueLiteral1,
        TrueLiteral2,
        TrueLiteral3,

        Finished,
    };

    pub const ParseError = error{
        InvalidStart,
        ExpectedColon,
        ExpectedKey,
        ExpectedTrue,
        ExpectedFalse,
    };

    pub const Value = union(enum) {
        boolean: bool,
        string: []const u8,
        tuple: [0:MAX_DIM]u32,
    };

    state: ParserState = ParserState.Start,
    start: usize = 0,
    key: ?[]const u8 = null,

    pub fn init() Parser {
        return Parser{
            .state = ParserState.Start,
        };
    }

    pub fn parseDict(p: *Parser, input: []const u8, allocator: mem.Allocator) anyerror!std.StringHashMap(Value) {
        var map = std.StringHashMap(Value).init(allocator);
        errdefer map.deinit();

        for (input) |ch, i| {
            switch (p.state) {
                .Start => {
                    switch (ch) {
                        '{' => {
                            p.state = ParserState.ExpectKey;
                        },
                        else => {
                            return ParseError.InvalidStart;
                        },
                    }
                },
                .ExpectKey => {
                    switch (ch) {
                        '}' => {
                            p.state = ParserState.Finished;
                        },
                        ' ', ',' => {}, // Skip whitespace and comma
                        '\'' => {
                            p.state = ParserState.InKey;
                            p.start = i + 1;
                        },
                        else => {
                            return ParseError.ExpectedKey;
                        },
                    }
                },
                .InKey => {
                    switch (ch) {
                        '\'' => {
                            p.state = ParserState.ExpectColon;
                            p.key = input[p.start..i];
                        },
                        // Waiting for '
                        else => {
                            p.state = ParserState.InKey;
                        },
                    }
                },
                .ExpectColon => {
                    switch (ch) {
                        ' ' => {}, // Skip whitespace
                        ':' => {
                            p.state = ParserState.ExpectVal;
                        },
                        else => {
                            return ParseError.ExpectedColon;
                        },
                    }
                },
                .ExpectVal => {
                    switch (ch) {
                        ' ' => {}, // Skip whitespace
                        '\'' => {
                            p.state = .StringVal;
                            p.start = i + 1;
                        },
                        'T' => {
                            p.state = .TrueLiteral1;
                        },
                        'F' => {
                            p.state = .FalseLiteral1;
                        },
                        else => {
                            return ParseError.ExpectedColon;
                        },
                    }
                },
                // True
                .TrueLiteral1 => { // r -> u
                    switch (ch) {
                        'r' => {
                            p.state = .TrueLiteral2;
                        },
                        else => {
                            return ParseError.ExpectedTrue;
                        },
                    }
                },
                .TrueLiteral2 => { // u -> e
                    switch (ch) {
                        'u' => {
                            p.state = .TrueLiteral3;
                        },
                        else => {
                            return ParseError.ExpectedTrue;
                        },
                    }
                },
                .TrueLiteral3 => { // e -> finished
                    switch (ch) {
                        'e' => {
                            p.state = .ExpectKey;
                            try map.put(p.key.?, Value{ .boolean = true });
                        },
                        else => {
                            return ParseError.ExpectedTrue;
                        },
                    }
                },
                // False Literal
                .FalseLiteral1 => { // a -> l
                    switch (ch) {
                        'a' => {
                            p.state = .FalseLiteral2;
                        },
                        else => {
                            return ParseError.ExpectedFalse;
                        },
                    }
                },
                .FalseLiteral2 => { // l -> s
                    switch (ch) {
                        'l' => {
                            p.state = .FalseLiteral3;
                        },
                        else => {
                            return ParseError.ExpectedTrue;
                        },
                    }
                },
                .FalseLiteral3 => { // s -> e
                    switch (ch) {
                        's' => {
                            p.state = .FalseLiteral4;
                        },
                        else => {
                            return ParseError.ExpectedFalse;
                        },
                    }
                },
                .FalseLiteral4 => { // s -> e
                    switch (ch) {
                        'e' => {
                            p.state = .ExpectKey;
                            try map.put(p.key.?, Value{ .boolean = false });
                        },
                        else => {
                            return ParseError.ExpectedFalse;
                        },
                    }
                },
                .StringVal => { // s -> e
                    switch (ch) {
                        '\'' => {
                            p.state = .ExpectKey;
                            try map.put(p.key.?, Value{ .string = input[p.start..i] });
                        },
                        else => {},
                    }
                },
                .Finished => {
                    break;
                },
            }
            // std.debug.print("ch: {c}, i: {}, state: {}\n", .{ ch, i, p.state });
        }

        return map;
    }
};

const testing = std.testing;

test "empty dict" {
    const empty = "{}";
    const alloc = std.testing.allocator;
    var parser = Parser.init();
    var result = try parser.parseDict(empty[0..], alloc);
    defer result.deinit();
    try testing.expectEqual(@intCast(u32, 0), result.count());
}

test "single string" {
    const in = "{'hello':'world'}";
    const alloc = std.testing.allocator;
    var parser = Parser.init();
    var result = try parser.parseDict(in[0..], alloc);
    defer result.deinit();
    try testing.expectEqual(@intCast(u32, 1), result.count());

    const val = result.get("hello").?;
    const expected = Parser.Value{ .string = "world" };
    try testing.expectEqualStrings(expected.string, val.string);
}

test "single true" {
    const in = "{'ok': True}";
    const alloc = std.testing.allocator;
    var parser = Parser.init();
    var result = try parser.parseDict(in[0..], alloc);
    defer result.deinit();
    try testing.expectEqual(@intCast(u32, 1), result.count());

    const val = result.get("ok").?;
    const expected = Parser.Value{ .boolean = true };
    try testing.expectEqual(expected, val);
}

test "single false" {
    const in = "{'not_ok': False}";
    const alloc = std.testing.allocator;
    var parser = Parser.init();
    var result = try parser.parseDict(in[0..], alloc);
    defer result.deinit();
    try testing.expectEqual(@intCast(u32, 1), result.count());

    const val = result.get("not_ok").?;
    const expected = Parser.Value{ .boolean = false };
    try testing.expectEqual(expected, val);
}

test "multiple bools" {
    const in = "{'not_ok': False, 'is_ok': True}";
    const alloc = std.testing.allocator;
    var parser = Parser.init();
    var result = try parser.parseDict(in[0..], alloc);
    defer result.deinit();
    try testing.expectEqual(@intCast(u32, 2), result.count());

    {
        const val = result.get("not_ok").?;
        const expected = Parser.Value{ .boolean = false };
        try testing.expectEqual(expected, val);
    }

    {
        const val = result.get("is_ok").?;
        const expected = Parser.Value{ .boolean = true };
        try testing.expectEqual(expected, val);
    }
}

test "multiple values mixed" {
    const in = "{'not_ok': False, 'is_ok': True, 'ma_str': 'is_nice'}";
    const alloc = std.testing.allocator;
    var parser = Parser.init();
    var result = try parser.parseDict(in[0..], alloc);
    defer result.deinit();
    try testing.expectEqual(@intCast(u32, 3), result.count());

    {
        const val = result.get("not_ok").?;
        const expected = Parser.Value{ .boolean = false };
        try testing.expectEqual(expected, val);
    }

    {
        const val = result.get("is_ok").?;
        const expected = Parser.Value{ .boolean = true };
        try testing.expectEqual(expected, val);
    }

    {
        const val = result.get("ma_str").?;
        const expected = Parser.Value{ .string = "is_nice" };
        try testing.expectEqualStrings(expected.string, val.string);
    }
}
