#!/bin/bash

# Check that an odd BufEncoder capacity fails to compile

cd tests/compiletest
if cargo run > /dev/null 2>&1; then
    echo "test compiled with an odd BufEncoder capacity when it shouldn't"
    pwd
    exit 1
else
    echo "odd BufEncoder capacity failed to compile as expected"
    exit 0
fi
