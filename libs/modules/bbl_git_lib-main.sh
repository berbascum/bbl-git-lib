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

#[HEADER_SECTION]
fn_header_info() {
    BIN_TYPE="lib"
    BIN_SRC_TYPE="bash"
    BIN_SRC_EXT="sh"
    BIN_NAME="bbl_git_lib"
    TOOL_VERSION="1.2.2.1"
    TOOL_RELEASE="testing"
    URGENCY='optional'
    TESTED_BASH_VER='5.2.15'
}
#[HEADER_END]


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

fn_bblgit_check_if_can_sign() {
    git_key_found="$(gpg --list-keys --keyid-format LONG | grep $(git config --global user.signingkey))"

    if [ -n "${git_key_found}" ]; then
        GIT_COMMIT_CMD='git commit -S -m "${commit_msg}"'
    else
        GIT_COMMIT_CMD='git commit -m "${commit_msg}"'
    fi
}

fn_bblgit_origin_status_ckeck() {
    ## Check the remote origin status
    current_branch=$(git branch | grep "*" | awk '{print $2}')
    ## Check if current branch exists in origin
    origin_branch_found=$(git log --decorate | grep "origin/${current_branch}")
    [ -z "${origin_branch_found}" ] && error "Curr branch \"${current_branch}\" not exist in origin"
    ## Check if origin is updated
    origin_is_updated=$(git log --decorate | head -n 1 | grep "origin/${current_branch}")
    if [ -z "${origin_is_updated}"  ]; then
        info "The current branch \"${current_branch}\" is not updated on origin."
        ASK " An updated origin is a requirement. Want to push last changes? [ y|n ]: "
        [ "${answer}" == "y" ] && git push origin ${current_branch} || abort "Canceled by user!"
    else
	info "The branch on origin is updated!"
    fi
}

fn_bblgit_linux_dist_releases_get() {
    url="$1"
    arr_releases_default=( "trixie" "stable" "testing" "unstable" "sid" "oldstable" "experimental" )
    arr_releases_dists=()
    IFS=$' '
    while read  release; do 
	arr_releases_dists+=( "${release}" )
    done <<<$(curl -s "${url}" | grep "\<li\>" | grep -v -E "devel|http|Pack|Inter" | grep "Debian " \
	 | awk -F'="' '{print $2}' | awk -F'/' '{print $1}')
    valid_tag_releases=$(echo ${arr_releases_default[*]} ${arr_releases_dists[*]})
    IFS=$' \t\n'
}

fn_bblgit_tag_check_get_info() {
    tag_name="$1"
    ## Check if the typed tag has a valid format
    if [ "${pkg_type}" == "debian_package" ]; then
        tag_release=$(echo "${tag_name}" | grep "\/" | awk -F'/' '{print $1}')
        tag_suffix=$(echo "${tag_name}" |awk -F'/' '{print $2}')
    elif [ "${pkg_type}" == "droidian_adaptation" ]; then
        tag_prefix=$(echo "${tag_name}" | grep "\/" | awk -F'/' '{print $1}')
        tag_release=$(echo "${tag_name}" | grep "\/" | awk -F'/' '{print $2}')
        tag_suffix=$(echo "${tag_name}" |awk -F'/' '{print $3}')
    fi
    [ -z "${tag_release}" ] && error "The tag name has not a valid format!"
    ## Check if the tag name has  a valid release to avoid dpkg build problems with changelog
    tag_release_is_valid=$(echo ${valid_tag_releases} | grep "${tag_release}")
    [ -z "${tag_release_is_valid}" ] && error "The tag name has not a valid release!"
    [ -z "${tag_suffix}" ] && error "The tag name has not a valid format (a version was expected!"
    tag_suffix_is_valid=$(echo "${tag_suffix}" | grep "^[0-9]")
    [ -z "${tag_suffix_is_valid}" ] && error "The tag_suffix (version) should start by a number!"
    ## If the typed tag is valid, set the final var and continue execution
    last_commit_tag="${tag_name}"
    tag_version="${tag_suffix}"
    tag_version=$(echo ${tag_version} | sed s/"-"/"."/g)
    tag_version_int=$(echo ${tag_version} | sed s/"\."/""/g | sed s/"-"/""/g)
    debug "tag_release = ${tag_release}"
    debug "tag_version = ${tag_version}"
    debug "tag_version:int = ${tag_version_int}"
}

fn_bblgit_ask_for_tag() {
    info "Last tag \"${last_tag}\" and it's \"${commit_old_count}\" commits old"
    info "Enter a tag name in \"${TAG_FORMAT}\" format. List of valid releases:"
    echo; echo "${valid_tag_prefixes}"
    ASK "Or empty to cancel: "
    [ -z "${answer}" ] && abort "Canceled by user!"
    ## Check if the tag name is valid
    fn_bblgit_tag_check_get_info "${answer}"
}

fn_bblgit_last_two_tags_check() {
    ## Get a list of valid debian releases to avoid buildpackage error related to changelog
    fn_bblgit_linux_dist_releases_get "https://www.debian.org/releases/"
    debug "valid_tag_prefixes = ${valid_tag_prefixes}"
    ## Check if the has commit has a tag
    last_commit_tag="$(git tag --contains "HEAD")"
    if [ -n "${last_commit_tag}" ]; then
        ## Check if the tag name is valid
        fn_bblgit_tag_check_get_info "${last_commit_tag}"
    else
        clear && info "The last commit has not assigned a tag and is required"
	start_with_last_commit_tag="False"
        last_tag=$(git tag --sort=-creatordate | sed -n '1p')
	debug "last_tag = ${last_tag}"
        if [ -n "${last_tag}" ]; then
	    last_commit_tagged=$(git log --decorate  --abbrev-commit \
	       | grep 'tag:' | head -n 1 | awk '{print $2}')
            info "Last commit tagged \"${last_commit_tagged}\""
            commit_old_count=$(git rev-list --count HEAD ^"${last_commit_tagged}")
	    ## ask fir a tag
            fn_bblgit_ask_for_tag
	else
            info "No git tags found!"
	    ## ask fir a tag
            fn_bblgit_ask_for_tag
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
    pkg_version_git=$(echo "${tag_version}+git${date_short}.${last_commit_id}.${tag_release}")
    echo "${package_name} (${pkg_version_git}) ${tag_release}; urgency=medium" \
	> "${changelog_git_relpath_filename}"
    echo >> "${changelog_git_relpath_filename}"
    debug "prev_last_commit_tag = ${prev_last_commit_tag}"
    debug "last_commit_tag = ${last_commit_tag}"
    [ -d "commits_tmpdir" ] ||  mkdir -v "commits_tmpdir"
    git log --pretty=format:"%h %an %ae %cn %ce %cD %ci %s" "${prev_last_commit_id}"..."${last_commit_id}" > commits_tmpdir/export.txt
    debug "File commits_tmpdir/export.txt created"
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
	debug2 "Commit header filtered = ${commit_header}"
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

fn_bblgit_commit_changes() {
    #file_updated="$1"
    commit_msg="$1"
    #file_updated_status=$(git status | grep "${file_updated}")
    #[ -z "${file_updated}" ] && error "Some went wrong when trying to commit \"${file_updated}\""
    #info "Committing the updated \"${file_updated}\"..."
    git status
    ASK "The above files and dirs will be added and commited. Want to continue? [ y|n ]: "
    [ "${answer}" != "y" ] && abort "Aborted by user!"
    git add -A
    fn_bblgit_check_if_can_sign
    eval "${GIT_COMMIT_CMD}"
}
