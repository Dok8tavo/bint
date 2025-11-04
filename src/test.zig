const std = @import("std");
const bint = @import("bint");
const cfg = @import("cfg");

const Bint = bint.Bint(cfg.min, cfg.max);

const Ints = struct {
    current: Bint.Backing = std.math.minInt(Bint.Backing),

    fn next(i: *Ints) ?Bint.Backing {
        if (i.current == std.math.maxInt(Bint.Backing))
            return null;

        defer i.current += 1;
        return i.current;
    }
};

const Bints = struct {
    current: ?Bint.Backing = cfg.min,

    fn next(b: *Bints) ?Bint {
        const current = b.current orelse return null;

        defer b.current = if (current == cfg.max) null else current + 1;
        return @enumFromInt(current);
    }
};

// The `expect` function is equivalent to being within the bounds.
test "expect property" {
    var i = Ints{};
    while (i.next()) |int| {
        const b: Bint = @enumFromInt(int);
        if (int < cfg.min or cfg.max < int) try std.testing.expectError(
            error.OutOfBoundsInteger,
            b.expect(),
        ) else try b.expect();
    }
}

// Each passing value returned by `init` is within the bounds.
test "init return" {
    var i = Ints{};
    while (i.next()) |int| {
        if (Bint.init(int)) |b|
            try b.expect()
        else |_| {}
    }
}

// Each value returned by `add` is within the bounds.
test "add return" {
    var xi = Bints{};
    while (xi.next()) |x| {
        var yi = Bints{};
        while (yi.next()) |y|
            try x.add(y).expect();
    }
}

// Each value returned by `sub` is within the bounds.
test "sub return" {
    var xi = Bints{};
    while (xi.next()) |x| {
        var yi = Bints{};
        while (yi.next()) |y|
            try x.sub(y).expect();
    }
}

// Each value returned by `mul` is within the bounds.
test "mul return" {
    var xi = Bints{};
    while (xi.next()) |x| {
        var yi = Bints{};
        while (yi.next()) |y|
            try x.mul(y).expect();
    }
}

// Each value returned by `divFloor` is within the bounds.
test "divFloor return" {
    var xi = Bints{};
    while (xi.next()) |x| {
        var yi = Bints{};
        while (yi.next()) |y| {
            if (x.divFloor(y)) |z|
                try z.expect()
            else |_| {}
        }
    }
}

// Each value returned by `divTrunc` is within the bounds.
test "divTrunc return" {
    var xi = Bints{};
    while (xi.next()) |x| {
        var yi = Bints{};
        while (yi.next()) |y| {
            if (x.divTrunc(y)) |z|
                z.expect() catch {
                    std.debug.print("{} divTrunc {} = {}\n", .{ x.value(), y.value(), z.value() });
                    std.debug.print("\n{} <= {} <= {}\n", .{ @TypeOf(z).min_value, z.value(), @TypeOf(z).max_value });
                    return error.OutOfBoundsInteger;
                }
            else |_| {}
        }
    }
}

const est = .{
    Bint.min_value - 1,
    Bint.min_value,
    Bint.min_value + 1,

    Bint.mid_value - 1,
    Bint.mid_value,
    Bint.mid_value + 1,

    Bint.max_value - 1,
    Bint.max_value,
    Bint.max_value + 1,
};

// Each bint returned by `furthest` is within the bounds.
test "furthest return" {
    inline for (est) |int|
        if (Bint.furthestStatic(int).bint()) |furthest|
            try furthest.expect();
}

// Each bint returned by `closest` is within the bounds.
test "closest return" {
    inline for (est) |int|
        try Bint.closestStatic(int).expect();
}

// Each bint returned by `floor` is within the bounds.
test "floor return" {
    var xi = Bints{};
    while (xi.next()) |x| {
        var yi = Bints{};
        while (yi.next()) |y| {
            const floored = x.floor(y) catch continue;
            try floored.expect();
        }
    }
}

// Each bint returned by `ceil` is within the bounds.
test "ceil return" {
    var xi = Bints{};
    while (xi.next()) |x| {
        var yi = Bints{};
        while (yi.next()) |y| {
            const ceiled = x.ceil(y) catch continue;
            try ceiled.expect();
        }
    }
}

// Each bint returned by `max` is within the bounds.
test "max return" {
    var xi = Bints{};
    while (xi.next()) |x| {
        var yi = Bints{};
        while (yi.next()) |y|
            try x.max(y).expect();
    }
}

// Each bint returned by `min` is within the bounds.
test "min return" {
    var xi = Bints{};
    while (xi.next()) |x| {
        var yi = Bints{};
        while (yi.next()) |y|
            try x.min(y).expect();
    }
}

// Each bint returned by `abs` is within the bounds.
test "abs return" {
    var xi = Bints{};
    while (xi.next()) |x|
        try x.abs().expect();
}
