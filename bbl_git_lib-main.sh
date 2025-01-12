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
    TOOL_VERSION="1.3.1.1"
    TOOL_VERSION_INT="1311"
    TOOL_RELEASE="testing"
    URGENCY='optional'
    TESTED_BASH_VER='5.2.15'
}
#[HEADER_END]

source /usr/lib/berb-bash-libs/bbl_general_lib_1101

fn_bblgit_check_args() {
    ## Check for --build-release=release flag
    flag_name=build-release
    fn_bbgl_check_args_search_flag $@
    debug "Iniciant bblgit check args"
    debug "bbl-git: FLAG_FOUND_VALUE = \"${FLAG_FOUND_VALUE}\""
    build_release_supplied=${FLAG_FOUND_VALUE}
    info "bbl-git: build_release_supplied: \"${FLAG_FOUND_VALUE}\""

    ## Check for --build-tag-prefix=str flag
    flag_name="build-tag-prefix"
    fn_bbgl_check_args_search_flag $@
    debug "bbl-git: FLAG_FOUND_VALUE = \"${FLAG_FOUND_VALUE}\""
    build_tag_prefix_supplied=${FLAG_FOUND_VALUE}
    info "bbl-git: build_tag_prefix_supplied: \"${FLAG_FOUND_VALUE}\""

    ## Check for --batch mode flag
    if [ -n "$(echo $@ | grep "\-\-batch")" ]; then
        BATCH_MODE_BBL_GIT=true
    else
        BATCH_MODE_BBL_GIT=false
    fi
    info "batch mode: ${BATCH_MODE_BBL_GIT}"
}

fn_bblgit_workdir_status_check() {
    if [ -z "$(git status | grep "staged")" ]; then
        info "${FUNCNAME[0]}: git workdir is clean!"
    else
        error "${FUNCNAME[0]}: git workdir is not clean!"
    fi
}

fn_bblgit_dir_is_git() {
## Abort if no .git directory found
    if [ -e ".git" ]; then
        info "${FUNCNAME[0]}: current dir is a git repo"
    else
        error "${FUNCNAME[0]}: current dir should be a git repo!"
    fi
}

fn_bblgit_debian_control_found() {
## Abort if no debian/control file found
    if [ -e "debian/control" ]; then
        info "${FUNCNAME[0]}: debian control file found"
    else
        error "${FUNCNAME[0]}: debian control file not found!"
    fi
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
    ## Check the remote origin status for branch
    [ -z "${current_branch}" ] && error "fn_bblgit_origin_status_ckeck: current_branch not defined"
        #current_branch=$(git branch | grep "*" | awk '{print $2}')
    ## Get origin branch info
    origin_branch_found=$(git log --decorate | grep "origin/${current_branch}")
    origin_branch_updated=$(git log --decorate | head -n 1 | grep "origin/${current_branch}")

    if [ -n "${origin_branch_updated}" ]; then
        info "bbl-git: Current branch \"${current_branch}\" exist in origin and is updated."
        git_origin_status=branch-updated
    elif [ -n "${origin_branch_found}" ]; then
        info "bbl-git: Current branch \"${current_branch}\" exist in origin but is not updated."
        git_origin_status=branch-outdated
    elif [ -z "${origin_branch_found}" ]; then
        info "bbl-git: Current branch \"${current_branch}\" not exist in origin."
        git_origin_status=branch-missing
    fi

    ## Origin only will be updated in interactive mode
    ## TODO: implement updates on origin using flags in batch mode
    if [ "${BATCH_MODE_BBL_GIT}" == "false" ]; then
        if [[ "${git_origin_status}" \
          =~ ^(branch-missing|branch-outdated)$ ]]; then
            ASK "bbl-git: Current branch \"${current_branch}\" not not found in origin. Push? [ y | any ]: "
            case "${answer}" in
                y)
                  git push origin ${current_branch}
                  ;;
                *)
              esac
        fi
    fi
}

