#!/usr/bin/env fish

# Define the board and port variables for easier maintenance
set board "accurate_2a_eval:samd:accurate_2A_eval_native"
set port "/dev/ttyUSB1"

# Compile the sketch
echo "Compiling sketch..."
if not ard compile -b $board
    echo "Compilation failed!"
    exit 1
end

# Upload the sketch
echo "Uploading to board..."
if not ard upload -b $board -p $port
    echo "Upload failed!"
    exit 1
end

# Start the serial monitor
echo "Starting serial monitor..."
ard monitor -p $port
