//! Although these tests are unit tests, I recommend reading them to understand the API of bints.
//! The code gives valid usage examples, and the comments thouroughly explain what is happening.
//! Following them in order is an efficient way of getting to know the entire API, since a test can
//! mostly build upon concepts that have been introduced earlier.
//!
//! Some specific features of a declaration might take a bit more work and/or are shared by other
//! functions. So there are some tests named "declarationName - feature/concept name".
//!

const bint = @import("root.zig");
const std = @import("std");

const Bint = bint.Bint;

test "fromComptime" {
    // The `fromComptime` function returns a bint.
    const thirteen = bint.fromComptime(13);
    const Thirteen = @TypeOf(thirteen);
    try std.testing.expect(bint.isBint(Thirteen));

    // The return type can represent one unique number.
    try std.testing.expectEqual(13, Thirteen.min_int);
    try std.testing.expectEqual(13, Thirteen.max_int);

    // It's the same as using the same upper and lower bounds.
    try std.testing.expectEqual(Bint(13, 13), Thirteen);
}

test "from" {
    // The `from` function returns a bint.
    const thirteen = bint.from(@as(i7, 13));
    const Thirteen = @TypeOf(thirteen);
    try std.testing.expect(bint.isBint(Thirteen));

    // The return type is as narrow as possible and as wide as necessary.
    try std.testing.expectEqual(std.math.minInt(i7), Thirteen.min_int);
    try std.testing.expectEqual(std.math.maxInt(i7), Thirteen.max_int);

    // For convenience, one can use other bints as arguments, it'll just return them back then.
    const FiveToEight = Bint(5, 8);

    var eight: FiveToEight =
        // Using `@enumFromInt(...)` on a bint type is highly discouraged.
        // Most cases should be covered by `from`, `.init` and `.widen`.
        @enumFromInt(8);

    _ = &eight;

    const eight_again = bint.from(eight);
    // The return type is still as narrom as possible and as wide as necessary.
    const FiveToEightAgain = @TypeOf(eight_again);
    try std.testing.expectEqual(FiveToEight, FiveToEightAgain);
    try std.testing.expectEqual(eight, eight_again);
}

test "init" {
    // The `.init` function makes an instance of a specific `Bint(...)` type out of the instance of
    // another `Bint(...)` type or a regular integer type.
    const SomeBint = Bint(-1, 10);
    // This works.
    const some_bint = try SomeBint.init(@as(u8, 1));

    const OtherBint = Bint(-2, 5);
    const other_bint = try OtherBint.init(@as(i8, 1));

    // This works too.
    const same_bint = try SomeBint.init(other_bint);
    try std.testing.expectEqual(some_bint, same_bint);

    // If you try to make the instance from some value out of the bounds, it'll fail.
    try std.testing.expectError(error.OutOfBoundsInteger, SomeBint.init(@as(u8, 11)));
    try std.testing.expectError(error.OutOfBoundsInteger, SomeBint.init(@as(i8, -2)));

    // It works with the bounds themselves.
    _ = try SomeBint.init(@as(i32, 10));
    _ = try SomeBint.init(@as(i32, -1));

    // Unfortunately, because of weird comptime vs runtime stuff, I haven't found a way to make it
    // work elegantly with `comptime_int` yet. This use-case might be limited though, because you
    // can still use `.widen` instead of `.init`.
}

test "init - comptime smartness" {
    // The result of `.init` is "comptime smart". By this I mean, it can't fail if you give it the
    // instance of a type that can't represent a value out of the bounds. It also can't pass if you
    // give it the instance of a type that can't represent a value *within* the bounds.
    //
    // You can always still handle these provably impossible cases. It's typically more elegant
    // when dealing with generics. But you can also `@compileError` your way out of them,
    // effectively letting Zig's type system proving the soundness of your `.init` call.

    const NegtenToTwenty = Bint(-10, 20);
    const NegtenToTwelve = Bint(-10, 12);

    const eleven = NegtenToTwelve.init(@as(u8, 11)) catch unreachable;

    // From it's type, Zig knows that `eleven` can't be out of `-10..=20`. So the failing path is a
    // dead path, not analyzed by Zig.
    var eleven_again = NegtenToTwenty.init(eleven) catch @compileError(
        "This can't happen because `NegtenToTwelve` only represent `-10..=12` values.",
    );

    // We're only ensuring this doesn't only work with comptime values.
    _ = &eleven_again;

    // Same with regular integers, if they can't represent an out-of-bounds value.
    var eleven_still = NegtenToTwenty.init(@as(u4, 11)) catch @compileError(
        "This can't happen because `u4` only represent `0..<16` values.",
    );

    _ = &eleven_still;

    try std.testing.expectEqual(eleven_again, eleven_still);

    // For a convenient wrapper around the `.init(...) catch @compileError(...)` construct, see
    // `.widen`.

    // On the other hand, and this is maybe less useful, the passing path is also a dead path
    // when you give `.init` a value that can't be within bounds.

    const TwentyToThirty = Bint(20, 30);

    // We're ensuring this doesn't only happen with comptime values.
    var runtime = TwentyToThirty.init(@as(u4, 10));
    _ = &runtime;

    if (runtime) |_|
        @compileError("This can't happen because `u4` only represents `0..<16` values")
    else |fail| // This will be reached though.
        try std.testing.expectEqual(error.OutOfBoundsInteger, fail);

    // Same with bints
    const ZeroToTen = Bint(0, 10);
    const five = ZeroToTen.init(@as(u8, 5)) catch unreachable;

    var runtime_2 = TwentyToThirty.init(five);
    _ = &runtime_2;

    if (runtime_2) |_|
        @compileError("This can't happen because `ZeroToTen` only represents `0..=10` values.")
    else |fail|
        try std.testing.expectEqual(error.OutOfBoundsInteger, fail);
}

