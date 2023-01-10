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
  --upload              Upload file to storage
  --remove              Remove after upload
  --gcpAccessToken      By specifying a GCP access token, the dump will be downloaded from GCP
  --pCloudUserName      By specifying a pCloud username name and password, the dump will be downloaded from pCloud
  --pCloudUserPassword  By specifying a pCloud username name and password, the dump will be downloaded from pCloud

Example: ${scriptName} --mode dev --upload
EOF
}

mode=
upload=0
remove=0
gcpAccessToken=
pCloudUserName=
pCloudUserPassword=

source "${currentPath}/../core/prepare-parameters.sh"

if [[ -z "${mode}" ]]; then
  usage
  exit 1
fi

if [[ ! -f "${currentPath}/../env.properties" ]]; then
  echo "No environment specified!"
  exit 1
fi

if [[ "${mode}" == "dev" ]] || [[ "${mode}" == "test" ]]; then
  excludeFile="${currentPath}/../var/media/exclude-${mode}.list"

  if [[ ! -f "${excludeFile}" ]]; then
      echo "No exclude list generated"
      exit 1
  fi
fi

magentoVersion=$(ini-parse "${currentPath}/../env.properties" "yes" "install" "magentoVersion")
serverList=( $(ini-parse "${currentPath}/../env.properties" "yes" "system" "server") )
if [[ "${#serverList[@]}" -eq 0 ]]; then
  echo "No servers specified!"
  exit 1
fi

for server in "${serverList[@]}"; do
  type=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "type")
  if [[ "${type}" == "local" ]]; then
    webPath=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "webPath")
    echo "Dumping media on local server: ${server}"

    if [[ ${magentoVersion::1} == 1 ]]; then
      sourcePath="${webPath}/media"
    else
      sourcePath="${webPath}/pub/media"
    fi

    dumpPath="${currentPath}/../var/media/dumps"

    mkdir -p "${dumpPath}"

    date=$(date +%Y-%m-%d)

    cd "${sourcePath}"
    if [[ "${mode}" == "dev" ]] || [[ "${mode}" == "test" ]]; then
      tar --exclude-from="${excludeFile}" -h -zcf "${dumpPath}/media-${mode}-${date}.tar.gz" .
    elif [[ "${mode}" == "catalog" ]] || [[ "${mode}" == "product" ]]; then
      cd catalog/
      if [[ "${mode}" == "catalog" ]]; then
        tar --exclude "./category/cache" "./product/cache" -h -zcf "${dumpPath}/media-${mode}-${date}.tar.gz" .
      elif [[ "${mode}" == "product" ]]; then
        cd product/
        tar --exclude "./cache" -h -zcf "${dumpPath}/media-${mode}-${date}.tar.gz" .
      fi
    elif [[ "${mode}" == "live" ]]; then
        tar --exclude "./catalog/category/cache" --exclude "./catalog/product/cache" --exclude "./wysiwyg/.thumbs" -h -zcf "${dumpPath}/media-${mode}-${date}.tar.gz" .
    fi

    if [[ "${upload}" == 1 ]]; then
      if [[ -n "${gcpAccessToken}" ]]; then
        "${currentPath}/upload-dump.sh" --mode "${mode}" --date "${date}" --gcpAccessToken "${gcpAccessToken}"
      elif [[ -n "${pCloudUserName}" ]] && [[ -n "${pCloudUserPassword}" ]]; then
        "${currentPath}/upload-dump.sh" --mode "${mode}" --date "${date}" --pCloudUserName "${pCloudUserName}" --pCloudUserPassword "${pCloudUserPassword}"
      else
        "${currentPath}/upload-dump.sh" --mode "${mode}" --date "${date}"
      fi

      if [[ "${remove}" == 1 ]]; then
        echo "Removing created archive: ${dumpPath}/media-${mode}-${date}.tar.gz"
        rm -rf "${dumpPath}/media-${mode}-${date}.tar.gz"
      fi
    fi
  fi
done
