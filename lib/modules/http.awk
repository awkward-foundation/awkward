
function hex_to_dec(hex,   i, c, n, v) {
    n = 0
    for (i = 1; i <= length(hex); i++) {
        c = tolower(substr(hex, i, 1))
        v = index("0123456789abcdef", c) - 1
        n = n * 16 + v
    }
    return n
}

function utf8_encode(code,   b1, b2, b3, b4) {
    if (code <= 127) {
        return sprintf("%c", code)
    } else if (code <= 2047) {
        b1 = 192 + int(code / 64)
        b2 = 128 + (code % 64)
        return sprintf("%c%c", b1, b2)
    } else if (code <= 65535) {
        b1 = 224 + int(code / 4096)
        b2 = 128 + (int(code / 64) % 64)
        b3 = 128 + (code % 64)
        return sprintf("%c%c%c", b1, b2, b3)
    } else {
        b1 = 240 + int(code / 262144)
        b2 = 128 + (int(code / 4096) % 64)
        b3 = 128 + (int(code / 64) % 64)
        b4 = 128 + (code % 64)
        return sprintf("%c%c%c%c", b1, b2, b3, b4)
    }
}

function create_http_module(obj_id, fun_id, methods, i) {
    debug_msg("Creating http module")
    obj_id = create_object()
    objects[obj_id, "type"] = TYPE_STRUCT
    objects[obj_id, "struct_name"] = "http"

    methods = "get post put delete patch head url_encode json_parse json_stringify handle"
    split(methods, funcs, " ")
    objects[obj_id, "properties_count"] = length(funcs)

    for (i = 1; i <= length(funcs); i++) {
        objects[obj_id, "prop_key_" i] = funcs[i]
        fun_id = create_value(TYPE_FUNCTION, "builtin:http." funcs[i])
        objects[obj_id, "prop_value_" i] = fun_id
    }

    return obj_id
}

function http_log_request(method, path, status,   cmd, ts) {
    cmd = "date '+%Y-%m-%d %H:%M:%S'"
    cmd | getline ts
    close(cmd)
    print "[" ts "] " method " " path " -> " status > "/dev/stderr"
    fflush("/dev/stderr")
}

function http_status_reason(status) {
    if (status == 200) return "OK"
    if (status == 201) return "Created"
    if (status == 204) return "No Content"
    if (status == 301) return "Moved Permanently"
    if (status == 302) return "Found"
    if (status == 304) return "Not Modified"
    if (status == 400) return "Bad Request"
    if (status == 401) return "Unauthorized"
    if (status == 403) return "Forbidden"
    if (status == 404) return "Not Found"
    if (status == 405) return "Method Not Allowed"
    if (status == 500) return "Internal Server Error"
    return "OK"
}

