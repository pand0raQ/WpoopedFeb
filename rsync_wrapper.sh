#!/bin/bash

# Log the command for debugging
echo "Running rsync with args: $@" >> ~/rsync_wrapper.log

# Run the actual rsync command with additional flags to avoid permission issues
/usr/bin/rsync --no-perms --chmod=ugo=rwX "$@" 