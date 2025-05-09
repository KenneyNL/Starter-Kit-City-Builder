#!/bin/bash

# Ask the user for the desired unlocked value
read -p "What do you want to set the structures' unlocked bool to? (T/F): " user_input

# Normalize input and determine the new value
case "$user_input" in
  [Tt]) new_value="true" ;;
  [Ff]) new_value="false" ;;
  *)
    echo "Invalid input. Please enter 'T' or 'F'."
    exit 1
    ;;
esac

# Loop through all .tres files in the /structures directory
for file in ../structures/*.tres; do
  # Check if the file exists and contains an 'unlocked' field
  if grep -q "^unlocked = " "$file"; then
    # Replace the unlocked value with the desired one
    sed -i "s/^unlocked = .*/unlocked = $new_value/" "$file"
    echo "Set unlocked in $file to $new_value"
  else
    echo "No 'unlocked' field found in $file, skipping."
  fi
done