# @doc [http]
# process under socat ...,fork. GET/HEAD/DELETE-style
# examples:
# import http;
# fn handle(req) {
#   if (req.path == "/") {
#       return "hello";
#   }
#   return {"status" = 404, "body" = "not found"};
# }
# http.handle(handle);
function http_handle(handler_id,   request_line, req_parts, n, method, path, version,
                      header_line, colon, hkey, hval, header_keys, header_values, header_count,
                      content_length, body,
                      req_keys, req_values, req_id, handler_args, response_id,
                      response_type, status, resp_body, resp_headers_id,
                      resp_prop_count, i, key, val_id, val, has_content_type,
                      header_text) {

    if ((getline request_line) <= 0) {
        error("http.handle: failed to read request line from stdin")
    }
    gsub(/\r$/, "", request_line)

    n = split(request_line, req_parts, " ")
    method = (n >= 1) ? req_parts[1] : ""
    path = (n >= 2) ? req_parts[2] : ""
    version = (n >= 3) ? req_parts[3] : "HTTP/1.1"

    header_count = 0
    content_length = 0
    while ((getline header_line) > 0) {
        gsub(/\r$/, "", header_line)
        if (header_line == "") break
        colon = index(header_line, ":")
        if (colon > 0) {
            hkey = tolower(substr(header_line, 1, colon - 1))
            hval = substr(header_line, colon + 1)
            sub(/^[ \t]+/, "", hval)
            header_count++
            header_keys[header_count] = hkey
            header_values[header_count] = create_value(TYPE_STRING, hval)
            if (hkey == "content-length") content_length = hval + 0
        }
    }

    if (content_length > 0) {
        printf "HTTP/1.1 411 Length Required\r\nContent-Type: text/plain\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        fflush()
        http_log_request(method, path, 411)
        return create_value(TYPE_NULL, "null", 0)
    }
    body = ""

    req_keys[1] = "method";  req_values[1] = create_value(TYPE_STRING, method)
    req_keys[2] = "path";    req_values[2] = create_value(TYPE_STRING, path)
    req_keys[3] = "version"; req_values[3] = create_value(TYPE_STRING, version)
    req_keys[4] = "headers"; req_values[4] = create_object(header_keys, header_values, header_count)
    req_keys[5] = "body";    req_values[5] = create_value(TYPE_STRING, body)
    req_id = create_object(req_keys, req_values, 5)

    delete handler_args
    handler_args[1] = req_id
    if (objects[handler_id, "value"] ~ /^lambda:/) {
        response_id = call_lambda(handler_id, handler_args, 1)
    } else {
        response_id = call_function(handler_id, handler_args, 1)
    }

    status = 200
    resp_body = ""
    resp_headers_id = ""
    response_type = objects[response_id, "type"]

    if (response_type == TYPE_OBJECT || response_type == TYPE_STRUCT) {
        resp_prop_count = objects[response_id, "properties_count"] + 0
        for (i = 1; i <= resp_prop_count; i++) {
            key = objects[response_id, "prop_key_" i]
            val_id = objects[response_id, "prop_value_" i]
            if (key == "status") status = objects[val_id, "value"] + 0
            else if (key == "body") resp_body = value_to_string(val_id)
            else if (key == "headers") resp_headers_id = val_id
        }
        if (status == 0) status = 200
    } else {
        resp_body = value_to_string(response_id)
    }

    header_text = ""
    has_content_type = 0
    if (resp_headers_id != "") {
        resp_prop_count = objects[resp_headers_id, "properties_count"] + 0
        for (i = 1; i <= resp_prop_count; i++) {
            key = objects[resp_headers_id, "prop_key_" i]
            val_id = objects[resp_headers_id, "prop_value_" i]
            val = value_to_string(val_id)
            if (tolower(key) == "content-type") has_content_type = 1
            header_text = header_text key ": " val "\r\n"
        }
    }
    if (!has_content_type) header_text = header_text "Content-Type: text/plain\r\n"
    header_text = header_text "Content-Length: " length(resp_body) "\r\n"
    header_text = header_text "Connection: close\r\n"

    printf "HTTP/1.1 %s %s\r\n%s\r\n%s", status, http_status_reason(status), header_text, resp_body
    fflush()
    http_log_request(method, path, status)

    return create_value(TYPE_NULL, "null", 0)
}

# @doc [http]
# Built-in HTTP client (used curl)
# Header keys on the response are lowercased.
# examples:
# import http;
# let r = http.get("https://example.com");
# print(r.status);
# print(r.body);
# http.post(url, body, {"Content-Type": "application/json"});
function builtin_http(func_name, args, argc,   parts, method, url, body_id, headers_id, s) {
    split(func_name, parts, ".")

    if (parts[2] == "url_encode") {
        if (argc != 1) error("url_encode expects 1 argument")
        s = objects[args[1], "value"]
        return create_value(TYPE_STRING, http_url_encode(s))
    }

    if (parts[2] == "json_parse") {
        if (argc != 1) error("json_parse expects 1 argument")
        s = objects[args[1], "value"]
        return http_json_parse(s)
    }

    if (parts[2] == "json_stringify") {
        if (argc != 1) error("json_stringify expects 1 argument")
        return create_value(TYPE_STRING, http_json_stringify(args[1]))
    }

    if (parts[2] == "handle") {
        if (argc != 1) error("http.handle expects 1 argument: handler")
        if (objects[args[1], "type"] != TYPE_FUNCTION) error("http.handle: argument must be a function")
        return http_handle(args[1])
    }

    if (parts[2] == "get")    method = "GET"
    else if (parts[2] == "post")   method = "POST"
    else if (parts[2] == "put")    method = "PUT"
    else if (parts[2] == "delete") method = "DELETE"
    else if (parts[2] == "patch")  method = "PATCH"
    else if (parts[2] == "head")   method = "HEAD"
    else error("Unknown http function: " func_name)

    if (argc < 1) error(parts[2] " expects at least 1 argument (url)")
    url = objects[args[1], "value"]

    body_id = ""
    headers_id = ""
    if (method == "GET" || method == "DELETE" || method == "HEAD") {
        if (argc >= 2) headers_id = args[2]
    } else {
        if (argc >= 2) body_id = args[2]
        if (argc >= 3) headers_id = args[3]
    }

    return http_request(method, url, body_id, headers_id)
}