test "widen" {
    // The `.widen` function makes an instance of a specific `Bint(...)` type out of the instance
    // of another `Bint(...)` type or a regular integer type.
    //
    // When the other `Bint(...)` type or the regular integer type CAN represent values out of
    // bounds, it throws a compile error.
    //
    // In the end, it's a convenient wrapper for `.init(...) catch @compileError(generic_message)`.

    const NegtenToTen = Bint(-10, 10);
    const OneToSeven = Bint(1, 7);

    const six = OneToSeven.init(@as(u8, 6)) catch unreachable;

    // This works:
    const six_again = NegtenToTen.widen(six);

    // This too:
    const six_still = NegtenToTen.widen(@as(i4, 6));

    const six_again_still = NegtenToTen.widen(6);

    try std.testing.expectEqual(six_again, six_still);
    try std.testing.expectEqual(six_still, six_again_still);

    // This wouldn't:
    //const six_still_again = NegtenToTen.widen(@as(u4, 6));

    // Nor this:
    //const not_six = NegtenToTen.widen(11);
}

test "int" {
    // This function gives you back an instance of smallest regular integer type that can represent
    // the value.

    const five = Bint(0, 20).widen(5);
    const as_u5 = five.int();

    try std.testing.expectEqual(5, as_u5);
    try std.testing.expectEqual(u5, @TypeOf(as_u5));

    const five_again = Bint(-1, 20).widen(5);
    const as_i6 = five_again.int();

    try std.testing.expectEqual(5, as_i6);
    try std.testing.expectEqual(i6, @TypeOf(as_i6));
}

// Now that we know how to initialize and reify bints, let's see how we can to manipulate them and
// take advantage of their invariants.

test "add" {
    // This function returns the addition of two bints (or a bint and a regular integer).
    // The result is a bint whose bounds cover all possible values.

    const TenToTwenty = Bint(10, 20);
    const ten = TenToTwenty.widen(10);

    const NegoneToTwo = Bint(-1, 2);
    const one = NegoneToTwo.widen(1);

    const eleven = ten.add(one);

    const NineToTwentytwo = @TypeOf(eleven);

    try std.testing.expectEqual(11, eleven.int());

    // If `one` was `-1` instead of `1`, the sum would've been `9`.
    try std.testing.expectEqual(9, NineToTwentytwo.min_int);

    // If `one` was `2` instead of `1`, and `ten` was `20` instead of `10`, the sum would've been
    // `22`.
    try std.testing.expectEqual(22, NineToTwentytwo.max_int);

    // That's what it comes down to:
    try std.testing.expectEqual(Bint(-1 + 10, 2 + 20), NineToTwentytwo);
}

test "add - widening" {
    // The result of an addition can be wider than its terms, in order to avoid overflowing.
    const UnsignedByte = Bint(0, 255);
    const unsigned_byte = UnsignedByte.widen(200);
    try std.testing.expectEqual(u8, @TypeOf(unsigned_byte.int()));

    const sum = unsigned_byte.add(unsigned_byte);
    // The addition could be `0 + 0 = 0` or `255 + 255 = 510`. We're ready for everything.
    try std.testing.expectEqual(Bint(0, 510), @TypeOf(sum));
    // A `u9` can hold an integer from `0` to `512`, so it's the best pick here.
    try std.testing.expectEqual(u9, @TypeOf(sum.int()));
    // The result didn't wrap, saturate or trigger illegal behavior.
    try std.testing.expectEqual(400, sum.int());

    const Negthousand = Bint(-1000, -1000);
    const negthousand = Negthousand.widen(-1000);

    // This works too when underflowing.
    const sum_2 = sum.add(negthousand);
    try std.testing.expectEqual(Bint(-1000, -490), @TypeOf(sum_2));
    try std.testing.expectEqual(i11, @TypeOf(sum_2.int()));
    try std.testing.expectEqual(-600, sum_2.int());
}

test "sub" {
    // This function returns the substraction of two bints (or a bint and a regular integer).
    // The result is a bint whose bounds cover all possible values.

    const TwelveToSeventeen = Bint(12, 17);
    const NegthreeToSix = Bint(-3, 6);

    const substractee = TwelveToSeventeen.widen(13);
    const substractor = NegthreeToSix.widen(1);
    const substracted = substractee.sub(substractor);

    try std.testing.expectEqual(Bint(6, 20), @TypeOf(substracted));
    try std.testing.expectEqual(12, substracted.int());
}

test "sub - widening" {
    // The result of a substraction can be wider than its terms, in order to avoid underflowing.
    const OneToTen = Bint(1, 10);
    const one = OneToTen.widen(1);
    const five = OneToTen.widen(5);

    try std.testing.expectEqual(u4, @TypeOf(one.int()));

    const negfour = one.sub(five);

    try std.testing.expectEqual(Bint(-9, 9), @TypeOf(negfour));
    try std.testing.expectEqual(i5, @TypeOf(negfour.int()));
    try std.testing.expectEqual(-4, negfour.int());

    // It works with overflowing too.
    const NegOneToZero = Bint(-1, 0);
    const negone = NegOneToZero.widen(-1);

    try std.testing.expectEqual(i1, @TypeOf(negone.int()));

    const zero = negone.sub(negone);

    try std.testing.expectEqual(Bint(-1, 1), @TypeOf(zero));
    try std.testing.expectEqual(i2, @TypeOf(zero.int()));
    try std.testing.expectEqual(0, zero.int());
}

