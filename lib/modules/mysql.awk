
function create_mysql_module(obj_id, fun_id, methods, funcs, i) {
    if (debug) debug_msg("Creating mysql module")
    obj_id = create_object()
    objects[obj_id, "type"] = TYPE_STRUCT
    objects[obj_id, "struct_name"] = "mysql"

    methods = "connect query close hex_encode hex_decode"
    split(methods, funcs, " ")
    objects[obj_id, "properties_count"] = length(funcs)
    for (i = 1; i <= length(funcs); i++) {
        objects[obj_id, "prop_key_" i] = funcs[i]
        fun_id = create_value(TYPE_FUNCTION, "builtin:mysql." funcs[i])
        objects[obj_id, "prop_value_" i] = fun_id
    }
    return obj_id
}

# @doc [mysql]
# MySQL/MariaDB client
# examples:
# import mysql;
# let conn = mysql.connect("127.0.0.1", 3306, "root", "testdb");
# let rows = mysql.query(conn, "SELECT id, title FROM tasks");
# let result = mysql.query(conn, "UPDATE tasks SET done=1 WHERE id=1");
# mysql.close(conn);
# mysql.query(conn, "INSERT INTO blobs (data) VALUES (UNHEX('" + mysql.hex_encode(raw_bytes) + "'))");
function builtin_mysql(func_name, args, argc,   parts, conn_id) {
    split(func_name, parts, ".")

    if (parts[2] == "connect") {
        if (argc != 4) error("mysql.connect expects 4 arguments: host, port, user, database")
        return create_value(TYPE_INT, mysql_connect(objects[args[1], "value"], objects[args[2], "value"], objects[args[3], "value"], objects[args[4], "value"]))
    }
    if (parts[2] == "query") {
        if (argc != 2) error("mysql.query expects 2 arguments: connection, sql")
        return mysql_query(objects[args[1], "value"], objects[args[2], "value"])
    }
    if (parts[2] == "close") {
        if (argc != 1) error("mysql.close expects 1 argument: connection")
        mysql_close(objects[args[1], "value"])
        return create_value(TYPE_NULL, "null")
    }
    if (parts[2] == "hex_encode") {
        if (argc != 1) error("mysql.hex_encode expects 1 argument")
        return create_value(TYPE_STRING, mysql_byte_to_hex(objects[args[1], "value"]))
    }
    if (parts[2] == "hex_decode") {
        if (argc != 1) error("mysql.hex_decode expects 1 argument")
        return create_value(TYPE_STRING, mysql_hex_to_bytes(objects[args[1], "value"]))
    }
    error("Unknown mysql function: " func_name)
}

function mysql_init_tables(   i) {
    if (MYSQL_TABLES_INIT) return
    for (i = 0; i < 256; i++) {
        MYSQL_CHR[i] = sprintf("%c", i)
        MYSQL_ORD[MYSQL_CHR[i]] = i
    }
    MYSQL_TABLES_INIT = 1
}

function mysql_byte_to_hex(s,   i, n, out, v, hex) {
    mysql_init_tables()
    hex = "0123456789abcdef"
    out = ""
    n = length(s)
    for (i = 1; i <= n; i++) {
        v = MYSQL_ORD[substr(s, i, 1)]
        out = out substr(hex, int(v / 16) + 1, 1) substr(hex, v % 16 + 1, 1)
    }
    return out
}

function mysql_hex_to_bytes(hex,   i, n, out, h, l, hv, lv) {
    gsub(/[^0-9a-fA-F]/, "", hex)
    n = length(hex)
    out = ""
    for (i = 1; i + 1 <= n; i += 2) {
        h = tolower(substr(hex, i, 1))
        l = tolower(substr(hex, i + 1, 1))
        hv = index("0123456789abcdef", h) - 1
        lv = index("0123456789abcdef", l) - 1
        out = out sprintf("%c", hv * 16 + lv)
    }
    return out
}

function mysql_zero_bytes(n,   r, i) {
    mysql_init_tables()
    r = ""
    for (i = 0; i < n; i++) r = r MYSQL_CHR[0]
    return r
}

function mysql_u32_le(n,   r, i) {
    mysql_init_tables()
    r = ""
    for (i = 0; i < 4; i++) {
        r = r MYSQL_CHR[n % 256]
        n = int(n / 256)
    }
    return r
}

