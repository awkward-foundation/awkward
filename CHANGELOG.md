# awkward changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2026-08-02

### Added

- unary `!` and `-` prefix operators
- Built-in `regex` module (`match`, `find`, `replace`, `replace_all`, `split`)
- `http.handle(handler)` handles one bodyless HTTP request (GET/HEAD/DELETE-style) read from stdinю Used an external listener (`socat TCP-LISTEN:PORT,reuseaddr,fork EXEC:"awkward server.awkward"`, or `nc`). No sockets are opened by awkward itself
- Built-in `mysql` module: a real MySQL/MariaDB wire-protocol client
- compound assignment operators `+=`, `-=`, `*=`, `/=`
- `else if` chaining, e.g. `if (a) {} else if (b) {} else {}`, instead of requiring a nested `if` inside every `else` block

### Changed

- src moved from a single `awkward` file to `lib/core.awk` + `lib/modules/*.awk`
- user modules (`import my_module`) now resolve against the installed lib dir (`$AWKWARD_LIBDIR`, passed through by the `awkward` launcher)
- launcher forces `LC_ALL=C`
- json `\uXXXX` escapes now encode via `utf8_encode()` instead of relying on `sprintf("%c", code)`

### Fixed

- User-defined modules (`import my_module`) could not call any builtin function (`print`, `assert`, `filter`, `map`, `reduce`, `range`, etc)
- `function.call()` silently returned `null` instead of invoking the function when called on a lambda/closure
- gc could sweep an object still referenced only by a closure's captured environment
- gc could delete the very object it was in the middle of constructing
- `print(a, b, ...)` never inserted the documented space separator between comma-separated arguments
- `set_indexed_value` returned `create_object(TYPE_NULL, "null", 0)` instead of `create_value(TYPE_NULL, "null", 0)`
- `get_object_property` checked the interpreter's own internal bookkeeping fields

## [0.1.2] - 2026-05-24

### Added

- Built-in `http` module for http requests
- Built-in `io` module for file streams
- Built-in `fs` module for filesystem operations
- `string.split(separator)` method that splits a string into an array
- Escape sequence handling in string literals
- Tests for fs, io and http modules

### Changed

- Binary expression evaluation reworked
- Struct comparison and several debug paths refactored...

## [0.1.1] - 2025-10-26

### Added

- Something meaningful

### Fixed

- Bug that nobody noticed

## [0.1.0] - 2025-10-26

### Added

- Support for functions as objects: they can be assigned, passed, and called using `.call()`
- Built-in functions have been added: `id`
- Support for methods on types:
  - for strings: `string.upper()`, `string.lower()`, `string.len()`
  - for arrays: `array.append()`, `array.extend()`, `array.len()`
  - for functions: `function.call()`, `function.name()`
- Import modules with aliases: `import module as my_module`
- Support for built-in modules (e.g., math) with automatic function registration.
- Creating objects and structures: `TYPE_OBJECT` and `TYPE_STRUCT` with fields and methods

### Changed

- The member expression mechanism for accessing properties of structs, arrays, and strings has been rewritten.
- Function calls and work with scope and closure have been optimized.
- Storing of string lengths in the `TYPE_STRING` object when creating has been implemented.

### Fixed

- The calculation of the string length in `string.len()` has been fixed
- The `.name()` method call for anonymous and named functions (`<anonymous>` for lambda functions) has been fixed.
- A bug with accessing properties of imported modules has been fixed.
