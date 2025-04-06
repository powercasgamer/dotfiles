#!/usr/bin/env bash

# Symlink gitignore script

SOURCE_FILE="gitignore.symlink"
TARGET_FILE="$HOME/.gitignore"

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
  echo "Error: $SOURCE_FILE not found in current directory" >&2
  exit 1
fi

# Create symlink (force overwrite if exists)
ln -sf "$(pwd)/$SOURCE_FILE" "$TARGET_FILE"

# Verify success
if [ $? -eq 0 ]; then
  echo "Created symlink: $TARGET_FILE → $(pwd)/$SOURCE_FILE"
else
  echo "Error: Failed to create symlink" >&2
  exit 1
fi