test "mul" {
    // This function returns the product of two bints (or a bint and a regular integer).
    // The result is a bint that can cover all possible values.

    const EightToTwenty = Bint(8, 20);
    const NegnineToTen = Bint(-9, 10);

    const ten = EightToTwenty.widen(10);
    const negone = NegnineToTen.widen(-1);
    const negten = ten.mul(negone);

    try std.testing.expectEqual(Bint(-180, 200), @TypeOf(negten));
    try std.testing.expectEqual(-10, negten.int());
}

test "mul - widening" {
    // The result of a multiplication can be wider than its terms, in order to avoid overflowing.
    const TwoToTen = Bint(2, 10);
    const three = TwoToTen.widen(3);
    const six = TwoToTen.widen(6);

    try std.testing.expectEqual(u4, @TypeOf(three.int()));

    const eighteen = six.mul(three);

    try std.testing.expectEqual(Bint(4, 100), @TypeOf(eighteen));
    try std.testing.expectEqual(u7, @TypeOf(eighteen.int()));
    try std.testing.expectEqual(18, eighteen.int());

    // It works with underflowing as well.
    const NegeightToZero = Bint(-8, 0);
    const negone = NegeightToZero.widen(-1);

    try std.testing.expectEqual(i4, @TypeOf(negone.int()));

    const negthree = three.mul(negone);

    try std.testing.expectEqual(Bint(-80, 0), @TypeOf(negthree));
    try std.testing.expectEqual(i8, @TypeOf(negthree.int()));
    try std.testing.expectEqual(-3, negthree.int());
}

test "mul - narrowing" {
    // Interestingly, three specific bints can result in narrowing instead of widening under
    // specific circumstances.
    const Zero = Bint(0, 0);
    const Negone = Bint(-1, -1);
    const NegoneToZero = Bint(-1, 0);

    const zero = Zero.widen(0);
    const negone = Negone.widen(-1);
    const negone_or_zero = NegoneToZero.widen(-1);

    const NegoneToEight = Bint(-1, 8);
    const one = NegoneToEight.widen(1);

    try std.testing.expectEqual(i5, @TypeOf(one.int()));

    const one_mul_zero = one.mul(zero);
    try std.testing.expectEqual(u0, @TypeOf(one_mul_zero.int()));

    const one_mul_negone = one.mul(negone);
    try std.testing.expectEqual(i4, @TypeOf(one_mul_negone.int()));

    const one_mul_any = one.mul(negone_or_zero);
    try std.testing.expectEqual(i4, @TypeOf(one_mul_any.int()));
}

test "min" {
    // This function takes the minimum of two bints (or a bint and a regular integer).

    const one = Bint(-1, 1).widen(1);
    const two = Bint(-2, 4).widen(2);

    const min = one.min(two);

    try std.testing.expectEqual(1, min.int());
}

test "min - narrowing" {
    // The result of `min` narrows down the upper bound to the lowest among the two arguments.

    const NegoneToEight = Bint(-1, 8);
    const ZeroToNine = Bint(0, 9);
    const OneToSeven = Bint(1, 7);

    const Min12 = NegoneToEight.Min(ZeroToNine);
    const Min13 = NegoneToEight.Min(OneToSeven);
    const Min23 = ZeroToNine.Min(OneToSeven);

    try std.testing.expect(Min12.max_int <= NegoneToEight.max_int);
    try std.testing.expect(Min13.max_int <= NegoneToEight.max_int);

    try std.testing.expect(Min12.max_int <= ZeroToNine.max_int);
    try std.testing.expect(Min23.max_int <= ZeroToNine.max_int);

    try std.testing.expect(Min13.max_int <= OneToSeven.max_int);
    try std.testing.expect(Min23.max_int <= OneToSeven.max_int);
}

test "min - widening" {
    // The result of `max` "widens" the lower bound to the lowest among the two arguments.
    const NegtenToThirty = Bint(-10, 30);
    const NegtwelveToSix = Bint(-12, 6);
    const NegsixToNegtwo = Bint(-6, -2);

    const Min12 = NegtenToThirty.Min(NegtwelveToSix);
    const Min13 = NegtenToThirty.Min(NegsixToNegtwo);
    const Min23 = NegtwelveToSix.Min(NegsixToNegtwo);

    try std.testing.expect(Min12.min_int <= NegtenToThirty.min_int);
    try std.testing.expect(Min13.min_int <= NegtenToThirty.min_int);

    try std.testing.expect(Min12.min_int <= NegsixToNegtwo.min_int);
    try std.testing.expect(Min23.min_int <= NegsixToNegtwo.min_int);

    try std.testing.expect(Min13.min_int <= NegsixToNegtwo.min_int);
    try std.testing.expect(Min23.min_int <= NegsixToNegtwo.min_int);
}

test "max" {
    // This function returns the maximum out of two bints (or one bint and a regular integer).

    const sixteen = Bint(-20, 16).widen(16);
    const ten = Bint(5, 17).widen(10);

    const max = sixteen.max(ten);

    try std.testing.expectEqual(16, max.int());
}

test "max - widening" {
    // The result of `max` widens the upper bound to the highest among the two arguments.

    const NegoneToTwo = Bint(-1, 2);
    const NegtwoToOne = Bint(-2, 1);
    const OneToTwelve = Bint(1, 12);

    const Max12 = NegoneToTwo.Max(NegtwoToOne);
    const Max13 = NegoneToTwo.Max(OneToTwelve);
    const Max23 = NegtwoToOne.Max(OneToTwelve);

    try std.testing.expect(NegoneToTwo.max_int <= Max12.max_int);
    try std.testing.expect(NegtwoToOne.max_int <= Max12.max_int);

    try std.testing.expect(NegoneToTwo.max_int <= Max13.max_int);
    try std.testing.expect(OneToTwelve.max_int <= Max13.max_int);

    try std.testing.expect(NegtwoToOne.max_int <= Max23.max_int);
    try std.testing.expect(OneToTwelve.max_int <= Max23.max_int);
}

