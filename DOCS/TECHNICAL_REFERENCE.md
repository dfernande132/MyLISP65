# MyLISP65 v1.0 — Technical Reference

A LISP interpreter for the MEGA65, written in C and compiled with Calypsi (`cc6502`/`ln6502`).

Lineage: the original is **MYLISP.pas**, in Pascal, for the Sinclair QL. From it came a C port
for the **ZX Spectrum Next**, and from that code — already in C — comes this port to the
MEGA65. It is the same language: MyLISP65 **is not a variant**, it is MyLISP on another
machine.

It is designed as a computer-algebra engine: it favours mathematical exactness over
convenience, strict lexical scope, and type safety over silent coercion.

> **About this document.** Everything here has been checked against the source or measured by
> running it. Nothing was inherited from the Next's reference without verification — because
> doing that check is what revealed that the older document described a rational arithmetic
> system its own code never implemented (see §4). Where something has not been measured, it
> says so.
>
> Error messages are quoted as the English build prints them.

---

## 1. Architecture

- **Lexer** — tokenises character by character: integers, rationals, floats, symbols, strings
  and delimiters.
- **Parser** — recursive descent, building the tree as linked pairs in the heap. It has a
  depth limit (§13).
- **Evaluator** — `EvalIterativo`, **a single loop with no C recursion**, driven by an
  explicit task stack. A LISP program's recursion depth **does not consume the CPU stack**,
  which on the 6502 is 256 bytes and runs out at 84 frames.
- **Heap** — 32,768 cells with a mark-sweep collector that marks iteratively.
- **REPL** — read-eval-print with multi-line input.

**All the large state lives in Attic RAM**, the MEGA65's 8 MB, reached through 32-bit `__huge`
pointers: the heap, both tables, the task stack, and the auxiliary stacks of the GC and of
`EQUAL`. The 32K program window (`0x2001-0xbfff`) holds nothing but code.

| Attic RAM region | size |
|---|---|
| cell heap | 262,144 B |
| string table | 16,320 B |
| symbol table | 8,192 B |
| task stack | 65,536 B |
| GC marking stack | 65,536 B |
| `EQUAL` stack | 131,072 B |
| compaction map | 255 B |
| **total** | **0.52 MB of 8** |

---

## 2. System limits

| limit | value | what happens when you hit it |
|---|---|---|
| heap cells | **32,768** | `* HEAP EXHAUSTED *`, evaluation is cut short |
| distinct symbols | **512** | error; they are consumed CUMULATIVELY across the session |
| symbol length | **15** | truncated **silently** |
| simultaneous strings | **255** | error creating the next one |
| string length | **63** | truncated silently |
| characters per expression | **500** | `ERR: expression too long`, input discarded |
| integers | ±2,147,483,647 | `ERR: overflow` (§4) |

Two warnings that practice has charged for:

**Symbols are never freed.** The GC compacts the string table but does not touch the symbol
table — which is correct, since an interned symbol can be referenced from anywhere, but it
means that loading three files in a row ADDS UP their symbols. A freshly started interpreter
holds 49; loading the regression battery plus `CAS.LSP` and `PCAS.LSP` leaves about 204.

**15 significant characters, and the truncation is silent.** `CALCULATE-SUMS` and
`CALCULATE-SUMR` are the same symbol. With the previous limit of 8 this bit for real:
`NUMBERP-n` and `NUMBERP-s` in the regression battery collided.

There is no separate float table: each `TFLOAT` is packed inside its own cell.

---

## 3. Data types

| internal type | description | literal |
|---|---|---|
| `TINT` | 32-bit signed integer | `42`, `-7` |
| `TRAT` | exact rational, always reduced | `1/3`, `-5/2` |
| `TFLOAT` | **32-bit** IEEE-754 floating point | `3.0`, `-2.5` |
| `TSYM` | symbol | `X`, `MY-FUN?` |
| `TSTRING` | string in double quotes | `"file.lsp"` |
| `TPAIR` | pair `(car . cdr)` | `(1 2 3)` |
| `TCLOSURE` | function with its captured environment | — |
| `TNIL` | the empty list / false | `NIL`, `()` |

`T` and `NIL` are real cells, always live in the heap. `NIL` is cell 0.

**The float here is NOT the Next's.** Under z88dk it took 6 bytes; under Calypsi it is 32-bit
IEEE-754 (4 bytes), i.e. **about 7 significant digits**. A program that depends on the Next's
exact decimal precision may give a different result here. That is a platform difference, not a
language one.

