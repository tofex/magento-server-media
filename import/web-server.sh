#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF

usage: ${scriptName} options

OPTIONS:
  --help            Show this message
  --magentoVersion  Magento version
  --webPath         Web path of Magento installation
  --dumpFile        File to import
  --mode            Mode (dev/test/live/catalog/product)

Example: ${scriptName} --magentoVersion 2.4.4 --webPath /var/www/magento/htdocs
EOF
}

magentoVersion=
webPath=
dumpFile=
mode=

if [[ -f "${currentPath}/../../core/prepare-parameters.sh" ]]; then
  source "${currentPath}/../../core/prepare-parameters.sh"
elif [[ -f /tmp/prepare-parameters.sh ]]; then
  source /tmp/prepare-parameters.sh
fi

if [[ -z "${magentoVersion}" ]]; then
  echo "No Magento version specified!"
  usage
  exit 1
fi

if [[ -z "${webPath}" ]]; then
  echo "No web path specified!"
  usage
  exit 1
fi

if [[ ! -d "${webPath}" ]]; then
  echo "No web path available!"
  exit 0
fi

if [[ -z "${dumpFile}" ]]; then
  echo "No dump file specified!"
  usage
  exit 1
fi

echo "Using dump file: ${dumpFile}"

if [[ ! -f "${dumpFile}" ]]; then
  echo "Required file not found at: ${dumpFile}"
  exit 1
fi

if [[ ${magentoVersion::0:1} == 1 ]]; then
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
fileName=$(basename "${dumpFile}")
echo "Extracting dump: ${fileName}"
tar -xf "${fileName}" | cat

echo "Removing copied dump: ${fileName}"
rm -rf "${fileName}"