fn_bblgit_linux_dist_releases_get() {
  url="https://www.debian.org/releases/"
  arr_releases_default=( "trixie" "stable" "testing" "unstable" "sid" "oldstable" "experimental" )
  arr_releases_dists=()
  IFS=$' '
  while read release; do
	arr_releases_dists+=( "${release}" )
  done <<<$(curl -s "${url}" | grep "\<li\>" | grep -v -E "devel|http|Pack|Inter" | grep "Debian " \
	 | awk -F'="' '{print $2}' | awk -F'/' '{print $1}')
       arr_valid_build_releases=( ${arr_releases_default[@]} ${arr_releases_dists[@]} )
  IFS=$' \t\n'
}

fn_git_ask_for_tagname() {
    ## ask for a tag
    tag_format_str="[some_prefix]/[other_string]/release/[other_string]version"
    last_commit_tagged_id=$(git log --decorate  --abbrev-commit \
	       | grep 'tag:' | head -n 1 | awk '{print $2}')
    last_commit_tagged_old_count=$(git rev-list --count HEAD ^"${last_commit_tagged_id}")
    echo ""
    echo "bbl-git: build_release_supplied was not supplied, and the last commit is not tagged"
    echo "bbl-git: bbl-git: Last commit tagged \"${last_commit_tagged_id}\" as \"${last_tag}\""
    echo "bbl-git: The last tag: \"${last_tag}\" tag is \"${last_commit_tagged_old_count}\" commits old"
    echo ""
    echo "Enter a new name for tagging the last commit,"
    echo "or an existing tag, and continue the build"
    echo ""
    echo "Format: ${tag_format_str}"
    echo ""
    echo "List of valid releases:"
    echo "${arr_valid_build_releases[@]}"
    ASK "Or press Intro to abort: "
    ## Check if contain a valid release
    for valid_build_release in ${arr_valid_build_releases[@]}; do
      valid_build_release_found=$(echo "${answer}" \
        | grep "${valid_build_release}")
      [ -n "${valid_build_release_found}" ] && break
    done
    ## Ensure a valid release is in the supplied tag name
    [ -n "${valid_build_release_found}" ] \
      || error "bbl-git: The supplied tag name should contain a valid release"
    build_release=${valid_build_release}
}

