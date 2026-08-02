# expressions

## `assignment`

Assignment expression, including the compound forms '+=', '-=', '*=', '/='.
The left-hand side must be an identifier or member expression.

**Examples:**
```awkward
x = 42;
obj.field = "hello";
arr[0] = 100;
x += 1;
total -= discount;
```

## `logical_or`

Logical OR expression `||`

**Examples:**
```awkward
let result = a || b;
let combined = (x > 0) || (y < 5);
```

## `logical_and`

Logical AND expression `&&`

**Examples:**
```awkward
let result = a && b;
let combined = (x > 0) && (y < 5);
```

## `equality`

Equality expression, supporting '==' and '!=' operators.

**Examples:**
```awkward
let result = a == b;
let result = x != y;
let flag = (a + b) == (c * d);
```

## `relational`

Relational expression, supporting '<', '>', '<=', and '>=' operators.

**Examples:**
```awkward
let is_greater = a > b;
let is_smaller_or_equal = x <= y;
let result = (a + b) >= (c - d);
```

## `additive`

Additive expression, supporting '+' and '-' operators.

**Examples:**
```awkward
let result = a + b;
let total = x - y;
let value = (a + b) - (c + d);
```

## `multiplicative`

Multiplicative expression, supporting '*', '/', and '%' operators.

**Examples:**
```awkward
let product = a * b;
let quotient = x / y;
let remainder = n % 3;
```

## `unary`

Unary expression, supporting the '!' (logical not) and '-' (negation) prefix operators.

**Examples:**
```awkward
let flag = !found;
let neg = -x;
let double_negated = !!flag;
if (!ready) { print("not ready"); }
```