A `TRAT` does not hold numerator and denominator inside the cell: it holds an index to a
`TPAIR` that contains them. **Each rational costs 4 cells** (numerator, denominator, the pair,
and the `TRAT` cell itself).

---

## 4. The numeric system: exact arithmetic

**Principle: MyLISP never promotes an integer to a float on its own.** A CAS that turns `13`
into `13.000001` produces incorrect algebraic results that propagate unnoticed. Floating point
is an INPUT type you ask for explicitly, never an automatic output.

> **This is new in version 1.0.** Until then rationals existed as a literal but took part in no
> operation at all: `(/ 1 3)` gave `0` and `(+ 1/3 1/3)` gave `ERR: expected integer`.

### The three types and their rules

**Integer.** Range ±2,147,483,647. If an operation would leave it, you get `ERR: overflow`
**before** the wrong number is produced.

**Rational.** Produced by `/` when dividing two exact values does not come out whole. Always
normalised: reduced by the GCD, sign in the numerator, and **collapsed to an integer when the
denominator ends up 1**. That is why there is exactly ONE representation of each value, and why
`EQUAL` can compare them.

**Float.** Appears only if the literal carries a decimal point. Once one operand is a float, the
whole operation is.

```lisp
(/ 1 3)          ; -> 1/3
(/ 4 6)          ; -> 2/3        reduced
(/ 10 2)         ; -> 5          collapses to an integer
4/8              ; -> 1/2        the literal is reduced too
(/ 10 -3)        ; -> -10/3      the sign goes to the numerator
(+ 1/2 1/3)      ; -> 5/6
(+ 1/3 1/3 1/3)  ; -> 1          collapses
(* 3 1/3)        ; -> 1
(+ 1 1/2)        ; -> 3/2        integers and rationals mix without ceremony
(+ 1/2 0.5)      ; -> 1.0        one float contaminates the whole operation
```

### `/` versus `DIV`/`MOD`

| | result | type |
|---|---|---|
| `(/ 10 3)` | `10/3` | exact rational |
| `(/ 10 2)` | `5` | integer |
| `(/ 1.0 3)` | `0.3333` | float |
| `(DIV 10 3)` | `3` | integer quotient, truncated toward zero |
| `(MOD 10 3)` | `1` | remainder, sign of the dividend |
| `(DIV -10 3)` | `-3` | |
| `(MOD -10 3)` | `-1` | |

`DIV` and `MOD` accept **integers only**. `(DIV 1/2 2)` is an error.

**`(/ x)` with a single argument returns `x`, not `1/x`.** Inherited behaviour from the
original, and not entirely natural now that rationals exist. Noted rather than changed.

### Equality: `=`, `EQUAL` and `EQ`

| | result | criterion |
|---|---|---|
| `(= 3 3.0)` | `T` | same numeric value, ignores type |
| `(= 1/2 0.5)` | `T` | |
| `(= 1/3 0.3333)` | `NIL` | **the comparison is exact**: it does not go through floating point |
| `(EQUAL 3 3.0)` | `NIL` | different types |
| `(EQUAL 4/8 2/4)` | `T` | both normalise to `1/2` |
| `(EQUAL (+ 1/2 1/2) 1)` | `T` | the result collapsed to an integer |
| `(EQ 'X 'X)` | `T` | same interned symbol |
| `(EQ 1 1)` | **`NIL`** | different cells — `EQ` is not for numbers |

The comparators `< > <= >=` compare exactly, by cross-multiplication, without going through
floating point. If the cross product leaves range they report `ERR: overflow` rather than
silently falling back to floats: a comparator that is sometimes exact and sometimes not is
worse than one that complains.

### Overflow

```lisp
(* 100000 100000)      ; -> ERR: overflow
(+ 2147483647 1)       ; -> ERR: overflow
(+ 1/100000 1/99999)   ; -> ERR: overflow
(< 'A 3)               ; -> ERR: expected integer
```

Rationals overflow far sooner than integers, because adding two fractions multiplies
denominators. The implementation reduces **before** multiplying precisely to delay that as long
as possible, but the range is still 32 bits.

---

## 5. Syntax

### Identifiers

Letters, digits, and `-`, `?`, `!`, `<` anywhere but the first position. **Only the first 15
characters are significant.**

```lisp
MY-FUNCTION   ; valid
PAIR?         ; valid (convention: predicates end in ?)
STR<          ; valid (convention: comparators end in <)
3X            ; invalid: cannot start with a digit
```

### Strings, comments and rational literals

```lisp
"cas.lsp"      ; string; 63 characters maximum
; comment to end of line, valid in the REPL and in LOAD
1/3            ; rational literal
4/8            ; stored already reduced, as 1/2
```

