
BEGIN {
    for (i = 1; i < ARGC; i++) {
        if (ARGV[i] == "--debug") {
            debug = 1
            ARGV[i] = ""
        }
    }

    init_interpreter()

    if (ARGC > 1) {
        program_file = ARGV[1]
        ARGV[1] = ""
        execute_program(program_file)
        exit(0)
    } else {
        exit(0)
    }
}

function debug_msg(msg) {
    if (debug) {
        print "DEBUG: " msg > "/dev/stderr"
    }
}

function init_interpreter() {
    VERSION = "0.1.2"

    debug_msg("Initializing awkward interpreter version " VERSION)

    call_stack_size = 0
    gc_protect_id = ""

    ast_node_counter = 0

    scope_counter = 0
    global_scope_id = ++scope_counter
    scopes[global_scope_id, "parent"] = 0
    scopes[global_scope_id, "variables_count"] = 0
    current_scope_id = global_scope_id

    object_counter = 0
    gc_threshold = 10000

    init_error_handling()

    return_value_set = 0
    break_flag = 0
    continue_flag = 0

    DEBUG_LEVEL = 1

    TYPE_NULL = "null"
    TYPE_BOOL = "bool"
    TYPE_INT = "int"
    TYPE_FLOAT = "float"
    TYPE_STRING = "string"
    TYPE_ARRAY = "array"
    TYPE_OBJECT = "object"
    TYPE_FUNCTION = "fn"
    TYPE_STRUCT = "struct"
    TYPE_ENUM = "enum"

    BUILTIN_MODULES["math"] = 1
    BUILTIN_MODULES["system"] = 1
    BUILTIN_MODULES["io"] = 1
    BUILTIN_MODULES["fs"] = 1
    BUILTIN_MODULES["http"] = 1
    BUILTIN_MODULES["regex"] = 1
    BUILTIN_MODULES["kek"] = 1
    BUILTIN_MODULES["mysql"] = 1

    http_request_counter = 0

    STRING_METHODS["upper"] = "string.upper"
    STRING_METHODS["lower"] = "string.lower"
    STRING_METHODS["len"]   = "string.len"

    ARRAY_METHODS["append"] = "array.append"
    ARRAY_METHODS["extend"] = "array.extend"
    ARRAY_METHODS["len"]   = "array.len"

    FUNCTION_METHODS["name"]   = "function.name"
    FUNCTION_METHODS["call"]   = "function.call"

    init_operators()

    init_builtins()
    init_builtin_methods()
}

function tokenize(code,   token_count, pos, token_found, current_char, substr_code, type, token_value) {
    debug_msg("Starting tokenization of code with length " length(code))
    delete tokens
    token_count = 0

    patterns["NUMBER"] = "^[0-9]+\\.?[0-9]*"
    patterns["STRING"] = "^\"([^\"\\\\]|\\\\.)*\""
    patterns["IDENTIFIER"] = "^[a-zA-Z_][a-zA-Z0-9_]*"
    patterns["OPERATOR"] = "^(\\+\\+|--|\\+=|-=|\\*=|/=|==|!=|<=|>=|&&|\\|\\||\\+|-|\\*|/|%|<|>|=|!|:)"
    patterns["DELIMITER"] = "^[{}\\[\\]();,.]"
    patterns["KEYWORD"] = "^(let|if|else|while|for|fn|struct|return|break|continue|try|catch|finally|import|null|true|false|in|new|impl|from|lambda|pipe|enum)([^a-zA-Z0-9_]|$)"
    patterns["COMMENT_HASH"] = "^#[^\n]*"

    pos = 1
    while (pos <= length(code)) {
        while (pos <= length(code) && match(substr(code, pos, 1), /[ \t\n\r]/)) {
            pos++
        }

        if (pos > length(code)) break

        token_found = 0
        current_char = substr(code, pos, 1)
        substr_code = substr(code, pos)

        if (match(substr_code, patterns["COMMENT_HASH"])) {
            type = "COMMENT"
            token_value = substr(substr_code, 1, RLENGTH)
            debug_msg("Found comment: " token_value)
            pos += RLENGTH
            token_found = 1
            continue
        } else if (match(substr_code, patterns["KEYWORD"])) {
            type = "KEYWORD"
            token_value = substr(substr_code, 1, RLENGTH)
            match(token_value, /^[a-zA-Z_]+/)
            token_value = substr(token_value, 1, RLENGTH)
            tokens[++token_count] = type ":" token_value
            pos += RLENGTH
            token_found = 1
        } else if (match(substr_code, patterns["IDENTIFIER"])) {
            type = "IDENTIFIER"
            token_value = substr(substr_code, 1, RLENGTH)
            tokens[++token_count] = type ":" token_value
            pos += RLENGTH
            token_found = 1
        } else if (match(substr_code, patterns["NUMBER"])) {
            type = "NUMBER"
            token_value = substr(substr_code, 1, RLENGTH)
            tokens[++token_count] = type ":" token_value
            pos += RLENGTH
            token_found = 1
        } else if (match(substr_code, patterns["STRING"])) {
            type = "STRING"
            token_value = substr(substr_code, 1, RLENGTH)
            tokens[++token_count] = type ":" token_value
            pos += RLENGTH
            token_found = 1
        } else if (match(substr_code, patterns["OPERATOR"])) {
            type = "OPERATOR"
            token_value = substr(substr_code, 1, RLENGTH)
            tokens[++token_count] = type ":" token_value
            pos += RLENGTH
            token_found = 1
        } else if (match(substr_code, patterns["DELIMITER"])) {
            type = "DELIMITER"
            token_value = substr(substr_code, 1, RLENGTH)
            tokens[++token_count] = type ":" token_value
            pos += RLENGTH
            token_found = 1
        }

        if (!token_found) {
            error("Unknown symbol: " current_char " at position " pos)
        }
    }

    debug_msg("Tokenization complete, found " token_count " tokens")
    if (debug) {
        for (token in tokens) {
            if (debug) debug_msg(token " token= " tokens[token])
        }
    }

    return token_count
}

function unescape_string(s,    out, i, n, c, next_c) {
    out = ""
    n = length(s)
    i = 1
    while (i <= n) {
        c = substr(s, i, 1)
        if (c == "\\" && i < n) {
            next_c = substr(s, i + 1, 1)
            if (next_c == "n") out = out "\n"
            else if (next_c == "t") out = out "\t"
            else if (next_c == "r") out = out "\r"
            else if (next_c == "\\") out = out "\\"
            else if (next_c == "\"") out = out "\""
            else if (next_c == "0") out = out sprintf("%c", 0)
            else out = out c next_c
            i += 2
        } else {
            out = out c
            i++
        }
    }
    return out
}

function parse(tokens_array, token_cnt,   prog_node) {
    debug_msg("Starting parsing with " token_cnt " tokens")
    delete ast_nodes
    current_token = 1
    total_tokens = token_cnt

    prog_node = parse_program(dir_path)
    debug_msg("Parsing complete, AST node count: " ast_node_counter)
    return prog_node
}

function parse_program(dir_path,   prog_node, stmt_node) {
    debug_msg("Parsing program")
    prog_node = ++ast_node_counter
    ast_nodes[prog_node, "type"] = "Program"
    ast_nodes[prog_node, "dir_path"] = dir_path
    ast_nodes[prog_node, "body_count"] = 0

    while (current_token <= total_tokens) {
        stmt_node = parse_statement()
        if (stmt_node != "") {
            ast_nodes[prog_node, "body_" ++ast_nodes[prog_node, "body_count"]] = stmt_node
            debug_msg("Added to program body: node " stmt_node " of type " ast_nodes[stmt_node, "type"] (ast_nodes[stmt_node, "name"] ? " name " ast_nodes[stmt_node, "name"] : ""))
        }
    }

    return prog_node
}

function parse_statement(   token, token_parts, token_type, token_value) {
    debug_msg("Parsing statement")
    if (current_token > total_tokens) return ""

    token = tokens[current_token]
    split(token, token_parts, ":")
    token_type = token_parts[1]
    token_value = token_parts[2]

    debug_msg("Parsing token=(" token_value ", " token_type ")")

    if (token_type == "DELIMITER" && token_value == ";") {
        advance_token()
        return ""
    } else if (token_type == "KEYWORD") {
        if (token_value == "let") {
            return parse_variable_declaration()
        } else if (token_value == "if") {
            return parse_if_statement()
        } else if (token_value == "while") {
            return parse_while_statement()
        } else if (token_value == "for") {
            return parse_for_statement()
        } else if (token_value == "fn") {
            return parse_function_declaration()
        } else if (token_value == "struct") {
            return parse_struct_declaration()
        } else if (token_value == "impl") {
            return parse_impl_declaration()
        } else if (token_value == "return") {
            return parse_return_statement()
        } else if (token_value == "break") {
            return parse_break_statement()
        } else if (token_value == "continue") {
            return parse_continue_statement()
        } else if (token_value == "try") {
            return parse_try_statement()
        } else if (token_value == "lambda") {
            return parse_lambda_declaration()
        } else if (token_value == "pipe") {
            return parse_pipe_declaration()
        } else if (token_value == "enum") {
            return parse_enum_declaration()
        }
    }
    return parse_expression_statement()
}

# @doc [pipes]
# Pipe expression `pipe` chaining two or more expressions
# examples:
# let mult = lambda x: x * 2;
# let x = 5
#   pipe mult
#   pipe print;
function parse_pipe_declaration(   left, right, pipe_node) {
    debug_msg("Parsing pipe expression")
    left = parse_logical_or()

    while (get_token_type() == "KEYWORD" && get_token_value() == "pipe") {
        debug_msg("Found pipe keyword")
        advance_token()

        right = parse_logical_or()

        pipe_node = ++ast_node_counter
        ast_nodes[pipe_node, "type"] = "PipeExpression"
        ast_nodes[pipe_node, "left"] = left
        ast_nodes[pipe_node, "right"] = right

        left = pipe_node
    }

    return left
}

function execute_pipe(node_id,   left_value, right_node, right_type, func_id, args, result, i, argc, callee_node, parts) {
    debug_msg("Executing pipe expression")

    left_value = execute(ast_nodes[node_id, "left"])
    debug_msg("Pipe left value: " left_value)

    right_node = ast_nodes[node_id, "right"]
    right_type = ast_nodes[right_node, "type"]

    if (right_type == "Identifier") {
        func_id = execute(right_node)
        delete args
        args[1] = left_value

        if (objects[func_id, "value"] ~ /^lambda:/) {
            return call_lambda(func_id, args, 1)
        } else if (objects[func_id, "value"] ~ /^builtin:/) {
            split(objects[func_id, "value"], parts, ":")
            return call_builtin(parts[2], args, 1)
        } else {
            return call_function(func_id, args, 1)
        }

    } else if (right_type == "CallExpression") {
        callee_node = ast_nodes[right_node, "callee_node"]
        func_id = execute(callee_node)

        argc = ast_nodes[right_node, "args_count"]
        delete args
        args[1] = left_value

        for (i = 1; i <= argc; i++) {
            args[i + 1] = execute(ast_nodes[right_node, "arg_" i])
        }

        if (objects[func_id, "value"] ~ /^lambda:/) {
            return call_lambda(func_id, args, argc + 1)
        } else if (objects[func_id, "value"] ~ /^builtin:/) {
            split(objects[func_id, "value"], parts, ":")
            return call_builtin(parts[2], args, argc + 1)
        } else {
            return call_function(func_id, args, argc + 1)
        }
    } else if (right_type == "LambdaExpression") {
        func_id = execute(right_node)
        delete args
        args[1] = left_value
        return call_lambda(func_id, args, 1)
    }

    error("Invalid pipe right side: " right_type)
}

# @doc [functions]
# Lambda (anonymous) function declaration.
# examples:
# let f = lambda (x, y): x + y;
# let g = lambda z: z * 2;
function parse_lambda_declaration(   lambda_node) {
    lambda_node = ++ast_node_counter
    ast_nodes[lambda_node, "type"] = "FunctionExpression"
    ast_nodes[lambda_node, "params_count"] = 0
    ast_nodes[lambda_node, "is_lambda"] = 1

    expect_token("KEYWORD", "lambda")

    if (get_token_value() == "(") {
        advance_token()
        while (get_token_value() != ")") {
            if (get_token_type() == "IDENTIFIER") {
                ast_nodes[lambda_node, "param_" ++ast_nodes[lambda_node, "params_count"]] = get_token_value()
                advance_token()
                if (get_token_value() == ",") advance_token()
            } else {
                error("Expected identifier in lambda parameters")
            }
        }
        advance_token()
    } else if (get_token_type() == "IDENTIFIER") {
        ast_nodes[lambda_node, "param_" ++ast_nodes[lambda_node, "params_count"]] = get_token_value()
        advance_token()
    }

    expect_token("OPERATOR", ":")

    ast_nodes[lambda_node, "body"] = parse_expression()

    return lambda_node
}

function execute_lambda(node_id,   lambda_id, param_count, i) {
    debug_msg("execute_lambda called with node=" node_id)

    if (node_id == "" || node_id == 0) {
        error("execute_lambda: node is empty!")
    }

    debug_msg("Creating lambda function from node " node_id)
    
    param_count = ast_nodes[node_id, "param_count"]
    debug_msg("Lambda has " param_count " parameters")

    lambda_id = create_value(TYPE_FUNCTION, "lambda:" node_id)
    objects[lambda_id, "param_count"] = param_count
    for (i = 0; i < param_count; i++) {
        objects[lambda_id, "param_" i] = ast_nodes[node_id, "param_" i]
        debug_msg("Lambda param " i " = " ast_nodes[node_id, "param_" i])
    }

    objects[lambda_id, "body"] = ast_nodes[node_id, "body"]
    debug_msg("Lambda body node: " ast_nodes[node_id, "body"])

    objects[lambda_id, "closure_scope"] = current_scope_id
    debug_msg("Lambda closure scope: " current_scope_id)
    debug_msg("Created lambda id=" lambda_id " with " param_count " parameters")

    return lambda_id
}