test "max - narrowing" {
    // The result of `max` narrows the lower bound to the highest among the two arguments.

    const NegtwelveToNegtwo = Bint(-12, -2);
    const SixteenToEighteen = Bint(16, 18);
    const ThreeToTwentyfour = Bint(3, 24);

    const Max12 = NegtwelveToNegtwo.Max(SixteenToEighteen);
    const Max13 = NegtwelveToNegtwo.Max(ThreeToTwentyfour);
    const Max23 = SixteenToEighteen.Max(ThreeToTwentyfour);

    try std.testing.expect(NegtwelveToNegtwo.min_int <= Max12.min_int);
    try std.testing.expect(SixteenToEighteen.min_int <= Max12.min_int);

    try std.testing.expect(NegtwelveToNegtwo.min_int <= Max13.min_int);
    try std.testing.expect(ThreeToTwentyfour.min_int <= Max13.min_int);

    try std.testing.expect(SixteenToEighteen.min_int <= Max23.min_int);
    try std.testing.expect(ThreeToTwentyfour.min_int <= Max23.min_int);
}

test "abs" {
    // The "abs" function return the abslute value of a bint, i.e. itself when it's positive, its
    // opposite when it's negative.

    const negative = Bint(-10, 20).widen(-8);
    const positive = Bint(-5, 4).widen(3);

    try std.testing.expectEqual(8, negative.abs().int());
    try std.testing.expectEqual(3, positive.abs().int());
}

test "abs - narrowing" {
    // The `abs` function is sometimes narrowing, when the negative part of a bint type is smaller
    // than the positive part.

    const NegtenToTwenty = Bint(-10, 20);

    // This can represent `-10..=20`, so `-32..<32`.
    try std.testing.expectEqual(i6, NegtenToTwenty.Backing);
    // This can represent `0..=20`, so `0..<32`.
    try std.testing.expectEqual(u5, NegtenToTwenty.Abs.Backing);
}

test "floor" {
    // The `floor` function ensures that a bint is at least as big as a given bint or regular
    // integer. If not, it'll fail.

    const NegthreeToFour = Bint(-3, 4);

    const two = NegthreeToFour.widen(2);
    const ensured_its_positive = try two.floor(
        // by using `0` as the floor, we know that a passing result is always >=0
        bint.fromComptime(0));

    try std.testing.expect(0 <= ensured_its_positive.int());
    try std.testing.expectError(error.Underflow, two.floor(
        // Since the floor is higher than `two`, the operation fails
        @as(usize, 3)));
}

test "floor - narrowing" {
    // The `floor` operation is always narrowing, or at least never widening. It narrows the lower
    // bound of the bint by the lower bound of the floor if it's higher. And unlike `max`, it
    // doesn't touch the upper bound.

    const NegeightToThree = Bint(-8, 3);
    const NegthreeToSeven = Bint(-3, 7);

    const two = NegeightToThree.widen(2);
    const negtwo = NegthreeToSeven.widen(-2);

    // Now, we know that floor isn't less than the lower bound of `negtwo`, i.e. `-3`.
    const floored = two.floor(negtwo) catch unreachable;
    const Floored = @TypeOf(floored);

    try std.testing.expectEqual(Bint(-3, 3), Floored);
    try std.testing.expectEqual(i4, @TypeOf(two.int()));
    try std.testing.expectEqual(i3, @TypeOf(floored.int()));
}

test "floor - comptime smartness" {
    // The `floor` function is "comptime smart". If by the type of its arguments, it can already
    // tell whether the operation is passing or failing, it'll make the other path dead to Zig.

    const ZeroToEight = Bint(0, 8);

    var four = ZeroToEight.widen(0);
    // We're ensuring that this doesn't only work with comptime values.
    _ = &four;

    _ = four.floor(Bint(-10, -5).widen(-6)) catch
        // The path of this compile error won't ever be reached because `floor` knows from its type
        // that it can't error: a `Bint(-10, -5)` is always smaller than a `Bint(0, 8)` anyway.
        @compileError("This floor operation must be guaranteed to pass!");

    // Although this is weirder to think about, you can also have the passing path as a dead path.
    if (four.floor(Bint(9, 10).widen(10))) |_|
        // A `Bint(9, 10)` is always greater than a `Bint(0, 8)`.
        @compileError("This floor operation must be guaranteed to fail!")
    else |fail|
        try std.testing.expectEqual(error.Underflow, fail);
}

test "ceil" {
    // The `ceil` function ensures that a bint is at least as small as another bint or regular
    // integer. If not, it'll fail.

    const ten = Bint(8, 16).widen(10);
    const eleven = Bint(8, 12).widen(11);

    const less_than_eleven = try ten.ceil(eleven);
    try std.testing.expect(less_than_eleven.int() <= 11);

    //@breakpoint();

    // If the first bint is bigger than the second argument, it'll fail.
    try std.testing.expectError(
        error.Overflow,
        eleven.ceil(ten),
    );
}

test "ceil - narrowing" {
    // The `ceil` operation is always narrowing, or at least never widening. It narrows the upper
    // bound of the bint to that of the ceil, and fails if it's higher. And unlike `min`, it
    // doesn't touch the lower bound.

    const six = Bint(-1, 16).widen(6);
    const seven = Bint(0, 10).widen(7);

    // Now, we know that `ceiled` is necessarily lower or equal to `seven`, and notably its upper
    // bound `10`.
    const ceiled = six.ceil(seven) catch unreachable;
    const Ceiled = @TypeOf(ceiled);

    try std.testing.expectEqual(Bint(-1, 10), Ceiled);
    try std.testing.expectEqual(i6, @TypeOf(six.int()));
    try std.testing.expectEqual(i5, @TypeOf(ceiled.int()));
}

