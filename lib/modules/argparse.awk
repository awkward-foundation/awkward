
function create_argparse_module(obj_id, fun_id, funcs, i) {
    if (debug) debug_msg("Creating argparse module")
    obj_id = create_object()
    objects[obj_id, "type"] = TYPE_STRUCT
    objects[obj_id, "struct_name"] = "argparse"

    argparse_funcs = "parse"
    split(argparse_funcs, funcs, " ")
    objects[obj_id, "properties_count"] = length(funcs)

    for (i = 1; i <= length(funcs); i++) {
        objects[obj_id, "prop_key_" i] = funcs[i]
        fun_id = create_value(TYPE_FUNCTION, "builtin:argparse." funcs[i])
        objects[obj_id, "prop_value_" i] = fun_id
    }

    return obj_id
}

# @doc [argparse]
# Parses the script's own extra command-line arguments into named flags
# --key=value sets a string value
# examples:
# ./awkward script.awkward --name=kek --count=3 --verbose input.txt
# import argparse;
# let opts = argparse.parse();
# print(opts.name, opts.count, opts.verbose, opts._positional);
# # kek 3 true [input.txt]
function builtin_argparse(func_name, args, argc,   parts) {
    split(func_name, parts, ".")
    if (parts[2] == "parse") {
        if (argc != 0) error("argparse.parse expects no arguments")
        return argparse_parse()
    }
    error("Unknown argparse function: " func_name)
}

function argparse_parse(   i, arg, eq, key, val, keys, vals, count, positional, poscount) {
    count = 0
    poscount = 0
    for (i = 1; i <= script_argc; i++) {
        arg = SCRIPT_ARGV[i]
        if (substr(arg, 1, 2) == "--") {
            arg = substr(arg, 3)
            eq = index(arg, "=")
            if (eq > 0) {
                key = substr(arg, 1, eq - 1)
                val = substr(arg, eq + 1)
                count++
                keys[count] = key
                vals[count] = create_value(TYPE_STRING, val)
            } else {
                count++
                keys[count] = arg
                vals[count] = create_value(TYPE_BOOL, 1)
            }
        } else {
            poscount++
            positional[poscount] = create_value(TYPE_STRING, arg)
        }
    }
    count++
    keys[count] = "_positional"
    vals[count] = create_array(positional, poscount)
    return create_object(keys, vals, count)
}