function mysql_read_u_le(s, nbytes,   i, v) {
    mysql_init_tables()
    v = 0
    for (i = nbytes; i >= 1; i--) {
        v = v * 256 + MYSQL_ORD[substr(s, i, 1)]
    }
    return v
}

function mysql_decoder_path(   path) {
    path = "/tmp/awkward_mysql_hexdecode.awk"
    if (MYSQL_DECODER_WRITTEN) return path
    print "{ gsub(/[^0-9a-fA-F]/, \"\"); line = tolower($0); n = length(line);" \
          " for (i = 1; i + 1 <= n; i += 2) {" \
          " h = substr(line, i, 1); l = substr(line, i + 1, 1);" \
          " hv = index(\"0123456789abcdef\", h) - 1; lv = index(\"0123456789abcdef\", l) - 1;" \
          " printf \"%c\", hv * 16 + lv } }" > path
    close(path)
    MYSQL_DECODER_WRITTEN = 1
    return path
}

function mysql_connect_timeout() {
    return 5
}

function mysql_open_transport(host, port,   id, to_fifo, from_fifo, shim_path, decoder_path, connect_marker, script, cmd) {
    id = ++MYSQL_CONN_COUNT

    to_fifo = "/tmp/awkward_mysql_" id "_to"
    from_fifo = "/tmp/awkward_mysql_" id "_from"
    shim_path = "/tmp/awkward_mysql_" id "_shim.sh"
    connect_marker = "/tmp/awkward_mysql_" id "_connected"
    decoder_path = mysql_decoder_path()

    system("rm -f " shell_escape(to_fifo) " " shell_escape(from_fifo) " " shell_escape(connect_marker))
    system("mkfifo " shell_escape(to_fifo) " " shell_escape(from_fifo))

    script = "#!/bin/sh\n"
    script = script "touch " shell_escape(connect_marker) "\n"
    script = script "( while [ -p " shell_escape(to_fifo) " ]; do awk -f " \
             shell_escape(decoder_path) " < " shell_escape(to_fifo) " 2>/dev/null; done ) &\n"
    script = script "exec stdbuf -oL od -An -tx1 -v -w1 > " shell_escape(from_fifo) "\n"
    print script > shim_path
    close(shim_path)

    cmd = "socat TCP:" shell_escape(host) ":" shell_escape(port) ",connect-timeout=" mysql_connect_timeout() \
          " SYSTEM:" shell_escape("sh " shim_path) " </dev/null >/dev/null 2>/dev/null &"
    system(cmd)

    MYSQL_CONNS[id, "to_fifo"] = to_fifo
    MYSQL_CONNS[id, "from_fifo"] = from_fifo
    MYSQL_CONNS[id, "shim_path"] = shim_path
    MYSQL_CONNS[id, "connect_marker"] = connect_marker
    MYSQL_CONNS[id, "inbuf"] = ""
    MYSQL_CONNS[id, "seq"] = 0

    return id
}

function mysql_wait_for_connect(id, host, port,   marker, ticks, max_ticks) {
    marker = MYSQL_CONNS[id, "connect_marker"]
    ticks = 0
    max_ticks = mysql_connect_timeout() * 10
    while (!file_exists(marker) && ticks < max_ticks) {
        system("sleep 0.1")
        ticks++
    }
    if (!file_exists(marker)) {
        mysql_teardown_transport(id)
        error("mysql: could not connect to " host ":" port " within " mysql_connect_timeout() "s")
        return 0
    }
    return 1
}

function mysql_teardown_transport(id) {
    system("rm -f " shell_escape(MYSQL_CONNS[id, "to_fifo"]) " " \
                     shell_escape(MYSQL_CONNS[id, "from_fifo"]) " " \
                     shell_escape(MYSQL_CONNS[id, "shim_path"]) " " \
                     shell_escape(MYSQL_CONNS[id, "connect_marker"]))
    delete MYSQL_CONNS[id, "to_fifo"]
    delete MYSQL_CONNS[id, "from_fifo"]
    delete MYSQL_CONNS[id, "shim_path"]
    delete MYSQL_CONNS[id, "connect_marker"]
    delete MYSQL_CONNS[id, "seq"]
    delete MYSQL_CONNS[id, "inbuf"]
}

