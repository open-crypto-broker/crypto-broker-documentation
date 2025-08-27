#!/bin/bash

# Usage: ./execute_command.sh "your_command_here"

for i in {1..100}; do
    echo "Running command #$i"
    eval "$1"
    sleep 1
done
