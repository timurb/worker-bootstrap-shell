#!/bin/sh -x

CONFIG_PATH=""
#CONFIG_ON_S3="1"  # set to 1 to download config from S3


fail() {
  echo "Error: $*"
  exit 1
}

usage() {
cat << EOF
Usage: $(basename $0) s3bucket/config.conf /path/to/awssecrets
EOF
exit 1
}

check_prereqs() {
  which aws > /dev/null || fail "'aws' script from github:timkay/aws is required to retrieve config from S3"
  which git > /dev/null || fail "git is not installed. Run \`sudo apt-get install git\`"
}

# Download config from S3 or do nothing if we are using local config
get_config() {
  [ -z "${CONFIG_ON_S3}" ] && return
  aws "${AWSSECRETS}" get "${CONFIG_PATH}" /tmp/config || \
    fail "There was an error while retrieving ${CONFIG_PATH} from S3"
  CONFIG_PATH="/tmp/config"
}

check_config() {
  [ -z "${CODE_PATH}" ]  && fail "No such variable in config: CODE_PATH"
  [ -z "${DATA_PATH}" ]  && fail "No such variable in config: DATA_PATH"
  [ -z "${SERVER_URL}" ] && fail "No such variable in config: SERVER_URL"
  [ -z "${GIT_REPO}" ]   && fail "No such variable in config: GIT_REPO"
  [ -z "${START_FILE}" ]  && fail "No such variable in config: START_FILE"
}

setup_stuff() {
  mkdir -p "${CODE_PATH}"
  mkdir -p "${DATA_PATH}"

  git clone "${GIT_REPO}" "${CODE_PATH}"

  # Copy the config file retrieved from S3 for the case you need it
  cp -n "${CONFIG_PATH}" "${CODE_PATH}/s3config.conf"
}

start_workers() {
  CPU_CORES="$( cat /proc/cpuinfo | egrep -c '^processor(\s+): ' )"

  cd "${CODE_PATH}"
  chmod +x "${START_FILE}"

  for CORE in $(seq 1 $CPU_CORES); do
    nohup "${START_FILE}" &
  done
}

[ -n "$1" ] && CONFIG_PATH="$1"
[ -n "$2" ] && AWSSECRETS="--secrets-file=$2" CONFIG_ON_S3=1
[ -z "${CONFIG_PATH}" ] && usage

get_config
. "${CONFIG_PATH}"  # This is a little bit evil but is much easier than parsing and evaling the config
check_config
setup_stuff
start_workers
