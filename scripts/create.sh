#!/usr/bin/env bash
set +o posix # enable process substitution
# Required Variables:
# * GRAPH_URL
# * API_URL
# * BACKEND_URL
# * SESSION_TOKEN
# * if SESSION_TOKEN not given:
#   * USERNAME
#   * PASSWORD

# ensure everything is installed
if ! command -v jsonnet &>/dev/null; then
  echo "please install jsonnet before executing this command"
  echo "on macOS this can be done via 'brew install go-jsonnet'"
  exit
fi
if ! command -v jq &>/dev/null; then
  echo "please install jq before executing this command"
  echo "on macOS this can be done via 'brew install jq'"
  exit
fi

# Find the current directory, courtesy of https://stackoverflow.com/a/246128/9077988
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR=$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR=$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)
DIR=$(cd -P "$(dirname "$DIR")" >/dev/null 2>&1 && pwd) # we need the parent directory

# taken from https://stackoverflow.com/a/13864829/9077988
if [ -z ${GRAPH_URL+x} ]; then
  read -r -p "What is the URL of the Graph API Server? " GRAPH_URL
fi
# remove the trailing slash (https://stackoverflow.com/a/9018877/9077988)
GRAPH_URL=${GRAPH_URL%/}

# taken from https://stackoverflow.com/a/13864829/9077988
if [ -z ${API_URL+x} ]; then
  read -r -p "What is the URL of the API Server? " API_URL
fi
# remove the trailing slash (https://stackoverflow.com/a/9018877/9077988)
API_URL=${API_URL%/}

# taken from https://stackoverflow.com/a/13864829/9077988
if [ -z ${BACKEND_URL+x} ]; then
  read -r -p "What is the URL of the Backend API Server? " BACKEND_URL
fi
# remove the trailing slash (https://stackoverflow.com/a/9018877/9077988)
BACKEND_URL=${BACKEND_URL%/}

function login() {
  if [ -z ${USERNAME+x} ]; then
    read -r -p "Username: " USERNAME
  fi
  if [ -z ${PASSWORD+x} ]; then
    read -r -s -p "Password: " PASSWORD
    echo ""
  fi

  ACTION_URL=$(
    curl -s -X GET \
      -H "Accept: application/json" \
      "$API_URL/ory/self-service/login/api" |
      jq -r '.ui.action'
  )

  PAYLOAD="{\"identifier\": \"$USERNAME\", \"password\": \"$PASSWORD\", \"method\": \"password\"}"

  SESSION_TOKEN=$(
    curl -s -X POST \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" \
      "$ACTION_URL" |
      jq -r '.session_token'
  )
}

if [ -z ${SESSION_TOKEN+x} ]; then
  login
fi

ACCOUNT_ID=$(
  curl -s -X POST -H "Authorization: Bearer $SESSION_TOKEN" -H "Content-Type: application/json" -d '{"query":"query {\n  me {\n    roots\n  }\n}"}' "$BACKEND_URL/graphql" |
    jq -r ".data.me.roots[0].baseId" |
    # for now ids are separated by `%`
    cut -d "%" -f 1
)

FILES=()
while read -r line; do
  FILES+=("$line")
done < <(sh "$DIR/scripts/find-deps.sh")

LENGTH=${#FILES[@]}
INDEX=0

for FILE in "${FILES[@]}"; do
  JSON=$(jsonnet "$FILE")
  TYPE=$(echo "$FILE" | rev | cut -f 2 -d "/" | rev)

  # determine the required endpoint, we do this by looking at the second to last folder
  case $TYPE in
  "entities" | "links")
    URL="$GRAPH_URL/entity-types"
    ;;
  "properties")
    URL="$GRAPH_URL/property-types"
    ;;
  esac


  # send POST request to the endpoint
  curl -X POST "$URL" -w "%{http_code}" \
    -H 'Content-Type: application/json' \
    -d "{\"schema\": $JSON, \"ownedById\": \"$ACCOUNT_ID\", \"actorId\": \"$ACCOUNT_ID\"}"

  ((INDEX += 1))
  printf "\nCreated %s/%s\n" "$INDEX" "$LENGTH"
done

echo "done c:"
