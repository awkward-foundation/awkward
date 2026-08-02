
function create_kek_module(obj_id,  kek_value_id) {
    obj_id = create_object()
    objects[obj_id, "type"] = TYPE_STRUCT
    objects[obj_id, "struct_name"] = "kek"

    kek_funcs = "show"
    split(kek_funcs, funcs, " ")
    objects[obj_id, "properties_count"] = length(funcs)

    for (i = 1; i <= length(funcs); i++) {
        objects[obj_id, "prop_key_" i] = funcs[i]
        fun_id = create_value(TYPE_FUNCTION, "builtin:kek." funcs[i])
        objects[obj_id, "prop_value_" i] = fun_id
    }

    return obj_id
}

function builtin_kek(func_name, args, argc,   parts, result) {
    split(func_name, parts, ".")
    if (parts[2] == "show") {
        if (argc != 0) error("kek.show expects no arguments")
        result = kek_show()
        return create_value(TYPE_STRING, result)
    }
    error("Unknown kek function: " func_name)
}

function ucfirst(s) {
    return toupper(substr(s,1,1)) substr(s,2)
}

function create_object_type(type) {
    return "Awkward" ucfirst(type) "Object"
}

function decode_kek(input, output, i, j, table, buf, c, idx) {
    table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    output = ""
    buf = 0
    j = 0

    for (i = 1; i <= length(input); i++) {
        c = substr(input, i, 1)
        if (c == "=") break
        idx = index(table, c) - 1
        buf = buf * 64 + idx
        j += 6
        if (j >= 8) {
            j -= 8
            output = output sprintf("%c", int(buf / (2^j)))
            buf = buf % (2^j)
        }
    }

    return output
}

function kek_show(  kek_text) {
    kek_text = "IkFsd2F5cyBjb21wbGljYXRlIHRoaW5ncy4gU2ltcGxlIGlzIGZvciB3ZWFrbGluZ3MuIiwKIklnbm9yZSBlcnJvcnMsIGJ1dCBjb21wbGFpbiBhYm91dCB0aGVtLiIsCiJXcml0ZSBjb2RlIG5vIG9uZSB3aWxsIGV2ZXIgdW5kZXJzdGFuZC4iLAoiQ29tbWVudHMgYXJlIGV2aWwuIERvY3VtZW50YXRpb24gaXMgY3JhcC4iLAoiVXNlIHBpcGVzIGV2ZXJ5d2hlcmUsIGV2ZW4gd2hlcmUgdGhleSBkb24ndCBtYWtlIHNlbnNlLiIsCiJBbnl0aGluZyB0aGF0IHdvcmtzIGlzIGFuIGFjY2lkZW50LiBBbnl0aGluZyB0aGF0IGRvZXNuJ3QgaXMgYSBtYXN0ZXJwaWVjZS4iLAoiQWNjaWRlbnRhbCByZXR1cm4gc3RhdGVtZW50cyBtYWtlIGNvZGUgbW9yZSBpbnRlcmVzdGluZy4iLAoiQWx3YXlzIHVzZSBsYW1iZGEsIGJ1dCBuZXZlciB1c2UgaXQuIiwKIkluIGV2ZXJ5IGpva2UsIHRoZXJlJ3MgYSBncmFpbiBvZiB0cnV0aC4iLAoiVGhlcmUncyBubyBzdWNoIHRoaW5nIGFzIGJhZCBjb2RlISBBbnkgY29kZSBpcyBhcnQsIGRvbid0IGxpc3RlbiB0byBpZGlvdHMuIiw="
    return decode_kek(kek_text)
}