fn_bblgit_tag_check() {
    tag_name="$1"
    debug "${FUNCNAME[0]}: Starting tag check, tag_name: ${tag_name}"
    # build_tag_prefix_supplied=berb
    arr_tag_field_seps=( '/' ) # Allowed tag seps list
    tag_field_seps_min="2" # Min release/version
    tag_fields_min=$((tag_field_seps_min + 1)) # Min release/version
    tag_field_seps_max=""  # No limit by default
    ## Override defults for previously defined vars
    [ -n "${arr_GIT_TAG_NAME_SEPARATORS}" ] \
	&& arr_tag_field_seps=${arr_GIT_TAG_NAME_SEPARATORS[@]}
    ## DEPRECATED:
    ## Now BUILD_TAG_PREFIX is passed using a flag,
    ## and checkargs fn from bbl-general
       #[ -n "${BUILD_TAG_PREFIX}" ] && \
       #build_tag_prefix_supplied=$BUILD_TAG_PREFIX}
    [ -n "${GIT_TAG_NAME_SEPARATORS_MIN}" ] \
	&& tag_field_seps_min=${GIT_TAG_NAME_SEPARATORS_MIN} \
	&& tag_fields_min=$((tag_field_seps_min + 1))
    [ -n "${GIT_TAG_NAME_SEPARATORS_MAX}" ] \
	&& tag_field_seps_max=${GIT_TAG_NAME_SEPARATORS_MAX}

    ## Search for valid separators in tag_name
    debug "bbl-git: Searching in the tag name for a separator from the allowed separators list"
    tag_fields_count=""
    for tag_field_sep in ${arr_tag_field_seps[@]}; do
        debug "bbl-git: Trying separator \"${tag_field_sep}\""
        ## Split fields in a temporary array
        IFS_BKP=$IFS
        IFS=$tag_field_sep read -ra arr_tag_fields <<< "${tag_name}"
        IFS=$IFS_BKP
        ## Check for the min fields count
        if [ "${#arr_tag_fields[@]}" -ge "${tag_fields_min}" ]; then
            tag_fields_count="${#arr_tag_fields[@]}"
            tag_field_sep_found=${tag_field_sep}
            debug "bbl-git: The tag name has the min fields count: \"${tag_fields_min}\""
            break
        elif [ "${#arr_tag_fields[@]}" -lt "${tag_fields_min}" ]; then
            debug "bbl-git: The tag name has not the min fields count: \"${tag_fields_min}\", or wrong separator \"${tag_field_sep}\""
        fi
    done

    ## Abort if no tag found with required format
    [ "${#arr_tag_fields[@]}" -ge "${tag_field_seps_min}" ] \
        || error "bbl-git: No tag found with min fields count: \"${tag_fields_min}\", or wrong separator"

    ## Check the tag prefix
    tag_prefix_current="${arr_tag_fields[0]}"
    debug "${FUNCNAME[0]}: tag_prefix_current: ${tag_prefix_current}"
    if [ -n "${build_tag_prefix_supplied}" ]; then
        if [ "${tag_prefix_current}" == "${build_tag_prefix_supplied}" ]; then
            build_tag_prefix=${build_tag_prefix_supplied}
            info "bbl-git: The build_tag_prefix_supplied \"${build_tag_prefix_supplied}\" is valid"
        else
            error "Sbbl-git: pecified build_tag_prefix_supplied \"${build_tag_prefix_supplied}\" not in tag"
        fi
    else
        ## prefix prèviament no definit
        build_tag_prefix=${tag_prefix_current}
        info "bbl-git: build_tag_prefix free \"${build_tag_prefix}\", defined from tag"
    fi

    ## Get the tag version (last field)
    tag_version=$(echo ${tag_name} \
      | awk -F$tag_field_sep '{print $NF}')

    ## Search for a field with valid release
    for tag_field in ${arr_tag_fields[@]}; do
        for valid_release in "${arr_valid_build_releases[@]}"; do
            if [ "${tag_field}" == "${valid_release}" ]; then
                info "bbl-git: Found a valid release in tag name"
                tag_release=${valid_release}
                [ -z "${build_release}" ] \
                    && build_release=${tag_release}
                break
            fi
        done
    done

<< "DEPRECATED"
#  ## Abort if no valid release found in the tag name
#  [ -n "${tag_release}" ] || error \
#    "No tags wich contain a valid release name were found"
DEPRECATED

    info "bbl-git: tag_name: ${tag_name}"
    info "bbl-git: build_release: ${build_release}"
    info "bbl-git: build_tag_prefix: ${build_tag_prefix}"
    info "bbl-git: tag_version: ${tag_version}"
    info "bbl-git: tag_fields_count: ${tag_fields_count}"
    if [ -n "${tag_fields_count}" ]; then
        build_tag="${build_tag_precheck}"
    else
        error "bbl-git: The tag \"${build_tag_precheck}\": invalid format"
    fi

<< "OLD_CKECK_TAG_METHOD"
    ## Check if the tag has a valid format
    if [ "${pkg_type}" == "debian_package" ]; then
        tag_release=$(echo "${tag_name}" | grep "\/" | awk -F'/' '{print $1}')
        tag_suffix=$(echo "${tag_name}" |awk -F'/' '{print $2}')
    elif [[ "${pkg_type}" =~ ^(droidian_adaptation|droidian_package)$ ]]; then
        tag_prefix=$(echo "${tag_name}" | grep "\/" | awk -F'/' '{print $1}')
        tag_release=$(echo "${tag_name}" | grep "\/" | awk -F'/' '{print $2}')
        tag_suffix=$(echo "${tag_name}" |awk -F'/' '{print $3}')
    elif [ "${pkg_type}" == "kernel" ] then
	read -p "bbl-git: TODO kernel condition fn_bblgit_tag_check"
    fi
    [ -z "${tag_release}" ] && error "The tag name has not a valid format!"
    ## Check if the tag name has  a valid release to avoid dpkg build problems with changelog
    tag_release_is_valid=$(echo ${arr_valid_build_releases} | grep "${tag_release}")
    [ -z "${tag_release_is_valid}" ] && error "bbl-git: The tag name has not a valid release!"
    [ -z "${tag_suffix}" ] && error "bbl-git: The tag name has not a valid format (a version was expected!"
    tag_suffix_is_valid=$(echo "${tag_suffix}" | grep "^[0-9]")
    [ -z "${tag_suffix_is_valid}" ] && error "bbl-git: The tag_suffix (version) should start by a number!"
    ## If the typed tag is valid, set the final var and continue execution
    last_commit_tag="${tag_name}"
    tag_version="${tag_suffix}"
    tag_version=$(echo ${tag_version} | sed s/"-"/"."/g)
    tag_version_int=$(echo ${tag_version} | sed s/"\."/""/g | sed s/"-"/""/g)
    debug "tag_release = ${tag_release}"
    debug "tag_version = ${tag_version}"
    debug "tag_version:int = ${tag_version_int}"
OLD_CKECK_TAG_METHOD
}

