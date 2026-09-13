# strings

## `builtin_string`

Built-in methods for string objects.

**Examples:**
```awkward
let str = "hello"
str.upper()  # returns "HELLO"
str.lower()  # returns "hello"
str.len()    # returns 5
let str = "hello, world";
str.split(",")    # returns [hello, world]
let padded = "  Hello, World!  ";
padded.trim()                   # "Hello, World!"
padded.trim().contains("World") # true
padded.trim().index_of("World") # 7
padded.trim().starts_with("Hello")  # true
padded.trim().ends_with("!")        # true
padded.trim().replace("World", "dude")  # "Hello, dude!"
padded.trim().slice(0, 5)      # "Hello"
"abc".reverse()                 # "cba"
"ab".repeat(3)                  # "ababab"
```