# @doc [enums]
# Parses an enum declaration and its variants.
# examples:
# enum Color {
#   Red,
#   Green,
#   Blue
# };
# let color = Color.Red;
# print(color == Color.Red);    # true
function parse_enum_declaration(   enum_node, variant_name) {
    debug_msg("Parsing enum declaration")
    enum_node = ++ast_node_counter
    ast_nodes[enum_node, "type"] = "EnumDeclaration"
    advance_token()

    if (get_token_type() != "IDENTIFIER") {
        error("Expected enum name")
    }
    ast_nodes[enum_node, "name"] = get_token_value()
    advance_token()

    expect_token("DELIMITER", "{")

    ast_nodes[enum_node, "variants_count"] = 0
    while (get_token_value() != "}") {
        if (get_token_type() == "IDENTIFIER") {
            variant_name = get_token_value()
            ast_nodes[enum_node, "variant_" ast_nodes[enum_node, "variants_count"]] = variant_name
            ast_nodes[enum_node, "variants_count"]++
            advance_token()
            
            if (get_token_value() == ",") {
                advance_token()
            }
        } else {
            error("Expected variant name in enum")
        }
    }

    expect_token("DELIMITER", "}")
    return enum_node
}

function execute_enum_declaration(enum_node,   enum_name, enum_id, i, variant_name, variant_id) {
    debug_msg("Executing enum declaration for " ast_nodes[enum_node, "name"])

    enum_name = ast_nodes[enum_node, "name"]
    enum_id = create_enum(enum_node)

    declare_variable(enum_name, enum_id)

    for (i = 0; i < ast_nodes[enum_node, "variants_count"]; i++) {
        variant_name = ast_nodes[enum_node, "variant_" i]

        variant_id = create_enum_variant(enum_name, variant_name, i)

        objects[enum_id, "prop_key_" (i + 1)] = variant_name
        objects[enum_id, "prop_value_" (i + 1)] = variant_id
    }
    objects[enum_id, "properties_count"] = ast_nodes[enum_node, "variants_count"]

    return create_value(TYPE_NULL, "null", 0)
}

function create_enum(enum_def_id,   enum_id) {
    debug_msg("Creating enum from definition node " enum_def_id)
    enum_id = ++object_counter
    objects[enum_id, "type"] = TYPE_OBJECT
    objects[enum_id, "enum_name"] = ast_nodes[enum_def_id, "name"]
    objects[enum_id, "definition"] = enum_def_id
    objects[enum_id, "properties_count"] = 0
    register_object(enum_id)
    debug_msg("Created enum " objects[enum_id, "enum_name"] " with id " enum_id)
    return enum_id
}

function create_enum_variant(enum_name, variant_name, index_,   variant_id) {
    debug_msg("Creating enum variant " enum_name "." variant_name " = " index_)
    variant_id = ++object_counter
    objects[variant_id, "type"] = TYPE_ENUM
    objects[variant_id, "enum_name"] = enum_name
    objects[variant_id, "variant_name"] = variant_name
    objects[variant_id, "value"] = index_
    register_object(variant_id)
    debug_msg("Created enum variant " enum_name "." variant_name " = " index_)
    return variant_id
}

function parse_struct_declaration(   struct_node, member_name, property_node) {
    debug_msg("Parsing struct declaration")
    struct_node = ++ast_node_counter
    ast_nodes[struct_node, "type"] = "StructDeclaration"
    advance_token()

    if (get_token_type() != "IDENTIFIER") {
        error("Expected struct name")
    }
    ast_nodes[struct_node, "name"] = get_token_value()
    advance_token()

    expect_token("DELIMITER", "{")

    ast_nodes[struct_node, "properties_count"] = 0
    while (get_token_value() != "}") {
        if (get_token_type() == "IDENTIFIER") {
            member_name = get_token_value()
            advance_token()
            expect_token("DELIMITER", ";")
            property_node = ++ast_node_counter
            ast_nodes[property_node, "type"] = "PropertyDefinition"
            ast_nodes[property_node, "name"] = member_name
            ast_nodes[struct_node, "property_" ++ast_nodes[struct_node, "properties_count"]] = property_node
        } else {
            error("Expected identifier in struct declaration")
        }
    }

    expect_token("DELIMITER", "}")
    return struct_node
}

function execute_struct_declaration(struct_node,   struct_name, struct_id) {
    debug_msg("Executing struct declaration for " ast_nodes[struct_node, "name"])
    struct_name = ast_nodes[struct_node, "name"]
    struct_id = create_struct(struct_node)
    declare_variable(struct_name, struct_id)
    return create_value(TYPE_STRUCT, struct_id)
}

# @doc [structs]
# Creates a struct object from its definition node.
# examples:
# struct Point {
#   x;
#   y;
# };
# let p = new Point{x=10, y=20};
# print(p.x);  # prints 10
function create_struct(struct_def_id,   struct_id) {
    debug_msg("Creating struct from definition node " struct_def_id)
    struct_id = ++object_counter
    objects[struct_id, "type"] = TYPE_STRUCT
    objects[struct_id, "struct_name"] = ast_nodes[struct_def_id, "name"]
    objects[struct_id, "definition"] = struct_def_id
    objects[struct_id, "methods_count"] = 0
    register_object(struct_id)
    debug_msg("Created struct " objects[struct_id, "struct_name"] " with id " struct_id)
    return struct_id
}

# @doc [structs]
# Implement block for a struct.
# examples:
# impl Point {
#   fn move(dx, dy) {
#     self.x = self.x + dx;
#     self.y = self.y + dy;
#   }
# }; # This adds the move method to the Point struct.
function parse_impl_declaration(   impl_node, struct_name, method_node) {
    debug_msg("Parsing impl declaration")
    impl_node = ++ast_node_counter
    ast_nodes[impl_node, "type"] = "ImplDeclaration"
    advance_token()

    if (get_token_type() != "IDENTIFIER") {
        error("Expected struct name after 'impl'")
    }
    struct_name = get_token_value()
    ast_nodes[impl_node, "struct_name"] = struct_name
    advance_token()

    expect_token("DELIMITER", "{")
    ast_nodes[impl_node, "methods_count"] = 0
    while (get_token_value() != "}") {
        if (get_token_type() == "KEYWORD" && get_token_value() == "fn") {
            method_node = parse_function_declaration()
            ast_nodes[impl_node, "method_" ++ast_nodes[impl_node, "methods_count"]] = method_node
            debug_msg("Added method " ast_nodes[method_node, "name"] " to impl for " struct_name)
        } else {
            error("Expected function declaration in impl block")
        }
    }
    expect_token("DELIMITER", "}")
    return impl_node
}

function execute_impl_declaration(impl_node,   struct_name, struct_id, i, method_node, method_id, existing_count, new_index, method_name, j) {
    debug_msg("Executing impl declaration for " ast_nodes[impl_node, "struct_name"])
    struct_name = ast_nodes[impl_node, "struct_name"]
    struct_id = get_variable(struct_name)

    if (objects[struct_id, "type"] != TYPE_STRUCT) {
        error("Impl target " struct_name " is not a struct")
    }

    existing_count = objects[struct_id, "methods_count"]
    if (existing_count == "") existing_count = 0

    for (i = 1; i <= ast_nodes[impl_node, "methods_count"]; i++) {
        method_node = ast_nodes[impl_node, "method_" i]
        method_name = ast_nodes[method_node, "name"]

        for (j = 1; j <= existing_count; j++) {
            if (objects[struct_id, "method_name_" j] == method_name) {
                error("Method " method_name " already defined for struct " struct_name)
            }
        }

        new_index = existing_count + i
        method_id = create_closure(method_node, current_scope_id)
        objects[struct_id, "method_" new_index] = method_id
        objects[struct_id, "method_name_" new_index] = method_name
        debug_msg("Added method " method_name " to struct " struct_name)
    }

    objects[struct_id, "methods_count"] = existing_count + ast_nodes[impl_node, "methods_count"]
    return create_value(TYPE_NULL, "null", 0)
}

# @doc [control_flow]
# Break statement.
# examples:
# for (let i = 0; i < 10; i = i + 1) {
#   if (i == 5) {
#     break;
#   }
#   print(i);
# }
function parse_break_statement(   break_node) {
    debug_msg("Parsing break statement")
    break_node = ++ast_node_counter
    ast_nodes[break_node, "type"] = "BreakStatement"
    advance_token()
    expect_token("DELIMITER", ";")
    return break_node
}

function execute_break_statement(break_node) {
    debug_msg("Executing break statement")
    break_flag = 1
    return create_value(TYPE_NULL, "null", 0)
}

# @doc [control_flow]
# Continue statement.
# examples:
# for (let i = 0; i < 10; i = i + 1) {
#   if (i % 2 == 0) {
#     continue;
#   }
#   print(i);
# }
function parse_continue_statement(   continue_node) {
    debug_msg("Parsing continue statement")
    continue_node = ++ast_node_counter
    ast_nodes[continue_node, "type"] = "ContinueStatement"
    advance_token()
    expect_token("DELIMITER", ";")
    return continue_node
}

function execute_continue_statement(continue_node) {
    debug_msg("Executing continue statement")
    continue_flag = 1
    return create_value(TYPE_NULL, "null", 0)
}

# @doc [variables]
# Variable declaration, optionally with an initializer.
# examples:
# let x;
# let y = 42;
# const pi = 3.14;
function parse_variable_declaration(   var_node) {
    debug_msg("Parsing variable declaration")
    var_node = ++ast_node_counter
    ast_nodes[var_node, "type"] = "VariableDeclaration"

    ast_nodes[var_node, "kind"] = get_token_value()
    advance_token()

    if (get_token_type() != "IDENTIFIER") {
        error("Expected variable name")
    }
    ast_nodes[var_node, "id"] = get_token_value()
    advance_token()

    if (get_token_value() == "=") {
        advance_token()
        ast_nodes[var_node, "init"] = parse_expression()
    }

    expect_token("DELIMITER", ";")
    return var_node
}

function execute_variable_declaration(var_node,   var_name, init_id, result_id) {
    debug_msg("Executing variable declaration for " ast_nodes[var_node, "id"])
    var_name = ast_nodes[var_node, "id"]
    init_id = ast_nodes[var_node, "init"]

    debug_msg("Variable " var_name " will be declared with init_id " init_id)

    if (init_id != "") {
        result_id = execute(init_id)
    } else {
        result_id = create_value(TYPE_NULL, "null", 0)
    }

    declare_variable(var_name, result_id)

    return result_id
}

function declare_variable(name, value, scope,   key) {
    if (scope == "") scope = current_scope_id

    debug_msg("Declaring variable " name " in scope " scope " with value " value)

    key = "var_" name
    if ((scope, key) in scopes) {
        error("Redeclaration of variable " name " in scope " scope)
    }
    scopes[scope, key] = value
    scopes[scope, "variables_count"]++

    debug_msg("Declared variable " name " in scope " scope ", check: scopes[" scope "," key "] = " scopes[scope, key])
}

function update_variable(name, value,   scope_id, key) {
    scope_id = current_scope_id
    key = "var_" name
    debug_msg("Updating variable " name " starting from scope " scope_id)
    while (scope_id != 0) {
        if ((scope_id, key) in scopes) {
            scopes[scope_id, key] = value
            debug_msg("Updated variable " name " in scope " scope_id)
            return
        }
        scope_id = scopes[scope_id, "parent"]
    }
    error("Assignment to undeclared variable " name)
}

function get_variable(name,   scope_id, key) {
    key = "var_" name
    scope_id = current_scope_id
    while (scope_id != 0) {
        if ((scope_id, key) in scopes) {
            return scopes[scope_id, key]
        }
        scope_id = scopes[scope_id, "parent"]
    }
    error("Variable not found: " name)
}

function parse_expression(   expr) {
    expr = parse_assignment()
    return expr
}

# @doc [expressions]
# Assignment expression, including the compound forms '+=', '-=', '*=', '/='.
# The left-hand side must be an identifier or member expression.
# examples:
# x = 42;
# obj.field = "hello";
# arr[0] = 100;
# x += 1;
# total -= discount;
function parse_assignment(   assign_left, assign_right, assign_node, op, bin_op, bin_node) {
    debug_msg("Parsing assignment")
    assign_left = parse_pipe_declaration()

    op = get_token_value()
    if (op == "=" || op == "+=" || op == "-=" || op == "*=" || op == "/=") {
        if (ast_nodes[assign_left, "type"] != "Identifier" && ast_nodes[assign_left, "type"] != "MemberExpression") {
            error("Left side of assignment must be an identifier or member expression at position " current_token)
        }

        advance_token()
        assign_right = parse_assignment()

        if (op != "=") {
            bin_op = substr(op, 1, 1)
            bin_node = ++ast_node_counter
            ast_nodes[bin_node, "type"] = "BinaryExpression"
            ast_nodes[bin_node, "operator"] = bin_op
            ast_nodes[bin_node, "left"] = assign_left
            ast_nodes[bin_node, "right"] = assign_right
            assign_right = bin_node
        }

        assign_node = ++ast_node_counter
        ast_nodes[assign_node, "type"] = "AssignmentExpression"
        ast_nodes[assign_node, "left"] = assign_left
        ast_nodes[assign_node, "right"] = assign_right
        return assign_node
    }

    return assign_left
}

function execute(node_id,   node_type) {
    if (!node_id) return create_value(TYPE_NULL, "null", 0)
    node_type = ast_nodes[node_id, "type"]
    debug_msg("Executing node " node_id " of type " node_type)

    if (node_type == "Identifier") {
        return get_variable(ast_nodes[node_id, "name"])
    } else if (node_type == "BinaryExpression") {
        return execute_binary_expression(node_id)
    } else if (node_type == "UnaryExpression") {
        return execute_unary_expression(node_id)
    } else if (node_type == "Literal") {
        return create_value(ast_nodes[node_id, "value_type"], ast_nodes[node_id, "value"])
    } else if (node_type == "CallExpression") {
        return execute_function_call(node_id)
    } else if (node_type == "ExpressionStatement") {
        return execute(ast_nodes[node_id, "expression"])
    } else if (node_type == "ReturnStatement") {
        return execute_return_statement(node_id)
    } else if (node_type == "IfStatement") {
        return execute_if_statement(node_id)
    } else if (node_type == "BlockStatement") {
        return execute_block_statement(node_id)
    } else if (node_type == "AssignmentExpression") {
        return execute_assignment(node_id)
    } else if (node_type == "MemberExpression") {
        return execute_member_expression(node_id)
    } else if (node_type == "VariableDeclaration") {
        return execute_variable_declaration(node_id)
    } else if (node_type == "WhileStatement") {
        return execute_while_statement(node_id)
    } else if (node_type == "ForInStatement") {
        return execute_for_in_statement(node_id)
    } else if (node_type == "ArrayExpression") {
        return execute_array_expression(node_id)
    } else if (node_type == "ObjectExpression") {
        return execute_object_expression(node_id)
    } else if (node_type == "BreakStatement") {
        return execute_break_statement(node_id)
    } else if (node_type == "ContinueStatement") {
        return execute_continue_statement(node_id)
    } else if (node_type == "TryStatement") {
        return execute_try_statement(node_id)
    } else if (node_type == "LambdaExpression") {
        return execute_lambda(node_id)
    } else if (node_type == "PipeExpression") {
        return execute_pipe(node_id)
    } else if (node_type == "FunctionDeclaration") {
        return execute_function_declaration(node_id)
    } else if (node_type == "StructDeclaration") {
        return execute_struct_declaration(node_id)
    } else if (node_type == "ImplDeclaration") {
        return execute_impl_declaration(node_id)
    } else if (node_type == "EnumDeclaration") {
        return execute_enum_declaration(node_id)
    } else if (node_type == "ImportDeclaration") {
        return execute_import_declaration(node_id)
    } else if (node_type == "Program") {
        return execute_program_node(node_id)
    }
    error("Unknown node type: " node_type)
}

