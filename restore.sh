#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  System name, default: system
  -d  Download file from Google storage
  -a  Access token to Google storage
  -m  Mode (dev/test/live/catalog/product)
  -f  Use this file, when not downloading from storage (optional)
  -r  Remove after import, default: no

Example: ${scriptName} -m dev -d
EOF
}

trim()
{
  echo -n "$1" | xargs
}

system="system"
download=0
accessToken=
mode=
dumpFile=
remove=0

while getopts hs:i:da:m:f:r? option; do
  case "${option}" in
    h) usage; exit 1;;
    s) system=$(trim "$OPTARG");;
    d) download=1;;
    a) accessToken=$(trim "$OPTARG");;
    m) mode=$(trim "$OPTARG");;
    f) dumpFile=$(trim "$OPTARG");;
    r) remove=1;;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${mode}" ]] && [[ -z "${dumpFile}" ]]; then
  echo "Specify either mode or file to import"
  echo ""
  usage
  exit 1
fi

if [[ -z "${dumpFile}" ]] && [[ "${mode}" != "dev" ]] && [[ "${mode}" != "test" ]] && [[ "${mode}" != "live" ]] && [[ "${mode}" != "catalog" ]] && [[ "${mode}" != "product" ]]; then
  echo "Invalid mode"
  echo ""
  usage
  exit 1
fi

echo "--- Restoring media ---"

if [[ "${download}" == 1 ]]; then
  dumpPath="${currentPath}/../var/media/dumps"
  mkdir -p "${dumpPath}"
  if [[ -z "${accessToken}" ]]; then
    "${currentPath}/download-dump.sh" -s "${system}" -m "${mode}"
  else
    "${currentPath}/download-dump.sh" -s "${system}" -m "${mode}" -a "${accessToken}"
  fi
  date=$(date +%Y-%m-%d)
  fileName="media-${mode}-${date}.tar.gz"
  dumpFile="${dumpPath}/${fileName}"
fi

"${currentPath}/import.sh" -s "${system}" -i "${dumpFile}"

if [[ "${remove}" == 1 ]]; then
  echo "Removing dump at: ${dumpFile}"
  rm -rf "${dumpFile}"
fi
