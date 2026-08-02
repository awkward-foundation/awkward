
function create_fs_module(obj_id, fun_id, methods, i) {
    debug_msg("Creating fs module")
    obj_id = create_object()
    objects[obj_id, "type"] = TYPE_STRUCT
    objects[obj_id, "struct_name"] = "fs"

    methods = "exists isfile isdir mkdir remove rmdir rename copy list size"
    split(methods, funcs, " ")
    objects[obj_id, "properties_count"] = length(funcs)

    for (i = 1; i <= length(funcs); i++) {
        objects[obj_id, "prop_key_" i] = funcs[i]
        fun_id = create_value(TYPE_FUNCTION, "builtin:fs." funcs[i])
        objects[obj_id, "prop_value_" i] = fun_id
    }

    return obj_id
}

function builtin_fs(func_name, args, argc,   parts, path, cmd, result, line) {
    split(func_name, parts, ".")
    
    if (parts[2] == "exists") {
        if (argc != 1) error("exists expects 1 argument")
        path = objects[args[1], "value"]
        result = (getline < path)
        close(path)
        return create_value(TYPE_BOOL, result != -1)
    }
    else if (parts[2] == "isfile") {
        if (argc != 1) error("isfile expects 1 argument")
        path = objects[args[1], "value"]
        cmd = "test -f " shell_escape(path) " && echo 1 || echo 0"
        cmd | getline result
        close(cmd)
        return create_value(TYPE_BOOL, result == 1)
    }
    else if (parts[2] == "isdir") {
        if (argc != 1) error("isdir expects 1 argument")
        path = objects[args[1], "value"]
        cmd = "test -d " shell_escape(path) " && echo 1 || echo 0"
        cmd | getline result
        close(cmd)
        return create_value(TYPE_BOOL, result == 1)
    }
    else if (parts[2] == "mkdir") {
        if (argc != 1) error("mkdir expects 1 argument")
        path = objects[args[1], "value"]
        result = system("mkdir -p " shell_escape(path))
        return create_value(TYPE_INT, result)
    }
    else if (parts[2] == "remove") {
        if (argc != 1) error("remove expects 1 argument")
        path = objects[args[1], "value"]
        result = system("rm -f " shell_escape(path))
        return create_value(TYPE_INT, result)
    }
    else if (parts[2] == "rmdir") {
        if (argc != 1) error("rmdir expects 1 argument")
        path = objects[args[1], "value"]
        result = system("rm -rf " shell_escape(path))
        return create_value(TYPE_INT, result)
    }
    else if (parts[2] == "rename") {
        if (argc != 2) error("rename expects 2 arguments")
        old = objects[args[1], "value"]
        new = objects[args[2], "value"]
        result = system("mv " shell_escape(old) " " shell_escape(new))
        return create_value(TYPE_INT, result)
    }
    else if (parts[2] == "copy") {
        if (argc != 2) error("copy expects 2 arguments")
        src = objects[args[1], "value"]
        dst = objects[args[2], "value"]
        result = system("cp " shell_escape(src) " " shell_escape(dst))
        return create_value(TYPE_INT, result)
    }
    else if (parts[2] == "list") {
        if (argc != 1) error("list expects 1 argument")
        path = objects[args[1], "value"]
        cmd = "ls -1 " shell_escape(path)
        arr_id = create_array()
        idx = 0
        while ((cmd | getline line) > 0) {
            element_ids[idx] = create_value(TYPE_STRING, line)
            idx += 1
        }
        close(cmd)
        return create_array(element_ids, idx - 1)
    }
    else if (parts[2] == "size") {
        if (argc != 1) error("size expects 1 argument")
        path = objects[args[1], "value"]
        cmd = "stat -f %z " shell_escape(path) " 2>/dev/null || stat -c %s " shell_escape(path)
        print "CMD: " cmd
        cmd | getline result
        close(cmd)
        return create_value(TYPE_INT, result)
    }
    
    error("Unknown fs function: " func_name)
}
