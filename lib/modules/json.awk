function create_json_module(obj_id, fun_id, funcs, i) {
    if (debug) debug_msg("Creating json module")
    obj_id = create_object()
    objects[obj_id, "type"] = TYPE_STRUCT
    objects[obj_id, "struct_name"] = "json"

    json_funcs = "parse stringify to_struct"
    split(json_funcs, funcs, " ")
    objects[obj_id, "properties_count"] = length(funcs)

    for (i = 1; i <= length(funcs); i++) {
        objects[obj_id, "prop_key_" i] = funcs[i]
        fun_id = create_value(TYPE_FUNCTION, "builtin:json." funcs[i])
        objects[obj_id, "prop_value_" i] = fun_id
    }

    return obj_id
}

# @doc [json]
# examples:
# import json;
# let v = json.parse("{\"a\":1,\"b\":[true,null]}");
# json.stringify(v);
function builtin_json(func_name, args, argc,   parts) {
    split(func_name, parts, ".")
    if (parts[2] == "parse") {
        if (argc != 1) error("json.parse expects 1 argument")
        return json_decode(objects[args[1], "value"])
    } else if (parts[2] == "stringify") {
        if (argc != 1) error("json.stringify expects 1 argument")
        return create_value(TYPE_STRING, json_encode(args[1]))
    } else if (parts[2] == "to_struct") {
        if (argc != 2) error("json.to_struct expects 2 arguments: a parsed object and a struct type")
        return json_to_struct(args[1], args[2])
    }
    error("Unknown json function: " func_name)
}

function json_to_struct(obj_id, type_id,   inst_id, i, j, len, def_id, def_count, def_name, have_it, count, walk_type_id) {
    if (objects[obj_id, "type"] != TYPE_OBJECT && objects[obj_id, "type"] != TYPE_STRUCT)
        error("json.to_struct expects a parsed object as the first argument")
    if (objects[type_id, "type"] != TYPE_STRUCT || objects[type_id, "definition"] == "")
        error("json.to_struct expects a struct type (not an instance) as the second argument")

    inst_id = create_object()
    objects[inst_id, "type"] = TYPE_STRUCT
    objects[inst_id, "prototype"] = type_id
    len = objects[obj_id, "properties_count"]
    for (i = 1; i <= len; i++) {
        objects[inst_id, "prop_key_" i] = objects[obj_id, "prop_key_" i]
        objects[inst_id, "prop_value_" i] = objects[obj_id, "prop_value_" i]
    }
    count = len

    walk_type_id = type_id
    while (walk_type_id != "") {
        def_id = objects[walk_type_id, "definition"]
        def_count = ast_nodes[def_id, "properties_count"]
        for (i = 1; i <= def_count; i++) {
            def_name = ast_nodes[ast_nodes[def_id, "property_" i], "name"]
            have_it = 0
            for (j = 1; j <= count; j++) {
                if (objects[inst_id, "prop_key_" j] == def_name) { have_it = 1; break }
            }
            if (!have_it) {
                count++
                objects[inst_id, "prop_key_" count] = def_name
                objects[inst_id, "prop_value_" count] = create_value(TYPE_NULL, "null")
            }
        }
        walk_type_id = objects[walk_type_id, "parent"]
    }
    objects[inst_id, "properties_count"] = count
    return inst_id
}

function json_escape(s) {
    gsub(/\\/, "\\\\", s)
    gsub(/"/, "\\\"", s)
    gsub(/\n/, "\\n", s)
    gsub(/\r/, "\\r", s)
    gsub(/\t/, "\\t", s)
    return s
}

function json_encode(val_id,   type, len, i, out) {
    type = objects[val_id, "type"]
    if (type == TYPE_NULL) return "null"
    if (type == TYPE_BOOL) return objects[val_id, "value"] ? "true" : "false"
    if (type == TYPE_INT || type == TYPE_FLOAT) return objects[val_id, "value"] + 0
    if (type == TYPE_STRING) return "\"" json_escape(objects[val_id, "value"]) "\""
    if (type == TYPE_ARRAY) {
        out = "["
        len = objects[val_id, "length"]
        for (i = 0; i < len; i++) {
            if (i > 0) out = out ","
            out = out json_encode(objects[val_id, "element_" i])
        }
        return out "]"
    }
    if (type == TYPE_OBJECT || type == TYPE_STRUCT) {
        out = "{"
        len = objects[val_id, "properties_count"]
        for (i = 1; i <= len; i++) {
            if (i > 1) out = out ","
            out = out "\"" json_escape(objects[val_id, "prop_key_" i]) "\":" json_encode(objects[val_id, "prop_value_" i])
        }
        return out "}"
    }
    error("Cannot JSON-encode a value of type '" type "'")
}

