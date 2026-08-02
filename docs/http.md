# http

## `http_handle`

process under socat ...,fork. GET/HEAD/DELETE-style

**Examples:**
```awkward
import http;
fn handle(req) {
  if (req.path == "/") {
      return "hello";
  }
  return {"status" = 404, "body" = "not found"};
}
http.handle(handle);
```

## `builtin_http`

Built-in HTTP client (used curl)
Header keys on the response are lowercased.

**Examples:**
```awkward
import http;
let r = http.get("https://example.com");
print(r.status);
print(r.body);
http.post(url, body, {"Content-Type": "application/json"});
```

