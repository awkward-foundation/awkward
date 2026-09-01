# builtins

## `builtin_id`

Provides the unique identifier of the given value.

**Examples:**
```awkward
id(value)  # returns the unique identifier of value
id("hello")  # returns the unique identifier of the string "hello"
id(42)  # returns the unique identifier of the integer 42
id([1, 2, 3])  # returns the unique identifier of the array [1, 2, 3]
```

## `builtin_print`

Prints one or more values to stdout.

**Examples:**
```awkward
print("Hello, World!")  # prints "Hello, World!"
print(value)  # prints the value
print(value, value2)  # prints multiple values separated by space
print(value, " - ", value2)   # prints values with custom separator
print("Value:", value, "is of type", type(value))  # prints value and its type
```

## `builtin_type`

Returns the type of the given value as a string.

**Examples:**
```awkward
type(42)  # returns "int"
type(3.14)  # returns "float"
type("hello")  # returns "string"
type([1, 2, 3])  # returns "array"
```

## `builtin_len`

Returns the length of a string, array, or struct.

**Examples:**
```awkward
len("hello")  # returns 5
len([1, 2, 3, 4])  # returns 4
```

## `builtin_pop`

Removes and returns the last element from an array.

**Examples:**
```awkward
let arr = [1, 2, 3]
let last = pop(arr)  # last = 3, arr = [1, 2]
let empty_arr = []
let last = pop(empty_arr)  # last = null, empty_arr = []
```

## `builtin_clear`

Clears all elements from an array.

**Examples:**
```awkward
let arr = [1, 2, 3]
clear(arr)  # arr = []
let empty_arr = []
clear(empty_arr)  # empty_arr = []
```

## `builtin_assert`

Asserts that a condition is true, otherwise raises an assertion error.

**Examples:**
```awkward
assert(x > 0, "x must be positive")  # raises error if x <= 0
assert(value)  # raises error if value is false or null
```

## `builtin_filter`

Filters elements from an array based on a predicate function.

**Examples:**
```awkward
let arr = [1, 2, 3, 4, 5]
let even_arr = filter(arr, lambda x: x % 2 == 0)  # even_arr = [2, 4]
```

## `builtin_map`

Maps elements from an array using a transformation function.

**Examples:**
```awkward
let arr = [1, 2, 3]
let squared_arr = map(arr, lambda x: x * x)  # squared_arr = [1, 4, 9]
```

## `builtin_reduce`

Reduces an array to a single value using a binary function.

**Examples:**
```awkward
let arr = [1, 2, 3, 4]
let sum = reduce(arr, lambda acc, x: acc + x, 0)  # sum = 10
```

## `builtin_range`

Creates a lazy iterator over a range of integers

**Examples:**
```awkward
for (let i in range(5)) { print(i) }  # 0 1 2 3 4
for (let i in range(2, 6)) { print(i) }  # 2 3 4 5
```

## `builtin_int`

Explicit type conversion. int()/float() accept int, float, bool, or string

**Examples:**
```awkward
int("42")    # 42
float("3.5") # 3.5
str(42)      # "42"
```

## `builtin_format`

printf-style formatting up to 5 value args for now

**Examples:**
```awkward
format("%.2f", 3.14159)      # "3.14"
format("%5d", 3)             # "    3"
format("%s is %d", "age", 9) # "age is 9"
```