function json_decode(str,   val) {
    JSON_STR = str
    JSON_POS = 1
    val = json_parse_value()
    return val
}

function json_skip_ws() {
    while (JSON_POS <= length(JSON_STR) && substr(JSON_STR, JSON_POS, 1) ~ /[ \t\r\n]/) JSON_POS++
}

function json_peek() {
    return substr(JSON_STR, JSON_POS, 1)
}

function json_parse_value(   c) {
    json_skip_ws()
    c = json_peek()
    if (c == "\"") return create_value(TYPE_STRING, json_parse_raw_string())
    if (c == "[") return json_parse_array_value()
    if (c == "{") return json_parse_object_value()
    if (substr(JSON_STR, JSON_POS, 4) == "true")  { JSON_POS += 4; return create_value(TYPE_BOOL, 1) }
    if (substr(JSON_STR, JSON_POS, 5) == "false") { JSON_POS += 5; return create_value(TYPE_BOOL, 0) }
    if (substr(JSON_STR, JSON_POS, 4) == "null")  { JSON_POS += 4; return create_value(TYPE_NULL, "null") }
    return json_parse_number_value()
}

function json_parse_raw_string(   out, c, hex, code, hex2, low) {
    JSON_POS++
    out = ""
    while (JSON_POS <= length(JSON_STR)) {
        c = substr(JSON_STR, JSON_POS, 1)
        if (c == "\"") { JSON_POS++; break }
        if (c == "\\") {
            JSON_POS++
            if (JSON_POS > length(JSON_STR)) error("json_parse: dangling backslash")
            c = substr(JSON_STR, JSON_POS, 1)
            if (c == "n") out = out "\n"
            else if (c == "t") out = out "\t"
            else if (c == "r") out = out "\r"
            else if (c == "b") out = out sprintf("%c", 8)
            else if (c == "f") out = out sprintf("%c", 12)
            else if (c == "\"" || c == "\\" || c == "/") out = out c
            else if (c == "u") {
                if (JSON_POS + 4 > length(JSON_STR)) error("json_parse: invalid \\u escape")
                hex = substr(JSON_STR, JSON_POS + 1, 4)
                code = hex_to_dec(hex)
                JSON_POS += 4
                # surrogate pair
                if (code >= 55296 && code <= 56319) {
                    if (substr(JSON_STR, JSON_POS + 1, 2) != "\\u")
                        error("json_parse: expected low surrogate")
                    JSON_POS += 2
                    if (JSON_POS + 4 > length(JSON_STR)) error("json_parse: invalid low surrogate")
                    hex2 = substr(JSON_STR, JSON_POS + 1, 4)
                    low = hex_to_dec(hex2)
                    JSON_POS += 4
                    code = 65536 + (code - 55296) * 1024 + (low - 56320)
                }
                out = out utf8_encode(code)
            }
            else error("json_parse: invalid escape \\" c)
            JSON_POS++
        } else {
            out = out c
            JSON_POS++
        }
    }
    return out
}

function json_parse_number_value(   start, s) {
    start = JSON_POS
    while (JSON_POS <= length(JSON_STR) && substr(JSON_STR, JSON_POS, 1) ~ /[-0-9.eE+]/) JSON_POS++
    s = substr(JSON_STR, start, JSON_POS - start)
    if (s ~ /[.eE]/) return create_value(TYPE_FLOAT, s + 0)
    return create_value(TYPE_INT, s + 0)
}

function json_parse_array_value(   elems, count, val) {
    JSON_POS++
    count = 0
    json_skip_ws()
    if (json_peek() == "]") { JSON_POS++; return create_array(elems, 0) }
    while (1) {
        val = json_parse_value()
        count++
        elems[count] = val
        json_skip_ws()
        if (json_peek() == ",") { JSON_POS++; continue }
        break
    }
    json_skip_ws()
    if (json_peek() == "]") JSON_POS++
    return create_array(elems, count)
}

function json_parse_object_value(   keys, vals, count, key) {
    JSON_POS++
    count = 0
    json_skip_ws()
    if (json_peek() == "}") { JSON_POS++; return create_object(keys, vals, 0) }
    while (1) {
        json_skip_ws()
        key = json_parse_raw_string()
        json_skip_ws()
        JSON_POS++ # skip
        count++
        keys[count] = key
        vals[count] = json_parse_value()
        json_skip_ws()
        if (json_peek() == ",") { JSON_POS++; continue }
        break
    }
    json_skip_ws()
    if (json_peek() == "}") JSON_POS++
    return create_object(keys, vals, count)
}
