#!/bin/bash

lib_src_relpath_file="libs/modules/bbl_git_lib-main.sh"

lib_ver_int=$(grep "TOOL_VERSION_INT" ${lib_src_relpath_file} | awk -F'=' '{print $2}' | sed 's/"//g')

lib_dst_fullpath_file="/usr/lib/berb-bash-libs/bbl_git_lib_${lib_ver_int}"

echo "Copying the lib to ${lib_dst_fullpath_file}..."
cat ${lib_src_relpath_file} | sudo tee ${lib_dst_fullpath_file} >/dev/null