function execute_member_expression(member_node,   obj_val_id, prop_val_id, type, method_id, property_name, prop_type) {
    debug_msg("Executing member expression")

    obj_val_id = execute(ast_nodes[member_node, "object"])

    if (ast_nodes[member_node, "computed"]) {
        prop_val_id = execute(ast_nodes[member_node, "property"])
    } else {
        prop_val_id = create_value(TYPE_STRING, ast_nodes[ast_nodes[member_node, "property"], "name"])
    }

    debug_msg("Object value id: " obj_val_id " of type " objects[obj_val_id, "type"] " value " objects[obj_val_id, "value"])

    type = objects[obj_val_id, "type"]
    prop_type = objects[prop_val_id, "type"]

    if (prop_type == TYPE_STRING) {
        property_name = objects[prop_val_id, "value"]
        method_id = try_get_builtin_method(obj_val_id, property_name)
        if (method_id != "") {
            return method_id
        }
    }

    if (is_indexable(type)) {
        if (prop_type == TYPE_INT) {
            return get_indexed_value(obj_val_id, prop_val_id)
        } else {
            error("Property not found: " objects[prop_val_id, "value"] " (arrays/strings only support numeric indexing)")
        }
    }

    if (type == TYPE_OBJECT || type == TYPE_STRUCT) {
        property_name = value_to_string(prop_val_id)
        result = get_object_property(obj_val_id, property_name)
        debug_msg("Got property '" property_name "': value_id=" result " type=" objects[result, "type"])
        return result
    }

    error("Cannot access member on type: " type)
}

function execute_array_expression(array_node,   elem_count, i, elem_id, element_ids, array_id) {
    debug_msg("Executing array expression")
    elem_count = ast_nodes[array_node, "elements_count"]
    for (i = 1; i <= elem_count; i++) {
        elem_id = ast_nodes[array_node, "element_" i]
        element_ids[i] = execute(elem_id)
    }
    array_id = create_array(element_ids, elem_count)
    return array_id
}

function execute_object_expression(obj_node,   prop_count, i, prop_id, prop_key, prop_value_id, property_keys, property_values) {
    debug_msg("Executing object expression")
    prop_count = ast_nodes[obj_node, "properties_count"]
    for (i = 1; i <= prop_count; i++) {
        prop_id = ast_nodes[obj_node, "property_" i]
        prop_key = ast_nodes[prop_id, "key"]
        prop_value_id = execute(ast_nodes[prop_id, "value"])
        property_keys[i] = prop_key
        property_values[i] = prop_value_id
    }
    return create_object(property_keys, property_values, prop_count)
}

function create_object(property_keys, property_values, count,   obj_id, i) {
    obj_id = ++object_counter
    objects[obj_id, "type"] = TYPE_OBJECT
    objects[obj_id, "properties_count"] = count
    for (i = 1; i <= count; i++) {
        objects[obj_id, "prop_key_" i] = property_keys[i]
        objects[obj_id, "prop_value_" i] = property_values[i]
    }
    register_object(obj_id)
    return obj_id
}

function execute_assignment(assign_node,   left_id, right_id, left_name, result_id, left_type, obj_val_id, prop_val_id, type, key) {
    debug_msg("Executing assignment")

    left_id = ast_nodes[assign_node, "left"]
    right_id = ast_nodes[assign_node, "right"]
    result_id = execute(right_id)

    left_type = ast_nodes[left_id, "type"]

    if (left_type == "Identifier") {
        left_name = ast_nodes[left_id, "name"]
        update_variable(left_name, result_id)
        return result_id
    }

    if (left_type == "MemberExpression") {
        obj_val_id = execute(ast_nodes[left_id, "object"])

        if (ast_nodes[left_id, "computed"]) {
            prop_val_id = execute(ast_nodes[left_id, "property"])
        } else {
            prop_val_id = create_value(TYPE_STRING, ast_nodes[ast_nodes[left_id, "property"], "name"])
        }

        type = objects[obj_val_id, "type"]

        if (is_index_writable(type)) {
            set_indexed_value(obj_val_id, prop_val_id, result_id)
            return result_id
        }

        if (type == TYPE_OBJECT || type == TYPE_STRUCT) {
            key = value_to_string(prop_val_id)
            set_object_property(obj_val_id, key, result_id)
            return result_id
        }

        error("Cannot assign to member of type: " type)
    }

    error("Left side of assignment must be an identifier or member expression")
}

function execute_binary_expression(bin_node,   op, left_val_id, right_val_id, result_type, result_val, lt, rt, lv, rv) {
    op = ast_nodes[bin_node, "operator"]
    debug_msg("Executing binary expression with operator " op)

    left_val_id  = execute(ast_nodes[bin_node, "left"])
    right_val_id = execute(ast_nodes[bin_node, "right"])

    lt = objects[left_val_id, "type"]
    rt = objects[right_val_id, "type"]
    lv = objects[left_val_id, "value"]
    rv = objects[right_val_id, "value"]

    if (op == "+") {
        if (lt == TYPE_STRING || rt == TYPE_STRING) {
            result_type = TYPE_STRING
            result_val = value_to_string(left_val_id) value_to_string(right_val_id)
        } else if (lt == TYPE_FLOAT || rt == TYPE_FLOAT) {
            result_type = TYPE_FLOAT
            result_val = lv + rv
        } else {
            result_type = TYPE_INT
            result_val = lv + rv
        }
    } else if (op == "-") {
        result_type = (lt == TYPE_FLOAT || rt == TYPE_FLOAT) ? TYPE_FLOAT : TYPE_INT
        result_val = lv - rv
    } else if (op == "*") {
        result_type = (lt == TYPE_FLOAT || rt == TYPE_FLOAT) ? TYPE_FLOAT : TYPE_INT
        result_val = lv * rv
    } else if (op == "<") {
        result_type = TYPE_BOOL
        result_val = (lv < rv)
    } else if (op == ">") {
        result_type = TYPE_BOOL
        result_val = (lv > rv)
    } else if (op == "<=") {
        result_type = TYPE_BOOL
        result_val = (lv <= rv)
    } else if (op == ">=") {
        result_type = TYPE_BOOL
        result_val = (lv >= rv)
    } else if (op == "==") {
        result_type = TYPE_BOOL
        if (lt == TYPE_STRUCT && rt == TYPE_STRUCT) {
            result_val = compare_structs(left_val_id, right_val_id)
        } else if (lt == TYPE_ARRAY && rt == TYPE_ARRAY) {
            result_val = compare_arrays(left_val_id, right_val_id)
        } else {
            result_val = (lv == rv)
        }
    } else if (op == "!=") {
        result_type = TYPE_BOOL
        result_val = (lv != rv)
    } else if (op == "/") {
        if (rv == 0) {
            error("Division by zero")
            result_val = 0
        } else {
            result_val = lv / rv
        }
        result_type = (lt == TYPE_FLOAT || rt == TYPE_FLOAT) ? TYPE_FLOAT : TYPE_INT
    } else if (op == "%") {
        if (rv == 0) {
            error("Modulo by zero")
            result_val = 0
        } else {
            result_val = int(lv) % int(rv)
        }
        result_type = TYPE_INT
    } else if (op == "&&") {
        result_type = TYPE_BOOL
        result_val = (lv && rv)
    } else if (op == "||") {
        result_type = TYPE_BOOL
        result_val = (lv || rv)
    } else {
        error("Unknown operator: " op)
    }

    if (lt == "" || rt == "")
        error("Type check on invalid value")

    return create_value(result_type, result_val)
}

function execute_unary_expression(unary_node,   op, operand_id, operand_type, operand_val) {
    op = ast_nodes[unary_node, "operator"]
    operand_id = execute(ast_nodes[unary_node, "argument"])

    if (op == "!") {
        return create_value(TYPE_BOOL, !to_bool(operand_id))
    } else if (op == "-") {
        operand_type = objects[operand_id, "type"]
        operand_val = objects[operand_id, "value"]
        if (operand_type != TYPE_INT && operand_type != TYPE_FLOAT) {
            error("Unary '-' requires a numeric operand, got " operand_type)
        }
        return create_value(operand_type, -operand_val)
    }

    error("Unknown unary operator: " op)
}

function compare_structs(left_id, right_id,   left_count, right_count, i, j, match_, key_l, val_l, key_r, val_r) {
    debug_msg("Comparing structs " left_id " and " right_id)
    left_count  = objects[left_id, "properties_count"]
    right_count = objects[right_id, "properties_count"]
    debug_msg("Left struct has " left_count " properties, right struct has " right_count " properties")

    if (left_count != right_count)
        return 0

    for (i = 1; i <= left_count; i++) {
        key_l = objects[left_id, "prop_key_" i]
        val_l = objects[left_id, "prop_value_" i]

        match_ = 0
        for (j = 1; j <= right_count; j++) {
            key_r = objects[right_id, "prop_key_" j]
            val_r = objects[right_id, "prop_value_" j]

            debug_msg("Comparing left key " key_l " with right key " key_r)

            if (key_l == key_r) {
                if (objects[val_l, "type"] == TYPE_STRUCT && objects[val_r, "type"] == TYPE_STRUCT) {
                    if (!compare_structs(val_l, val_r))
                        return 0
                } else {
                    if (objects[val_l, "value"] != objects[val_r, "value"])
                        return 0
                }
                match_ = 1
                break
            }
        }

        if (!match_) {
            debug_msg("compare_structs: mismatch on key " key_l)
            return 0
        }
    }

    return 1
}

function compare_arrays(id1, id2,    len1, len2, i, el1, el2) {
    debug_msg("Comparing arrays " id1 " and " id2)
    len1 = objects[id1, "length"]
    len2 = objects[id2, "length"]

    debug_msg("Array lengths: " len1 " vs " len2)

    if (len1 != len2) {
        debug_msg("compare_arrays: different lengths " len1 " vs " len2)
        return 0
    }

    for (i = 0; i < len1; i++) {
        el1 = objects[id1, "element_" i]
        el2 = objects[id2, "element_" i]

        if (objects[el1, "type"] != objects[el2, "type"]) {
            debug_msg("compare_arrays: element " i " type mismatch: " objects[el1, "type"] " vs " objects[el2, "type"])
            return 0
        }

        if (objects[el1, "value"] != objects[el2, "value"]) {
            debug_msg("compare_arrays: element " i " value mismatch: " \
                      objects[el1, "value"] " vs " objects[el2, "value"])
            return 0
        }
    }

    return 1
}

function execute_function_call(call_node,   callee_node, args, argc, i, arg_id, result_id, val_id, parts, val_value) {
    debug_msg("Executing function call")
    callee_node = ast_nodes[call_node, "callee_node"]
    debug_msg("Callee node: " callee_node " of type " ast_nodes[callee_node, "type"] " value " ast_nodes[callee_node, "value"])
    argc = ast_nodes[call_node, "args_count"]
    delete args
    for (i = 1; i <= argc; i++) {
        arg_id = ast_nodes[call_node, "arg_" i]
        args[i] = arg_id
    }
    val_id = execute(callee_node)
    debug_msg("Callee value id: " val_id " of type " objects[val_id, "type"] " value " objects[val_id, "value"])
    val_value = objects[val_id, "value"]

    if (val_value ~ /^lambda:/) {
        for (i = 1; i <= argc; i++) {
            args[i] = execute(args[i])
        }
        debug_msg("Calling lambda function")
        return call_lambda(val_id, args, argc)
    }

    if (val_value ~ /^builtin:/) {
        split(val_value, parts, ":")
        for (i = 1; i <= argc; i++) {
            args[i] = execute(args[i])
        }
        if (objects[val_id, "self"] != "") {
            args[0] = objects[val_id, "self"]
        }
        debug_msg("Calling builtin function " parts[1] " with " argc " args")
        return call_builtin(parts[2], args, argc)
    } else if (objects[val_id, "type"] == TYPE_FUNCTION) {
        for (i = 1; i <= argc; i++) {
            args[i] = execute(args[i])
        }
        return call_function(val_id, args, argc)
    } else if (objects[val_id, "type"] == TYPE_STRUCT || objects[val_id, "type"] == TYPE_OBJECT) {
        return create_instance(val_id, args, argc)
    }
    error("Called value is not a function or constructor")
    return create_value(TYPE_NULL, "null", 0)
}

function call_lambda(lambda_id, args, argc,   param_count, i, body_node, old_scope, result, new_scope) {
    debug_msg("call_lambda: id=" lambda_id " argc=" argc)

    param_count = objects[lambda_id, "param_count"]
    debug_msg("Lambda expects " param_count " parameters")

    if (argc != param_count) {
        error("Lambda expects " param_count " arguments, got " argc)
    }

    old_scope = current_scope_id
    new_scope = ++scope_counter
    current_scope_id = new_scope
    scopes[new_scope, "parent"] = objects[lambda_id, "closure_scope"]
    debug_msg("Created lambda scope " new_scope " with parent " scopes[new_scope, "parent"])

    for (i = 0; i < param_count; i++) {
        debug_msg("Declaring lambda param " objects[lambda_id, "param_" i] " = " args[i + 1] " in scope " new_scope)
        declare_variable(objects[lambda_id, "param_" i], args[i + 1], new_scope)
    }

    body_node = objects[lambda_id, "body"]
    debug_msg("Executing lambda body node " body_node)
    result = execute(body_node)

    current_scope_id = old_scope
    debug_msg("Restored scope to " current_scope_id)

    return result
}

