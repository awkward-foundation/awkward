# variables

## `variable_declaration`

Variable declaration, optionally with an initializer and a type annotation

**Examples:**
```awkward
let x;                      # untyped, defaults to null
let y = 42;                 # untyped, inferred at runtime only
let count: int = 0;
let note: ?string;          # nullable
let name: string;           # error! no initializer, defaults to null
count = "kek";             # runtime error: count is declared int
```

