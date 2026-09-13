# stdin

## `builtin_stdin`

Reading real stdin

**Examples:**
```awkward
import stdin;
let line = stdin.read_line();       # one line, or null at EOF
let all = stdin.read_all();         # every remaining line, joined with "\n"
for (let line in stdin.lines()) {   # lazy, one line per next()
  print(line);
}
```