---

## 6. Immutability

**There is no `SETQ`, nor any way to modify an existing binding.** That is a design decision,
not a gap. `DEFINE` always ADDS a new binding in the global environment; define the same symbol
twice and the second shadows the first in lookups, but the original cell is untouched.

For mutable state, the idiomatic form is an accumulator parameter:

```lisp
(DEFUN SUM-LIST (L ACC)
  (IF (NULL L) ACC
      (SUM-LIST (CDR L) (+ ACC (CAR L)))))
(SUM-LIST '(1 2 3 4 5) 0)   ; -> 15
```

And if you really do need a counter, `DEFINE` shadowing works — it is what the regression
battery uses to count failures:

```lisp
(DEFINE FAILURES 0)
(DEFINE FAILURES (+ FAILURES 1))
```

It costs one global binding each time, so it is not for hot loops.

---

## 7. Lexical scope and closures

`LAMBDA` captures the environment at the moment it is created:

```lisp
(DEFINE make-adder (LAMBDA (n) (LAMBDA (x) (+ x n))))
(DEFINE add5 (make-adder 5))
(add5 10)   ; -> 15
```

`(DEFUN F (X) body)` is exactly `(DEFINE F (LAMBDA (X) body))`.

**A `LET`'s values are evaluated in the OUTER environment**, not in terms of each other:

```lisp
(LET ((A 1) (B A)) B)   ; -> ERR: unbound: A
```

**Single namespace (Lisp-1).** Variables and functions share one environment, so defining a
variable with a primitive's name hides it:

```lisp
(DEFINE LIST 5)
(LIST 1 2 3)   ; -> ERROR: 5 is not a function
```

---

## 8. Special forms

| form | evaluation |
|---|---|
| `(QUOTE e)` or `'e` | does not evaluate `e` |
| `(IF test then)` | with no else branch, returns `NIL` when the test is false |
| `(IF test then else)` | evaluates only the chosen branch |
| `(COND (t1 e1) ...)` | first true test; `NIL` if none |
| `(AND ...)` | short-circuits on the first `NIL`; `(AND)` is `T` |
| `(OR ...)` | short-circuits on the first non-`NIL`; `(OR)` is `NIL` |
| `(PROGN ...)` | all in order, returns the last |
| `(LET ((v e) ...) body)` | the `e`s in the current environment, the body in the new one |
| `(LAMBDA (args) body)` | creates the closure without evaluating the body |
| `(DEFINE sym val)` | evaluates `val`, adds a global binding |
| `(DEFUN f (args) body)` | sugar for `DEFINE` + `LAMBDA` |
| `(LOAD "file")` | does not evaluate the name; reads and evaluates the file (§11) |
| `(EVAL e)` | evaluates `e`, then evaluates the result again in the global environment |
| `(STATUS)` | table state and peaks (§13). Returns `VOID` |
| `(CLEAN)` | immediate collection, printing before and after. Returns `VOID` |
| `(NEW)` | restarts the interpreter, asking for confirmation. Returns `VOID` |
| `(SYMBOLS)` | lists the user's symbols. Returns `VOID` |

`(SYMBOLS)` lists newest first and **shows shadowed bindings too**: if you have done
`DEFINE X` twice, `X` appears twice.

---

## 9. Memory and garbage collection

### The heap

32,768 cells in Attic RAM. Each cell is **8 bytes**: a tag, a mark, and six of payload — two
cell indices for a pair, a 32-bit integer, the packed float, or the three indices of a closure,
which fit exactly. There is no dynamic allocation from the operating system: the heap is all
there is.

Beside it live the string table (255 entries of 63 characters) and the symbol table (512 of 15).

### The collector

Mark-sweep with **iterative marking** (its own stack in Attic RAM, not C recursion). It fires
only between expressions — in the REPL and during a `LOAD` alike — when the heap passes 80%
occupancy, or when the string table passes 80% of its own.

**The automatic GC is completely silent.** It prints nothing. To see what it has been doing,
`(STATUS)` keeps a count of how many times it has run and how much the last run freed.

`(CLEAN)` **does speak** — it prints the before and after — because the user typed it on
purpose, and staying quiet would leave them without an answer.

Four things are roots: `NIL`, `T`, the global environment, and **the evaluator's task stack**.
That last one is what makes `(CLEAN)` safe in the middle of an evaluation; without it the GC
took away the environment of the call in progress, and from then on **every** symbol came back
unbound.

### Exhaustion

