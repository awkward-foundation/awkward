# regex

## `builtin_regex`

Built-in regex functions

**Examples:**
```awkward
import regex;
regex.match("hello123", "[0-9]+")             # returns true
regex.find("hello123", "[0-9]+")              # returns "123"
regex.replace("hello123", "[0-9]+", "X")      # returns "helloX"
regex.replace_all("a1b2c3", "[0-9]", "_")     # returns "a_b_c_"
regex.split("a, b,  c", "[, ]+")              # returns ["a", "b", "c"]
```

