#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -s  System name, default: system
  -i  Installation system name, default: install
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
installation="install"
download=0
accessToken=
mode=
dumpFile=
remove=0

while getopts hs:i:da:m:f:r? option; do
  case "${option}" in
    s) system=$(trim "$OPTARG");;
    i) installation=$(trim "$OPTARG");;
    d) download=1;;
    a) accessToken=$(trim "$OPTARG");;
    h) usage; exit 1;;
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

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -f "${currentPath}/../env.properties" ]]; then
  echo "No environment specified!"
  exit 1
fi

magentoVersion=$(ini-parse "${currentPath}/../env.properties" "yes" "${installation}" "magentoVersion")
if [ -z "${magentoVersion}" ]; then
  echo "No magento version host specified!"
  exit 1
fi

serverList=( $(ini-parse "${currentPath}/../env.properties" "yes" "${system}" "server") )
if [[ "${#serverList[@]}" -eq 0 ]]; then
  echo "No servers specified!"
  exit 1
fi

for server in "${serverList[@]}"; do
  webServer=$(ini-parse "${currentPath}/../env.properties" "no" "${server}" "webServer")
  if [[ -n "${webServer}" ]]; then
    type=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "type")

    if [[ "${type}" == "local" ]]; then
      echo "--- Restoring media on local server: ${server} ---"

      webPath=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "webPath")
      if [[ -z "${webPath}" ]]; then
        echo "No web path defined!"
        exit 1
      fi

      dumpPath="${currentPath}/dumps"

      if [[ "${download}" == 1 ]]; then
        mkdir -p "${dumpPath}"
        if [[ -z "${accessToken}" ]]; then
          "${currentPath}/download-dump.sh" -s "${system}" -t media -m "${mode}"
        else
          "${currentPath}/download-dump.sh" -s "${system}" -t media -m "${mode}" -a "${accessToken}"
        fi
      fi

      if [[ -z "${dumpFile}" ]]; then
        date=$(date +%Y-%m-%d)
        fileName="media-${mode}-${date}.tar.gz"
        dumpFile="${dumpPath}/${fileName}"
      else
        fileName=$(basename "${dumpFile}")
      fi

      echo "Using dump file: ${dumpFile}"

      if [[ ! -f "${dumpFile}" ]]; then
        echo "Required file not found at: ${dumpFile}"
        exit 1
      fi

      if [[ ${magentoVersion::1} == 1 ]]; then
        targetPath="${webPath}/media"
      else
        targetPath="${webPath}/pub/media"
      fi

      if [[ "${mode}" == "catalog" ]] || [[ "${mode}" == "product" ]]; then
        targetPath="${targetPath}/catalog"
      fi

      if [[ "${mode}" == "product" ]]; then
        targetPath="${targetPath}/product"
      fi

      mkdir -p "${targetPath}"
      echo "Copy dump to: ${targetPath}"
      cp "${dumpFile}" "${targetPath}"

      cd "${targetPath}"
      echo "Extracting dump: ${fileName}"
      tar -xf "${fileName}" | cat

      echo "Removing copied dump: ${fileName}"
      rm -rf "${fileName}"

      if [[ "${remove}" == 1 ]]; then
        echo "Removing downloaded dump: ${dumpFile}"
        rm -rf "${dumpFile}"
      fi
    fi
  fi
done
