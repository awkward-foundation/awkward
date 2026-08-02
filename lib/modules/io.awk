
function create_io_module(obj_id, fun_id, methods, i) {
    debug_msg("Creating io module")
    obj_id = create_object()
    objects[obj_id, "type"] = TYPE_STRUCT
    objects[obj_id, "struct_name"] = "io"

    methods = "open read write close"
    split(methods, funcs, " ")
    objects[obj_id, "properties_count"] = length(funcs)

    for (i = 1; i <= length(funcs); i++) {
        objects[obj_id, "prop_key_" i] = funcs[i]
        fun_id = create_value(TYPE_FUNCTION, "builtin:io." funcs[i])
        objects[obj_id, "prop_value_" i] = fun_id
    }

    return obj_id
}

# @doc [io]
# Built-in io functions.
# examples:
# io.open("file_name", "mode")  # opens file and return stream id
# io.read("stream_id")  # reads content from stream
# io.write("stream_id", "data")  # writes content to stream
# io.close("stream_id")  # closes stream by id
function builtin_io(func_name, args, argc,   parts, stream_id, path, mode, data) {
    split(func_name, parts, ".")
    
    if (parts[2] == "open") {
        if (argc != 2) error("open expects 2 arguments")
        path = objects[args[1], "value"]
        mode = objects[args[2], "value"]
        stream_id = io_open(path, mode)
        return create_value(TYPE_INT, stream_id)
    }
    else if (parts[2] == "read") {
        if (argc < 1) error("read expects 1 argument at least")
        stream_id = objects[args[1], "value"]
        bytes = objects[args[2], "value"]
        data = io_read(stream_id, bytes, mode)
        return create_value(TYPE_STRING, data)
    }
    else if (parts[2] == "write") {
        if (argc != 2) error("write expects 2 arguments")
        stream_id = objects[args[1], "value"]
        data = objects[args[2], "value"]
        bytes = io_write(stream_id, data, mode)
        return create_value(TYPE_INT, bytes)
    }
    else if (parts[2] == "close") {
        if (argc != 1) error("close expects 1 argument")
        stream_id = objects[args[1], "value"]
        io_close(stream_id)
        return create_value(TYPE_NULL, "null")
    }
    
    error("Unknown io function: " func_name)
}

function io_open(path, mode,   stream_id, test_line) {
    stream_id = ++STREAM_COUNT

    if (mode == "r") {
        if ((getline test_line < path) < 0) {
            error("Failed to open file for reading: " path)
        }
        close(path)
        STREAMS[stream_id, "path"] = path
        STREAMS[stream_id, "mode"] = "r"
    } else if (mode == "w" || mode == "a") {
        if ((getline test_line < path) < 0) {
            error("Failed to open file for writing: " path)
        }
        close(path)
        STREAMS[stream_id, "path"] = path
        STREAMS[stream_id, "mode"] = mode
    } else {
        error("Unknown mode: " mode)
    }
    return stream_id
}

function io_read(stream_id, max_bytes,   mode, path, data, line, bytes_read, read_all, ret) {
    if (STREAMS[stream_id, "path"] == "") {
        error("Invalid stream id for reading: " stream_id)
    }

    path = STREAMS[stream_id, "path"]
    mode = STREAMS[stream_id, "mode"]
    data = ""
    bytes_read = 0
    read_all = (max_bytes == "" || max_bytes == 0)

    while ((read_all || bytes_read < max_bytes) && ((ret = (getline line < path)) > 0)) {
        if (data != "") data = data "\n"
        data = data line
        bytes_read += length(line) + 1
        if (!read_all && bytes_read >= max_bytes) break
    }
    if (ret == 0) {
        close(path)
    }

    return data
}

function io_write(stream_id, data,   mode, path, old_data, new_data, bytes) {
    if (STREAMS[stream_id, "path"] == "") {
        error("Invalid stream id: " stream_id)
    }
    mode = STREAMS[stream_id, "mode"]
    if (STREAMS[stream_id, "path"] == "") {
        error("Invalid stream id: " stream_id)
    }
    
    path = STREAMS[stream_id, "path"]
    bytes = length(data)

    if (mode == "w") {
        print data > path
        fflush(path)
    } else if (mode == "a") {
        print data >> path
    } else {
        error("Cannot write to stream opened for reading")
    }
    
    return bytes
}

function io_close(stream_id,   path) {
    if (STREAMS[stream_id, "path"] == "") {
        error("Invalid stream id: " stream_id)
    }

    path = STREAMS[stream_id, "path"]
    close(path)

    delete STREAMS[stream_id, "path"]
    delete STREAMS[stream_id, "mode"]
}
