# objects

## `builtin_object`

Dict-style helpers

**Examples:**
```awkward
let o = { a: 1, b: 2 };
o.keys();          # ["a", "b"]
o.values();         # [1, 2]
o.has("a");         # true
o.remove("a");
```

