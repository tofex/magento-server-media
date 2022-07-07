#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -i  Import file
  -m  Mode (dev/test/live/catalog/product)

Example: ${scriptName} -i import.tar.gz -m dev
EOF
}

trim()
{
  echo -n "$1" | xargs
}

importFile=
mode=

while getopts hi:m:? option; do
  case "${option}" in
    h) usage; exit 1;;
    i) importFile=$(trim "$OPTARG");;
    m) mode=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${importFile}" ]]; then
  echo "No import file specified!"
  usage
  exit 1
fi

"${currentPath}/../core/script/run.sh" "install,webServer" "${currentPath}/import/web-server.sh" \
  --importFile "${importFile}" \
  --mode "${mode}"
