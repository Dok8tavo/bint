const std = @import("std");

pub const Range = @import("Range.zig");

pub fn from(anyint: anytype) From(@TypeOf(anyint)) {
    if (comptime isBint(@TypeOf(anyint)))
        return anyint;
    return @enumFromInt(anyint);
}

pub fn fromComptime(comptime anyint: comptime_int) FromComptime(anyint) {
    return @enumFromInt(anyint);
}

pub fn FromComptime(comptime int: comptime_int) type {
    return Bint(int, int);
}

pub fn From(comptime T: type) type {
    if (T == comptime_int) @compileError(
        \\The function you're using doesn't support `comptime_int` parameters.
        \\Consider using `fromComptime` to get a bint out of it.
    );

    return Bint(
        if (isBint(T))
            return T
        else
            std.math.minInt(T),
        std.math.maxInt(T),
    );
}

pub fn rangeCompileError(
    comptime e: Range.FromError,
    comptime minimum: comptime_int,
    comptime maximum: comptime_int,
) noreturn {
    switch (e) {
        error.LowerOverUpper => compileError(
            \\The `minimum` parameter must be less or equal to the `maximum` parameter. 
            \\Found {} as the `minimum` and {} as the `maximum`. 
        ,
            .{ minimum, maximum },
        ),
        error.LowerTooSmall => compileError(
            "The `minimum` parameter must be at least {}. Found {}.",
            .{ Range.any_min, minimum },
        ),
        error.UpperTooBig => compileError(
            "The `maximum` parameter must be at most {}. Found {}.",
            .{ Range.any_max, maximum },
        ),
    }
}

/// This function checks whether the `T` parameter has been returned specifically by `Bint`.
pub fn isBint(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        else => false,
        .@"enum" => @hasDecl(T, "max_int") and
            @hasDecl(T, "min_int") and
            @TypeOf(T.max_int) == comptime_int and
            @TypeOf(T.min_int) == comptime_int and
            T.min_int <= T.max_int and
            T == Bint(T.min_int, T.max_int),
    };
}

pub fn FromRange(r: Range) type {
    return Bint(r.lower, r.upper);
}

