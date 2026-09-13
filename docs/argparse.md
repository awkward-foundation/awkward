# argparse

## `builtin_argparse`

Parses the script's own extra command-line arguments into named flags
--key=value sets a string value

**Examples:**
```awkward
./awkward script.awkward --name=kek --count=3 --verbose input.txt
import argparse;
let opts = argparse.parse();
print(opts.name, opts.count, opts.verbose, opts._positional);
# kek 3 true [input.txt]
```