function mysql_fill_buffer(id, need,   from_fifo, line) {
    from_fifo = MYSQL_CONNS[id, "from_fifo"]
    while (length(MYSQL_CONNS[id, "inbuf"]) < need) {
        if ((getline line < from_fifo) <= 0) {
            error("mysql: connection closed while reading")
            return
        }
        MYSQL_CONNS[id, "inbuf"] = MYSQL_CONNS[id, "inbuf"] mysql_hex_to_bytes(line)
    }
}

function mysql_take_bytes(id, n,   buf, result) {
    mysql_fill_buffer(id, n)
    buf = MYSQL_CONNS[id, "inbuf"]
    result = substr(buf, 1, n)
    MYSQL_CONNS[id, "inbuf"] = substr(buf, n + 1)
    return result
}

function mysql_send_bytes(id, raw,   to_fifo) {
    to_fifo = MYSQL_CONNS[id, "to_fifo"]
    print mysql_byte_to_hex(raw) > to_fifo
    close(to_fifo)
}

function mysql_send_packet(id, payload,   seq, len) {
    seq = MYSQL_CONNS[id, "seq"] + 0
    len = length(payload)
    mysql_send_bytes(id, MYSQL_CHR[len % 256] MYSQL_CHR[int(len / 256) % 256] \
                          MYSQL_CHR[int(len / 65536) % 256] MYSQL_CHR[seq % 256] payload)
    MYSQL_CONNS[id, "seq"] = seq + 1
}

function mysql_recv_packet(id,   hdr, len, seq, payload) {
    hdr = mysql_take_bytes(id, 4)
    len = mysql_read_u_le(hdr, 3)
    seq = MYSQL_ORD[substr(hdr, 4, 1)]
    MYSQL_CONNS[id, "seq"] = seq + 1
    payload = mysql_take_bytes(id, len)
    return payload
}

function mysql_p_init(buf) {
    MYSQL_PBUF = buf
    MYSQL_PLEN = length(buf)
    MYSQL_PPOS = 1
}

function mysql_p_bytes(n,   r) {
    r = substr(MYSQL_PBUF, MYSQL_PPOS, n)
    MYSQL_PPOS += n
    return r
}

function mysql_p_byte(   r) {
    r = MYSQL_ORD[substr(MYSQL_PBUF, MYSQL_PPOS, 1)]
    MYSQL_PPOS += 1
    return r
}

function mysql_p_u_le(n) {
    return mysql_read_u_le(mysql_p_bytes(n), n)
}

function mysql_p_lenenc_int(   first) {
    first = mysql_p_byte()
    if (first < 251) return first
    if (first == 252) return mysql_p_u_le(2)
    if (first == 253) return mysql_p_u_le(3)
    if (first == 254) return mysql_p_u_le(8)
    error("mysql: invalid length-encoded integer prefix " first)
}

function mysql_p_lenenc_str() {
    return mysql_p_bytes(mysql_p_lenenc_int())
}

function mysql_p_nulstr(   start, r) {
    start = MYSQL_PPOS
    while (MYSQL_PPOS <= MYSQL_PLEN && substr(MYSQL_PBUF, MYSQL_PPOS, 1) != MYSQL_CHR[0]) {
        MYSQL_PPOS += 1
    }
    r = substr(MYSQL_PBUF, start, MYSQL_PPOS - start)
    MYSQL_PPOS += 1
    return r
}

function mysql_p_remaining(   r) {
    r = substr(MYSQL_PBUF, MYSQL_PPOS)
    MYSQL_PPOS = MYSQL_PLEN + 1
    return r
}

function mysql_raise_err(   code, sqlstate, msg) {
    code = mysql_p_u_le(2)
    mysql_p_bytes(1)
    sqlstate = mysql_p_bytes(5)
    msg = mysql_p_remaining()
    error("mysql error " code " (" sqlstate "): " msg)
}

