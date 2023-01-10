#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  --help                Show this message
  --mode                Mode (dev/test/live/catalog/product)
  --download            Download file from Google storage
  --dumpFile            Use this file, when not downloading from storage (optional)
  --remove              Remove after import, default: no
  --gcpAccessToken      By specifying a GCP access token, the dump will be downloaded from GCP
  --pCloudUserName      By specifying a pCloud username name and password, the dump will be downloaded from pCloud
  --pCloudUserPassword  By specifying a pCloud username name and password, the dump will be downloaded from pCloud

Example: ${scriptName} --mode dev --download --remove
EOF
}

mode=
download=0
dumpFile=
remove=0
gcpAccessToken=
pCloudUserName=
pCloudUserPassword=

source "${currentPath}/../core/prepare-parameters.sh"

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
  if [[ -n "${gcpAccessToken}" ]]; then
    "${currentPath}/download-dump.sh" --mode "${mode}" --gcpAccessToken "${gcpAccessToken}"
  elif [[ -n "${pCloudUserName}" ]] && [[ -n "${pCloudUserPassword}" ]]; then
    "${currentPath}/download-dump.sh" --mode "${mode}" --pCloudUserName "${pCloudUserName}" --pCloudUserPassword "${pCloudUserPassword}"
  else
    "${currentPath}/download-dump.sh" --mode "${mode}"
  fi
  date=$(date +%Y-%m-%d)
  fileName="media-${mode}-${date}.tar.gz"
  dumpFile="${dumpPath}/${fileName}"
fi

"${currentPath}/import.sh" -i "${dumpFile}" -m "${mode}"

magentoVersion=$(ini-parse "${currentPath}/../env.properties" "yes" "install" "magentoVersion")
if [[ -z "${magentoVersion}" ]]; then
  echo "No magento version specified!"
  usage
  exit 1
fi

if [[ ${magentoVersion:0:1} == 1 ]]; then
  "${currentPath}/../ops/create-shared.sh" \
    -f media \
    -o
else
  "${currentPath}/../ops/create-shared.sh" \
    -f pub/media \
    -o
fi

if [[ "${remove}" == 1 ]]; then
  echo "Removing dump at: ${dumpFile}"
  rm -rf "${dumpFile}"
fi
