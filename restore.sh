#!/bin/bash

# ==================== FUNCTIONS ====================
function restore() {

  # Error message if file does not exist
  if [ ! -e $HOME/recyclebin/$1 ];then
    echo "restore: cannot restore '$1': No such file" >&2
    return 1
  fi

  # Get the original full path
  originalPath=$(grep -w $1 $HOME/.restore.info | cut -d":" -f2)

  # Strip last comment from file name
  originalLocation=$(dirname $originalPath)

  # If file with same name already exists in target directory
  # Prompt user to overwrite
  if [ -e $originalPath ];then
    read -p "Do you want to overwrite? y/n" ans
    case $ans in
      [!Y!y]*) return 0 ;;
    esac
  fi

  # Create parent directories
  mkdir -p $originalLocation

  # Move the file from recyclebin to original path
  mv $HOME/recyclebin/$1 $originalPath
  
  # Delete the entry in .restore.info file
  grep -v $1 $HOME/.restore.info > $HOME/tmp
  mv $HOME/tmp $HOME/.restore.info

  return 0
}

# ==================== MAIN ====================
# Error message and terminate: no argument provided
if [ $# -eq 0 ];then
  echo "restore: missing operand" >&2
  exit 1
fi

# Iterate arguments provided
for arg in $*
do
  restore $arg
done