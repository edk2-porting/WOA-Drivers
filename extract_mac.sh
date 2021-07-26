#!/bin/bash
set -e
if [ -z "${1}" ]
then
	echo "no codename specified" >&2
	echo "Usage: ${0} <CODENAME>" >&2
	exit 1
fi
cd "$(dirname "$0")"
CONFIGS=definitions
CONFIG="${CONFIGS}/${1}.txt"
if ! [ -f "${CONFIG}" ]
then
	echo "ERROR: your model has no definition file, please check!" >&2
	exit 1
fi
rm -rf ./output
echo "copying drivers..."
while read -r line
do
	file="${line//$'\r'/}"
	file="${file//'\'//}"
	cp -r ."${file}" output/
done<"${CONFIG}"
echo "rename drivers..."
find output -type f -name '*.inf_'|while read -r line
do mv "${line}" "${line//.inf_/.inf}"
done
echo "done"
