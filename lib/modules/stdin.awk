
function create_stdin_module(obj_id, fun_id, methods, funcs, i) {
    if (debug) debug_msg("Creating stdin module")
    obj_id = create_object()
    objects[obj_id, "type"] = TYPE_STRUCT
    objects[obj_id, "struct_name"] = "stdin"

    methods = "read_line read_all lines"
    split(methods, funcs, " ")
    objects[obj_id, "properties_count"] = length(funcs)

    for (i = 1; i <= length(funcs); i++) {
        objects[obj_id, "prop_key_" i] = funcs[i]
        fun_id = create_value(TYPE_FUNCTION, "builtin:stdin." funcs[i])
        objects[obj_id, "prop_value_" i] = fun_id
    }

    return obj_id
}

# @doc [stdin]
# Reading real stdin
# examples:
# import stdin;
# let line = stdin.read_line();       # one line, or null at EOF
# let all = stdin.read_all();         # every remaining line, joined with "\n"
# for (let line in stdin.lines()) {   # lazy, one line per next()
#   print(line);
# }
function builtin_stdin(func_name, args, argc,   parts, id) {
    split(func_name, parts, ".")
    if (parts[2] == "read_line") {
        if (argc != 0) error("stdin.read_line expects no arguments")
        return stdin_read_line()
    } else if (parts[2] == "read_all") {
        if (argc != 0) error("stdin.read_all expects no arguments")
        return stdin_read_all()
    } else if (parts[2] == "lines") {
        if (argc != 0) error("stdin.lines expects no arguments")
        id = create_value(TYPE_ITERATOR, "")
        objects[id, "kind"] = "stdin_lines"
        return id
    }
    error("Unknown stdin function: " func_name)
}

function stdin_read_line(   line, ret) {
    ret = (getline line)
    if (ret <= 0) return create_value(TYPE_NULL, "null")
    return create_value(TYPE_STRING, line)
}

function stdin_read_all(   line, out, first) {
    out = ""
    first = 1
    while ((getline line) > 0) {
        out = first ? line : out "\n" line
        first = 0
    }
    return create_value(TYPE_STRING, out)
}