test "ceil - comptime smartness" {
    // The `ceil` function is "comptime smart". If by the type of its argument, it can tell whether
    // it'll be passing or failing, then it'll make the other path unreachable at compile-time.

    const NegfourToFive = Bint(-4, 5);

    var two = NegfourToFive.widen(2);
    // Here we're ensuring that this works with runtime values as well.
    _ = &two;

    _ = two.ceil(Bint(5, 12).widen(6)) catch
        // This error will never be triggered because Zig knows a `Bint(5, 12)` is always bigger
        // than a `Bint(-4, 5)`.
        @compileError("The ceil should be guaranteed to be higher!");

    // Interestingly, you can also ensure the operation must always fail.
    if (two.ceil(Bint(-6, -5).widen(-5))) |_|
        // This will never be reached.
        @compileError("The ceil should always be too low!")
    else |fail|
        // This will always be reached.
        try std.testing.expectEqual(error.Overflow, fail);
}

test "clamp" {
    // The `clamp` functon is equivalent to `floor` and `ceil` at once.
    const floor = Bint(-10, 10).widen(5);
    const ceil = Bint(-20, 12).widen(7);

    const four = Bint(-9, 100).widen(4);
    const five = Bint(0, 255).widen(5);
    const six = Bint(-1, 10).widen(6);
    const seven = Bint(1, 8).widen(7);
    const eight = Bint(2, 9).widen(8);

    // If the floor is bigger, it fails.
    try std.testing.expectEqual(error.Underflow, four.clamp(floor, ceil));
    // If it's equal, it passes.
    const clamped_five = try five.clamp(floor, ceil);
    const clamped_six = try six.clamp(floor, ceil);
    const clamped_seven = try seven.clamp(floor, ceil);
    // If the ceil is smaller, it fails again.
    try std.testing.expectEqual(error.Overflow, eight.clamp(floor, ceil));

    try std.testing.expectEqual(5, clamped_five.int());
    try std.testing.expectEqual(6, clamped_six.int());
    try std.testing.expectEqual(7, clamped_seven.int());
}

test "clamp - narrowing" {
    // The `clamp` operation is always narrowing, or at least never widening. It narrows to the
    // lowest floor and highest ceil.

    const one = Bint(1, 10).widen(1);
    const two = Bint(0, 8).widen(2);
    const three = Bint(0, 11).widen(3);

    try std.testing.expectEqual(
        Bint(1, 8),
        @TypeOf(try two.clamp(one, three)),
    );

    try std.testing.expectEqual(
        Bint(1, 10),
        @TypeOf(try one.clamp(two, three)),
    );

    try std.testing.expectEqual(
        Bint(1, 8),
        @TypeOf(try three.clamp(one, two)),
    );
}

test "div" {
    // The `div` function attempts a floored or truncated integer division. It fails when dividing
    // by zero. When the result of the division isn't exact and is negative, it rounds towards
    // negative infinity with the `.floor` option, and towards 0 with the `.trunc` option.

    const eight = Bint(0, 100).widen(8);
    const four = try eight.div(.floor, @as(u8, 2));
    try std.testing.expectEqual(4, four.int());

    // This is the integer division, so `7 ÷ 2 = 3`
    const negseven = Bint(-16, 16).widen(-7);
    const three = try negseven.div(.floor, @as(i8, -2));
    try std.testing.expectEqual(3, three.int());

    // Dividing by 0 is punishable by death.
    const ten = Bint(8, 12).widen(10);
    try std.testing.expectError(
        error.DivisionByZero,
        ten.div(.floor, @as(u8, 0)),
    );

    // The division is floored, so `(-7) ÷ 2 = 7 ÷ (-2) = -4`
    const negfour = try negseven.div(.floor, @as(isize, 2));
    try std.testing.expectEqual(-4, negfour.int());

    // The division is truncated, so `(-7) ÷ 2 = 7 ÷ (-2) = -3`
    const negthree = try negseven.div(.trunc, @as(u8, 2));
    try std.testing.expectEqual(-3, negthree.int());
}

test "div - narrowing" {
    // Integer division always results in a smaller or equally big number (in absolute value).
    // It results in `div` being narrowing when the divider can't be `1` or `-1`.

    const Byte = Bint(0, 255);
    const NotOne = Bint(2, 255);

    const eight = Byte.widen(8);
    const two = NotOne.widen(2);

    const four = try eight.div(.floor, two);
    const Four = @TypeOf(four);

    try std.testing.expectEqual(u8, Byte.Backing);
    try std.testing.expectEqual(u8, NotOne.Backing);
    try std.testing.expectEqual(Bint(0, 127), Four);
    try std.testing.expectEqual(u7, Four.Backing);
}

test "div - widening" {
    // When divided by -1, a power of 2 requires more bits for its representation.
    const SignedByte = Bint(-128, 127);
    const sbyte = SignedByte.widen(-16);
    const reverse_sbyte = sbyte.div(.floor, bint.fromComptime(-1)) catch unreachable;

    const ReversedSignedByte = @TypeOf(reverse_sbyte);
    try std.testing.expectEqual(16, reverse_sbyte.int());
    try std.testing.expectEqual(i8, SignedByte.Backing);
    try std.testing.expectEqual(Bint(-127, 128), ReversedSignedByte);
    try std.testing.expectEqual(i9, ReversedSignedByte.Backing);
}