function mysql_connect(host, port, user, database,   id, greeting, proto_ver, \
                        salt1, cap_lo, charset, auth_len, plugin, caps, response) {
    id = mysql_open_transport(host, port)
    if (!mysql_wait_for_connect(id, host, port)) return create_value(TYPE_NULL, "null")

    greeting = mysql_recv_packet(id)
    mysql_p_init(greeting)

    proto_ver = mysql_p_byte()
    if (proto_ver != 10) error("mysql: unsupported protocol version " proto_ver)
    mysql_p_nulstr()
    mysql_p_u_le(4)
    salt1 = mysql_p_bytes(8)
    mysql_p_byte()
    cap_lo = mysql_p_u_le(2)
    charset = mysql_p_byte()
    mysql_p_u_le(2)
    mysql_p_u_le(2)
    auth_len = mysql_p_byte()
    mysql_p_bytes(10)
    mysql_p_bytes((auth_len - 8 > 13) ? auth_len - 8 : 13)
    plugin = mysql_p_nulstr()

    caps = 1 + 8 + 512 + 32768 + 524288
    response = mysql_u32_le(caps) mysql_u32_le(16777216) MYSQL_CHR[charset]
    response = response mysql_zero_bytes(23)
    response = response user MYSQL_CHR[0]
    response = response MYSQL_CHR[0]
    response = response database MYSQL_CHR[0]
    response = response plugin MYSQL_CHR[0]

    mysql_send_packet(id, response)
    mysql_expect_ok(id, "handshake")

    return id
}

function mysql_expect_ok(id, context,   pkt, marker) {
    pkt = mysql_recv_packet(id)
    mysql_p_init(pkt)
    marker = mysql_p_byte()
    if (marker == 255) mysql_raise_err()
    if (marker != 0) error("mysql: expected OK packet during " context ", got marker " marker)
}

function mysql_query(id, sql,   pkt, marker) {
    MYSQL_CONNS[id, "seq"] = 0
    mysql_send_packet(id, MYSQL_CHR[3] sql)   # COM_QUERY

    pkt = mysql_recv_packet(id)
    mysql_p_init(pkt)
    marker = mysql_p_byte()

    if (marker == 255) { mysql_raise_err(); return create_value(TYPE_NULL, "null") }
    if (marker == 0) return mysql_parse_ok()

    MYSQL_PPOS = 1
    return mysql_read_result_set(id)
}

function mysql_parse_ok(   affected, last_id, keys, values) {
    affected = mysql_p_lenenc_int()
    last_id = mysql_p_lenenc_int()
    keys[1] = "affected_rows"; values[1] = create_value(TYPE_INT, affected)
    keys[2] = "last_insert_id"; values[2] = create_value(TYPE_INT, last_id)
    return create_object(keys, values, 2)
}

function mysql_read_result_set(id,   ncols, i, j, col_names, pkt, marker, \
                                row_count, keys, values, val, rows_arr) {
    ncols = mysql_p_lenenc_int()

    for (i = 1; i <= ncols; i++) {
        if (error_occurred) return create_value(TYPE_NULL, "null")
        pkt = mysql_recv_packet(id)
        mysql_p_init(pkt)
        mysql_p_lenenc_str() # catalog
        mysql_p_lenenc_str() # schema
        mysql_p_lenenc_str() # table
        mysql_p_lenenc_str()
        col_names[i] = mysql_p_lenenc_str()
        mysql_p_lenenc_str()
        mysql_p_lenenc_int()
        mysql_p_bytes(12)
    }

    pkt = mysql_recv_packet(id) # eof
    mysql_p_init(pkt)
    if (mysql_p_byte() != 254) error("mysql: expected EOF after column definitions")

    row_count = 0
    while (1) {
        if (error_occurred) return create_value(TYPE_NULL, "null")
        pkt = mysql_recv_packet(id)
        mysql_p_init(pkt)
        marker = mysql_p_byte()
        if (marker == 254 && length(pkt) < 9) break

        MYSQL_PPOS = 1
        row_count++
        for (j = 1; j <= ncols; j++) {
            keys[j] = col_names[j]
            if (substr(MYSQL_PBUF, MYSQL_PPOS, 1) == MYSQL_CHR[251]) {
                MYSQL_PPOS++
                val = create_value(TYPE_NULL, "null")
            } else {
                val = create_value(TYPE_STRING, mysql_p_lenenc_str())
            }
            values[j] = val
        }
        rows_arr[row_count] = create_object(keys, values, ncols)
    }

    return create_array(rows_arr, row_count)
}

function mysql_close(id) {
    if (!((id, "to_fifo") in MYSQL_CONNS)) return

    MYSQL_CONNS[id, "seq"] = 0
    mysql_send_packet(id, MYSQL_CHR[1]) # COM_QUIT

    close(MYSQL_CONNS[id, "from_fifo"])
    close(MYSQL_CONNS[id, "to_fifo"])
    mysql_teardown_transport(id)
}