fn_bblgit_build_version_info_analyze_ref() {
## Get version info for packaging from git branch/tag

    ## Set early vars
    build_tag=""
    last_tag=$(git tag --sort=-creatordate | sed -n '1p')

    ## First set a list of valid releases for packaging
    fn_bblgit_linux_dist_releases_get

    ## Search for a supplied release branch to build
    if [ -n "${build_release_supplied}" ]; then
        debug "bbl-git: build_release_supplied previously defined: \"${build_release_supplied}\""
        build_release="${build_release_supplied}"
        ## Check if the supplied release has tags
        last_tag_build_release=$(git tag --sort=-creatordate \
            | grep "${build_release}" | head -n 1)
        if [ -n "${last_tag_build_release}" ]; then
            build_tag_precheck="${last_tag_build_release}"
            debug "bbl-git: The tag_name contains the supplied release"
        else
            ## TODO: ASK for tag in interactive mode
            error "bbl-git: Tag_name not contains the supplied release"
        fi
    else
        debug "bbl-git: build_release_supplied not defined"
        ## Check if the last commit is tagged
        last_commit_tag=$(git tag --contains "HEAD")
        if [ -n "${last_commit_tag}" ]; then
            debug "bbl-git: The last commit is tagged"
            build_tag_precheck="${last_commit_tag}"
            info "bbl-git: Defined build_tag_precheck: \"${build_tag_precheck}\""
        else
            debug "bbl-git: The last commit is not tagged"
            if [ "${BATCH_MODE_BBL_GIT}" == "false" ]; then
                ## For non batch mode:
                ## if last commit is tagged, use it
                ## untagged, ask tag creation
                debug "bbl-git: no tag in last commit, no batch"
                ## ask for a tag
                fn_git_ask_for_tagname
                [ -z "${answer}" ] && abort "bbl-git: Aborted"
                if [ -z "$(git tag | grep "^${answer}$")" ]; then
                    ## no tag found with user supplied name
                    debug "bbl-git: No tag found with the user supplied name, will be checked"
                    new_tag_name="${answer}"
                    build_tag_precheck="${new_tag_name}"
                    info "bbl-git: Defined build_tag_precheck: \"${build_tag_precheck}\""
                elif [ -n "$(git tag | grep "^${answer}$")" ]; then
                    ## tag found with supplied name
                    debug "bbl-git: tag found with supplied name, not need to check"
                    build_tag="${answer}"
                    build_tag_precheck="" # no need to check
                    info "bbl-git: Defined build_tag_precheck: \"${build_tag_precheck}\""
                fi
            fi # batch fals -z build_release_supplied -z last_commit_tag
        fi # last_commit_tag
    fi # build_release supplied or not

    [ -n "${build_tag_precheck}" ] && fn_bblgit_tag_check "${build_tag_precheck}"

    ## Create a new tag if requested
    if [ -n "${new_tag_name}" ]; then
        debug "bbl-git: Tag creation was requested: \"${build_tag}\""
        tag_commit_id="HEAD" # empty for head
        pause "bbl-git: a punt de crear new_tag_name: \"${new_tag_name}\" "
        fn_bblgit_create_tag \
          "${new_tag_name}" \
          "${tag_commit_id}"
    fi

    ## Branch info
    ## Get early vars
    current_branch=$(git branch | awk '/\*/ {print $2}')
    build_branch="${current_branch}"
    arr_branch_field_seps=( '-' '_' ) # Allowed branch seps list
    for branch_field_sep in ${arr_tag_field_seps[@]}; do
        if [ -n "$(echo "${build_branch}" | grep "${branch_field_sep}")" ]; then
            debug "bbl-git: separator \"${branch_field_sep}\" found in the current branch name"
            break
        fi
    done
    ## Create version comment for Droidian build tools integration
    branch_version_comment=$(echo ${build_branch} | sed "s|\${branch_field_sep}|\.|g")
    branch_version_comment=$(echo "${build_branch}")

    info "bbl-git: branch_version_comment: ${branch_version_comment}"
    build_version_comment="${branch_version_comment}"."${build_release}"
    info "bbl-git: build_version_comment: ${build_version_comment}"



<< "VARS_UNUSED_BUT_MIGHT_BE_USEFUL_FROM_OLD_CHECK_METHOD"
    last_commit_id=$(git log --decorate  --abbrev-commit | head -n 1 | awk '{print $2}')
    prev_last_commit_tag="$(git tag --sort=-creatordate | sed -n '2p')"
    if [ -n "${prev_last_commit_tag}" ]; then
        prev_last_commit_id=$(git log --decorate  --abbrev-commit | grep "tag:" \
            | grep "${prev_last_commit_tag}" | head -n 1 | awk '{print $2}')
    else
        ## If there is only the last tag, set the initial commit as prev_last_commit
	
        prev_last_commit_id=$(git log --pretty=format:"%h" | tail -n 1)
    fi
    debug "bbl-git: prev_last_commit_id definition finished"
    debug "bbl-git: Last commit tag defined: ${last_commit_tag}"
    debug "bbl-git: Last commit id defined: ${last_commit_id}"
    debug "bbl-git: PrevLast commit tag defined: ${prev_last_commit_tag}"
    debug "bbl-git: PrevLast commit id defined: ${prev_last_commit_id}"
VARS_UNUSED_BUT_MIGHT_BE_USEFUL_FROM_OLD_CHECK_METHOD
}