pub fn Bint(comptime minimum: comptime_int, comptime maximum: comptime_int) type {
    return enum(Backing) {
        _,

        const Self = @This();

        pub const range = Range.from(minimum, maximum);

        pub const min_bint: Self = @enumFromInt(min_int);
        pub const mid_bint: Self = @enumFromInt(mid_int);
        pub const max_bint: Self = @enumFromInt(max_int);

        pub const min_int = minimum;
        pub const max_int = maximum;
        pub const mid_int: comptime_int = range.middle();

        pub const mid_is_exact = range.middleIsExact();

        pub const unique_int: ?comptime_int = range.unique();

        pub const Backing = std.math.IntFittingRange(min_int, max_int);

        pub const DivisionError = error{DivisionByZero};
        pub const BoundsError = error{
            /// An attempt to make/use a bint outside of its defined bounds.
            OutOfBoundsInteger,
        };

        pub fn InitError(comptime T: type) type {
            const Other = From(T);
            return if (range.hasRange(Other.range)) error{} else BoundsError;
        }

        pub fn InitPayload(comptime T: type) type {
            const Other = From(T);
            return Bint(
                if (Other.range.upper < range.lower)
                    return noreturn // This makes me laugh
                else
                    range.lower,
                if (range.upper < Other.range.lower)
                    return noreturn // ha ha
                else
                    range.upper,
            );
        }

        pub fn Init(comptime T: type) type {
            return InitError(T)!InitPayload(T);
        }

        pub fn Add(comptime T: type) type {
            const Other = From(T);
            return FromRange(range.add(Other.range));
        }

        pub fn Sub(comptime T: type) type {
            const Other = From(T);
            return FromRange(range.sub(Other.range));
        }

        pub const Neg = FromRange(Range.splat(0).sub(range));

        pub fn Mul(comptime T: type) type {
            const Other = From(T);
            return FromRange(range.mul(Other.range));
        }

        pub fn Min(comptime T: type) type {
            const Other = From(T);
            return FromRange(range.min(Other.range));
        }

        pub fn Max(comptime T: type) type {
            const Other = From(T);
            return FromRange(range.max(Other.range));
        }

        pub const Abs = FromRange(range.abs());

        pub fn FloorError(comptime T: type) type {
            const Other = From(T);
            return switch (range.floor(Other.range)) {
                .must_pass => error{},
                else => BoundsError,
            };
        }

        pub fn FloorPayload(comptime T: type) type {
            const Other = From(T);
            return FromRange(switch (range.floor(Other.range)) {
                .must_fail => return noreturn,
                .can_both, .must_pass => |floored_range| floored_range,
            });
        }

        pub fn Floor(comptime T: type) type {
            return FloorError(T)!FloorPayload(T);
        }

        pub fn CeilPayload(comptime T: type) type {
            const Other = From(T);
            return FromRange(switch (range.ceil(Other.range)) {
                .must_fail => return noreturn,
                .must_pass, .can_both => |ceiled_range| ceiled_range,
            });
        }

        pub fn CeilError(comptime T: type) type {
            const Other = From(T);
            return switch (range.ceil(Other.range)) {
                .must_pass => error{},
                else => BoundsError,
            };
        }

        pub fn Ceil(comptime T: type) type {
            return CeilError(T)!CeilPayload(T);
        }

        pub fn Closest(comptime T: type) type {
            const Other = From(T);
            return FromRange(range.closest(Other.range));
        }

        pub fn Furthest(comptime T: type) type {
            const Other = From(T);

            const rf = range.furthest(Other.range);

            const Upper = if (rf.has(.upper)) FromComptime(max_int) else noreturn;
            const Lower = if (rf.has(.lower)) FromComptime(min_int) else noreturn;
            const Equal = if (rf == .equal) FromComptime(mid_int) else noreturn;
            const Equid = if (rf.has(.equid)) void else noreturn;

            return union(enum) {
                /// The upper bound is furthest.
                upper: Upper,
                /// The lower bound is furthest.
                lower: Lower,
                /// The upper and lower bound are equals anyway.
                equal: Equal,
                /// The upper and lower bound aren't equal, but equidistant.
                equid: Equid,

                pub fn int(f: Furthest(T)) ?Backing {
                    return switch (f) {
                        .upper => max_int,
                        .lower => min_int,
                        .equal => unique_int.?,
                        .equid => null,
                    };
                }

                pub fn bint(f: Furthest(T)) ?Self {
                    return switch (f) {
                        .upper => max_bint,
                        .lower => min_bint,
                        .equal => mid_bint,
                        .equid => null,
                    };
                }

                pub fn has(comptime field: std.meta.FieldEnum(@This())) bool {
                    return @FieldType(@This(), @tagName(field)) != noreturn;
                }
            };
        }

        pub fn Union(comptime T: type) type {
            const Other = From(T);
            return FromRange(range.@"union"(Other.range));
        }

        pub fn DivError(comptime T: type) type {
            const Other = From(T);
            return switch (range.div(.floor, Other.range)) {
                .must_pass => error{},
                else => DivisionError,
            };
        }

        pub fn DivFloorPayload(comptime T: type) type {
            const Other = From(T);
            return FromRange(switch (range.div(Other.range, .floor)) {
                .must_fail => return noreturn,
                .must_pass, .can_both => |div_range| div_range,
            });
        }

        pub fn DivFloor(comptime T: type) type {
            return DivError(T)!DivFloorPayload(T);
        }

        pub fn DivTruncPayload(comptime T: type) type {
            const Other = From(T);
            return FromRange(switch (range.div(Other.range, .trunc)) {
                .must_fail => return noreturn,
                .must_pass, .can_both => |div_range| div_range,
            });
        }

        pub fn DivTrunc(comptime T: type) type {
            return DivError(T)!DivTruncPayload(T);
        }

        pub fn init(anyint: anytype) Init(@TypeOf(anyint)) {
            const other = from(anyint);
            const Other = @TypeOf(other);

            if (comptime Other.range.upper < Self.range.lower)
                return BoundsError.OutOfBoundsInteger;

            if (comptime Self.range.upper < Other.range.lower)
                return BoundsError.OutOfBoundsInteger;

            if (comptime (Self.range.lower <= Other.range.lower and Other.range.upper <= Self.range.upper))
                return @enumFromInt(other.int());

            if (other.int() < Self.range.lower)
                return BoundsError.OutOfBoundsInteger;

            if (Self.range.upper < other.int())
                return BoundsError.OutOfBoundsInteger;

            return @enumFromInt(other.int());
        }

        pub fn widen(anyint: anytype) Self {
            const Anyint = @TypeOf(anyint);
            const anybint = if (Anyint == comptime_int) fromComptime(anyint) else from(anyint);
            const Anybint = @TypeOf(anybint);
            return init(anybint) catch compileError(
                \\The `anyint` parameter isn't guaranteed to fit within `{}..={}`.
                \\It's bound by `{}..={}` instead.
            , .{
                min_int,         max_int,
                Anybint.min_int, Anybint.max_int,
            });
        }

        pub fn add(s: Self, other: anytype) Add(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            if (comptime Self.unique_int) |unique_self|
                if (comptime Other.unique_int) |unique_other|
                    return @enumFromInt(unique_self + unique_other);

            const Result = Self.Add(Other);
            const Wide = Self.Union(Other).Union(Result);

            const self_wide: Wide = .widen(s);
            const other_wide: Wide = .widen(other);
            return @enumFromInt(self_wide.int() + other_wide.int());
        }

        pub fn sub(s: Self, other: anytype) Sub(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            if (comptime Self.unique_int) |unique_self|
                if (comptime Other.unique_int) |unique_other|
                    return @enumFromInt(unique_self - unique_other);

            const Result = Self.Sub(Other);
            const Wide = Self.Union(Other).Union(Result);

            const self_wide: Wide = .widen(s);
            const other_wide: Wide = .widen(other);

            return @enumFromInt(self_wide.int() - other_wide.int());
        }

        pub fn neg(s: Self) Neg {
            return fromComptime(0).sub(s);
        }

        pub fn mul(s: Self, other: anytype) Mul(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            if (comptime Self.unique_int) |unique_self|
                if (comptime Other.unique_int) |unique_other|
                    return @enumFromInt(unique_self * unique_other);

            const Result = Self.Mul(Other);
            const Wide = Self.Union(Other).Union(Result);

            const self_wide: Wide = .widen(s);
            const other_wide: Wide = .widen(other);

            return @enumFromInt(self_wide.int() * other_wide.int());
        }

        pub fn divFloor(s: Self, other: anytype) DivFloor(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            const Wide = Self.Union(Other).Union(Self.DivFloor(Other));

            if (comptime Self.unique_int) |unique_self| {
                if (comptime Other.unique_int) |unique_other| {
                    if (unique_other == 0)
                        return DivisionError.DivisionByZero;
                    return @enumFromInt(@divFloor(unique_self, unique_other));
                }
            }

            const other_wide: Wide = .init(other) catch comptime unreachable;
            const self_wide: Wide = .init(s) catch comptime unreachable;

            if (comptime Self.unique_int) |unique_self| {
                if (other_wide.ord(0) == .eq)
                    return DivisionError.DivisionByZero;

                return @divFloor(unique_self, other_wide.int());
            }

            if (comptime Other.unique_int) |unique_other| {
                if (unique_other == 0)
                    return DivisionError.DivisionByZero;

                return @divFloor(self_wide.int(), unique_other);
            }

            if (other_wide.ord(0) == .eq)
                return DivisionError.DivisionByZero;

            return @enumFromInt(@divFloor(
                self_wide.int(),
                other_wide.int(),
            ));
        }

        pub fn divTrunc(s: Self, other: anytype) DivFloor(@TypeOf(other)) {
            const Other = From(@TypeOf(other));
            const Wide = Self.Union(Other).Union(Self.DivTrunc(Other));

            if (comptime Self.unique_int) |unique_self| {
                if (comptime Other.unique_int) |unique_other| {
                    if (unique_other == 0)
                        return DivisionError.DivisionByZero;
                    return @enumFromInt(@divTrunc(
                        unique_self,
                        unique_other,
                    ));
                }
            }

            const other_wide: Wide = .init(other) catch comptime unreachable;
            const self_wide: Wide = .init(s) catch comptime unreachable;

            if (comptime Self.unique_int) |unique_self| {
                if (other_wide.ord(0) == .eq)
                    return DivisionError.DivisionByZero;

                return @enumFromInt(@divTrunc(
                    unique_self,
                    other_wide.int(),
                ));
            }

            if (comptime Other.unique_int) |unique_other| {
                if (unique_other == 0)
                    return DivisionError.DivisionByZero;

                return @enumFromInt(@divTrunc(
                    self_wide.int(),
                    unique_other,
                ));
            }

            if (other_wide.ord(0) == .eq)
                return DivisionError.DivisionByZero;

            return @enumFromInt(@divTrunc(
                self_wide.int(),
                other_wide.int(),
            ));
        }

        pub fn min(s: Self, other: anytype) Min(@TypeOf(other)) {
            const o = from(other);
            const Other = From(@TypeOf(other));
            return switch (s.ord(other)) {
                .lt => if (comptime Self.unique_int) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(s.int()),
                .gt => if (comptime Other.unique_int) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(o.int()),
                .eq => if (comptime Self.unique_int) |uv|
                    @enumFromInt(uv)
                else if (comptime Other.unique_int) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(s.int()),
            };
        }

        pub fn max(s: Self, other: anytype) Max(@TypeOf(other)) {
            const o = from(other);
            const Other = From(@TypeOf(other));
            return switch (s.ord(other)) {
                .lt => if (comptime Other.unique_int) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(o.int()),
                .gt => if (comptime Self.unique_int) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(s.int()),
                .eq => if (comptime Other.unique_int) |uv|
                    @enumFromInt(uv)
                else if (comptime Self.unique_int) |uv|
                    @enumFromInt(uv)
                else
                    @enumFromInt(s.int()),
            };
        }

        pub fn abs(s: Self) Abs {
            if (comptime Self.unique_int) |uv|
                return comptime @enumFromInt(@abs(uv));

            if (comptime 0 <= Self.min_int)
                return @enumFromInt(s.int());

            const wide: Self.Union(Abs) = .widen(s);

            if (comptime Self.max_int <= 0)
                return @enumFromInt(-wide.int());

            return @enumFromInt(@abs(wide.int()));
        }

        pub fn floor(s: Self, bound: anytype) Floor(@TypeOf(bound)) {
            const Other = From(@TypeOf(bound));

            if (comptime Self.max_int < Other.min_int)
                return BoundsError.OutOfBoundsInteger;

            if (comptime Other.max_int <= Self.min_int)
                return @enumFromInt(s.int());

            const b = from(bound);

            if (s.int() < b.int())
                return BoundsError.OutOfBoundsInteger;

            return @enumFromInt(s.int());
        }

        pub fn ceil(s: Self, bound: anytype) Ceil(@TypeOf(bound)) {
            const Other = From(@TypeOf(bound));

            if (comptime Other.max_int < Self.min_int)
                return BoundsError.OutOfBoundsInteger;

            if (comptime Self.max_int <= Other.min_int)
                return @enumFromInt(s.int());

            const b = from(bound);

            if (b.int() < s.int())
                return BoundsError.OutOfBoundsInteger;

            return @enumFromInt(s.int());
        }

        pub fn closest(anyint: anytype) Closest(@TypeOf(anyint)) {
            const i = from(anyint);
            const Int = @TypeOf(i);

            if (comptime Self.unique_int) |unique_self|
                return @enumFromInt(unique_self);

            if (comptime Int.max_int < Self.min_int)
                return @enumFromInt(Self.min_int);

            if (comptime Self.max_int < Int.min_int)
                return @enumFromInt(Self.max_int);

            if (comptime Int.unique_int) |unique_other| {
                if (comptime unique_other <= Self.min_int)
                    return @enumFromInt(Self.min_int);

                if (comptime Self.max_int <= unique_other)
                    return @enumFromInt(Self.max_int);

                return @enumFromInt(unique_other);
            }

            if (i.int() <= Self.min_int)
                return @enumFromInt(Self.min_int);

            if (Self.max_int <= i.int())
                return @enumFromInt(Self.max_int);

            return @enumFromInt(i.int());
        }

        pub fn furthest(anyint: anytype) Furthest(@TypeOf(anyint)) {
            const i = from(anyint);
            const Int = @TypeOf(i);

            const result = comptime range.furthest(Int.range);

            return switch (result) {
                .equal => .{ .equal = .widen(mid_int) },
                .lower => .{ .lower = .widen(min_int) },
                .upper => .{ .upper = .widen(max_int) },
                .equid => .equid,
                .lower_or_equid => if (i.int() == mid_int) .equid else .{
                    .lower = .widen(min_int),
                },
                .upper_or_equid => if (i.int() == mid_int) .equid else .{
                    .upper = .widen(max_int),
                },
                .lower_or_upper => if (i.int() <= mid_int) .{
                    .lower = .widen(min_int),
                } else .{
                    .upper = .widen(max_int),
                },
                .lower_or_upper_or_equid => switch (i.ord(mid_bint)) {
                    .gt => .{ .lower = .widen(min_int) },
                    .eq => .equid,
                    .lt => .{ .upper = .widen(max_int) },
                },
            };
        }

        pub fn ord(s: Self, other: anytype) std.math.Order {
            const o = switch (@TypeOf(other)) {
                comptime_int => fromComptime(other),
                else => from(other),
            };

            const Other = @TypeOf(o);

            if (comptime Other.max_int < Self.min_int)
                return .gt;

            if (comptime Self.max_int < Other.min_int)
                return .lt;

            if (comptime Self.unique_int) |unique_self|
                if (comptime Other.unique_int) |unique_other|
                    return comptime std.math.order(unique_self, unique_other);

            // TODO: use `@branchHint` for runtime operations
            if (comptime Self.unique_int) |unique_self|
                return std.math.order(unique_self, o.int());

            if (comptime Other.unique_int) |unique_other|
                return std.math.order(s.int(), unique_other);

            return std.math.order(s.int(), o.int());
        }

        pub fn expect(s: Self) BoundsError!void {
            if (s.int() < min_int or max_int < s.int())
                return BoundsError.OutOfBoundsInteger;
        }

        pub fn int(s: Self) Backing {
            return @intFromEnum(s);
        }
    };
}

inline fn compileError(comptime fmt: []const u8, comptime args: anytype) noreturn {
    @compileError(std.fmt.comptimePrint(fmt, args));
}

test {
    _ = @import("test.zig");
}
