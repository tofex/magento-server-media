#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -f  Use this file
  -m  Mode (dev/test/live/catalog/product)

Example: ${scriptName} -f import.tar.gz -m dev
EOF
}

trim()
{
  echo -n "$1" | xargs
}

dumpFile=
mode=

while getopts hf:m:? option; do
  case "${option}" in
    h) usage; exit 1;;
    f) dumpFile=$(trim "$OPTARG");;
    m) mode=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${mode}" ]] && [[ -z "${dumpFile}" ]]; then
  echo "Specify either mode or file to import"
  echo ""
  usage
  exit 1
fi

"${currentPath}/../core/script/run.sh" "install,webServer" "${currentPath}/import/web-server.sh" \
  --dumpFile "${dumpFile}" \
  --mode "${mode}"
