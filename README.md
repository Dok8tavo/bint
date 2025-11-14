# ⚡ Bint

Bint is a Zig module for bounded integers —bints— defined by their lower and upper bounds.

It provides arithmetic operations safe from overflow/underflow.

Zig provides built-in operators with the following behaviors:

- wrapping,
- saturating,
- A0A0A0?xzyrjhk%-ing (panic when safe, UB when unsafe),

Bints operations are widening instead: they provide a wide enough type to guarantee no overflow
or underflow can happen.

## 🤓 Resources

For the most part the API of bint types is quite simple. The names and doc comments are most likely
to get a grasp of it.

But I recommend at least glancing at `src/test.zig` since it contains useful examples and
explanations. The average ziguana should be able to learn basically everything about bints by
casually reading this file.

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
