#!/bin/bash

## berb-bash-libs git functions
#
# Upstream-Name: berb-bash-libs
# Source: https://github.com/berbascum/berb-bash-libs
#
# Copyright (C) 2024 Berbascum <berbascum@ticv.cat>
# All rights reserved.
#
# BSD 3-Clause License
#
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of the <organization> nor the
#      names of its contributors may be used to endorse or promote products
#      derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

fn_bblgit_workdir_status_check() {
    [ -n "$(git status | grep "staged")" ] && abort "The git workdir is not clean!"
}

fn_bblgit_dir_is_git() {
## Abort if no .git directory found
    [ ! -d ".git" ] && abort "The current dir should be a git repo!"
}

fn_bblgit_debian_control_found() {
## Abort if no debian/control file found
    [ ! -f "debian/control" ] && abort "debian control file not found!"
}

fn_bblgit_last_two_tags_check() {
    ## Check if the has commit has a tag
    last_commit_tag="$(git tag --contains "HEAD")"
    if [ -z "${last_commit_tag}" ]; then
        clear && info "The last commit has not assigned a tag and is required"
	start_with_last_commit_tag="False"
        last_tag=$(git tag --sort=-creatordate | sed -n '1p')
        if [ -n "${last_tag}" ]; then
	    last_commit_tagged=$(git log --decorate  --abbrev-commit \
	       | grep 'tag:' | head -n 1 | awk '{print $2}')
            info "Last commit taged \"${last_commit_tagged}\""
            commit_old_count=$(git rev-list --count HEAD ^"${last_commit_tagged}")
            info "Last tag \"${last_tag}\" and it's \"${commit_old_count}\" commits old"
            ask "Enter a tag name in \"<tag_prefix>/<version>\" format or empty to cancel: "
            [ -z "${answer}" ] && abort "Canceled by user!"
            input_tag_is_valid=$(echo "${answer}" | grep "\/")
            [ -z "${input_tag_is_valid}" ] && error "The typed tag has not a valid format!"
            last_commit_tag="${answer}"
	else
            info "No git tags found!"
            ask "Enter a tag name in \"<tag_prefix>/<version>\" format or empty to cancel: "
            [ -z "${answer}" ] && abort "Canceled by user!"
            input_tag_is_valid=$(echo "${answer}" | grep "\/")
            [ -z "${input_tag_is_valid}" ] && error "The typed tag has not a valid format!"
            last_commit_tag="${answer}"
	fi
    fi
    debug "last_commit_tag definition finished"
    last_commit_id=$(git log --decorate  --abbrev-commit | head -n 1 | awk '{print $2}')
    prev_last_commit_tag="$(git tag --sort=-creatordate | sed -n '2p')"
    if [ -n "${prev_last_commit_tag}" ]; then
        prev_last_commit_id=$(git log --decorate  --abbrev-commit | grep "tag:" \
            | grep "${prev_last_commit_tag}" | head -n 1 | awk '{print $2}')
    else
        ## If there is only the last tag, set the initial commit as prev_last_commit
        prev_last_commit_id=$(git log --pretty=format:"%h" | tail -n 1)
    fi
    debug "prev_last_commit_id definition finished"
    debug "Last commit tag defined: ${last_commit_tag}"
    debug "Last commit id defined: ${last_commit_id}"
    debug "PrevLast commit tag defined: ${prev_last_commit_tag}"
    debug "PrevLast commit id defined: ${prev_last_commit_id}"
}

fn_bblgit_create_tag() {
    ## First ensure again that the tag not exist yet
    tag_exist=$(git log --decorate | grep "tag:" | grep "${last_commit_tag}")
    [ -n "${tag_exis}" ] && return
    ## Create the last_commit_tag if was defined by this script
    if [ "${start_with_last_commit_tag}" == "False" ]; then
        info "Creating tag \"${last_commit_tag}\" on the last commit..."
        git tag "${last_commit_tag}"
	git push --tags origin
    fi
}

