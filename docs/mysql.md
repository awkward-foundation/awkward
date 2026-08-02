# mysql

## `builtin_mysql`

MySQL/MariaDB client

**Examples:**
```awkward
import mysql;
let conn = mysql.connect("127.0.0.1", 3306, "root", "testdb");
let rows = mysql.query(conn, "SELECT id, title FROM tasks");
let result = mysql.query(conn, "UPDATE tasks SET done=1 WHERE id=1");
mysql.close(conn);
mysql.query(conn, "INSERT INTO blobs (data) VALUES (UNHEX('" + mysql.hex_encode(raw_bytes) + "'))");
```