fn_bblgit_bdm_build_version_info_get() {
    ## pass required flags to the bblgit check args
    fn_bblgit_check_args \
        --batch \
        --build-release=${BUILD_RELEASE} \
        --build-tag-prefix=${BUILD_TAG_PREFIX}
    debug "${FUNCNAME[0]}: Finished bblgit check_args call"
    ## Get vars from git tag and branch
    fn_bblgit_build_version_info_analyze_ref
    debug "${FUNCNAME[0]}: Finished bblgit version_info_from_git call"
}

fn_bblgit_create_tag() {
  tag_name=$1
  tag_from=$2
  [ -n "${tag_name}" ] || error "bbl-git: create_tag: A tag name is required"
  info "bbl-git: Creating tag \"${tag_name}\" on the last commit..."
  git tag "${tag_name}" "${tag_from}"
  [ $? -eq "0" ] || error "Tag creation failed!"

  ## Ask for pushing changes
  if [ "${BATCH_MODE_BBL_GIT}" == "false" ]; then
    ASK "bbl-git: Push the tag ${tag_name} to origin? [ y | any ]: " answer
    [ "${answer}" == "y" ] \
      && git push origin "${tag_name}"
  fi
}

fn_bblgit_changelog_build() {
    info "${FUNCNAME[0]}: Generating a debian formatted changelog file from git log..."
    ## Header:
       ## changelog_version_git:
          ## package_name: from control
          ## tag_ch_version
          ## tag_ch_commit_date_short
          ## tag_ch_commit_id_short
          ## build_version_comment
    ## Commits:
       ## comm_ch_author
            ## comm_ch_id_short
            ## Comment
    ## Footer:
       ## packager name: from user's git config
       ## packaging date: date_now_long

    ## Prepare changelog
    changelog_git_relpath_filename="debian/changelog"
#    [ -f "${changelog_git_relpath_filename}" ] \
        rm -v "${changelog_git_relpath_filename}"
    touch "${changelog_git_relpath_filename}"

    ## The locale en_US.utf8 should be ensured
    ## to avoid format errors in changelog
    en_us_locale=$(locale -a | grep "en_US.utf8")
    if [ -z "${en_us_locale}" ]; then
        PAUSE "bbl-git: Gen en_US.utf8 locale is needed, the sudo password will be needed!"
        ${SUDO} sed -i 's/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
        ${SUDO}  locale-gen && ${SUDO} update-locale
    fi
    export LC_TIME=en_US.utf8

    ## Put all release tags in an array
    arr_tags_found=()
    arr_tag_ranges=()
    tag_older=
    tag_newer=
    ## NOTICE: For by creation descending list
    ## NOTICE: Filter by build_release
    for tag in $(git tag --sort=-creatordate | grep "${build_release}"); do
        if [ -n "${tag_newer}" ] && [ -n "${tag_older}" ]; then
        ## Iter > 2, both vars defined
            tag_older="${tag}"
            tag_newer="${tag_previous}"
            tag_previous="${tag}"
        ## Range still not valid
        elif [ -z "${tag_newer}" ] && [ -z "${tag_older}" ]; then 
        ## First iter: nothing defined
            tag_newer="${tag}"
        elif [ -n "${tag_newer}" ] && [ -z "${tag_older}" ]; then 
        ## Second iter: only older defined
        ## Range is valid from now
            tag_older="${tag}"
            tag_previous="${tag}"
        fi
        ## Only add range if both vars defined
        if [ -n "${tag_older}" ] && [ -n "${tag_older}" ]; then
            arr_tag_ranges+=( "${tag_older}..${tag_newer}" )
        fi
        debug "tag_newer=${tag_newer}"
        debug "tag_previous=${tag_previous}"
        debug "tag_older=${tag_older}"
        debug "tag_rang=${tag_older}..${tag_newer}"
        DEBUG "Final iteració for tag"
        arr_tags_found+=( "${tag}" )
    done # finish for tag
    ## Above for returns two arrays:
       # arr_tags_found
       # arr_tag_ranges
    #tags_found_count="${#arr_tags_build_release[@]}"
    printf '%s\n' ${arr_tags_found[@]}
    DEBUG "Above: printf arr_tags_found"
    printf '%s\n' ${arr_tag_ranges[@]}
    DEBUG "Above: printf arr_tag_ranges"

    ## When the initial commit is not tagged,
    ## we need to define an extra range to get
    ## commits between older tag and ini commit
    commit_initial_id_short=$(git rev-list --max-parents=0 --abbrev-commit HEAD)
    commit_initial_is_tagged=$(git tag --points-at ${commit_initial})
    if [ -z "${commit_initial_is_tagged}" ]; then
        tag_last=$(printf '%s\n' \
            ${arr_tags_found[@]} | tail -n 1)
        DEBUG "${FUNCNAME[0]}: initial commin untagged:"
        debug "Adding tag_last..initial_commit_id range: \"${tag_last}..${commit_initial_id_short}\""
        arr_tag_ranges+=( ${commit_initial_id_short}.."${tag_last}" )
        printf '%s\n' ${arr_tag_ranges[@]}
        DEBUG "Above: printf arr_tag_ranges including initial commit"
    fi

    # Constructed and working:
      # arr_tag_ranges
      # arr_tags_found

    ## Create the changelog
    date_now_short=$(date +%Y%m%d%H%M%S)
    date_now_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
    packager_name=$(git config --global user.name)
    packager_email=$(git config --global user.email)
    ## remove from the log lines with patterns:
    commit_pattern_exclude="$(IFS=\|; echo "${arr_commit_patterns_exclude_lines[*]}")"

    arr_tag_range_authors=()
    for tag_range in ${arr_tag_ranges[@]}; do
        ## Collect required info for each tag
        #build_tag_commit_id_short=$(git show ${build_tag} --pretty=format:"%h" -s)
        ## 2nd tag of the range, is the newer:
        tag=$(echo ${tag_range} | awk -F'[.]{2}' '{print $2}')
        tag_ch_version=$(echo ${tag} | awk -F"${tag_field_sep_found}" '{print $NF}')
        tag_ch_commit_id_short=$(git rev-parse --short ${tag})
        tag_ch_commit_date_full=$(date -d \
            "$(git show --abbrev-commit \
            ${tag_ch_commit_id_short} \
            --pretty=format:"%cI" -s)" \
            +"%a, %d %b %Y %H:%M:%S %z")
        tag_ch_commit_date_short=$(date -d \
            "$(git show --abbrev-commit \
            ${tag_ch_commit_id_short} \
            --pretty=format:"%cI" -s)" \
            +"%Y%m%d%H%M%S")
        debug "tag_ch_commit_date_full = ${tag_ch_commit_date_full}"
        debug "tag_ch_commit_date_short = ${tag_ch_commit_date_short}"
        changelog_version_git=$(echo "${tag_ch_version}+git${tag_ch_commit_date_short}.${tag_ch_commit_id_short}.${build_version_comment}")

        ## Do different things for first range
        if echo "${tag_range}" \
        | grep "${build_tag}"; then
            debug "${FUNCNAME[0]}: First tag_range loop iter, doing nothing"
        else
            debug "${FUNCNAME[0]}: Not the first tag_range loop iter, adding empty line before the version header..."
            echo >> "${changelog_git_relpath_filename}"
        fi
        ## Write the current tag version header
        echo "${pkg_name} (${changelog_version_git}) ${build_release}; urgency=medium" \
	        >> "${changelog_git_relpath_filename}"
        echo >> "${changelog_git_relpath_filename}"
        debug "${FUNCNAME[0]}: Writed version header for tag_range: \"${tag_range}\""

        ## Get the tag range authors list
        for author in $(git log ${tag_range} --pretty=format:"%an" | sort -u); do
            debug "author: ${author}"
            arr_tag_range_authors+=( "${author}" )
            ## Write the austhor header
            echo "  [ ${author} ]" >> "${changelog_git_relpath_filename}"
            ## Get commits for each author
            ## and tagsrange
            git log ${tag_range} \
                --pretty=format:'[%an]  * %h %s' \
                | grep "${author}" \
                | sed "s/^\[${author}\]//g" \
                | grep -v -E "${commit_pattern_exclude}" \
                >> "${changelog_git_relpath_filename}"
        done #for authors 
        debug "${FUNCNAME[0]}: Writed version footer for tag_range: \"${tag_range}\""
        ## Write the version footer
        echo >> "${changelog_git_relpath_filename}"
        echo  " -- ${packager_name} <${packager_email}>  ${date_now_long}" \
            >> "${changelog_git_relpath_filename}"
        debug "${FUNCNAME[0]}: Finished arr_tag_range_authors creation with value: ${arr_tag_range_authors[@]} for the tag_range: ${tag_range[*]}"
    done #for tag_ranges

    # vim "${changelog_git_relpath_filename}"

    info "${FUNCNAME[0]}: commit_pattern_exclude: ${commit_pattern_exclude}"

    # Constructed and working:
      # arr_tag_ranges
      # arr_tags_found
      # arr_tag_ranges
      # arr_tags_found
      # arr_tag_range_authors
      # commit_pattern_exclude

    info "bbl-git: Finalized changelog file build from git log..."
}

