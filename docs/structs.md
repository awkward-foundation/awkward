# structs

## `create_struct`

Creates a struct object from its definition node. Fields are optional

**Examples:**
```awkward
struct Point {
  x: int;
  y: int;
};
let p = new Point{x=10, y=20};
print(p.x);  # 10

struct Point3D extends Point {
  z: int;
};
let p3 = new Point3D{x=1, y=2, z=3};
print(p3.x, p3.z);  # inherited field + own field
```

## `impl_declaration`

Implement block for a struct.

**Examples:**
```awkward
impl Point {
  fn move(dx, dy) {
    self.x = self.x + dx;
    self.y = self.y + dy;
  }
}; # This adds the move method to the Point struct.
```