function resolve_identifier(id_name) {
    debug_msg("Resolving identifier " id_name)
    return get_variable(id_name)
}

function execute_program_node(prog_node,   result_id, i, stmt_node) {
    debug_msg("Executing program node")
    result_id = create_value(TYPE_NULL, "null")

    for (i = 1; i <= ast_nodes[prog_node, "body_count"]; i++) {
        stmt_node = ast_nodes[prog_node, "body_" i]
        result_id = execute(stmt_node)

        if (control_flow_active()) {
            break
        }
    }

    return result_id
}

function create_value(type, val, register,   obj_id) {
    if (register == "") register = 1
    if (register && object_counter > 0 && object_counter % gc_threshold == 0) {
        garbage_collect()
    }
    obj_id = ++object_counter
    objects[obj_id, "type"] = type
    objects[obj_id, "value"] = val
    if (type == TYPE_STRING) {
        objects[obj_id, "length"] = length(val)
    }
    debug_msg("Created value of type " type " with id " obj_id " (registered=" register ")")
    return obj_id
}

function type_check(val1_id, val2_id, operation,   type1, type2) {
    debug_msg("Type checking values " val1_id " and " val2_id " for operation " operation)
    type1 = objects[val1_id, "type"]
    type2 = objects[val2_id, "type"]

    if (type1 == "" || type2 == "") {
        error("Type check on invalid value")
    }

    if (operation == "+" && (type1 == TYPE_STRING || type2 == TYPE_STRING)) {
        return TYPE_STRING
    }

    if ((type1 == TYPE_INT || type1 == TYPE_FLOAT) && 
        (type2 == TYPE_INT || type2 == TYPE_FLOAT)) {
        if (type1 == TYPE_FLOAT || type2 == TYPE_FLOAT) {
            return TYPE_FLOAT
        }
        return TYPE_INT
    }

    if (operation == "==" || operation == "!=" || 
        operation == "<" || operation == ">" ||
        operation == "<=" || operation == ">=" ||
        operation == "||" || operation == "&&") {
        return TYPE_BOOL
    }

    error("Incompatible types for operation " operation ": " type1 " and " type2)
}

function register_object(obj_id) {
    debug_msg("Registering object " obj_id)
    if (object_counter % gc_threshold == 0) {
        debug_msg("GC threshold reached (" object_counter " objects), running garbage collector...")
        gc_protect_id = obj_id
        garbage_collect()
        gc_protect_id = ""
    }
}

function garbage_collect(   idx, parts, id, deleted_ids, swept) {
    debug_msg("Starting garbage collector...")

    delete marked
    mark_reachable_objects()

    swept = 0
    delete deleted_ids
    for (idx in objects) {
        split(idx, parts, SUBSEP)
        id = parts[1]
        if (!(id in marked)) {
            delete objects[idx]
            deleted_ids[id] = 1
        }
        debug_msg("GC: checked object " id)
    }
    swept = length(deleted_ids)

    debug_msg("GC: deleted " swept " objects")
}

function mark_reachable_objects(   i) {
    debug_msg("Marking reachable objects...")
    mark_scope_objects(global_scope_id)

    for (i = 1; i <= call_stack_size; i++) {
        mark_scope_objects(call_stack[i, "scope"])
        debug_msg("Marked scope " call_stack[i, "scope"] " from call stack")
    }

    mark_scope_chain(current_scope_id)

    if (gc_protect_id != "") mark_object(gc_protect_id)
}

function mark_scope_chain(scope_id) {
    debug_msg("Marking scope chain starting from scope " scope_id)
    while (scope_id != 0) {
        mark_scope_objects(scope_id)
        scope_id = scopes[scope_id, "parent"]
        debug_msg("Moving to parent scope " scope_id)
    }
}

function mark_object(id,   type, i, sub_id, j, prop_count, closure_scope_id) {
    debug_msg("Marking object " id)
    if (id in marked) return
    marked[id] = 1

    type = objects[id, "type"]
    if (type == TYPE_ARRAY) {
        for (i = 0; i < objects[id, "length"]; i++) {
            sub_id = objects[id, "element_" i]
            if (sub_id + 0 == sub_id) mark_object(sub_id)
        }
    } else if (type == TYPE_OBJECT || type == TYPE_STRUCT) {
        prop_count = objects[id, "properties_count"]
        for (j = 1; j <= prop_count; j++) {
            sub_id = objects[id, "prop_value_" j]
            if (sub_id + 0 == sub_id) mark_object(sub_id)
        }
        sub_id = objects[id, "prototype"]
        if (sub_id + 0 == sub_id) mark_object(sub_id)
    } else if (type == TYPE_FUNCTION) {
        sub_id = objects[id, "self"]
        if (sub_id != "" && sub_id + 0 == sub_id) mark_object(sub_id)

        closure_scope_id = objects[id, "closure_scope"]
        if (closure_scope_id != "") mark_scope_chain(closure_scope_id)
    }
}

function mark_scope_objects(scope_id,   idx, parts, s_id, key, val_id) {
    debug_msg("Marking objects in scope " scope_id)
    for (idx in scopes) {
        split(idx, parts, SUBSEP)
        s_id = parts[1]
        if (s_id == scope_id && substr(parts[2], 1, 4) == "var_") {
            val_id = scopes[idx]
            if (val_id + 0 == val_id) {
                mark_object(val_id)
            }
        }
        debug_msg("Marked variable " parts[2] " in scope " s_id)
    }
}

function new_scope(parent_id,   new_id) {
    debug_msg("Creating new scope with parent " parent_id)
    new_id = ++scope_counter
    scopes[new_id, "parent"] = parent_id
    scopes[new_id, "variables_count"] = 0
    debug_msg("Created new scope " new_id " with parent " parent_id)
    return new_id
}

function init_builtins() {
    debug_msg("Initializing built-in functions...")
    register_builtin_function("id")
    register_builtin_function("print")
    register_builtin_function("type")
    register_builtin_function("len")
    register_builtin_function("assert")
    register_builtin_function("pop")
    register_builtin_function("clear")
    register_builtin_function("filter")
    register_builtin_function("map")
    register_builtin_function("reduce")
    register_builtin_function("range")
}

function init_builtin_methods() {
    debug_msg("Initializing built-in methods...")
    METHODS[TYPE_STRING, "upper"] = "string.upper"
    METHODS[TYPE_STRING, "lower"] = "string.lower"
    METHODS[TYPE_STRING, "len"]   = "string.len"
    METHODS[TYPE_STRING, "split"]   = "string.split"

    METHODS[TYPE_ARRAY, "append"] = "array.append"
    METHODS[TYPE_ARRAY, "extend"] = "array.extend"
    METHODS[TYPE_ARRAY, "len"]    = "array.len"

    METHODS[TYPE_FUNCTION, "name"] = "function.name"
    METHODS[TYPE_FUNCTION, "call"] = "function.call"
}

function try_get_builtin_method(obj_val_id, method_name,   type, func_id) {
    debug_msg("Trying to get builtin method " method_name " for object " obj_val_id)
    type = objects[obj_val_id, "type"]

    if ((type, method_name) in METHODS) {
        func_id = create_value(TYPE_FUNCTION, "builtin:" METHODS[type, method_name])
        objects[func_id, "self"] = obj_val_id
        return func_id
    }

    return ""
}

function is_indexable(type) {
    debug_msg("Checking if type " type " is indexable")
    return (type == TYPE_ARRAY || type == TYPE_STRING)
}

function is_index_writable(type) {
    debug_msg("Checking if type " type " is index writable")
    return (type == TYPE_ARRAY || type == TYPE_STRING)
}

function register_builtin_function(name,   fun_id) {
    debug_msg("Registering builtin function " name)
    fun_id = create_value(TYPE_FUNCTION, "builtin:" name)
    objects[fun_id, "name"] = name
    objects[fun_id, "is_builtin"] = 1
    declare_variable(name, fun_id)
}

function get_indexed_value(obj_val_id, index_val_id,   type, prop_type, index_, str_len, char) {
    debug_msg("Getting indexed value from object " obj_val_id)
    type = objects[obj_val_id, "type"]
    prop_type = objects[index_val_id, "type"]

    if (prop_type != TYPE_INT) {
        error((type == TYPE_ARRAY ? "Array" : "String") " index must be integer")
    }

    index_ = objects[index_val_id, "value"]

    if (type == TYPE_ARRAY) {
        if (index_ < 0 || index_ >= objects[obj_val_id, "length"]) {
            error("Array index out of bounds")
        }
        return objects[obj_val_id, "element_" index_]
    } else if (type == TYPE_STRING) {
        str_len = length(objects[obj_val_id, "value"])
        if (index_ < 0 || index_ >= str_len) {
            error("String index out of bounds")
        }
        char = substr(objects[obj_val_id, "value"], index_ + 1, 1)
        return create_value(TYPE_STRING, char)
    }
}

function set_indexed_value(obj_val_id, index_val_id, value_id,   type, prop_type, index_, old_str, old_str_len, new_char, new_str) {
    debug_msg("Setting indexed value in object " obj_val_id)
    type = objects[obj_val_id, "type"]
    prop_type = objects[index_val_id, "type"]

    if (prop_type != TYPE_INT) {
        error("Index must be integer")
    }

    index_ = objects[index_val_id, "value"]

    if (type == TYPE_ARRAY) {
        if (index_ < 0 || index_ >= objects[obj_val_id, "length"]) {
            error("Array index out of bounds")
        }
        objects[obj_val_id, "element_" index_] = value_id
        return create_value(TYPE_NULL, "null", 0)
    } else if (type == TYPE_STRING) {
        old_str = objects[obj_val_id, "value"]
        old_str_len = objects[obj_val_id, "length"]
        
        if (index_ < 0 || index_ >= old_str_len) {
            error("String index out of bounds")
        }

        if (objects[value_id, "type"] != TYPE_STRING) {
            error("Can only assign string to string index")
        }
        new_char = objects[value_id, "value"]

        if (length(new_char) > 1) {
            new_char = substr(new_char, 1, 1)
        }
        if (length(new_char) == 0) {
            error("Cannot assign empty string to string index")
        }

        if (index_ == 0) {
            new_str = new_char substr(old_str, 2)
        } else if (index_ == old_str_len - 1) {
            new_str = substr(old_str, 1, old_str_len - 1) new_char
        } else {
            new_str = substr(old_str, 1, index_) new_char substr(old_str, index_ + 2)
        }

        objects[obj_val_id, "value"] = new_str
        return create_value(TYPE_NULL, "null", 0)
    }

    return create_value(TYPE_NULL, "null", 0)
}

function init_custom_builtins(module_name,  obj_id) {
    debug_msg("Initializing custom builtin module: " module_name)
    if (module_name == "math") {
        obj_id = create_math_module()
        return obj_id
    } else if (module_name == "system") {
        obj_id = create_system_module()
        return obj_id
    } else if (module_name == "io") {
        obj_id = create_io_module()
        return obj_id
    } else if (module_name == "fs") {
        obj_id = create_fs_module()
        return obj_id
    } else if (module_name == "http") {
        obj_id = create_http_module()
        return obj_id
    } else if (module_name == "regex") {
        obj_id = create_regex_module()
        return obj_id
    } else if (module_name == "kek") {
        obj_id = create_kek_module()
        return obj_id
    } else if (module_name == "mysql") {
        obj_id = create_mysql_module()
        return obj_id
    }
    return create_value(TYPE_NULL, "null", 0)
}

function get_object_property(obj_val_id, key,   i, prototype_id, method_id) {
    debug_msg("Getting property '" key "' from object " obj_val_id)

    for (i = 1; i <= objects[obj_val_id, "properties_count"]; i++) {
        if (objects[obj_val_id, "prop_key_" i] == key) {
            return objects[obj_val_id, "prop_value_" i]
        }
    }

    if ((obj_val_id, key) in objects) {
        debug_msg("  Found as direct property")
        return objects[obj_val_id, key]
    }

    if (objects[obj_val_id, "prototype"] != "") {
        prototype_id = objects[obj_val_id, "prototype"]
        for (i = 1; i <= objects[prototype_id, "methods_count"]; i++) {
            if (objects[prototype_id, "method_name_" i] == key) {
                method_id = objects[prototype_id, "method_" i]
                objects[method_id, "self"] = obj_val_id
                return method_id
            }
        }
    }
    error("Property or method not found: " key)
}

function set_object_property(obj_val_id, key, value_id,   i) {
    debug_msg("Setting property '" key "' on object " obj_val_id)
    for (i = 1; i <= objects[obj_val_id, "properties_count"]; i++) {
        if (objects[obj_val_id, "prop_key_" i] == key) {
            objects[obj_val_id, "prop_value_" i] = value_id
            return 1
        }
    }

    objects[obj_val_id, "properties_count"]++
    i = objects[obj_val_id, "properties_count"]
    objects[obj_val_id, "prop_key_" i] = key
    objects[obj_val_id, "prop_value_" i] = value_id
    return 1
}

function call_builtin(func_name, args, argc) {
    debug_msg("Builtin function " func_name " with " argc " arguments")

    # builins functions
    if (func_name == "id") return builtin_id(args, argc)
    if (func_name == "print") return builtin_print(args, argc)
    if (func_name == "type") return builtin_type(args, argc)
    if (func_name == "len") return builtin_len(args, argc)
    if (func_name == "pop") return builtin_pop(args, argc)
    if (func_name == "clear") return builtin_clear(args, argc)
    if (func_name == "assert") return builtin_assert(args, argc)
    if (func_name == "filter") return builtin_filter(args, argc)
    if (func_name == "map") return builtin_map(args, argc)
    if (func_name == "reduce") return builtin_reduce(args, argc)
    if (func_name == "range") return builtin_range(args, argc)

    # builins modules
    if (func_name ~ /^math\./) return builtin_math(func_name, args, argc)
    if (func_name ~ /^system\./) return builtin_system(func_name, args, argc)
    if (func_name ~ /^io\./) return builtin_io(func_name, args, argc)
    if (func_name ~ /^fs\./) return builtin_fs(func_name, args, argc)
    if (func_name ~ /^http\./) return builtin_http(func_name, args, argc)
    if (func_name ~ /^regex\./) return builtin_regex(func_name, args, argc)
    if (func_name ~ /^kek\./) return builtin_kek(func_name, args, argc)
    if (func_name ~ /^mysql\./) return builtin_mysql(func_name, args, argc)

    # builins object methods
    if (func_name ~ /^string\./) return builtin_string(func_name, args, argc)
    if (func_name ~ /^array\./) return builtin_array(func_name, args, argc)
    if (func_name ~ /^function\./) return builtin_function(func_name, args, argc)

    error("Unknown builtin function: " func_name)
}