fn_bblgit_changelog_build() {
    changelog_git_relpath_filename="debian/changelog"
    changelog_builder_user=$(git config --global user.name)
    changelog_builder_email=$(git config --global user.email)
    ## Prepare changelog
    if [ -f "${changelog_git_relpath_filename}" ]; then
	rm "${changelog_git_relpath_filename}"
    fi
    touch "${changelog_git_relpath_filename}"
    ## Get commit_id short=%h author=%an author_mail=%ae committer=%cn 
    ## committer_mail=%ce date_RFC2822=%aD date_ISO-8601-like=%ai \
    ## header=%s(need to be the last)
    info "Generating a debian formatted changelog file from git log..."
    ## The locale en_US.utf8 should be ensured to avoid format errors in changelog
    en_us_locale=$(locale -a | grep "en_US.utf8")
    if [ -z "${en_us_locale}" ]; then
	PAUSE "Gen en_US.utf8 locale is needed, the sudo password will be needed!"
        ${SUDO} sed -i 's/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
	${SUDO}  locale-gen && ${SUDO} update-locale
    fi
    export LC_TIME=en_US.utf8
    date_full=$(date +"%a, %d %b %Y %H:%M:%S %z")
    debug "date_full = ${date_full}"
    date_short=$(date +%Y%m%d%H%M%S)
    pkg_version_git=$(echo "${package_version}+git${date_short}.${last_commit_id}.${pkg_dist_channel}")
    echo "${package_name} (${pkg_version_git}) ${pkg_dist_channel}; urgency=medium" \
	> "${changelog_git_relpath_filename}"
    echo >> "${changelog_git_relpath_filename}"
    debug "prev_last_commit_tag = ${prev_last_commit_tag}"
    debug "last_commit_tag = ${last_commit_tag}"
    [ -d "commits_tmpdir" ] ||  mkdir -v "commits_tmpdir"
    git log --pretty=format:"%h %an %ae %cn %ce %cD %ci %s" "${prev_last_commit_id}"..."${last_commit_id}" > commits_tmpdir/export.txt
    while read commit; do
	commit_id_short=$(echo ${commit} | awk '{print $1}')
	author_name=$(echo ${commit} | awk '{print $2}') ## %an
	author_email=$(echo ${commit} | awk '{print $3}') ## %an
	commiter_name=$(echo ${commit} | awk '{print $4}')
	debug2 "commiter_name =${commiter_name}"
	commiter_email=$(echo ${commit} | awk '{print $5}')
        #COMMITTER_DATE_RFC2822=$(echo ${commit} \
	    ##| awk '{print $6 " " $7 " "  $8 " "  $9 " "  $10 " " $11}')
        #COMMITTER_DATE_COMPACTED=$(echo ${commit} | awk '{print $12 $13}' \
	    ## | tr  -d "-" | tr -d ":")
	commit_header=$(echo ${commit} | awk '{ for (i=15; i<=NF; i++) printf $i " " }')
	commit_body=$(git show --format=%b ${commit_id_short} | awk 'NR==1,/diff --git/' \
	    | grep --invert-match 'diff --git' | egrep '^[[:blank:]]*[^[:blank:]#]')
        ## Put the commits in a file for each commiter
	echo "  * (${commit_id_short}) ${commit_header}" \
	    >> commits_tmpdir/${commiter_name}
	if [ -n "${commit_body}" ]; then
	    echo "              ${commit_body}" >> commits_tmpdir/${commiter_name}
	fi
    done <commits_tmpdir/export.txt
    rm commits_tmpdir/export.txt
    ## Cat every commiteter commits to the changelog file
    for commiter_file in $(ls commits_tmpdir); do
	echo "  [${commiter_name}]" >> "${changelog_git_relpath_filename}"
        cat commits_tmpdir/${commiter_name} >> "${changelog_git_relpath_filename}"
	echo >> "${changelog_git_relpath_filename}"
    done
    ## Committer of changes
    echo  " -- ${changelog_builder_user} <${changelog_builder_email}>  ${date_full}" \
        >> "${changelog_git_relpath_filename}"
    rm -r commits_tmpdir
    INFO "Finalized changelog file build from git log..."
}

fn_bblgit_changelog_commit() {
    ## First check possible edited files rather than changelog and commit if exist
    arr_files_may_have_been_edited=( "debian/changelog" "${package_name}.sh" )
    arr_files_to_commit=()
    for file_edited in ${arr_files_may_have_been_edited[@]}; do
	[ -f "${file_edited}" ] && arr_files_to_commit+=( "${file_edited}" )
    done
    ## Check arr_files to_commit befor doing the commit
    if [ "${#arr_files_to_commit[@]}" -eq "0" ]; then
        error "debian/changelog not found when trying to commit it!"
    else
        info "Creating commit with the updated changelog..."
        git add "${arr_files_to_commit[@]}"
        git commit -m "Build \"${last_commit_tag}\" version: debian/changelog and other version related upgrades"
    fi
}
