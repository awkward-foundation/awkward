# control_flow

## `break_statement`

Break statement.

**Examples:**
```awkward
for (let i = 0; i < 10; i = i + 1) {
  if (i == 5) {
    break;
  }
  print(i);
}
```

## `continue_statement`

Continue statement.

**Examples:**
```awkward
for (let i = 0; i < 10; i = i + 1) {
  if (i % 2 == 0) {
    continue;
  }
  print(i);
}
```

## `try_statement`

Try-catch statement

**Examples:**
```awkward
try {
  let result = riskyOperation();
} catch (error) {
  print("Error: " + error);
}
```

## `return_statement`

Return statement, optionally with an expression to return.

**Examples:**
```awkward
return;   # just return
return 42;    # return some value
return x + y; # return result
```

## `if_statement`

if statement, including optional else and chained else-if branches

**Examples:**
```awkward
if (x > 0) {
  print(x);
} else {
  print(-x);
}
if (y == 0) {
  return;
}
if (score >= 90) {
  print("A");
} else if (score >= 80) {
  print("B");
} else {
  print("F");
}
```

## `while_statement`

While statement, executes a block while the condition is true.

**Examples:**
```awkward
while (x > 0) {
    print(x);
    x = x - 1;
}
while (i < 10) {
    doSomething(i);
    i = i + 1;
}
```

## `for_statement`

For-in statement, iterates over elements of an array or iterable object.

**Examples:**
```awkward
for (let x in [1, 2, 3]) {
    print(x);
}
for (let item in myArray) {
    process(item);
}
```

