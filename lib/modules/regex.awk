
function create_regex_module(obj_id, fun_id, methods, i) {
    debug_msg("Creating regex module")
    obj_id = create_object()
    objects[obj_id, "type"] = TYPE_STRUCT
    objects[obj_id, "struct_name"] = "regex"

    methods = "match find replace replace_all split"
    split(methods, funcs, " ")
    objects[obj_id, "properties_count"] = length(funcs)

    for (i = 1; i <= length(funcs); i++) {
        objects[obj_id, "prop_key_" i] = funcs[i]
        fun_id = create_value(TYPE_FUNCTION, "builtin:regex." funcs[i])
        objects[obj_id, "prop_value_" i] = fun_id
    }

    return obj_id
}

# @doc [regex]
# Built-in regex functions
# examples:
# import regex;
# regex.match("hello123", "[0-9]+")             # returns true
# regex.find("hello123", "[0-9]+")              # returns "123"
# regex.replace("hello123", "[0-9]+", "X")      # returns "helloX"
# regex.replace_all("a1b2c3", "[0-9]", "_")     # returns "a_b_c_"
# regex.split("a, b,  c", "[, ]+")              # returns ["a", "b", "c"]
function builtin_regex(func_name, args, argc,   parts, str, pattern, repl, result, out_arr, out_len, i, element_ids) {
    split(func_name, parts, ".")
    str = value_to_string(args[1])

    if (parts[2] == "match") {
        if (argc != 2) error("regex.match expects 2 arguments")
        pattern = value_to_string(args[2])
        return create_value(TYPE_BOOL, match(str, pattern) > 0)
    } else if (parts[2] == "find") {
        if (argc != 2) error("regex.find expects 2 arguments")
        pattern = value_to_string(args[2])
        if (match(str, pattern) > 0) {
            return create_value(TYPE_STRING, substr(str, RSTART, RLENGTH))
        }
        return create_value(TYPE_NULL, "null")
    } else if (parts[2] == "replace") {
        if (argc != 3) error("regex.replace expects 3 arguments")
        pattern = value_to_string(args[2])
        repl = value_to_string(args[3])
        result = str
        sub(pattern, repl, result)
        return create_value(TYPE_STRING, result)
    } else if (parts[2] == "replace_all") {
        if (argc != 3) error("regex.replace_all expects 3 arguments")
        pattern = value_to_string(args[2])
        repl = value_to_string(args[3])
        result = str
        gsub(pattern, repl, result)
        return create_value(TYPE_STRING, result)
    } else if (parts[2] == "split") {
        if (argc != 2) error("regex.split expects 2 arguments")
        pattern = value_to_string(args[2])
        delete out_arr
        out_len = split(str, out_arr, pattern)
        delete element_ids
        for (i = 1; i <= out_len; i++) {
            element_ids[i] = create_value(TYPE_STRING, out_arr[i])
        }
        return create_array(element_ids, out_len)
    }

    error("Unknown regex function: " func_name)
}
