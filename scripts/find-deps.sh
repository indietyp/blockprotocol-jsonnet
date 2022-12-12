#!/usr/bin/env bash

# Find the current directory, courtesy of https://stackoverflow.com/a/246128/9077988
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR=$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR=$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)
DIR=$(cd -P "$(dirname "$DIR")" >/dev/null 2>&1 && pwd) # we need the parent directory

# find all jsonnet files, that are NOT data and NOT lib
FILES=$(find "$DIR" -type f -name "*.jsonnet" -not -path "*/data/*" -and -not -path "*/lib/*")
PATHS=()

# examine every file and find all
for FILE in $FILES; do
  DIRECTORY=$(/usr/bin/dirname "$FILE")
  cd -P "$DIRECTORY" || exit 1
  # search for all import statements and remove the `import '` prefix and `'` suffix,
  # filter out any imports of libraries or data
  IMPORTS=$(grep -Eo "import '(.+?)'" "$FILE" | sed -E "s/import '(.*)'/\1/" | grep -Ev "^../lib" | grep -Ev "^../data")

  for IMPORT in $IMPORTS; do
    IMPORT=$(realpath "$IMPORT")

    PATHS+=("$FILE $IMPORT")
  done
done

TEMP=$(mktemp)

for LINE in "${PATHS[@]}"; do
  echo "$LINE" >>"$TEMP"
done

OUTPUT=$(tsort "$TEMP")
rm "$TEMP"

echo "$OUTPUT" | tac