If the heap runs out, `HeapError` and `ErrorFlag` are raised and the evaluation in progress is
cut short in an orderly way. In the REPL the session continues; a `LOAD` is aborted.

---

## 10. The REPL

**Multi-line input.** If parentheses are still open at the end of a line, `..` appears and the
continuation is awaited. Lines accumulate until they balance.

**A 500-character limit** on the accumulated expression, the same in the REPL and in `LOAD`.
Past it: `ERR: expression too long`, and what was accumulated is discarded.

**`BYE`** at the prompt exits. Typed in the middle of a multi-line expression it is ordinary
text, not a command.

---

## 11. `LOAD` and the disk

```lisp
(LOAD "cas.lsp")   ; name in quotes
(LOAD 'MYLIB)      ; or as a symbol, without quotes
```

**The name is upper-cased** before opening: in PETSCII the capitals match ASCII numerically
(`$41-$5A`), so an upper-case name is the correct directory name. `(LOAD "cas.lsp")` and
`(LOAD "CAS.LSP")` open the same file.

**Device 8**, the floppy drive / mounted `.d81` image. Measured under Xemu, not assumed — it was
one of four environment unknowns that could not be settled by reading documentation. The other
candidate was 12, the internal FAT32 SD card that `DLOAD "X",U12` uses from BASIC 65; it is not
used here, and whether it answers a KERNAL `OPEN` **has not been tested**. The name goes
**bare**, without the Commodore `,S,R` convention: the secondary address is enough for the
MEGA65's DOS.

`LOAD` reads line by line, accumulating until the parentheses balance, and evaluates each
complete expression, printing the result exactly as the REPL does. Three differences from the
REPL are worth knowing:

1. **An error does not stop the load.** It is shown and the next expression is evaluated. The
   only thing that aborts is heap exhaustion.
2. **Two expressions on the same line are an error**, not silently ignored. In a file, losing
   code without warning is worse than at the keyboard.