test "div - comptime smartness" {
    // The `div` function is "comptime smart": if it can tell from the types of its arguments that
    // it can't fail (or can't pass), it'll make the failing (or passing) path dead code.

    const Numerator = Bint(-128, 127);
    const NotZero = Bint(1, 100);

    var numerator = Numerator.widen(100);
    _ = &numerator; // making sure it works with runtime values too.
    var denominator = NotZero.widen(25);
    _ = &denominator;

    const fraction = numerator.div(.trunc, denominator) catch
        // This will never trigger an error, because the type system knows there's no error for
        // `divFloor` to return here.
        @compileError("This division must be guarded against `error.DivisionByZero`!");

    try std.testing.expectEqual(4, fraction.int());

    // It works too if you divide by a bint that can't be anything but 0.
    const failure = fraction.div(.floor, bint.fromComptime(0));
    if (failure) |_|
        @compileError("The division, must be guaranteed to fail (wtf am I on?).")
    else |err|
        try std.testing.expectEqual(error.DivisionByZero, err);
}

test "rem" {
    // The `rem` function attempts to retrieve the remainder of the floored or truncated integer
    // division. It fails when given 0 as the denominator.

    const eight = Bint(5, 12).widen(8);
    const four = Bint(-2, 7).widen(4);

    // Since 4 divides 8, the remainder is zero.
    const zero = try eight.rem(.floor, four);
    try std.testing.expectEqual(0, zero.int());

    const negfive = four.sub(bint.fromComptime(9));

    const negtwo = try eight.rem(.floor, negfive);
    try std.testing.expectEqual(-2, negtwo.int());
    try std.testing.expectEqual(
        eight.int(),
        (try eight.div(.floor, negfive))
            .mul(negfive)
            .add(try eight.rem(.floor, negfive))
            .int(),
    );

    const three = try eight.rem(.trunc, negfive);
    try std.testing.expectEqual(3, three.int());
    try std.testing.expectEqual(
        eight.int(),
        (try eight.div(.trunc, negfive))
            .mul(negfive)
            .add(try eight.rem(.trunc, negfive))
            .int(),
    );
}

test "rem - resizing" {
    // For now, the `rem` function return type is always within those bounds:
    // `- |denominator|.upper <..< |denominator|.upper`. It may become narrower in some cases in
    // the future.
    const TenToTwelve = Bint(10, 12);
    const NegsevenToFive = Bint(-7, 5);

    try std.testing.expectEqual(Bint(-11, 11), NegsevenToFive.RemPayload(.floor, TenToTwelve));
    try std.testing.expectEqual(Bint(-6, 6), TenToTwelve.RemPayload(.trunc, NegsevenToFive));
}

test "rem - comptime smartness" {
    // The `rem` function is "comptime smart", when it can tell by the types that it can't or must
    // fail, it'll make the passing or failing path respectively a dead path.
    const NotZero = Bint(1, 10);
    const Zero = Bint(0, 0);

    var must_pass = Zero.widen(0).rem(.trunc, NotZero.widen(8));
    _ = &must_pass;

    _ = must_pass catch @compileError(
        "This can't happen, the denominator is never zero, you can tell by its type!",
    );

    var must_fail = NotZero.widen(1).rem(.floor, Zero.widen(0));
    _ = &must_fail;
    if (must_fail) |_| @compileError(
        "This can't happen, the denominator is always zero, you can tell by its type!",
    ) else |fail| try std.testing.expectEqual(error.DivisionByZero, fail);
}

test "closest" {
    // This function returns the closest bint within bounds to a given bint or regular integer.

    const NegtwoToOne = Bint(-2, 1);

    const negthree: i8 = -3;
    const negtwo = Bint(-100, 100).widen(-2);
    const zero: usize = 0;
    const two: c_int = 2;
    const three: u8 = 3;

    try std.testing.expectEqual(-2, NegtwoToOne.closest(negthree).int());
    try std.testing.expectEqual(-2, NegtwoToOne.closest(negtwo).int());
    try std.testing.expectEqual(0, NegtwoToOne.closest(zero).int());
    try std.testing.expectEqual(1, NegtwoToOne.closest(two).int());
    try std.testing.expectEqual(1, NegtwoToOne.closest(three).int());
}

test "closest - narrowing" {
    // The `closest` function can narrow down its return type when its argument can't represent
    // some values that are valid for the bint it's trying to make.

    const Byte = Bint(0, 255);

    try std.testing.expectEqual(
        // A `u8` can represent `-128..<128`, but since the number it's trying to make is `0..<256`
        // It creates a `0..<128`.
        Bint(0, 127),
        Byte.Closest(i8),
    );

    try std.testing.expectEqual(
        Bint(10, 255),
        Byte.Closest(Bint(10, 1000)),
    );

    try std.testing.expectEqual(
        Bint(25, 36),
        Byte.Closest(Bint(25, 36)),
    );

    // When its argument can't even represent a valid value, then the result is a known bint:

    try std.testing.expectEqual(
        Bint(0, 0),
        // It knows that a number within `-10..=-1` is necessarily smaller than one within
        // `0..=255`, so it always returns the lower bound.
        Byte.Closest(Bint(-10, -1)),
    );

    try std.testing.expectEqual(
        Bint(255, 255),
        // It knows that a number within `1000..=2000` is necessarily bigger than one within
        // `0..=255`, so it always returns the upper bound.
        Byte.Closest(Bint(1000, 2000)),
    );

    // When the argument is able to represent all valid values, the return type is the "namespace"
    // Bint.
    try std.testing.expectEqual(
        Byte,
        Byte.Closest(isize),
    );

    try std.testing.expectEqual(
        Byte,
        Byte.Closest(Byte),
    );

    // This means that one can always use `YourBint.widen` on the result of `YourBint.closest`
    const eight: Byte = .widen(Byte.closest(@as(i8, 8)));
    try std.testing.expectEqual(8, eight.int());

    const zero: Byte = .widen(Byte.closest(@as(isize, -100)));
    try std.testing.expectEqual(0, zero.int());
}

