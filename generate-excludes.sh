#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -m  Mode (dev/test)
  -f  Comma separated list of forced excluded

Example: ${scriptName} -m dev -f ./dir1,./dir2/dir3
EOF
}

trim()
{
  echo -n "$1" | xargs
}

mode=

while getopts hm:f:? option; do
  case "${option}" in
    h) usage; exit 1;;
    m) mode=$(trim "$OPTARG");;
    f) force=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${mode}" ]]; then
  usage
  exit 1
fi

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -f "${currentPath}/../env.properties" ]]; then
  echo "No environment specified!"
  exit 1
fi

magentoVersion=$(ini-parse "${currentPath}/../env.properties" "yes" "install" "magentoVersion")
if [[ -z "${magentoVersion}" ]]; then
  echo "No Magento version specified!"
  exit 1
fi

serverList=( $(ini-parse "${currentPath}/../env.properties" "yes" "system" "server") )
if [[ "${#serverList[@]}" -eq 0 ]]; then
  echo "No servers specified!"
  exit 1
fi

for server in "${serverList[@]}"; do
  type=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "type")
  if [[ "${type}" == "local" ]]; then
    webPath=$(ini-parse "${currentPath}/../env.properties" "yes" "${server}" "webPath")
    echo "Checking on server: ${server}"
    excludeFile="${currentPath}/exclude-${mode}.list"

    if [[ "${mode}" == "dev" ]]; then
      cat << EOF > "${excludeFile}"
./captcha
./catalog/category/cache
./catalog/product
./css
./css_secure
./js
./tmp
./wysiwyg/.thumbs
EOF
    else
      cat << EOF > "${excludeFile}"
./captcha
./catalog/category/cache
./catalog/product/cache
./css
./css_secure
./js
./tmp
./wysiwyg/.thumbs
EOF
    fi

    if [[ -n "${force}" ]]; then
      IFS=', ' read -r -a forceDirectories <<< "${force}"
      for forceDirectory in "${forceDirectories[@]}"; do
        echo "./${forceDirectory}" >> "${excludeFile}"
      done
    fi

    tempExcludeFile="/tmp/media-exclude-${mode}.list"

    cat "${excludeFile}" | cut -c 3- > "${tempExcludeFile}"

    if [[ ${magentoVersion::1} == 1 ]]; then
      neverExcludeDirectories=( catalog/category wysiwyg )
    else
      neverExcludeDirectories=( catalog/category wysiwyg )
    fi

    for neverExcludeDirectory in "${neverExcludeDirectories[@]}"; do
      echo "${neverExcludeDirectory}" >> "${tempExcludeFile}"
    done

    if [[ ${magentoVersion::1} == 1 ]]; then
      sourcePath="${webPath}/media"
    else
      sourcePath="${webPath}/pub/media"
    fi

    cd "${sourcePath}"

    echo "Checking for big media files in: ${sourcePath}"
    # shellcheck disable=SC2035
    bigMediaFiles=( $(du --exclude-from="${tempExcludeFile}" -s * | grep -E "^[0-9]{5,}") )

    for ((x=0; x<${#bigMediaFiles[@]}; x++)); do
      bigMediaFileSize=${bigMediaFiles[x]}
      x=$((x+1))
      bigMediaFileName=${bigMediaFiles[x]}
      if [[ ${bigMediaFileSize} -gt 99999 ]]; then
        if [[ -d ${bigMediaFileName} ]]; then
          if [[ "${bigMediaFileName}" != "catalog/product" ]]; then
            # check if directory itself contains files to exclude the main media folder
            echo "Checking for big media files in: ${sourcePath}/${bigMediaFileName}"
            if [[ $(du -sS "${bigMediaFileName}"/ | grep -E "^[0-9]{5,}" | wc -l) -eq 1 ]]; then
              echo "./${bigMediaFileName}" >> "${excludeFile}"
            else
              # find all sub directories which cause the big size
              bigMediaSubFiles=( $( find "${bigMediaFileName}"/ -maxdepth 1 -type d ! -name "." ! -path "${bigMediaFileName}"/ -exec du --exclude-from="${tempExcludeFile}" -s {} + | sort -rh | head -10 | grep -E "^[0-9]{5,}" | cat ) )
              for ((y=0; y<${#bigMediaSubFiles[@]}; y++)); do
                bigMediaSubFileSize=${bigMediaSubFiles[y]}
                y=$((y+1))
                bigMediaSubFileName=${bigMediaSubFiles[y]}
                if [[ "${bigMediaSubFileSize}" -gt 99999 ]]; then
                  if [[ "${bigMediaSubFileName}" != "catalog/product" ]]; then
                    echo "./${bigMediaSubFileName}" >> "${excludeFile}"
                  fi
                fi
              done
            fi
          fi
        fi
      fi
    done
    echo "Finished"
  fi
done