3. **`LOAD` is NOT re-entrant.** A file loaded with `LOAD` cannot contain another `LOAD`: you
   get `ERR: nested LOAD`. (The Next's reference claimed the opposite of that version.) `EVAL`
   does work inside a loaded file.

The collector does run during a `LOAD`, between expressions, at the same 80% threshold.

---

## 12. Primitive quick reference

Everything in this section was measured by running it, not deduced.

### Lists

| function | result |
|---|---|
| `(CAR l)` | first element. **`ERR: expected list`** if `l` is `NIL` or an atom |
| `(CDR l)` | rest. Same error in the same cases |
| `(CONS x y)` | new pair. `(CONS 1 2)` prints `(1 . 2)` |
| `(LIST ...)` | list of the arguments. `(LIST)` is `NIL` |
| `(APPEND a b)` | concatenates; `a` is rebuilt, `b` is shared |

### Predicates

| function | result |
|---|---|
| `(ATOM x)` | `T` if not a pair. `(ATOM '())` is `T` |
| `(NULL x)` | `T` only for `NIL`. `(NULL 0)` is `NIL` |
| `(NOT x)` | `T` if `NIL` |
| `(NUMBERP x)` | `T` for `TINT`, `TRAT` and `TFLOAT` |
| `(SYMBOLP x)` | `T` for symbols |
| `(LISTP x)` | `T` for pairs and for `NIL` |
| `(EQ x y)` | same symbol or same cell. **`(EQ 1 1)` is `NIL`** |
| `(EQUAL x y)` | same structure and same exact type |

### Arithmetic and comparison

| function | notes |
|---|---|
| `(+ ...)` | variadic. `(+)` is `0` |
| `(- ...)` | variadic. `(- x)` negates |
| `(* ...)` | variadic. `(*)` is `1` |
| `(/ ...)` | exact: yields a rational when it does not divide. `(/ x)` returns `x` |
| `(DIV a b)` | truncated integer quotient. Integers only |
| `(MOD a b)` | remainder, sign of `a`. Integers only |
| `(= a b)` | numeric value; exact between exact types |
| `(< a b)` `(> a b)` `(<= a b)` `(>= a b)` | binary, not variadic |

`DIV` and `MOD` with a zero divisor give `ERR: division by zero`.

### Output and text

| function | notes |
|---|---|
| `(PRINT x)` | quotes around strings, with a newline. Returns `x` |
| `(DISPLAY x)` | no quotes and **no newline**. Returns `VOID`, which the REPL does not print |
| `(NEWLINE)` | newline, no arguments |
| `(SYMNAME s)` | symbol to string. The result is truncated to 15 characters |
| `(STR< a b)` | alphabetical order. Accepts strings and symbols |
| `(STRCAT a b)` | concatenates, converting to text. Truncates to 63 |

`STRCAT` accepts strings, symbols, integers and rationals (`(STRCAT "a" 1/2)` gives `"a1/2"`).
**It does not accept floats**: you get `ERR: expected symbol/str`.

---

## 13. Depth limits and diagnostics

Three traversals do consume the C stack, and all three are bounded. The 6502's stack is 256
bytes, and an insufficient stack **corrupts memory without raising an error**, so these limits
are not cosmetic.

| traversal | limit | what consumes it |
|---|---|---|
| parser | 55 | parenthesis nesting |
| printer | 32 | nesting of the structure being printed |
| evaluator re-entry | 8 | nested `(EVAL '(EVAL ...))`, and `LOAD` |

A LISP program's own recursion is **not** in this table: it lives in the task stack in Attic
RAM, with 8192 entries. That is the whole point of the iterative evaluator.

`(STATUS)` publishes all of them:

```
Heap: 4211/32768 (12%, live 4211)
Symbols: 141/512
Strings: 13/255
GC: 0 runs, last freed 0
peaks: parser 23/55 print 1 eval 3/8 tasks 28/8192
```

**All four are SESSION maxima**, not current values, and only `(NEW)` resets them. They exist so
limits can be calibrated from data rather than by eye: if `eval` reaches `8/8` on legitimate
code, the limit is too low.

Reference figures, measured loading the regression battery plus `CAS.LSP` and `PCAS.LSP` back to
back: **parser 31**, print 4, eval 3, tasks 29. That 31 matches the figure estimated by
simulation for `CAS.LSP` much earlier in development — two independent methods, the same number.

**`cstack` is at 4096 bytes and has NOT been measured**, by explicit decision: the program window
is not tight and the measurement costs an iteration. It is a known gap, not an oversight.

---

## 14. Programming notes

### Symbols versus strings

| | symbol | string |
|---|---|---|
| maximum length | 15 | 63 |
| table | 512 entries | 255 entries |
| GC handling | **never freed** | freed and compacted |
| self-evaluates to | its value (or an error) | itself |

**Rule of thumb:** symbols for labels, test names and identifiers. Strings only for text longer
than 15 characters or destined for `LOAD`.

The classic mistake is using strings as test labels:

```lisp
(CHECK "sum test" (+ 1 2) 3)   ; BAD: every call burns a string-table entry
(CHECK 'sum-test  (+ 1 2) 3)   ; GOOD
```

### `DISPLAY` versus `PRINT`

| | `PRINT` | `DISPLAY` |
|---|---|---|
| strings | quoted | unquoted |
| newline | always | never |
| return value | the value (visible in the REPL) | `VOID` |
| for | debugging, seeing the exact type | output to the user |

```lisp
(DISPLAY "result: ") (DISPLAY (+ 2 3)) (NEWLINE)   ; result: 5
```

### Deep recursion

It is cheap: it does not consume CPU stack. The real limit is the heap.

```lisp
(DEFUN count (n) (IF (= n 0) 0 (+ 1 (count (- n 1)))))
(count 500)   ; no problem
```

What is expensive is accumulating structure: 32,768 cells go faster than you would think if
every level builds lists.

### Ordering symbols

```lisp
(STR< 'ALFA 'BETA)   ; -> T   directly, without creating the intermediate string
```

`STR<` accepts symbols, so going through `SYMNAME` only burns a string-table entry.

---

## 15. Notes for anyone touching the code

Two things you will not deduce by reading the sources, and that cost time to find:

**No expression combines two computed values in 32-bit arithmetic, and every Attic RAM slot is
a power of two.** With certain expression shapes, `cc6502` produces an address with its two low
bytes swapped. It is measured and reproducible; the cause is **not established**. Values are
moved into local variables, one operation per statement. A standalone test program is kept in
the project as a check: before changing any constant that sizes a slot, it gets run.

**Nothing drawn on screen may depend on the active font bank.** MyLISP65 starts in
LOWERCASE+UPPERCASE, and the PETSCII graphics characters (`$A0-$BF`) exist only in the other
bank. Every literal goes through an ASCII-to-screen translation at run time, and the logo's
solid blocks are reverse-video spaces — which is bit 7 of the screen code, not a glyph —
precisely so as not to be tied to the bank again.

And one you can deduce, but only learn late: **the host test bench cannot see the compiler or
the hardware.** It is good for logic. For anything that depends on `cc6502` or on the MEGA65,
the only judge is Xemu.