test "furthest" {
    // The `furthest` function takes a bint or a regular integer as argument and returns the number
    // within the range of the namespace it's called from that's the furthest from.

    // Since the furthest number is always one of the bounds, the return type is different than
    // just a bint. To allow further narrowing, it treats separately four different scenarios:
    // 1. `upper`: the upper bound is the furthest,
    // 2. `lower`: the lower bound is the furthest,
    // 3. `equal`: the lower and upper bounds are equal anyway,
    // 4. `equid`: the lower and upper bounds aren't equal but equidistant.

    const furthest = Bint(0, 100).furthest(@as(i8, 55));
    switch (furthest) {
        .upper => |upper| {
            // In this scenario, we would've given `furthest` a number under 50.
            try std.testing.expectEqual(Bint(100, 100), @TypeOf(upper));
        },
        .lower => |lower| {
            // This is what happens, since we've given `furthest a number above 50.
            try std.testing.expectEqual(Bint(0, 0), @TypeOf(lower));
        },
        .equid => |equid| {
            // In this scenario, we would've given `furthest` exactly 50.
            try std.testing.expectEqual(void, @TypeOf(equid));
        },
        .equal => |equal| {
            // This isn't possible, but if we had a `Bint(n, n)` instead, it would've been the only
            // possibility. You might want to see `furthest - comptime smartnesss` for more info.
            _ = equal;
        },
    }

    try std.testing.expect(.lower == furthest);

    // You can get it as a bint
    const as_bint = furthest.bint() orelse
        // This would've happened in an `.equid` scenario, where it can't make a decision between
        // the lower and upper bound.
        return error.ExpectedLower;

    // Or directly as a regular integer
    const as_int = furthest.int() orelse
        // Same as before.
        return error.ExpectedLower;

    try std.testing.expectEqual(0, as_bint.int());
    try std.testing.expectEqual(0, as_int);

    // This is different than accessing the payload, since you get the wide version, the original
    // Bint.
    try std.testing.expectEqual(Bint(0, 100), @TypeOf(as_bint));
    try std.testing.expectEqual(Bint(0, 100).Backing, @TypeOf(as_int));
}

test "furthest - comptime smartness" {
    // The `furthest` function distinguishes four scenarios and returns a union. But when one of
    // these scenarios can be determined impossible at compile-time, the corresponding variant is
    // defined as `noreturn`, and makes the paths that unwrap it dead code.

    // Obviously a `i4` is within `-16..<16`, and therefore further from 200 than 100.
    var only_upper = Bint(100, 200).furthest(@as(i4, 3));
    _ = &only_upper; // making sure it doesn't just work with comptime known values

    const OnlyUpper = @TypeOf(only_upper);
    // Those are impossible
    try std.testing.expectEqual(noreturn, @FieldType(OnlyUpper, "lower"));
    try std.testing.expectEqual(noreturn, @FieldType(OnlyUpper, "equid"));
    try std.testing.expectEqual(noreturn, @FieldType(OnlyUpper, "equal"));
    // This is possible
    try std.testing.expectEqual(Bint(200, 200), @FieldType(OnlyUpper, "upper"));

    switch (only_upper) {
        .upper => |upper| {
            // This is the only path that actually can happen.
            try std.testing.expectEqual(200, upper.int());
        },
        .lower => {
            // This won't even get evaluated, since `lower` is `noreturn`.
            @compileError("The `.lower` variant shouldn't be reachable!");
        },
        .equid => {
            // This branch not getting evaluated means that this won't tigger any error:
            try std.testing.expectEqual(42, 69);
        },
        .equal => |equal| {
            // Nor this:
            try std.testing.expectEqual(123467890, equal.int());

            // Nor this, which can be useful for generic code:
            try std.testing.expectEqual(Bint(12, 12), @TypeOf(equal));

            // Not even this:
            if (Bint(1000, 1000) != @TypeOf(equal))
                @compileError("This is not what I expected!");

            // Or this, which is strange:
            _ = Bint("Wrong argument", .funny);

            // Weird...
            _ = equal.i_dont_even_exist_lol;
            const not_a_string: "is" = .not_a_string;
            _ = not_a_string;

            // crazy
            return error.THIS_IS_NOT_AN_ERROR_MUHAHAHA;
        },
    }

    var only_lower = Bint(100, 200).furthest(Bint(151, 250).widen(180));
    _ = &only_lower;
    switch (only_lower) {
        .lower => |lower| try std.testing.expectEqual(100, lower.int()),
        else => @compileError("Impossible!"),
    }

    var only_equal = Bint(150, 150).furthest(@as(u8, 16));
    _ = &only_equal;
    switch (only_equal) {
        .equal => |equal| try std.testing.expectEqual(150, equal.int()),
        else => @compileError(
            "It doesn't even matter what you put as an argument, it's always going to be 150.",
        ),
    }

    var only_equid = Bint(10, 20).furthest(Bint(15, 15).widen(15));
    _ = &only_equid;
    switch (only_equid) {
        .equid => {},
        else => @compileError("The argument is always right in the middle."),
    }

    var lower_or_equid = Bint(10, 20).furthest(Bint(15, 1000).widen(15));
    _ = &lower_or_equid;
    switch (lower_or_equid) {
        .equid, .lower => {},
        else => @compileError("The argument is always bigger or equal to the middle."),
    }

    var upper_or_equid = Bint(10, 20).furthest(Bint(-100, 15).widen(15));
    _ = &upper_or_equid;
    switch (upper_or_equid) {
        .upper, .equid => {},
        else => @compileError(
            "The argument is always smaller or equal to the middle.",
        ),
    }

    var lower_or_upper = Bint(10, 19).furthest(@as(i8, 0));
    _ = &lower_or_upper;
    switch (lower_or_upper) {
        .lower, .upper => {},
        else => @compileError(
            "The furthest from the argument can be anywhere, but there's no middle.",
        ),
    }

    var lower_or_upper_or_equid = Bint(10, 20).furthest(Bint(14, 16).widen(15));
    _ = &lower_or_upper_or_equid;
    switch (lower_or_upper_or_equid) {
        .equal => @compileError(
            \\The furthest from the argument could be anywhere.
            \\The lower and upper bounds aren't equal, though.
        ),
        else => {},
    }
}

