#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

AWKWARD=../awkward
TEST_DIR=$(dirname "$0")
cd "$TEST_DIR" || exit 1

total=0
passed=0

function check_tests() {
    for src in test_*.awkward; do
        test_name="${src%.awkward}"
        if [[ ! -f "${test_name}.expected" && ! -f "${test_name}.stderr" && ! -f "${test_name}.exitcode" ]]; then
            echo "Error: no expected files found for $test_name"
            exit 1
        fi
    done
}

check_tests

for src in test_*.awkward; do
    name="${src%.awkward}"

    total=$((total+1))
    echo "Running $name"

    stdout_out=$(mktemp)
    stderr_out=$(mktemp)

    if [ -f "$name.stdin" ]; then
        "$AWKWARD" "$src" <"$name.stdin" >"$stdout_out" 2>"$stderr_out"
    else
        "$AWKWARD" "$src" </dev/null >"$stdout_out" 2>"$stderr_out"
    fi
    exit_code=$?

    ok_stdout=true
    ok_stderr=true
    ok_exit=true

    if [ -f "$name.expected" ]; then
        if ! diff -u "$name.expected" "$stdout_out" >/dev/null; then
            echo "stdout differs"
            diff -u "$name.expected" "$stdout_out"
            ok_stdout=false
        fi
    fi

    if [ -f "$name.stderr" ]; then
        if ! diff -u "$name.stderr" "$stderr_out" >/dev/null; then
            echo "stderr differs"
            diff -u "$name.stderr" "$stderr_out"
            ok_stderr=false
        fi
    elif [ -f "$name.ignorestderr" ]; then
        : # stderr
    else
        if [ -s "$stderr_out" ]; then
            echo "unexpected stderr output:"
            cat "$stderr_out"
            ok_stderr=false
        fi
    fi

    expected_exit=0
    if [ -f "$name.exitcode" ]; then
        expected_exit=$(cat "$name.exitcode")
    fi
    if [ "$exit_code" -ne "$expected_exit" ]; then
        echo "Awkward exited with code $exit_code (expected $expected_exit)"
        ok_exit=false
    fi

    if $ok_stdout && $ok_stderr && $ok_exit; then
        echo -e "${GREEN}$name passed${NC}"
        passed=$((passed+1))
    else
        echo -e "${RED}$name failed${NC}"
    fi

    rm -f "$stdout_out" "$stderr_out"
    echo
done

echo "Summary: $passed / $total tests passed"
exit $([ "$passed" -eq "$total" ] && echo 0 || echo 1)