# @doc [strings]
# Built-in methods for string objects.
# examples:
# let str = "hello"
# str.upper()  # returns "HELLO"
# str.lower()  # returns "hello"
# str.len()    # returns 5
# let str = "hello, world";
# str.split(",")    # returns [hello, world]
function builtin_string(func_name, args, argc,  self_id, self_value, result) {
    debug_msg("Executing builtin string method " func_name " with " argc " arguments")
    self_id = args[0]
    if (self_id == "") error("Method " func_name " called without context")
    self_value = objects[self_id, "value"]

    if (func_name == "string.upper") {
        result = toupper(self_value)
    } else if (func_name == "string.lower") {
        result = tolower(self_value)
    } else if (func_name == "string.len") {
        return create_value(TYPE_INT, objects[self_id, "length"], 0)
    } else if (func_name == "string.split") {
        return split_string(self_value, args)
    }
    else {
        error("Unknown string method: " func_name)
    }

    objects[self_id, "value"] = result
    return self_id
}

function split_string(self_value, args,   delimiter_id, delimiter_value, result_array, i, part, output_id) {
    debug_msg("Splitting string id " self_id)
    delimiter_id = args[1]
    
    delimiter_value = " "
    if (delimiter_id != "") {
        delimiter_value = objects[delimiter_id, "value"]
    }

    split(self_value, result_array, delimiter_value)
    
    result_array_len = length(result_array)

    for (i = 1; i <= result_array_len; i++) {
        element_ids[i] = create_value(TYPE_STRING, result_array[i])
    }

    return create_array(element_ids, result_array_len)
}

# @doc [functions]
# Built-in methods for function objects.
# examples:
# func.name()  # returns the name of the function
# func.call()  # calls the function
function builtin_function(func_name, args, argc,  self_id, self_value) {
    debug_msg("Executing builtin function method " func_name " with " argc " arguments")
    self_id = args[0]
    if (self_id == "") error("Method " func_name " called without context")
    self_value = objects[self_id, "name"]

    if (func_name == "function.name") {
        self_value = objects[self_id, "name"]
        if (self_value == "") self_value = "<anonymous>"
        return create_value(TYPE_STRING, self_value, 0)
    } else if (func_name == "function.call") {
        delete call_args
        for (i = 1; i <= argc; i++) call_args[i] = args[i]
        if (objects[self_id, "value"] ~ /^lambda:/) {
            return call_lambda(self_id, call_args, argc)
        }
        return call_function(self_id, call_args, argc)
    } else {
        error("Unknown string method: " func_name)
    }

    return self_id
}

# @doc [arrays]
# Built-in methods for array objects.
# examples:
# let arr = [1, 2, 3]
# arr.len()  # returns 3
# arr.append(4)  # appends 4 to the array
# arr.extend([5, 6])  # extends the array with another array    
function builtin_array(func_name, args, argc,  self_id, self_value) {
    debug_msg("Executing builtin array method " func_name " with " argc " arguments")
    self_id = args[0]
    if (self_id == "") error("Method " func_name " called without context")
    self_value = objects[self_id, "value"]

    if (func_name == "array.len") {
        return create_value(TYPE_INT, objects[self_id, "length"], 0)
    } else if (func_name == "array.append") {
        if (argc != 1) error("append expects 1 argument")
        value_id = args[1]
        len = objects[self_id, "length"]
        objects[self_id, "element_" len] = value_id
        objects[self_id, "length"] = len + 1
        return create_value(TYPE_NULL, "null", 0)
    } else if (func_name == "array.extend") {
        value_id = args[1]
        value_type = objects[value_id, "type"]
        if (value_type != TYPE_ARRAY) error("extend argument must be array")
        len = objects[self_id, "length"]
        value_len = objects[value_id, "length"]
        for (i = 0; i < value_len; i++) {
            objects[self_id, "element_" (len + i)] = objects[value_id, "element_" i]
        }
        objects[self_id, "length"] = len + value_len
        return create_value(TYPE_NULL, "null", 0)
    } else {
        error("Unknown array method: " func_name)
    }

    return self_id
}

# @doc [builtins]
# Provides the unique identifier of the given value.
# examples:
# id(value)  # returns the unique identifier of value
# id("hello")  # returns the unique identifier of the string "hello"
# id(42)  # returns the unique identifier of the integer 42
# id([1, 2, 3])  # returns the unique identifier of the array [1, 2, 3]
function builtin_id(args, argc,   i, output) {
    debug_msg("Executing builtin id with " argc " arguments")
    if (argc != 1) error("type expects 1 argument")
    return create_value(TYPE_STRING, args[1])
}

# @doc [builtins]
# Prints one or more values to stdout.
# examples:
# print("Hello, World!")  # prints "Hello, World!"
# print(value)  # prints the value
# print(value, value2)  # prints multiple values separated by space
# print(value, " - ", value2)   # prints values with custom separator
# print("Value:", value, "is of type", type(value))  # prints value and its type
function builtin_print(args, argc,   i, output) {
    debug_msg("Executing builtin print with " argc " arguments")
    output = ""
    for (i = 1; i <= argc; i++) {
        if (i > 1) output = output " "
        output = output value_to_string(args[i])
    }
    print output
    return create_value(TYPE_NULL, "null")
}

# @doc [builtins]
# Returns the type of the given value as a string.
# examples:
# type(42)  # returns "int"
# type(3.14)  # returns "float"
# type("hello")  # returns "string"
# type([1, 2, 3])  # returns "array"
function builtin_type(args, argc,   arg_type) {
    debug_msg("Executing builtin type with " argc " arguments")
    if (argc != 1) error("type expects 1 argument")
    arg_type = objects[args[1], "type"]
    return create_value(TYPE_STRING, arg_type)
}

# @doc [builtins]
# Returns the length of a string, array, or struct.
# examples:
# len("hello")  # returns 5
# len([1, 2, 3, 4])  # returns 4
function builtin_len(args, argc,   arg, arg_type) {
    debug_msg("Executing builtin len with " argc " arguments")
    if (argc != 1) error("len expects 1 argument")
    arg = args[1]
    arg_type = objects[arg, "type"]
    if (arg_type == TYPE_STRING)
        return create_value(TYPE_INT, length(objects[arg, "value"]))
    else if (arg_type == TYPE_ARRAY)
        return create_value(TYPE_INT, objects[arg, "length"])
    else if (arg_type == TYPE_OBJECT || arg_type == TYPE_STRUCT)
        return create_value(TYPE_INT, objects[arg, "properties_count"])
    error("len applicable only to strings, arrays, or structs")
}

# @doc [builtins]
# Removes and returns the last element from an array.
# examples:
# let arr = [1, 2, 3]
# let last = pop(arr)  # last = 3, arr = [1, 2]
# let empty_arr = []
# let last = pop(empty_arr)  # last = null, empty_arr = []
function builtin_pop(args, argc,   target_id, target_type, len, last_index, res) {
    debug_msg("builtin_pop starts")
    if (argc != 1) error("pop expects 1 argument")

    target_id = args[1]
    target_type = objects[target_id, "type"]
    if (target_type != TYPE_ARRAY) error("pop applicable only to arrays")

    len = objects[target_id, "length"]
    if (len == 0) {
        debug_msg("pop: array " target_id " is empty")
        return create_value(TYPE_NULL, "null")
    }

    last_index = len - 1
    res = objects[target_id, "element_" last_index]
    delete objects[target_id, "element_" last_index]
    objects[target_id, "length"] = last_index

    debug_msg("pop: removed element " res " from array " target_id ", new length = " last_index)
    return res
}

# @doc [builtins]
# Clears all elements from an array.
# examples:
# let arr = [1, 2, 3]
# clear(arr)  # arr = []
# let empty_arr = []
# clear(empty_arr)  # empty_arr = []
function builtin_clear(args, argc,   target_id, target_type, len, last_index, res) {
    debug_msg("builtin_clear starts")
    if (argc != 1) error("clear expects 1 argument")

    target_id = args[1]
    target_type = objects[target_id, "type"]
    if (target_type == TYPE_ARRAY) {
        len = objects[target_id, "length"]
        for (i = 0; i < len; i++) {
            delete objects[target_id, "element_" i]
        }
        objects[target_id, "length"] = 0
        debug_msg("clear: array " target_id " cleared")
        return create_value(TYPE_NULL, "null")
    }
}

# @doc [builtins]
# Asserts that a condition is true, otherwise raises an assertion error.
# examples:
# assert(x > 0, "x must be positive")  # raises error if x <= 0
# assert(value)  # raises error if value is false or null
function builtin_assert(args, argc,   condition, cond_type, cond_val, is_false, msg) {
    debug_msg("builtin_assert called")
    if (argc < 1) error("assert expects at least 1 argument")

    condition = args[1]
    cond_type = objects[condition, "type"]
    cond_val  = objects[condition, "value"]

    is_false = 0
    if (cond_type == TYPE_NULL)
        is_false = 1
    else if (cond_type == TYPE_BOOL && (cond_val == "false" || cond_val == 0))
        is_false = 1
    else if ((cond_type == TYPE_INT || cond_type == TYPE_FLOAT) && cond_val == 0)
        is_false = 1

    if (is_false) {
        if (argc > 1)
            msg = value_to_string(args[2])
        else
            msg = "Assertion failed"
        print "AssertionError: " msg > "/dev/stderr"
        exit(1)
    }

    return create_value(TYPE_NULL, "null")
}

# @doc [builtins]
# Filters elements from an array based on a predicate function.
# examples:
# let arr = [1, 2, 3, 4, 5]
# let even_arr = filter(arr, lambda x: x % 2 == 0)  # even_arr = [2, 4]
function builtin_filter(args, argc,   arr_id, func_id, result_id, i, len, elem_id, filter_args, filter_result, result_count) {
    debug_msg("builtin_filter called")
    if (argc != 2) error("filter expects 2 arguments: array and function")

    arr_id = args[1]
    func_id = args[2]

    if (objects[arr_id, "type"] != TYPE_ARRAY) {
        error("filter: first argument must be array")
    }

    if (objects[func_id, "type"] != TYPE_FUNCTION) {
        error("filter: second argument must be function")
    }

    result_id = create_value(TYPE_ARRAY, "")
    result_count = 0

    len = objects[arr_id, "length"]
    for (i = 0; i < len; i++) {
        elem_id = objects[arr_id, "element_" i]

        delete filter_args
        filter_args[1] = elem_id

        if (objects[func_id, "value"] ~ /^lambda:/) {
            filter_result = call_lambda(func_id, filter_args, 1)
        } else {
            filter_result = call_function(func_id, filter_args, 1)
        }

        if (objects[filter_result, "type"] == TYPE_BOOL && objects[filter_result, "value"] == 1) {
            objects[result_id, "element_" result_count] = elem_id
            result_count++
        } else if (objects[filter_result, "type"] == TYPE_INT && objects[filter_result, "value"] != 0) {
            objects[result_id, "element_" result_count] = elem_id
            result_count++
        }
    }

    objects[result_id, "length"] = result_count
    debug_msg("filter: created array with " result_count " elements")

    return result_id
}

# @doc [builtins]
# Maps elements from an array using a transformation function.
# examples:
# let arr = [1, 2, 3]
# let squared_arr = map(arr, lambda x: x * x)  # squared_arr = [1, 4, 9]
function builtin_map(args, argc,   arr_id, func_id, result_id, i, len, elem_id, map_args, map_result) {
    debug_msg("builtin_map called")
    if (argc != 2) error("map expects 2 arguments: array and function")

    arr_id = args[1]
    func_id = args[2]

    if (objects[arr_id, "type"] != TYPE_ARRAY) {
        error("map: first argument must be array")
    }

    if (objects[func_id, "type"] != TYPE_FUNCTION) {
        error("map: second argument must be function")
    }

    result_id = create_value(TYPE_ARRAY, "")
    len = objects[arr_id, "length"]

    for (i = 0; i < len; i++) {
        elem_id = objects[arr_id, "element_" i]

        delete map_args
        map_args[1] = elem_id

        if (objects[func_id, "value"] ~ /^lambda:/) {
            map_result = call_lambda(func_id, map_args, 1)
        } else {
            map_result = call_function(func_id, map_args, 1)
        }

        objects[result_id, "element_" i] = map_result
    }

    objects[result_id, "length"] = len
    debug_msg("map: created array with " len " elements")

    return result_id
}

# @doc [builtins]
# Reduces an array to a single value using a binary function.
# examples:
# let arr = [1, 2, 3, 4]
# let sum = reduce(arr, lambda acc, x: acc + x, 0)  # sum = 10
function builtin_reduce(args, argc,   arr_id, func_id, acc_id, i, len, elem_id, reduce_args) {
    debug_msg("builtin_reduce called")
    if (argc != 3) error("reduce expects 3 arguments: array, function, and initial value")

    arr_id = args[1]
    func_id = args[2]
    acc_id = args[3]

    if (objects[arr_id, "type"] != TYPE_ARRAY) {
        error("reduce: first argument must be array")
    }

    if (objects[func_id, "type"] != TYPE_FUNCTION) {
        error("reduce: second argument must be function")
    }

    len = objects[arr_id, "length"]

    for (i = 0; i < len; i++) {
        elem_id = objects[arr_id, "element_" i]

        delete reduce_args
        reduce_args[1] = acc_id
        reduce_args[2] = elem_id

        if (objects[func_id, "value"] ~ /^lambda:/) {
            acc_id = call_lambda(func_id, reduce_args, 2)
        } else {
            acc_id = call_function(func_id, reduce_args, 2)
        }
    }

    return acc_id
}

# @doc [builtins]
# Creates an array containing a range of integers.
# examples:
# let arr = range(5)  # arr = [0, 1, 2, 3, 4]
# let arr2 = range(2, 6)  # arr2 = [2, 3, 4, 5]
function builtin_range(args, argc,   start_id, end_id, start_val, end_val, target_id, value_id, target_type, len, i) {
    debug_msg("builtin_range called")
    if (argc < 1) error("range expects at least 1 argument")

    if (argc == 1) {
        start_val = 0
        end_id = args[1]
        if (objects[end_id, "type"] != TYPE_INT) error("range expects integer argument")
        end_val = objects[end_id, "value"]
    } else {
        start_id = args[1]
        end_id = args[2]
        if (objects[start_id, "type"] != TYPE_INT || objects[end_id, "type"] != TYPE_INT) error("range expects integer arguments")
        start_val = objects[start_id, "value"]
        end_val = objects[end_id, "value"]
    }

    for (i = start_val; i < end_val; i++) {
        element_ids[i - start_val + 1] = create_value(TYPE_INT, i)
    }

    array_id = create_array(element_ids, end_val - start_val)
    debug_msg("range: created array with " (end_val - start_val) " elements")
    return array_id
}

