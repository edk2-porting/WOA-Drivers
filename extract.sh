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
DEF=sdm845-generic
CONFIG="${CONFIGS}/${1}.txt"
if ! [ -f "${CONFIG}" ]
then
	echo "warning: your model has no definition file, use default" >&2
	CONFIG="${CONFIGS}/${DEF}.txt"
	if ! [ -f "${CONFIG}" ]
	then
		echo "default definition file not found"
		exit 1
	fi
fi
rm -rf ./output
echo "copying drivers..."
while read -r line
do
	file="${line//$'\r'/}"
	file="${file//\\/\/}"
	cp -r ."${file}" output/
done<"${CONFIG}"
echo "rename drivers..."
find output -type f -name '*.inf_'|while read -r line
do mv "${line}" "${line//.inf_/.inf}"
done
echo "done"
