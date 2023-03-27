#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -f ${currentPath}/../env.properties ]]; then
  echo "No environment specified!"
  exit 1
fi

dumpPath="${currentPath}/backups"

if [[ ! -d "${dumpPath}" ]]; then
  echo "Creating backup directory: ${dumpPath}"
  mkdir -p "${dumpPath}"
fi

date=$(date +%Y-%m-%d)
dumpFile="${dumpPath}/media-backup-${date}.tar.gz"

if [[ -f "${dumpFile}" ]]; then
  echo "Backup already created in file: ${dumpFile}"
else
  servers=$(ini-parse "${currentPath}/../env.properties" "yes" "project" "servers")
  magentoVersion=$(ini-parse "${currentPath}/../env.properties" "yes" "install" "magentoVersion")

  IFS=',' read -r -a serverList <<< "${servers}"

  for server in "${serverList[@]}"; do
    type=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "type")
    webServer=$(ini-parse "${currentPath}/../env.properties" "no" "${server}" "webServer")

    if [[ -n "${webServer}" ]]; then
      if [[ "${type}" == "local" ]]; then
        echo "Dumping on local server: ${server}"

        webPath=$(ini-parse "${currentPath}/../env.properties" "yes" "${webServer}" "path")

        if [[ ${magentoVersion::1} == 1 ]]; then
          sourcePath="${webPath}/media"
        else
          sourcePath="${webPath}/pub/media"
        fi

        cat << EOF > /tmp/exclude-backup.list
./captcha
./catalog/category/cache
./catalog/product/cache
./css
./css_secure
./js
./tmp
./wysiwyg/.thumbs
EOF

        cd "${sourcePath}"
        echo "Creating archive: ${dumpFile}"
        tar --exclude-from=/tmp/exclude-backup.list -h -zcf "${dumpFile}" .
      fi
    fi
  done
fi
