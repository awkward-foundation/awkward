# functions

## `lambda_declaration`

Lambda (anonymous) function declaration.

**Examples:**
```awkward
let f = lambda (x, y): x + y;
let g = lambda z: z * 2;
```

## `builtin_function`

Built-in methods for function objects.

**Examples:**
```awkward
func.name()  # returns the name of the function
func.call()  # calls the function
```

## `create_closure`

Creates a closure object for a given function definition within a specific scope.

**Examples:**
```awkward
fn external() {
  fn internal() {
      return "internal value";
  }
  internal();
}
```

## `function_declaration`

Declares a function with a name and parameters. Params and the return
value can each carry an optional type annotation (`?Type` for nullable),

**Examples:**
```awkward
fn add(a, b) {
    return a + b;
}
fn greet(name) {
    print("Hello, " + name);
}
fn square(x: int): int {
    return x * x;
}
fn find_user(id: int): ?string {
    if (id != 1) { return null; }
    return "Alice";
}
```

