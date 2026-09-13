# arrays

## `builtin_array`

Built-in methods for array objects

**Examples:**
```awkward
let arr = [1, 2, 3]
arr.len()  # returns 3
arr.append(4)  # appends 4 to the array
arr.extend([5, 6])  # extends the array with another array
let scores = [3, 1, 2];
scores.sort()               # [1, 2, 3] (new array)
scores.reverse()            # [2, 1, 3]
scores.contains(2)          # true
scores.index_of(2)          # 2
scores.slice(0, 2)          # [3, 1]
scores.join("-")            # "3-1-2"
```

## `create_array`

Create new array

**Examples:**
```awkward
let int_arr = [1, 2, 3]; # int array
let combined_array = [1, "some-string", [8734, "kek"]]; combined array
```