function create_instance(type_id, constructor_args, argc,   inst_id, i, prop_count, prop_node, prop_name, prop_value, obj_node) {
    debug_msg("Creating instance of type " objects[type_id, "type"])
    inst_id = ++object_counter
    objects[inst_id, "type"] = TYPE_STRUCT
    objects[inst_id, "properties_count"] = 0
    objects[inst_id, "prototype"] = type_id
    if (objects[type_id, "type"] == TYPE_STRUCT) {
        if (argc != 1 || ast_nodes[constructor_args[1], "type"] != "ObjectExpression") {
            error("Struct instantiation requires a single object literal argument")
        }
        obj_node = constructor_args[1]
        prop_count = ast_nodes[obj_node, "properties_count"]
        for (i = 1; i <= prop_count; i++) {
            prop_node = ast_nodes[obj_node, "property_" i]
            prop_name = ast_nodes[prop_node, "key"]
            prop_value = execute(ast_nodes[prop_node, "value"])
            objects[inst_id, "prop_key_" i] = prop_name
            objects[inst_id, "prop_value_" i] = prop_value
        }
        objects[inst_id, "properties_count"] = prop_count
    } else {
        error("Cannot instantiate non-struct type")
    }
    register_object(inst_id)
    return inst_id
}

function parse_lambda(   lambda_node, param_count) {
    debug_msg("Parsing lambda expression")

    lambda_node = ++ast_node_counter
    ast_nodes[lambda_node, "type"] = "LambdaExpression"

    expect_token("KEYWORD", "lambda")

    param_count = 0

    while (get_token_value() != ":") {
        debug_msg("Lambda param loop: token_type=" get_token_type() " token_value=[" get_token_value() "]")
        
        if (get_token_type() != "IDENTIFIER") {
            error("Expected parameter name in lambda, got " get_token_type() " '" get_token_value() "'")
        }

        ast_nodes[lambda_node, "param_" param_count] = get_token_value()
        debug_msg("Added lambda param: " get_token_value())
        param_count++
        advance_token()

        debug_msg("After advance: token_type=" get_token_type() " token_value=[" get_token_value() "]")

        if (get_token_value() == ",") {
            advance_token()
        } else if (get_token_value() != ":") {
            error("Expected , or : in lambda, got '" get_token_value() "' (length=" length(get_token_value()) ")")
        }
    }

    ast_nodes[lambda_node, "param_count"] = param_count

    debug_msg("About to expect : token")
    expect_token("OPERATOR", ":")

    ast_nodes[lambda_node, "body"] = parse_assignment()

    debug_msg("Lambda parsed with " param_count " parameters")

    return lambda_node
}

# @doc [functions]
# Creates a closure object for a given function definition within a specific scope.
# examples:
# fn external() {
#   fn internal() {
#       return "internal value";
#   }
#   internal();
# }
function create_closure(func_def_id, closure_scope_id,   closure_id) {
    debug_msg("Creating closure for function definition " func_def_id " with closure scope " closure_scope_id)
    closure_id = ++object_counter
    objects[closure_id, "type"] = TYPE_FUNCTION
    objects[closure_id, "definition"] = func_def_id
    objects[closure_id, "closure_scope"] = closure_scope_id
    objects[closure_id, "is_closure"] = 1

    register_object(closure_id)
    debug_msg("Created closure with id " closure_id)
    return closure_id
}

function parse_array_literal(   array_node, elem_node, count) {
    debug_msg("Parsing array literal")
    array_node = ++ast_node_counter
    ast_nodes[array_node, "type"] = "ArrayExpression"
    ast_nodes[array_node, "elements_count"] = 0

    advance_token()

    count = 0
    while (get_token_value() != "]") {
        elem_node = parse_expression()
        ast_nodes[array_node, "element_" ++count] = elem_node
        ast_nodes[array_node, "elements_count"] = count

        if (get_token_value() == ",") {
            advance_token()
        }
    }

    expect_token("DELIMITER", "]")
    return array_node
}

# @doc [arrays]
# Create new array
# examples:
# let int_arr = [1, 2, 3]; # int array
# let combined_array = [1, "some-string", [8734, "kek"]]; combined array
function create_array(element_ids, count,   array_id, i) {
    debug_msg("Creating array with " count " elements")
    array_id = ++object_counter
    objects[array_id, "type"] = TYPE_ARRAY
    objects[array_id, "length"] = count

    for (i = 1; i <= count; i++) {
        objects[array_id, "element_" (i-1)] = element_ids[i]
    }

    register_object(array_id)
    return array_id
}

function parse_object_literal(   obj_node, key, value_node, prop_node) {
    debug_msg("Parsing object literal")
    obj_node = ++ast_node_counter
    ast_nodes[obj_node, "type"] = "ObjectExpression"
    ast_nodes[obj_node, "properties_count"] = 0
    advance_token()

    while (get_token_value() != "}") {
        if (get_token_type() == "IDENTIFIER" || get_token_type() == "STRING") {
            key = get_token_value()
            if (get_token_type() == "STRING") {
                key = unescape_string(substr(key, 2, length(key) - 2))
            }
            advance_token()
            expect_token("OPERATOR", "=")
            value_node = parse_expression()
            prop_node = ++ast_node_counter
            ast_nodes[prop_node, "type"] = "Property"
            ast_nodes[prop_node, "key"] = key
            ast_nodes[prop_node, "value"] = value_node
            ast_nodes[obj_node, "property_" ++ast_nodes[obj_node, "properties_count"]] = prop_node
            if (get_token_value() == ",") {
                advance_token()
            }
        } else {
            error("Expected identifier or string for object property key")
        }
    }
    expect_token("DELIMITER", "}")
    return obj_node
}

# @doc [control_flow]
# Try-catch statement
# examples:
# try {
#   let result = riskyOperation();
# } catch (error) {
#   print("Error: " + error);
# }
function parse_try_statement(   try_node) {
    debug_msg("Parsing try statement")
    try_node = ++ast_node_counter
    ast_nodes[try_node, "type"] = "TryStatement"
    advance_token()

    ast_nodes[try_node, "block"] = parse_block_statement()

    if (get_token_value() == "catch") {
        advance_token()
        expect_token("DELIMITER", "(")
        ast_nodes[try_node, "param"] = get_token_value()
        advance_token()
        expect_token("DELIMITER", ")")
        ast_nodes[try_node, "handler"] = parse_block_statement()
    }

    if (get_token_value() == "finally") {
        advance_token()
        ast_nodes[try_node, "finalizer"] = parse_block_statement()
    }

    return try_node
}

ERROR_ID = -1

function execute_with_error_check(node,   old_error_state, temp_result) {
    debug_msg("Executing node with error check: " node)
    old_error_state = error_occurred
    error_occurred = 0
    last_exception = ""

    temp_result = execute(node)
    if (error_occurred) {
        error_occurred = old_error_state
        return ERROR_ID
    } else {
        error_occurred = old_error_state
        return temp_result
    }
}

function execute_try_statement(try_node,   old_exception_handler, result_id, exception_occurred, exception_value, old_scope_id, block_result, handler_result, finalizer_result) {
    debug_msg("Executing try statement")
    old_exception_handler = current_exception_handler
    current_exception_handler = try_node

    result_id = create_value(TYPE_NULL, "null")
    exception_occurred = 0
    exception_value = ""

    block_result = execute_with_error_check(ast_nodes[try_node, "block"])
    if (block_result == ERROR_ID) {
        exception_occurred = 1
        exception_value = last_exception
        result_id = create_value(TYPE_NULL, "null")
    } else {
        result_id = block_result
    }

    if (exception_occurred && ast_nodes[try_node, "handler"] != "") {
        old_scope_id = current_scope_id
        current_scope_id = new_scope(current_scope_id)

        if (ast_nodes[try_node, "param"] != "") {
            declare_variable(ast_nodes[try_node, "param"], create_value(TYPE_STRING, exception_value))
        }

        handler_result = execute_with_error_check(ast_nodes[try_node, "handler"])
        if (handler_result != ERROR_ID) {
            result_id = handler_result
        }
        current_scope_id = old_scope_id

        exception_occurred = 0
    }

    if (ast_nodes[try_node, "finalizer"] != "") {
        finalizer_result = execute_with_error_check(ast_nodes[try_node, "finalizer"])
    }

    current_exception_handler = old_exception_handler

    if (exception_occurred) {
        error(exception_value)
    }

    return result_id
}

# @doc [imports]
# Import declaration, adds it to the current program.
# examples:
# import math   # import math module
# import system as sys  # import system module with alias
# import my_module  # import custom user modele
function parse_import(   import_node, module_name, alias_name, expr_stmt_node) {
    debug_msg("Parsing import declaration")
    import_node = ++ast_node_counter
    ast_nodes[import_node, "type"] = "ImportDeclaration"
    advance_token()
    module_name = get_token_value()
    advance_token()

    while (get_token_value() == ".") {
        module_name = module_name "."
        advance_token()
        module_name = module_name get_token_value()
        advance_token()
    }

    alias_name = ""

    if (get_token_value() == "as") {
        advance_token()
        alias_name = get_token_value()
        debug_msg("Parsed alias: '" alias_name "'")
        advance_token()
    } else {
        debug_msg("No 'as' keyword found")
    }

    ast_nodes[import_node, "source"] = module_name
    ast_nodes[import_node, "default"] = alias_name

    debug_msg("Parsed import: source='" module_name "' alias='" alias_name "'")

    if ((module_name) in BUILTIN_MODULES) {
        ast_nodes[import_node, "builtin"] = 1
        debug_msg("Using builtin module: " module_name)
    } else {
        ast_nodes[import_node, "builtin"] = 0
        debug_msg("Using user module: " module_name)
    }

    expr_stmt_node = ++ast_node_counter
    ast_nodes[expr_stmt_node, "type"] = "ExpressionStatement"
    ast_nodes[expr_stmt_node, "expression"] = import_node

    return expr_stmt_node
}

function execute_import_declaration(node,   module_name, default_name, value_id) {
    debug_msg("Executing import declaration")
    module_name = ast_nodes[node, "source"]

    if (ast_nodes[node, "builtin"]) {
        value_id = init_custom_builtins(module_name)
    } else {
        value_id = load_user_module(module_name)
    }

    default_name = ast_nodes[node, "default"]

    if (default_name == "") default_name = module_name
    declare_variable(default_name, value_id)
    return create_value(TYPE_NULL, "null")
}

function load_user_module(module_name,   file_path, code, 
                          saved_tokens, saved_token_count, saved_ast_nodes, saved_ast_counter, saved_current_token,
                          token_count, prog_node, saved_scope, module_scope_id, 
                          module_obj_id, i, key) {

    debug_msg("Loading user module: " module_name)

    file_path = resolve_module_path(module_name)

    code = read_file(file_path)
    if (code == "") {
        error("Cannot read module file: " file_path)
    }

    saved_token_count = token_count
    saved_ast_counter = ast_node_counter
    saved_current_token = current_token

    for (i = 1; i <= token_count; i++) {
        saved_tokens[i, "type"] = tokens[i, "type"]
        saved_tokens[i, "value"] = tokens[i, "value"]
    }

    for (key in ast_nodes) {
        saved_ast_nodes[key] = ast_nodes[key]
    }

    token_count = tokenize(code)
    prog_node = parse(tokens, token_count)

    saved_scope = current_scope_id
    module_scope_id = ++scope_counter
    scopes[module_scope_id, "parent"] = global_scope_id
    scopes[module_scope_id, "variables_count"] = 0
    current_scope_id = module_scope_id

    debug_msg("Created module scope: " module_scope_id)

    execute(prog_node)
    debug_msg("After executing module, checking scope " module_scope_id)

    module_obj_id = collect_module_variables(module_scope_id)
    current_scope_id = saved_scope

    delete tokens
    for (i = 1; i <= saved_token_count; i++) {
        tokens[i, "type"] = saved_tokens[i, "type"]
        tokens[i, "value"] = saved_tokens[i, "value"]
    }
    token_count = saved_token_count
    current_token = saved_current_token

    for (key in ast_nodes) {
        saved_ast_nodes[key] = ast_nodes[key]
    }

    delete ast_nodes
    for (key in saved_ast_nodes) {
        ast_nodes[key] = saved_ast_nodes[key]
    }

    debug_msg("Loaded module: " module_name " as object " module_obj_id)
    return module_obj_id
}

function collect_module_variables(scope_id,   obj_id, key, var_name, var_value, prop_count, pattern) {
    debug_msg("Collecting variables from module scope " scope_id)

    pattern = "^" scope_id SUBSEP "var_"
    debug_msg("Looking for pattern: '" pattern "'")

    obj_id = ++object_counter
    objects[obj_id, "type"] = TYPE_OBJECT
    objects[obj_id, "value"] = ""

    prop_count = 0
    for (key in scopes) {
        if (key ~ pattern) {
            prop_count++
        }
    }

    objects[obj_id, "properties_count"] = prop_count
    debug_msg("Module has " prop_count " properties")

    prop_count = 0
    for (key in scopes) {
        if (key ~ pattern) {
            var_name = key
            sub(pattern, "", var_name)
            var_value = scopes[key]

            prop_count++
            objects[obj_id, "prop_key_" prop_count] = var_name
            objects[obj_id, "prop_value_" prop_count] = var_value
        }
    }

    register_object(obj_id)
    debug_msg("Created module object " obj_id " with " prop_count " properties")
    return obj_id
}

function resolve_module_path(module_name,   path, lib_path) {
    gsub("\\.", "/", module_name)

    if (module_name ~ /\.awkward$/) {
        path = module_name
    } else {
        path = module_name ".awkward"
    }

    if (!file_exists(path) && AWKWARD_LIBDIR != "") {
        lib_path = AWKWARD_LIBDIR "/" path
        if (file_exists(lib_path)) {
            path = lib_path
        }
    }

    debug_msg("Resolved module path: " path)

    return path
}

