
function create_system_module(obj_id, fun_id, i) {
    if (debug) debug_msg("Creating system module")
    obj_id = create_object()
    objects[obj_id, "type"] = TYPE_STRUCT
    objects[obj_id, "struct_name"] = "system"

    system_funcs = "user hostname datetime cwd getenv setenv exec args"
    split(system_funcs, funcs, " ")
    objects[obj_id, "properties_count"] = length(funcs)

    for (i = 1; i <= length(funcs); i++) {
        objects[obj_id, "prop_key_" i] = funcs[i]
        fun_id = create_value(TYPE_FUNCTION, "builtin:system." funcs[i])
        objects[obj_id, "prop_value_" i] = fun_id
    }

    return obj_id
}

# @doc [system]
# Built-in system functions.
# examples:
# system.user()  # returns the current system user
# system.getenv("PATH")  # returns the value of the PATH environment variable
# system.setenv("MY_VAR", "my_value")  # sets the MY_VAR environment variable to "my_value"
# system.hostname()  # returns the system hostname
# system.datetime()  # returns the current date and time
# system.cwd()  # returns the current working directory
function builtin_system(func_name, args, argc,   parts, result, arg, arg_type, arg1_type, arg2_type) {
    if (debug) debug_msg("Executing builtin system function " func_name " with " argc " arguments")
    split(func_name, parts, ".")
    if (parts[2] == "user") {
        if (argc != 0) error("system.user expects no arguments")
        result = system_user()
        return create_value(TYPE_STRING, result)
    } else if (parts[2] == "getenv") {
        if (argc != 1) error("system.getenv expects 1 argument")
        var_name = value_to_string(args[1])
        result = system_getenv(var_name)
        return create_value(TYPE_STRING, result)
    } else if (parts[2] == "setenv") {
        if (argc != 2) error("system.getenv expects 2 arguments")
        var_name = value_to_string(args[1])
        var_value = value_to_string(args[2])
        result = system_setenv(var_name, var_value)
        return create_value(TYPE_STRING, result)
    } else if (parts[2] == "hostname") {
        if (argc != 0) error("system.hostname expects no arguments")
        result = system_hostname()
        return create_value(TYPE_STRING, result)
    } else if (parts[2] == "datetime") {
        if (argc != 0) error("system.datetime expects no arguments")
        result = system_datetime()
        return create_value(TYPE_STRING, result)
    } else if (parts[2] == "cwd") {
        if (argc != 0) error("system.cwd expects no arguments")
        result = system_cwd()
        return create_value(TYPE_STRING, result)
    } else if (parts[2] == "exec") {
        if (argc != 1) error("system.exec expects 1 argument")
        result = system_exec(value_to_string(args[1]))
        return create_value(TYPE_STRING, result)
    } else if (parts[2] == "args") {
        if (argc != 0) error("system.args expects no arguments")
        return system_args()
    }
    error("Unknown system function: " func_name)
}

# SYSTEM HELPERS

function system_user() {
    return ENVIRON["USER"]
}

function system_getenv(var) {
    return ENVIRON[var]
}

function system_setenv(var, value) {
    ENVIRON[var] = value
}

function system_unsetenv(var) {
    delete ENVIRON[var]
}

function system_hostname(cmd, host) {
    cmd = "hostname"
    host = ""
    while ((cmd | getline line) > 0) {
        host = host line
    }
    close(cmd)
    return host
}

function system_datetime() {
    "date +%Y-%m-%d\\ %H:%M:%S" | getline now
    close("date +%Y-%m-%d\\ %H:%M:%S")
    return now
}

function system_cwd(cmd, cwd) {
    cmd = "pwd"
    cwd = ""
    while ((cmd | getline line) > 0) {
        cwd = cwd line
    }
    close(cmd)
    return cwd
}

function system_exec(cmd,   line, out, first) {
    out = ""
    first = 1
    while ((cmd | getline line) > 0) {
        out = first ? line : out "\n" line
        first = 0
    }
    close(cmd)
    return out
}

function system_args(   i, elems) {
    for (i = 1; i <= script_argc; i++) {
        elems[i] = create_value(TYPE_STRING, SCRIPT_ARGV[i])
    }
    return create_array(elems, script_argc)
}