fn_bblgit_workdir_file_edited_ckeck() {
    file_edited="$1"
    file_edited_status=$(git status | grep "${file_edited}")
    if [ -z "${file_edited_status}" ]; then
        warn "${FUNCNAME[0]}: Something went wrong when trying to commit" \
        PAUSE "${FUNCNAME[0]}: ERROR: The specified file \"${file_edited}\" is not in the git status"
    else
        debug "${FUNCNAME[0]}: The specified file \"${file_edited}\" was found as edited"
    fi

}

fn_bblgit_commit_changes() {
    ## TODO: 
    commit_msg="$1"
    debug "${FUNCNAME[0]}: Starting checks for committing edited package files by the bdm build script "

    ## Determine if sign can be used by the host
    fn_bblgit_check_if_can_sign
    ## Ckeck if supplied finenames was really edited
    for file_edited in ${arr_pkg_files_edited[@]}; do
        fn_bblgit_workdir_file_edited_ckeck "${file_edited}"
    done
    ## If OK: fn_bblgit_workdir_file_edited_ckeck
    debug "${FUNCNAME[0]}: All the specified files was found as edited: \"${arr_pkg_files_edited[*]}\""
    ## Now the workdir should be clean, check again
    fn_bblgit_workdir_status_check

## TODO: Create --batch mode for bdm
    info "${FUNCNAME[0]}: Committing the updated files: \"${arr_pkg_files_edited[*]}\"..."
    info "${FUNCNAME[0]}: tag_version defined: ${tag_version}"
    info "${FUNCNAME[0]}: tag_release defined: ${tag_release}"
    ASK "Want continue? [ y | any ]: "
    case "${answer}" in
        y)
            git add -A
            eval "${GIT_COMMIT_CMD}"
            ;;
    esac
}