function file_exists(filename,   ret, line) {
    ret = (getline line < filename)
    close(filename)
    return (ret >= 0)
}

function parse_block_statement(   block_node, stmt_node) {
    debug_msg("Parsing block statement")
    block_node = ++ast_node_counter
    ast_nodes[block_node, "type"] = "BlockStatement"
    ast_nodes[block_node, "body_count"] = 0

    expect_token("DELIMITER", "{")

    while (get_token_value() != "}") {
        stmt_node = parse_statement()
        if (stmt_node != "") {
            ast_nodes[block_node, "body_" ++ast_nodes[block_node, "body_count"]] = stmt_node
            debug_msg("Added to block " block_node ": node " stmt_node " of type " ast_nodes[stmt_node, "type"] (ast_nodes[stmt_node, "name"] ? " name " ast_nodes[stmt_node, "name"] : ""))
        }
    }

    expect_token("DELIMITER", "}")
    return block_node
}

function execute_block_statement(block_node,   old_scope_id, result_id, i, n) {
    debug_msg("Executing block statement")
    old_scope_id = current_scope_id
    current_scope_id = new_scope(current_scope_id)

    result_id = create_value(TYPE_NULL, "null")
    n = ast_nodes[block_node, "body_count"]

    for (i = 1; i <= n; i++) {
        result_id = execute(ast_nodes[block_node, "body_" i])
        if (return_value_set || break_flag || continue_flag || error_occurred)
            break
    }

    current_scope_id = old_scope_id
    return result_id
}

# @doc [control_flow]
# Return statement, optionally with an expression to return.
# examples:
# return;   # just return
# return 42;    # return some value
# return x + y; # return result
function parse_return_statement(   ret_node) {
    debug_msg("Parsing return statement")
    ret_node = ++ast_node_counter
    ast_nodes[ret_node, "type"] = "ReturnStatement"
    advance_token()

    if (get_token_value() != ";") {
        ast_nodes[ret_node, "argument"] = parse_expression()
    }

    expect_token("DELIMITER", ";")
    return ret_node
}

function execute_return_statement(ret_node,   arg_id) {
    debug_msg("Executing return statement")
    arg_id = ast_nodes[ret_node, "argument"]

    if (arg_id != "") {
        return_value = execute(arg_id)
    } else {
        return_value = create_value(TYPE_NULL, "null")
    }

    return_value_set = 1
    return return_value
}

# @doc [control_flow]
# if statement, including optional else and chained else-if branches
# examples:
# if (x > 0) {
#   print(x);
# } else {
#   print(-x);
# }
# if (y == 0) {
#   return;
# }
# if (score >= 90) {
#   print("A");
# } else if (score >= 80) {
#   print("B");
# } else {
#   print("F");
# }
function parse_if_statement(   if_node) {
    debug_msg("Parsing if statement")
    if_node = ++ast_node_counter
    ast_nodes[if_node, "type"] = "IfStatement"
    advance_token()

    expect_token("DELIMITER", "(")
    ast_nodes[if_node, "test"] = parse_expression()
    expect_token("DELIMITER", ")")

    ast_nodes[if_node, "consequent"] = parse_block_statement()

    if (get_token_value() == "else") {
        advance_token()
        if (get_token_type() == "KEYWORD" && get_token_value() == "if") {
            ast_nodes[if_node, "alternate"] = parse_if_statement()
        } else {
            ast_nodes[if_node, "alternate"] = parse_block_statement()
        }
    }

    return if_node
}

function execute_if_statement(if_node,   test_id, test_val_id, result_id) {
    debug_msg("Executing if statement")
    test_id = ast_nodes[if_node, "test"]
    test_val_id = execute(test_id)
    if (to_bool(test_val_id)) {
        result_id = execute(ast_nodes[if_node, "consequent"])
    } else if (ast_nodes[if_node, "alternate"] != "") {
        result_id = execute(ast_nodes[if_node, "alternate"])
    } else {
        result_id = create_value(TYPE_NULL, "null")
    }
    return result_id
}

# @doc [control_flow]
# While statement, executes a block while the condition is true.
# examples:
# while (x > 0) {
#     print(x);
#     x = x - 1;
# }
# while (i < 10) {
#     doSomething(i);
#     i = i + 1;
# }
function parse_while_statement(   while_node) {
    debug_msg("Parsing while statement")
    while_node = ++ast_node_counter
    ast_nodes[while_node, "type"] = "WhileStatement"
    advance_token()

    expect_token("DELIMITER", "(")
    ast_nodes[while_node, "test"] = parse_expression()
    expect_token("DELIMITER", ")")

    ast_nodes[while_node, "body"] = parse_block_statement()

    return while_node
}

# @doc [control_flow]
# For-in statement, iterates over elements of an array or iterable object.
# examples:
# for (let x in [1, 2, 3]) {
#     print(x);
# }
# for (let item in myArray) {
#     process(item);
# }
function parse_for_statement(   for_node) {
    debug_msg("Parsing for-in statement")
    for_node = ++ast_node_counter
    ast_nodes[for_node, "type"] = "ForInStatement"

    advance_token()
    expect_token("DELIMITER", "(")
    expect_token("KEYWORD", "let")

    if (get_token_type() != "IDENTIFIER")
        error("Expected identifier in for loop")
    var_name = get_token_value()
    ast_nodes[for_node, "id"] = var_name
    advance_token()

    expect_token("KEYWORD", "in")

    arr_expr = parse_expression()
    ast_nodes[for_node, "iterable"] = arr_expr

    expect_token("DELIMITER", ")")

    ast_nodes[for_node, "body"] = parse_block_statement()

    return for_node
}

function execute_while_statement(while_node,   test_id, body_id, test_val_id, result_id) {
    debug_msg("Executing while statement")
    result_id = create_value(TYPE_NULL, "null")
    test_id = ast_nodes[while_node, "test"]
    body_id = ast_nodes[while_node, "body"]
    while (1) {
        test_val_id = execute(test_id)
        if (!to_bool(test_val_id)) break
        result_id = execute(body_id)
        if (control_flow_active()) {
            if (continue_flag) {
                continue_flag = 0
                continue
            }
            if (break_flag) {
                break_flag = 0
                break
            }
            if (return_value_set || error_occurred) break
        }
    }
    return result_id
}

function execute_for_in_statement(for_node,   var_name, iterable_node, iterable_val_id,
                                  body_node, result_id, i, var_id, parent_scope_id, loop_scope_id) {
    debug_msg("Executing for-in statement")

    result_id = create_value(TYPE_NULL, "null")

    var_name = ast_nodes[for_node, "id"]
    iterable_node = ast_nodes[for_node, "iterable"]
    body_node = ast_nodes[for_node, "body"]

    iterable_val_id = execute(iterable_node)

    if (objects[iterable_val_id, "type"] == TYPE_VARIABLE)
        iterable_val_id = objects[iterable_val_id, "value"]

    if (objects[iterable_val_id, "type"] != TYPE_ARRAY && objects[iterable_val_id, "type"] != TYPE_STRUCT) {
        runtime_error("Cannot iterate over non-array or non-struct value in for-in loop")
        return result_id
    }

    parent_scope_id = current_scope_id

    loop_scope_id = ++scope_counter
    scopes[loop_scope_id, "parent"] = parent_scope_id
    scopes[loop_scope_id, "variables_count"] = 0

    old_scope_id = current_scope_id
    current_scope_id = loop_scope_id
    var_id = create_value(objects[iterable_val_id, "type"] == TYPE_ARRAY ? TYPE_INT : TYPE_STRING, 0)
    declare_variable(var_name, var_id)
    current_scope_id = old_scope_id

    if (objects[iterable_val_id, "type"] == TYPE_ARRAY) {
        for (i = 0; i < objects[iterable_val_id, "length"]; i++) {
            debug_msg("Iterating array index " i)
            objects[var_id, "value"] = i
            current_scope_id = loop_scope_id
            execute(body_node)
            current_scope_id = parent_scope_id
            if (control_flow_active()) {
                if (continue_flag) {
                    continue_flag = 0
                    continue
                }
                if (break_flag) {
                    break_flag = 0
                    break
                }
                if (return_value_set || error_occurred) break
            }
        }
    } else if (objects[iterable_val_id, "type"] == TYPE_STRUCT) {
        for (i = 1; i <= objects[iterable_val_id, "properties_count"]; i++) {
            debug_msg("Iterating struct key " objects[iterable_val_id, "prop_key_" i])
            objects[var_id, "value"] = objects[iterable_val_id, "prop_key_" i]
            current_scope_id = loop_scope_id
            execute(body_node)
            current_scope_id = parent_scope_id
            if (control_flow_active()) {
                if (continue_flag) {
                    continue_flag = 0
                    continue
                }
                if (break_flag) {
                    break_flag = 0
                    break
                }
                if (return_value_set || error_occurred) break
            }
        }
    }

    current_scope_id = parent_scope_id
    return result_id
}

function to_bool(val_id,   type, val) {
    type = objects[val_id, "type"]
    val = objects[val_id, "value"]
    if (type == TYPE_NULL) return 0
    if (type == TYPE_BOOL) return val
    if (type == TYPE_INT || type == TYPE_FLOAT) return (val != 0)
    if (type == TYPE_STRING) return (length(val) > 0)
    return 1
}

# @doc [functions]
# Declares a function with a name and parameters.
# examples:
# fn add(a, b) {
#     return a + b;
# }
# fn greet(name) {
#     print("Hello, " + name);
# }
function parse_function_declaration(   func_node) {
    debug_msg("Parsing function declaration")
    func_node = ++ast_node_counter
    ast_nodes[func_node, "type"] = "FunctionDeclaration"
    advance_token()

    ast_nodes[func_node, "name"] = get_token_value()
    advance_token()

    expect_token("DELIMITER", "(")
    ast_nodes[func_node, "params_count"] = 0

    while (get_token_value() != ")") {
        if (get_token_type() == "IDENTIFIER") {
            ast_nodes[func_node, "param_" ++ast_nodes[func_node, "params_count"]] = get_token_value()
            advance_token()
            if (get_token_value() == ",") advance_token()
        }
    }
    advance_token()

    ast_nodes[func_node, "body"] = parse_block_statement()

    return func_node
}

function execute_function_declaration(func_node,   func_name, func_id) {
    debug_msg("Executing function declaration for " ast_nodes[func_node, "name"])
    func_name = ast_nodes[func_node, "name"]
    func_id = create_closure(func_node, current_scope_id)
    objects[func_id, "name"] = func_name
    declare_variable(func_name, func_id)
    return create_value(TYPE_NULL, "null")
}

function call_function(func_id, args, argc,   func_def, closure_scope, old_scope_id, i, param_name, arg_val, body_id, result_id, old_return_value_set, old_return_value, body_count, bi) {
    debug_msg("Calling function with id " func_id)
    func_def = objects[func_id, "definition"]
    closure_scope = objects[func_id, "closure_scope"]
    old_scope_id = current_scope_id
    current_scope_id = new_scope(closure_scope)
    if (objects[func_id, "self"] != "") {
        declare_variable("self", objects[func_id, "self"])
        debug_msg("Bound 'self' to instance " objects[func_id, "self"])
    }
    for (i = 1; i <= ast_nodes[func_def, "params_count"]; i++) {
        param_name = ast_nodes[func_def, "param_" i]
        arg_val = (i <= argc) ? args[i] : create_value(TYPE_NULL, "null")
        declare_variable(param_name, arg_val)
    }
    call_stack[++call_stack_size, "scope"] = current_scope_id
    old_return_value_set = return_value_set
    old_return_value = return_value
    return_value_set = 0
    body_id = ast_nodes[func_def, "body"]
    if (ast_nodes[body_id, "type"] == "BlockStatement") {
        body_count = ast_nodes[body_id, "body_count"]
        for (bi = 1; bi <= body_count; bi++) {
            result_id = execute(ast_nodes[body_id, "body_" bi])
            if (return_value_set || break_flag || continue_flag || error_occurred)
                break
        }
    } else {
        result_id = execute(body_id)
    }
    if (return_value_set) {
        result_id = return_value
    }
    return_value_set = old_return_value_set
    return_value = old_return_value
    delete call_stack[call_stack_size]
    call_stack_size--
    current_scope_id = old_scope_id
    return result_id ? result_id : create_value(TYPE_NULL, "null")
}

function parse_expression_statement(   expr_stmt_node) {
    debug_msg("Parsing expression statement")
    expr_stmt_node = ++ast_node_counter
    ast_nodes[expr_stmt_node, "type"] = "ExpressionStatement"
    ast_nodes[expr_stmt_node, "expression"] = parse_expression()

    if (get_token_value() == ";") {
        advance_token()
    }

    return expr_stmt_node
}

# @doc [expressions]
# Logical OR expression `||`
# examples:
# let result = a || b;
# let combined = (x > 0) || (y < 5);
function parse_logical_or(   lor_left, op, lor_right, lor_node) {
    lor_left = parse_logical_and()

    while (get_token_value() == "||") {
        op = get_token_value()
        advance_token()
        lor_right = parse_logical_and()

        lor_node = ++ast_node_counter
        ast_nodes[lor_node, "type"] = "BinaryExpression"
        ast_nodes[lor_node, "operator"] = op
        ast_nodes[lor_node, "left"] = lor_left
        ast_nodes[lor_node, "right"] = lor_right
        lor_left = lor_node
    }

    return lor_left
}

# @doc [expressions]
# Logical AND expression `&&`
# examples:
# let result = a && b;
# let combined = (x > 0) && (y < 5);
function parse_logical_and(   land_left, op, land_right, land_node) {
    land_left = parse_equality()

    while (get_token_value() == "&&") {
        op = get_token_value()
        advance_token()
        land_right = parse_equality()

        land_node = ++ast_node_counter
        ast_nodes[land_node, "type"] = "BinaryExpression"
        ast_nodes[land_node, "operator"] = op
        ast_nodes[land_node, "left"] = land_left
        ast_nodes[land_node, "right"] = land_right
        land_left = land_node
    }

    return land_left
}

# @doc [expressions]
# Equality expression, supporting '==' and '!=' operators.
# examples:
# let result = a == b;
# let result = x != y;
# let flag = (a + b) == (c * d);
function parse_equality(   eq_left, op, eq_right, eq_node) {
    debug_msg("Parsing equality expression")
    eq_left = parse_relational()

    while (get_token_value() == "==" || get_token_value() == "!=") {
        op = get_token_value()
        advance_token()
        eq_right = parse_relational()

        eq_node = ++ast_node_counter
        ast_nodes[eq_node, "type"] = "BinaryExpression"
        ast_nodes[eq_node, "operator"] = op
        ast_nodes[eq_node, "left"] = eq_left
        ast_nodes[eq_node, "right"] = eq_right
        eq_left = eq_node
    }

    return eq_left
}

