test "two empty lines after block" {
    try testTransform(
        \\const foo = fn(a)
        \\    a * 4
        \\const bar = 2
    ,
        \\const foo = fn(a)
        \\    a * 4
        \\
        \\
        \\const bar = 2
        \\
    );
}

test "respect new lines" {
    try testCanonical(
        \\const foo = 1
        \\
        \\const bar = 2
        \\
    );
    try testTransform(
        \\const foo = 1
        \\
        \\
        \\const bar = 2
    ,
        \\const foo = 1
        \\
        \\const bar = 2
        \\
    );
}

test "native function" {
    try testCanonical(
        \\const foo = native("bar.foo")
        \\
    );
}

test "nested blocks" {
    try testCanonical(
        \\if (false)
        \\    if (false)
        \\        3
        \\    else if (true)
        \\        4
        \\    else
        \\        5
        \\
    );
}

test "preserve comment after comma" {
    try testCanonical(
        \\(1, #hello world
        \\    2)
        \\
    );
    // TODO make this prettier
    try testCanonical(
        \\(1#hello world
        \\    , 2)
        \\
    );
}

test "range operator" {
    try testCanonical(
        \\1...2
        \\
    );
}

test "preserve comments" {
    try testCanonical(
        \\#some comment
        \\123 + #another comment
        \\    #third comment
        \\    2
        \\#fourth comment
        \\#fifth comment
        \\
    );
}

test "match" {
    try testCanonical(
        \\match (2)
        \\    let (x, 2): x + 4
        \\    2, 3: 1
        \\    _: ()
        \\
    );
}

test "if" {
    try testCanonical(
        \\if (foo) bar else baz
        \\if (const foo = bar()) baz
        \\
    );
}

test "catch" {
    try testCanonical(
        \\foo() catch bar()
        \\baz() catch (const e) return e
        \\
    );
}

test "tuples, lists, maps" {
    try testCanonical(
        \\(a, b)
        \\[a, b]
        \\{a: b, c: d}
        \\
    );
    try testTransform(
        \\(a,b,c,)
    ,
        \\(
        \\    a,
        \\    b,
        \\    c,
        \\)
        \\
    );
}

test "functions" {
    try testCanonical(
        \\const foo = fn(arg1, arg2, _, arg3) (arg1, arg2, arg3)
        \\const bar = fn(val)
        \\    val * 45
        \\
    );
}

test "unicode identifiers" {
    try testTransform(
        \\öäöäö;öö
    ,
        \\öäöäö
        \\öö
        \\
    );
}

test "trailing comma in call" {
    try testCanonical(
        \\foo(2, 3)
        \\bar(
        \\    2,
        \\    3,
        \\)
        \\
    );
    try testTransform(
        \\foo(2,3,)
        \\bar(
        \\    2,
        \\    3
        \\)
        \\
    ,
        \\foo(
        \\    2,
        \\    3,
        \\)
        \\bar(
        \\    2,
        \\    3,
        \\)
        \\
    );
}

test "loops" {
    try testCanonical(
        \\while (true) break
        \\return 123 // 4
        \\for (let foo in arr) foo + 2
        \\for (1...3) continue
        \\
    );
}

test "declarations" {
    try testCanonical(
        \\let bar = import("args")
        \\const foo = bar + 2
        \\let err = error(foo)
        \\
    );
}

test "suffix ops" {
    try testCanonical(
        \\foo[2].bar(2).baz[5 + 5]
        \\
    );
}

test "prefix ops" {
    try testCanonical(
        \\not true
        \\-2
        \\
    );
}

test "infix ops" {
    try testCanonical(
        \\123 + 2 * 3 / (4 as num) + ()
        \\
    );
}

const std = @import("std");
const mem = std.mem;
const warn = std.debug.warn;
const bog = @import("bog");

var buffer: [10 * 1024]u8 = undefined;

fn fmt(source: []const u8) ![]u8 {
    var buf_alloc = std.heap.FixedBufferAllocator.init(buffer[0..]);
    const alloc = &buf_alloc.allocator;

    var errors = bog.Errors.init(alloc);
    var tree = bog.parse(alloc, source, &errors) catch |e| switch (e) {
        error.OutOfMemory => return error.OutOfMemory,
        error.TokenizeError, error.ParseError => {
            try errors.render(source, std.io.getStdErr().outStream());
            return e;
        },
    };

    var out_buf = try std.Buffer.initSize(alloc, 0);
    try tree.render(out_buf.outStream());
    return out_buf.toOwnedSlice();
}

fn testTransform(source: []const u8, expected: []const u8) !void {
    const result = try fmt(source);
    if (!mem.eql(u8, result, expected)) {
        warn("\n---expected----\n{}\n-----found-----\n{}\n---------------\n", .{ expected, result });
        return error.TestFailed;
    }
}

fn testCanonical(source: []const u8) !void {
    return testTransform(source, source);
}