test "ord" {
    // The `ord` function returns the order which of two bints (or a bint and a regular integer) is bigger.
    const smol = Bint(0, 12).widen(1);
    const big = Bint(-10, 4).widen(3);

    // `smol` is less than `big`
    try std.testing.expectEqual(.less, smol.ord(big));
    // `big` is more than `smol`
    try std.testing.expectEqual(.more, big.ord(smol));
    // `smol` is the same as `smol`
    try std.testing.expectEqual(.same, smol.ord(smol));
}

test "ord - comptime smartness" {
    // The `ord` function is "comptime-smart", which means that a result that's proved impossible
    // by the type system will be a `noreturn`. And the unreachable branches that results from it
    // won't even be analyzed.

    var negative = Bint(-16, -1).widen(-2);
    var positive = Bint(1, 15).widen(4);
    _ = &negative;
    _ = &positive;

    const always_more = positive.ord(negative);

    if (always_more == .less)
        // This won't be evaluated by Zig, because the type of the `.less` variant is `noreturn`.
        @compileError("The order `always_more` must be proved not to be `.less`!");

    if (always_more == .same)
        @compileError("The order `always_more` can't be `.same` either!");

    try std.testing.expectEqual(.more, always_more);

    const always_less = negative.ord(positive);
    switch (always_less) {
        .less => try std.testing.expect(!@inComptime()),
        .more, .same => @compileError("The order `always` must be proved to be `.less`!"),
    }

    var both = Bint(-1, 1).widen(0);
    _ = &both;

    const less_or_same = both.ord(positive);
    switch (less_or_same) {
        // Those are both possible
        .less, .same => {},
        .more => @compileError("This one's impossible!"),
    }

    const same_or_more = both.ord(negative);
    switch (same_or_more) {
        // Those are both possible
        .same, .more => {},
        .less => @compileError("This one's impossible!"),
    }

    // There's one case when both must be the same:
    var sixty_nine = bint.fromComptime(69);
    _ = &sixty_nine;

    const always_same = sixty_nine.ord(sixty_nine);

    switch (always_same) {
        .same => try std.testing.expect(!@inComptime()),
        else => @compileError("The order `always_same` must be proved to be always `.same`!"),
    }
}

test "expect" {
    // This function could be useful if you get a bint from somewhere and not sure if it is valid.
    // This can happen in two scenarios:
    // - the bint was initialized with `@enumFromInt(...)` with an unsound logic,
    // - the bint was left undefined.

    var not_nine: Bint(0, 8) = @enumFromInt(9);
    try std.testing.expectError(error.OutOfBoundsInteger, not_nine.expect());

    not_nine = @enumFromInt(7);
    try not_nine.expect();
}

test "Iterator(...).init" {
    // The `Iterator` type is there to make it easier to go through the entire range in a loop.
    const MyBint = Bint(-1, 13);

    // Either by using both bounds at their maximum:
    var iterator = try MyBint.Iterator(.min, .max).init({}, {});
    var check: isize = -1;
    while (iterator.next()) |my_bint| : (check += 1) {
        try std.testing.expectEqual(MyBint, @TypeOf(my_bint));
        try std.testing.expectEqual(check, my_bint.int());
    }

    // Or custom ones:
    var iterator_2 = try MyBint.Iterator(.runtime, .runtime).init(
        .widen(2),
        .widen(8),
    );

    check = 2;
    while (iterator_2.next()) |my_bint| : (check += 1) {
        try std.testing.expectEqual(MyBint, @TypeOf(my_bint));
        try std.testing.expectEqual(check, my_bint.int());
    }

    // Or only one custom:
    var iterator_3 = try MyBint.Iterator(.min, .runtime).init({}, .widen(2));
    check = -1;
    while (iterator_3.next()) |my_bint| : (check += 1) {
        try std.testing.expectEqual(MyBint, @TypeOf(my_bint));
        try std.testing.expectEqual(check, my_bint.int());
    }

    // When both the lower and upper bounds are runtime, the `init` function can fail:
    try std.testing.expectError(
        error.LowerIsMoreThanUpper,
        MyBint.Iterator(.runtime, .runtime).init(.widen(2), .widen(1)),
    );
}

test "Iterator.init - comptime smartness" {
    // When using `Iterator(...).init`, if the function can't fail because the lower bound is set
    // to `.min` or the upper bound is set to `.max` or both, the failing path is a dead path.

    const Iterator1 = Bint(-128, 64).Iterator(.min, .runtime);
    _ = Iterator1.init({}, .widen(10)) catch @compileError(
        "This can't be reached, because the upper argument is always bigger than `.min_bint`.",
    );

    const Iterator2 = Bint(-128, 100).Iterator(.runtime, .max);
    _ = Iterator2.init(.widen(99), {}) catch @compileError(
        "This can't be reached, because the lower argument is always smaller than `.max_bint`.",
    );

    const Iterator3 = Bint(-10, 10).Iterator(.min, .max);
    _ = Iterator3.init({}, {}) catch @compileError(
        "This can't be reached, because obviously `.min_bint` is smaller than `.max_bint`.",
    );
}
