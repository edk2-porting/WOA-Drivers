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
while read -r line
do
	file="${line//$'\r'/}"
	file="${file//'\'//}"
	cp -vr ."${file}" output/
done<"${CONFIG}"
find output -type f -name '*.inf_'|while read -r line
do mv -v "${line}" "${line//.inf_/.inf}"
done
