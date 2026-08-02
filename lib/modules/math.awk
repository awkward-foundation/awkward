
function create_math_module(obj_id, fun_id, i) {
    debug_msg("Creating math module")
    obj_id = create_object()
    objects[obj_id, "type"] = TYPE_STRUCT
    objects[obj_id, "struct_name"] = "math"

    math_funcs = "sin cos tan abs sqrt asin acos atan pow"
    split(math_funcs, funcs, " ")
    objects[obj_id, "properties_count"] = length(funcs)

    for (i = 1; i <= length(funcs); i++) {
        objects[obj_id, "prop_key_" i] = funcs[i]
        fun_id = create_value(TYPE_FUNCTION, "builtin:math." funcs[i])
        objects[obj_id, "prop_value_" i] = fun_id
    }

    return obj_id
}

function call_math(func_name, arg, arg2,    result) {
    debug_msg("call_math received func_name: '" func_name "' arg: " arg)
    if (func_name == "sin") {
        result = sin(arg)
    } else if (func_name == "cos") {
        result = cos(arg)
    } else if (func_name == "tan") {
        result = math_tan(arg)
    } else if (func_name == "sqrt") {
        result = sqrt(arg)
    } else if (func_name == "abs") {
        result = (arg < 0 ? -arg : arg)
    } else if (func_name == "asin") {
        result = math_asin(arg)
    } else if (func_name == "acos") {
        result = math_acos(arg)
    } else if (func_name == "atan") {
        result = math_atan(arg)
    } else if (func_name == "pow") {
        result = math_pow(arg, arg2)        
    } else {
        error("Unknown math function: " func_name)
    }
    return result
}

# @doc [math]
# Built-in math functions.
# examples:
# math.sin(x)  # returns the sine of x (x in radians)
# math.cos(x)  # returns the cosine of x (x in radians)
function builtin_math(func_name, args, argc,   parts, result, arg, arg_type, arg1_type, arg2_type) {
    debug_msg("Executing builtin math function " func_name " with " argc " arguments")
    split(func_name, parts, ".")
    if (parts[2] == "pow") {
        if (argc != 2) error("math.pow expects 2 arguments")
        arg1_type = objects[args[1], "type"]
        arg2_type = objects[args[2], "type"]
        if ((arg1_type != TYPE_INT && arg1_type != TYPE_FLOAT) ||
            (arg2_type != TYPE_INT && arg2_type != TYPE_FLOAT)) {
            error("math.pow expects numeric arguments")
        }
        result = call_math("pow", objects[args[1], "value"], objects[args[2], "value"])
        debug_msg("Calling math.pow with arguments " objects[args[1], "value"] ", " objects[args[2], "value"] " result " result)
        return create_value(TYPE_FLOAT, result)
    }

    if (argc != 1) error(func_name " expects 1 argument")
    arg = args[1]
    arg_type = objects[arg, "type"]
    if (arg_type != TYPE_INT && arg_type != TYPE_FLOAT) {
        error(func_name " expects numeric argument")
    }
    result = call_math(parts[2], objects[arg, "value"])
    debug_msg("Calling math function " func_name " with argument type " arg_type " value " objects[arg, "value"] " result " result)
    return create_value(TYPE_FLOAT, result)
}

# MATH HELPERS

function math_tan(x) {
    return sin(x) / cos(x)
}

function math_asin(x) {
    if (x < -1 || x > 1) {
        error("asin argument out of range")
    }
    return atan2(x, sqrt(1 - x*x))
}

function math_acos(x) {
    if (x < -1) x = -1
    if (x > 1) x = 1
    
    return atan2(sqrt(1 - x*x), x)
}

function math_atan(x) {
    return atan2(x, 1)
}

function math_pow(x, y) {
    return x^y
}
