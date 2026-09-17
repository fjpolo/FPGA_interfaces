#!/bin/bash
clear; ./test_all.sh | tee >(cat > test_log.txt)