# @doc [expressions]
# Relational expression, supporting '<', '>', '<=', and '>=' operators.
# examples:
# let is_greater = a > b;
# let is_smaller_or_equal = x <= y;
# let result = (a + b) >= (c - d);
function parse_relational(   rel_left, op, rel_right, rel_node) {
    rel_left = parse_additive()

    while (get_token_value() == "<" || get_token_value() == ">" ||
           get_token_value() == "<=" || get_token_value() == ">=") {
        op = get_token_value()
        advance_token()
        rel_right = parse_additive()

        rel_node = ++ast_node_counter
        ast_nodes[rel_node, "type"] = "BinaryExpression"
        ast_nodes[rel_node, "operator"] = op
        ast_nodes[rel_node, "left"] = rel_left
        ast_nodes[rel_node, "right"] = rel_right
        rel_left = rel_node
    }

    return rel_left
}

# @doc [expressions]
# Additive expression, supporting '+' and '-' operators.
# examples:
# let result = a + b;
# let total = x - y;
# let value = (a + b) - (c + d);
function parse_additive(   add_left, op, add_right, add_node) {
    add_left = parse_multiplicative()

    while (get_token_value() == "+" || get_token_value() == "-") {
        op = get_token_value()
        advance_token()
        add_right = parse_multiplicative()

        add_node = ++ast_node_counter
        ast_nodes[add_node, "type"] = "BinaryExpression"
        ast_nodes[add_node, "operator"] = op
        ast_nodes[add_node, "left"] = add_left
        ast_nodes[add_node, "right"] = add_right
        add_left = add_node
    }

    return add_left
}

# @doc [expressions]
# Multiplicative expression, supporting '*', '/', and '%' operators.
# examples:
# let product = a * b;
# let quotient = x / y;
# let remainder = n % 3;
function parse_multiplicative(   mul_left, op, mul_right, mul_node) {
    mul_left = parse_unary()

    while (get_token_value() == "*" || get_token_value() == "/" || get_token_value() == "%") {
        op = get_token_value()
        advance_token()
        mul_right = parse_unary()

        mul_node = ++ast_node_counter
        ast_nodes[mul_node, "type"] = "BinaryExpression"
        ast_nodes[mul_node, "operator"] = op
        ast_nodes[mul_node, "left"] = mul_left
        ast_nodes[mul_node, "right"] = mul_right
        mul_left = mul_node
    }

    return mul_left
}

# @doc [expressions]
# Unary expression, supporting the '!' (logical not) and '-' (negation) prefix operators.
# examples:
# let flag = !found;
# let neg = -x;
# let double_negated = !!flag;
# if (!ready) { print("not ready"); }
function parse_unary(   op, unary_node, operand) {
    if (get_token_value() == "!" || get_token_value() == "-") {
        op = get_token_value()
        advance_token()
        operand = parse_unary()

        unary_node = ++ast_node_counter
        ast_nodes[unary_node, "type"] = "UnaryExpression"
        ast_nodes[unary_node, "operator"] = op
        ast_nodes[unary_node, "argument"] = operand
        return unary_node
    }

    return parse_primary()
}

function create_identifier_node(name,   id_node) {
    id_node = ++ast_node_counter
    ast_nodes[id_node, "type"] = "Identifier"
    ast_nodes[id_node, "name"] = name
    return id_node
}

function parse_primary(   prim_type, prim_value, prim_node, left, name, expr, op, member_node, call_node, arg_node) {
    prim_type = get_token_type()
    prim_value = get_token_value()

    while (prim_type == "COMMENT") {
        advance_token()
        prim_type = get_token_type()
        prim_value = get_token_value()
    }

    if (prim_type == "KEYWORD" && prim_value == "lambda") {
        return parse_lambda()
    }

    if (prim_type == "KEYWORD" && prim_value == "new") {
        advance_token()
        if (get_token_type() != "IDENTIFIER") {
            error("Expected identifier after 'new'")
        }
        name = get_token_value()
        callee_node = create_identifier_node(name)
        advance_token()

        while (get_token_value() == ".") {
            advance_token()
            if (get_token_type() != "IDENTIFIER") {
                error("Expected identifier after '.'")
            }
            property_name = get_token_value()

            member_node = ++ast_node_counter
            ast_nodes[member_node, "type"] = "MemberExpression"
            ast_nodes[member_node, "object"] = callee_node
            ast_nodes[member_node, "property"] = create_identifier_node(property_name)
            ast_nodes[member_node, "computed"] = 0

            callee_node = member_node
            advance_token()
        }

        call_node = ++ast_node_counter
        ast_nodes[call_node, "type"] = "CallExpression"
        ast_nodes[call_node, "callee_node"] = callee_node
        ast_nodes[call_node, "args_count"] = 0
        if (get_token_value() == "{") {
            arg_node = parse_object_literal()
            ast_nodes[call_node, "arg_" ++ast_nodes[call_node, "args_count"]] = arg_node
        } else if (get_token_value() == "(") {
            advance_token()
            while (get_token_value() != ")") {
                arg_node = parse_expression()
                ast_nodes[call_node, "arg_" ++ast_nodes[call_node, "args_count"]] = arg_node
                if (get_token_value() == ",") advance_token()
            }
            advance_token()
        }
        return call_node
    } else if (prim_type == "KEYWORD" && (prim_value == "true" || prim_value == "false" || prim_value == "null")) {
        advance_token()
        prim_node = ++ast_node_counter
        ast_nodes[prim_node, "type"] = "Literal"
        if (prim_value == "null") {
            ast_nodes[prim_node, "value_type"] = TYPE_NULL
            ast_nodes[prim_node, "value"] = "null"
        } else {
            ast_nodes[prim_node, "value_type"] = TYPE_BOOL
            ast_nodes[prim_node, "value"] = (prim_value == "true" ? 1 : 0)
        }
        left = prim_node
    } else if (prim_type == "NUMBER") {
        advance_token()
        prim_node = ++ast_node_counter
        ast_nodes[prim_node, "type"] = "Literal"
        if (index(prim_value, ".") > 0) {
            ast_nodes[prim_node, "value_type"] = TYPE_FLOAT
        } else {
            ast_nodes[prim_node, "value_type"] = TYPE_INT
        }
        ast_nodes[prim_node, "value"] = prim_value + 0
        left = prim_node
    } else if (prim_type == "STRING") {
        advance_token()
        prim_node = ++ast_node_counter
        ast_nodes[prim_node, "type"] = "Literal"
        ast_nodes[prim_node, "value_type"] = TYPE_STRING
        ast_nodes[prim_node, "value"] = unescape_string(substr(prim_value, 2, length(prim_value) - 2))
        left = prim_node
    } else if (prim_type == "IDENTIFIER") {
        name = prim_value
        advance_token()
        left = create_identifier_node(name)
    } else if (prim_value == "(") {
        advance_token()
        left = parse_expression()
        expect_token("DELIMITER", ")")
    } else if (prim_value == "[") {
        left = parse_array_literal()
    } else if (prim_value == "{") {
        left = parse_object_literal()
    } else if (prim_type == "KEYWORD" && prim_value == "import") {
        import_node = parse_import()
        expr_node = ++ast_node_counter
        ast_nodes[expr_node, "type"] = "ExpressionStatement"
        ast_nodes[expr_node, "expression"] = import_node
        left = expr_node
    } else {
        error("Unexpected token: " prim_value)
    }

    while (1) {
        if (get_token_value() == "(") {
            call_node = ++ast_node_counter
            ast_nodes[call_node, "type"] = "CallExpression"
            ast_nodes[call_node, "callee_node"] = left
            ast_nodes[call_node, "args_count"] = 0
            advance_token()
            while (get_token_value() != ")") {
                arg_node = parse_expression()
                ast_nodes[call_node, "arg_" ++ast_nodes[call_node, "args_count"]] = arg_node
                if (get_token_value() == ",") advance_token()
            }
            advance_token()
            left = call_node
        } else if (get_token_value() == "{") {
            call_node = ++ast_node_counter
            ast_nodes[call_node, "type"] = "CallExpression"
            ast_nodes[call_node, "callee_node"] = left
            ast_nodes[call_node, "args_count"] = 0
            
            arg_node = parse_object_literal()
            ast_nodes[call_node, "arg_" ++ast_nodes[call_node, "args_count"]] = arg_node
            
            left = call_node
        } else if (get_token_value() == "[" || get_token_value() == ".") {
            op = get_token_value()
            advance_token()
            member_node = ++ast_node_counter
            ast_nodes[member_node, "type"] = "MemberExpression"
            ast_nodes[member_node, "object"] = left
            ast_nodes[member_node, "computed"] = (op == "[")
            if (ast_nodes[member_node, "computed"]) {
                ast_nodes[member_node, "property"] = parse_expression()
                expect_token("DELIMITER", "]")
            } else {
                if (get_token_type() != "IDENTIFIER") error("Expected identifier after .")
                ast_nodes[member_node, "property"] = create_identifier_node(get_token_value())
                advance_token()
            }
            left = member_node
        } else {
            break
        }
    }
    return left
}

function value_to_string(val_id,   type, str, i, len) {
    if (val_id + 0 != val_id) return val_id
    type = objects[val_id, "type"]
    if (type == TYPE_STRING) {
        return objects[val_id, "value"]
    } else if (type == TYPE_NULL) {
        return "null"
    } else if (type == TYPE_BOOL) {
        return objects[val_id, "value"] ? "true" : "false"
    } else if (type == TYPE_ARRAY) {
        str = "["
        len = objects[val_id, "length"]
        for (i = 0; i < len; i++) {
            if (i > 0) str = str ", "
            str = str value_to_string(objects[val_id, "element_" i])
        }
        str = str "]"
        return str
    } else if (type == TYPE_OBJECT || type == TYPE_STRUCT) {
        str = "{"
        len = objects[val_id, "properties_count"]
        for (i = 1; i <= len; i++) {
            if (i > 1) str = str ", "
            str = str objects[val_id, "prop_key_" i] ": " value_to_string(objects[val_id, "prop_value_" i])
        }
        str = str "}"
        return str
    } else if (type == TYPE_ENUM) {
        return objects[val_id, "enum_name"] "." objects[val_id, "variant_name"]
    }
    return objects[val_id, "value"] + ""
}

function error(message) {
    if (current_exception_handler != "") {
        error_occurred = 1
        last_exception = message
        debug_msg("Error occurred: " message)
        return
    }

    print "Error: " message > "/dev/stderr"
    exit(1)
}

function init_error_handling() {
    error_occurred = 0
    last_exception = ""
    current_exception_handler = ""
}

function control_flow_active() {
    return (return_value_set || break_flag || continue_flag || error_occurred)
}

function advance_token() {
    current_token++
}

function get_token_type(   token_str, colon_pos) {
    if (current_token < 1 || current_token > length(tokens)) return ""
    
    token_str = tokens[current_token]
    colon_pos = index(token_str, ":")
    
    if (colon_pos == 0) return token_str

    return substr(token_str, 1, colon_pos - 1)
}

function get_token_value(   token_str, colon_pos) {
    if (current_token < 1 || current_token > length(tokens)) return ""
    
    token_str = tokens[current_token]
    colon_pos = index(token_str, ":")
    
    if (colon_pos == 0) return token_str

    return substr(token_str, colon_pos + 1)
}

function expect_token(expected_type, expected_value) {
    if (get_token_type() != expected_type || 
        (expected_value != "" && get_token_value() != expected_value)) {
        error("Expected " expected_type " " expected_value ", got " get_token_type() " " get_token_value())
    }
    advance_token()
}

function read_file(filename,   code, line, ret) {
    code = ""
    while ((ret = (getline line < filename)) > 0) {
        code = code line "\n"
    }
    close(filename)

    if (ret < 0) {
        return ""
    }
    return code
}

function realpath_dir(filename,   abs, dir) {
    cmd = "realpath " shellquote(filename)
    cmd | getline abs
    close(cmd)

    dir = abs
    sub(/\/[^\/]*$/, "/", dir)

    return dir
}

function shellquote(s) {
    gsub(/'/, "'\\''", s)
    return "'" s "'"
}

function execute_program(filename,   code, line, token_count, prog_node, result, start_time, end_time, time_diff) {
    if (debug) {
        start_time = _now()
        debug_msg("Executing program from file " filename)
    }

    code = read_file(filename)
    debug_msg("Read file, code length: " length(code))

    token_count = tokenize(code)
    debug_msg("Tokenized, token count: " token_count)
    dir_path = realpath_dir(filename)
    prog_node = parse(tokens, token_count)
    debug_msg("Parsed, prog_node: " prog_node)
    result = execute(prog_node)

    if (debug) {
        end_time = _now()
        time_diff = end_time - start_time

        debug_msg("Started executing program at: " sprintf("%.3f", start_time) " sec")
        debug_msg("Ended executing program at: " sprintf("%.3f", end_time) " sec")
        debug_msg("Finished executing program, time: " sprintf("%.3f", time_diff) " sec")
    }

    return result
}

function init_operators() {
    precedence["="] = 1
    precedence["||"] = 2
    precedence["&&"] = 3
    precedence["=="] = 4; precedence["!="] = 4
    precedence["<"] = 5; precedence[">"] = 5
    precedence["<="] = 5; precedence[">="] = 5
    precedence["+"] = 6; precedence["-"] = 6
    precedence["*"] = 7; precedence["/"] = 7; precedence["%"] = 7
}

function runtime_error(message) {
    error(message)
}

# AWKWARD HELPERS

function shell_escape(str) {
    gsub(/'/, "'\\''", str)
    return "'" str "'"
}

function _now(   t, status) {
    if (system("test -f /proc/uptime") == 0) {
        "/bin/cat /proc/uptime" | getline t
        close("/bin/cat /proc/uptime")
        return +t
    }

    # yeah, this is ugly
    status = ("perl -MTime::HiRes=time -e 'print time'" | getline t)
    close("perl -MTime::HiRes=time -e 'print time'")
    if (status > 0 && t != "") return t + 0.0

    "date +%s" | getline t
    close("date +%s")
    return t + 0.0
}