function http_request(method, url, body_id, headers_id,   counter, body_file, hdr_file, cmd, status, line, body, nlines, header_lines, i, last_status_idx, colon, hkey, hval, hcount, hk, hv, type_h, prop_count, key, val_id, val, btype, bval, response_keys, response_values, hdr_obj_id, body_val_id, status_val_id) {
    counter = ++http_request_counter
    body_file = "/tmp/awkward_http_body_" counter
    hdr_file  = "/tmp/awkward_http_hdr_" counter

    cmd = "curl -sS -L -X " shell_escape(method)
    cmd = cmd " -D " shell_escape(hdr_file)
    cmd = cmd " -o " shell_escape(body_file)
    cmd = cmd " -w '%{http_code}'"

    if (method == "HEAD") {
        cmd = cmd " -I"
    }

    if (headers_id != "" && headers_id != 0) {
        type_h = objects[headers_id, "type"]
        if (type_h == TYPE_OBJECT || type_h == TYPE_STRUCT) {
            prop_count = objects[headers_id, "properties_count"] + 0
            for (i = 1; i <= prop_count; i++) {
                key = objects[headers_id, "prop_key_" i]
                val_id = objects[headers_id, "prop_value_" i]
                val = objects[val_id, "value"]
                cmd = cmd " -H " shell_escape(key ": " val)
            }
        }
    }

    if (body_id != "" && body_id != 0) {
        btype = objects[body_id, "type"]
        if (btype != TYPE_NULL) {
            bval = objects[body_id, "value"]
            cmd = cmd " --data-raw " shell_escape(bval)
        }
    }

    cmd = cmd " " shell_escape(url)
    cmd = cmd " 2>/dev/null"

    debug_msg("HTTP " method " " url)

    status = ""
    cmd | getline status
    close(cmd)

    body = ""
    if (method != "HEAD") {
        nlines = 0
        while ((getline line < body_file) > 0) {
            if (nlines == 0) body = line
            else body = body "\n" line
            nlines++
        }
        close(body_file)
    }
    system("rm -f " shell_escape(body_file))

    nlines = 0
    delete header_lines
    while ((getline line < hdr_file) > 0) {
        sub(/\r$/, "", line)
        nlines++
        header_lines[nlines] = line
    }
    close(hdr_file)
    system("rm -f " shell_escape(hdr_file))

    last_status_idx = 0
    for (i = 1; i <= nlines; i++) {
        if (header_lines[i] ~ /^HTTP\//) last_status_idx = i
    }

    hcount = 0
    for (i = last_status_idx + 1; i <= nlines; i++) {
        if (header_lines[i] == "") break
        colon = index(header_lines[i], ":")
        if (colon > 0) {
            hkey = substr(header_lines[i], 1, colon - 1)
            hval = substr(header_lines[i], colon + 1)
            sub(/^[ \t]+/, "", hval)
            hkey = tolower(hkey)
            hcount++
            hk[hcount] = hkey
            hv[hcount] = create_value(TYPE_STRING, hval)
        }
    }

    hdr_obj_id = create_object(hk, hv, hcount)

    body_val_id = create_value(TYPE_STRING, body)
    status_val_id = create_value(TYPE_INT, status + 0)

    response_keys[1] = "status"
    response_keys[2] = "headers"
    response_keys[3] = "body"
    response_values[1] = status_val_id
    response_values[2] = hdr_obj_id
    response_values[3] = body_val_id

    return create_object(response_keys, response_values, 3)
}

function http_url_encode(s,   cmd, line, hex_str, parts, n, i, byte_val, c, out) {
    if (s == "") return ""

    cmd = "printf %s " shell_escape(s) " | od -An -tx1 -v"
    hex_str = ""
    while ((cmd | getline line) > 0) {
        gsub(/^[ \t]+|[ \t]+$/, "", line)
        if (line == "") continue
        hex_str = hex_str (hex_str == "" ? "" : " ") line
    }
    close(cmd)

    n = split(hex_str, parts, " ")
    out = ""
    for (i = 1; i <= n; i++) {
        if (parts[i] == "") continue
        byte_val = hex_to_dec(parts[i])
        c = sprintf("%c", byte_val)
        if (byte_val < 128 && c ~ /[A-Za-z0-9._~-]/) {
            out = out c
        } else {
            out = out "%" toupper(parts[i])
        }
    }
    return out
}

function http_json_parse(s,   val_id) {
    json_src = s
    json_pos = 1
    json_len = length(s)
    json_skip_ws()
    if (json_pos > json_len) error("json_parse: empty input")
    val_id = json_parse_value()
    json_skip_ws()
    if (json_pos <= json_len) error("json_parse: trailing data at position " json_pos)
    return val_id
}

function json_skip_ws(   c) {
    while (json_pos <= json_len) {
        c = substr(json_src, json_pos, 1)
        if (c == " " || c == "\t" || c == "\n" || c == "\r") json_pos++
        else break
    }
}

function json_parse_value(   c) {
    json_skip_ws()
    if (json_pos > json_len) error("json_parse: unexpected end of input")
    c = substr(json_src, json_pos, 1)
    if (c == "{") return json_parse_object()
    if (c == "[") return json_parse_array()
    if (c == "\"") return json_parse_string()
    if (c == "t" || c == "f") return json_parse_bool()
    if (c == "n") return json_parse_null()
    if (c == "-" || (c >= "0" && c <= "9")) return json_parse_number()
    error("json_parse: unexpected character '" c "' at position " json_pos)
}

function json_parse_object(   keys, values, count, key_id, val_id, c) {
    json_pos++
    count = 0
    json_skip_ws()
    if (substr(json_src, json_pos, 1) == "}") {
        json_pos++
        return create_object(keys, values, 0)
    }
    while (1) {
        json_skip_ws()
        if (substr(json_src, json_pos, 1) != "\"") error("json_parse: expected string key at position " json_pos)
        key_id = json_parse_string()
        json_skip_ws()
        if (substr(json_src, json_pos, 1) != ":") error("json_parse: expected ':' at position " json_pos)
        json_pos++
        val_id = json_parse_value()
        count++
        keys[count] = objects[key_id, "value"]
        values[count] = val_id
        json_skip_ws()
        c = substr(json_src, json_pos, 1)
        if (c == ",") { json_pos++; continue }
        if (c == "}") { json_pos++; break }
        error("json_parse: expected ',' or '}' at position " json_pos)
    }
    return create_object(keys, values, count)
}

function json_parse_array(   element_ids, count, c) {
    json_pos++
    count = 0
    json_skip_ws()
    if (substr(json_src, json_pos, 1) == "]") {
        json_pos++
        return create_array(element_ids, 0)
    }
    while (1) {
        element_ids[++count] = json_parse_value()
        json_skip_ws()
        c = substr(json_src, json_pos, 1)
        if (c == ",") { json_pos++; continue }
        if (c == "]") { json_pos++; break }
        error("json_parse: expected ',' or ']' at position " json_pos)
    }
    return create_array(element_ids, count)
}

function json_parse_string(   out, c, next_c, hex, hex2, code, low) {
    json_pos++
    out = ""
    while (json_pos <= json_len) {
        c = substr(json_src, json_pos, 1)
        if (c == "\"") {
            json_pos++
            return create_value(TYPE_STRING, out)
        }
        if (c == "\\") {
            json_pos++
            if (json_pos > json_len) error("json_parse: dangling backslash")
            next_c = substr(json_src, json_pos, 1)
            if (next_c == "\"") out = out "\""
            else if (next_c == "\\") out = out "\\"
            else if (next_c == "/") out = out "/"
            else if (next_c == "b") out = out sprintf("%c", 8)
            else if (next_c == "f") out = out sprintf("%c", 12)
            else if (next_c == "n") out = out "\n"
            else if (next_c == "r") out = out "\r"
            else if (next_c == "t") out = out "\t"
            else if (next_c == "u") {
                if (json_pos + 4 > json_len) error("json_parse: invalid \\u escape")
                hex = substr(json_src, json_pos + 1, 4)
                code = hex_to_dec(hex)
                json_pos += 4
                if (code >= 55296 && code <= 56319) {
                    if (substr(json_src, json_pos + 1, 2) != "\\u") error("json_parse: expected low surrogate")
                    json_pos += 2
                    if (json_pos + 4 > json_len) error("json_parse: invalid low surrogate")
                    hex2 = substr(json_src, json_pos + 1, 4)
                    low = hex_to_dec(hex2)
                    json_pos += 4
                    code = 65536 + (code - 55296) * 1024 + (low - 56320)
                }
                out = out utf8_encode(code)
            }
            else error("json_parse: invalid escape \\" next_c)
            json_pos++
        } else {
            out = out c
            json_pos++
        }
    }
    error("json_parse: unterminated string")
}

function json_parse_number(   start, c, has_dot, has_e, num_str) {
    start = json_pos
    has_dot = 0
    has_e = 0
    if (substr(json_src, json_pos, 1) == "-") json_pos++
    while (json_pos <= json_len) {
        c = substr(json_src, json_pos, 1)
        if (c >= "0" && c <= "9") {
            json_pos++
        } else if (c == "." && !has_dot && !has_e) {
            has_dot = 1
            json_pos++
        } else if ((c == "e" || c == "E") && !has_e) {
            has_e = 1
            json_pos++
            c = substr(json_src, json_pos, 1)
            if (c == "+" || c == "-") json_pos++
        } else {
            break
        }
    }
    num_str = substr(json_src, start, json_pos - start)
    if (has_dot || has_e) return create_value(TYPE_FLOAT, num_str + 0)
    return create_value(TYPE_INT, num_str + 0)
}

function json_parse_bool() {
    if (substr(json_src, json_pos, 4) == "true") {
        json_pos += 4
        return create_value(TYPE_BOOL, 1)
    }
    if (substr(json_src, json_pos, 5) == "false") {
        json_pos += 5
        return create_value(TYPE_BOOL, 0)
    }
    error("json_parse: invalid literal at position " json_pos)
}

function json_parse_null() {
    if (substr(json_src, json_pos, 4) == "null") {
        json_pos += 4
        return create_value(TYPE_NULL, "null")
    }
    error("json_parse: invalid literal at position " json_pos)
}

function http_json_stringify(val_id,   type, val, out, i, n, count, key, prop_val_id) {
    type = objects[val_id, "type"]
    if (type == TYPE_NULL)   return "null"
    if (type == TYPE_BOOL)   return (objects[val_id, "value"] + 0) ? "true" : "false"
    if (type == TYPE_INT)    return objects[val_id, "value"] ""
    if (type == TYPE_FLOAT)  return objects[val_id, "value"] ""
    if (type == TYPE_STRING) return json_escape_string(objects[val_id, "value"])
    if (type == TYPE_ARRAY) {
        n = objects[val_id, "length"]
        out = "["
        for (i = 0; i < n; i++) {
            if (i > 0) out = out ","
            out = out http_json_stringify(objects[val_id, "element_" i])
        }
        return out "]"
    }
    if (type == TYPE_OBJECT || type == TYPE_STRUCT) {
        count = objects[val_id, "properties_count"] + 0
        out = "{"
        for (i = 1; i <= count; i++) {
            if (i > 1) out = out ","
            key = objects[val_id, "prop_key_" i]
            prop_val_id = objects[val_id, "prop_value_" i]
            out = out json_escape_string(key) ":" http_json_stringify(prop_val_id)
        }
        return out "}"
    }
    error("json_stringify: cannot stringify type " type)
}

function json_escape_string(s,   out, i, n, c, code) {
    out = "\""
    n = length(s)
    for (i = 1; i <= n; i++) {
        c = substr(s, i, 1)
        if (c == "\"")      out = out "\\\""
        else if (c == "\\") out = out "\\\\"
        else if (c == "\n") out = out "\\n"
        else if (c == "\r") out = out "\\r"
        else if (c == "\t") out = out "\\t"
        else if (c == "\b") out = out "\\b"
        else if (c == "\f") out = out "\\f"
        else                out = out c
    }
    return out "\""
}
