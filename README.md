# ⚡ Bint

Bint is a Zig module for bounded integers, bints, defined by their lower and upper bounds.

## 🤓 Resources

For the most part the API of bint types is quite simple. The names and doc comments are most likely
to get a grasp of it.

But I recommend at least glancing at `src/test.zig` since it contains useful examples and
explanations. The average ziguana should be able to learn basically everything about bints by
casually reading this file.

## 🧰 Usage

### Use bint in your project

1. fetch bint in your project with the `build.zig.zon`:

```sh
zig fetch --save=bint git+github.com/Dok8tavo/bint
```

2. get it from the builder in `build.zig`:

```zig
const bint_dependency = b.dependency("bint");
```

3. get the bint module from the dependency:

```zig
const bint_module = bint_dependency.module("bint");
```

4. add it to your own module:

```zig
your_module.addImport("bint", bint_module);
```

5. import it and use it in your codebase:

```zig
const bint = @import("bint");
```

6. Read `src/test.zig` to get familiar with the API of bints.

### Handling overflow/underflow

Zig provides built-in operators that have the following behavior when overflowing/underflowing:

- wrapping (get back to the opposite bound and continue the operation),
- saturating (stay at the overflowed/underflowed bound),
- A0A0A0?xzyrjhk%-ing (panic in safe mode, UB in unsafe mode),

Bints operations are widening instead: they provide a wide enough type to guarantee no overflow
or underflow can happen. And thus, they're safe from overflow/underflow at compile-time. Some
operations can also be narrowing.

In short, if an overflow/underflow is even possible, the program won't compile.

If you can prove that your operation is safe, it's possible bint types will too. You'll be
guaranteed some optimizations (checks are done at compile-time). If not, you'll have to resort to
use `.init(...) catch unreachable` at some point, and although the optimization isn't guaranteed,
it can still happen.

### Comptime smartness

Similarily to the widening/narrowing strategy, bints can prove some kind of results are unreachable
at compile time. For a lack of a better wording, I call this "comptime-smartness".

Some functions, like `furthest` or `ord`, returns enums/unions, whose variants can be of type
`noreturn`. This means that branches that results from those variants aren't even evaluated. You
can `@compileError(...)` your way out of those to make sure they were proven unreachable at compile
time. Generic code shouldn't be affected: since those branches aren't evaluated, whether you handle
them or `@compileError(...)` them, they won't modify the behavior of your program.

Some other functions, like `div` or `init`, can fail at runtime. If the types of their arguments is
enough to prove they can't fail, their error set will be `error{}`. You can then
`catch @compileError(...)` your way out of the failing cases.

## 📃 License

MIT License

Copyright (c) 2025 Dok8tavo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
