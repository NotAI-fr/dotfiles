#!/usr/bin/env bash

NOTE_DIR="$HOME/Notes"

# 1. Gather counts for all 4 categories safely
DUMP_COUNT=$(wc -l < "$NOTE_DIR/dump.txt" 2>/dev/null || echo 0)
TODO_COUNT=$(wc -l < "$NOTE_DIR/todo.txt" 2>/dev/null || echo 0)
IDEA_COUNT=$(wc -l < "$NOTE_DIR/idea.txt" 2>/dev/null || echo 0)
NOTE_COUNT=$(wc -l < "$NOTE_DIR/general.txt" 2>/dev/null || echo 0)

# 2. Build a dynamic output array based on active notes
OUTPUT_PARTS=()

if [ "$TODO_COUNT" -gt 0 ]; then
    OUTPUT_PARTS+=("󱓥 $TODO_COUNT")
fi

if [ "$DUMP_COUNT" -gt 0 ]; then
    OUTPUT_PARTS+=("󰏔 $DUMP_COUNT")
fi

if [ "$IDEA_COUNT" -gt 0 ]; then
    OUTPUT_PARTS+=("󰌵 $IDEA_COUNT")
fi

if [ "$NOTE_COUNT" -gt 0 ]; then
    OUTPUT_PARTS+=("󰎚 $NOTE_COUNT")
fi

# 3. Print the array elements separated by standard spaces
echo "${OUTPUT_PARTS[*]}"
