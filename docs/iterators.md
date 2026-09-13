# iterators

## `builtin_iterator`

Built-in methods for iterator objects

**Examples:**
```awkward
let it = range(3);
it.next();  # 0
it.next();  # 1

struct Countdown { current; };
impl Countdown {
  fn next() {
    if (self.current <= 0) { return null; }
    let v = self.current;
    self.current = self.current - 1;
    return v;
  }
}
for (let n in new Countdown{current=3}) { print(n); }  # 3 2 1
```

