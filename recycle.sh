#!/bin/bash


# ==================== FUNCTIONS ====================
function createRecycleBinIfNotExist() {
  if [ ! -d $HOME/recyclebin ];then
    mkdir $HOME/recyclebin
  fi
}


function optFunc() {
  interactive=false
  verbose=false
  recursive=false

  while getopts :ivr opt
  do
    case $opt in
      i) interactive=true ;;
      v) verbose=true ;;
      r) recursive=true ;;
      *) echo "$OPTARG is not a valid option" >&2
         exit 1 ;;
    esac
  done
}

function promptBeforeDescendIntoDirectoryIfInteractive() {
  # Confirm descending if -i option is not chosen
  if [ $interactive = false ];then
    return 0
  else
    # Prompt User
    read -p "recycle: descend into directory '$1'?" ans
    case $ans in
      [Yy]*)
        return 0 ;;
      *)
        return 1 ;;
    esac
  fi
}

function promptBeforeRemoveDirectory() {
  # Confirm removing if -i option is not chosen
  if [ $interactive = false ];then
    return 0
  else
    # Prompt User
    read -p "rm: remove directory '$1'?" ans
    case $ans in
      [Yy]*)
        return 0 ;;
      *)
        return 1 ;;
    esac
  fi
}

function promptBeforeRecycle() {
  # Confirm recycling the file if -i option is not chosen
  if [ $interactive = false ];then
    return 0
  else
    # Different prompt messages according to file type
    local promptMessage=""
    if [ -h $1 ];then
      promptMessage="recycle: recycle symbolic link '$1'?"
    elif [ -s $1 ];then
      promptMessage="recycle: recycle regular file '$1'?"
    else
      promptMessage="recycle: recycle regular empty file '$1'?"
    fi

    # Prompt User
    read -p "$promptMessage" ans
    case $ans in
      [Yy]*)
        return 0 ;;
      *)
        return 1 ;;
    esac
  fi
}


function recycle() {

  # Error message: file does not exist
  if [ ! -e $1 ];then
    echo "recycle: cannot recycle '$1': No such file or directory" >&2

    # Help determine exit status of the script
    containsNonExistingFile=true
    return 1
  fi

  # Error message: attempt to recycle the script itself
  if [ $(realpath -e -s $1) = $(which recycle) ];then
    echo "Attempting to delete recycle - operation aborted" >&2
    return 1
  fi

  # Directory provided
  if [ -d $1 ];then
    # Error message: directory provided without -r option
    if [ $recursive = false ];then
      echo "recycle: cannot recycle '$1': Is a directory" >&2
 
      # Help determine exit status of the script
      containsDirectoryWithoutRecursive=true
      return 1
        
    # Remove directory and its contents recursively if -r option is chosen
    else

      # Prompt user and exit the function if user says no      
      if ! promptBeforeDescendIntoDirectoryIfInteractive $1;then
        return 0
      fi

      cd $1

      # Recycle files in the directory
      for file in $(find . -maxdepth 1 ! -name '\.' ! -name '\.\.' -exec basename {} \;)
      do
        recycle $file
      done

      cd ..

      # Prmopt user and exit the function if user says no
      if ! promptBeforeRemoveDirectory $1;then
        return 0
      fi

      # Remove the directory
      rm -r $1

      # Echo name of the directory removed if -v option is chosen
      if [ $verbose = true ];then
        echo "removed '$1'"
      fi

      return 0
    fi
  fi

  ################# Recycle a regular or symbolic link file #################

  # Prmopt user and exit the function if user says no
  if ! promptBeforeRecycle $1;then
    return 0
  fi

  # Get inode, basename and full path of the file
  local inode=$(ls -i $1 | cut -d" " -f1)
  local basename=$(basename $1)
  local fullpath=$(realpath -e -s $1)

  # To get around potential problem of deleting two files with the same name,
  # file will be renamed as [basename]_[inode]
  mv $1 "$HOME/recyclebin/$basename""_$inode"

  # Add a new entry in the .restore.info file
  echo "$basename""_$inode:$fullpath" >> "$HOME/.restore.info"

  # Echo name of the file recycled if -v option is chosen
  if [ $verbose = true ];then
    echo "recycled '$1'"
  fi
  return 0
}


######################### MAIN #########################
# Help determine exit status
containsDirectoryWithoutRecursive=false
containsNonExistingFile=false

createRecycleBinIfNotExist

optFunc $*
shift $[OPTIND-1]

# Error message and terminate: no filename provided
if [ $# -eq 0 ];then
  echo "rm: missing operand" >&2
  exit 1
fi

# Iterate arguments provided
for arg in $*
do
  recycle $arg
done

# Exit 1 if contains any directory without choosing -r OR contains non-existing file 
if [ $containsDirectoryWithoutRecursive = true ] || [ $containsNonExistingFile = true ];then
  exit 1
fi
