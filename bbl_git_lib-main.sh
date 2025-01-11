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
    arr_tags_build_release=()
    for tag in $(git tag --sort=-creatordate | grep "${build_release}"); do
        arr_tags_build_release+=( "${tag}" )
    done
    ## Create the changelog
    date_now_short=$(date +%Y%m%d%H%M%S)
    date_now_long=$(date +"%a, %d %b %Y %H:%M:%S %z")
    packager_name=$(git config --global user.name)
    packager_email=$(git config --global user.email)
    commit_initial=$(git rev-list --max-parents=0 --abbrev-commit HEAD)

    #build_tag_commit_id_short=$(git show ${build_tag} --pretty=format:"%h" -s)
    ## TAGS INFO
    arr_commit_patterns_exclude=(
        'Build release:'
        '(gitignore)'
        'Increase version strings'
        '(pkg_rootfs)'
    )
    
    commit_pattern_exclude="$(IFS=\|; echo "${arr_commit_patterns_exclude[*]}")"
    echo "commit_pattern_exclude${commit_pattern_exclude}"
    pause "Pausa print var"
    tags_found_count="${#arr_tags_build_release[@]}"
    tags_processed_count="1"

    for tag in ${arr_tags_build_release[@]}; do
        ## Collect required info for each tag
        tag_ch_current=${tag}
        tag_ch_previous=${arr_tags_build_release["${tags_processed_count}"]}
        tag_ch_version=$(echo ${tag} | awk -F"${tag_field_sep_found}" '{print $NF}')
        tag_ch_commit_id_short=$(git rev-parse --short ${tag})
        tag_ch_commit_date_full=$(date -d "$(git show ${tag_commit_id_short} --pretty=format:"%cI" -s)" +"%a, %d %b %Y %H:%M:%S %z")
        tag_ch_commit_date_short=$(date -d "$(git show ${tag_commit_id_short} --pretty=format:"%cI" -s)" +"%Y%m%d%H%M%S")
        changelog_version_git=$(echo "${tag_ch_version}+git${tag_ch_commit_date_short}.${tag_ch_commit_id_short}.${build_version_comment}")
        ## TAGS: USER INFO
        #commiter_name=$(git show ${tag_commit_id_short} --pretty=format:"%cn" -s)
        #commiter_email=$(git show ${tag_commit_id_short} --pretty=format:"%ce" -s)
        #comm_ch_author=$(git show ${tag_commit_id_short} --pretty=format:"%an" -s)
        #author_email=$(git show ${tag_commit_id_short} --pretty=format:"%ae" -s)


        ## Use a diferent version for the first tag
        if [ "${tag}" != "${build_tag}" ]; then
            echo >> "${changelog_git_relpath_filename}"
        fi
        ## Write the current tag version header
        echo "${pkg_name} (${changelog_version_git}) ${build_release}; urgency=medium" \
	        >> "${changelog_git_relpath_filename}"
        echo >> "${changelog_git_relpath_filename}"

        ## When count the first tag, set
        ## tag_previous = initial commit d
        if [ "${tag_previous}" == "" ]; then
            tag_previous="${commit_initial}"
        fi
        debug "${FUNCNAME[0]}: tag_ch_current: ${tag_ch_current}"
        debug "${FUNCNAME[0]}: tag_ch_previous: ${tag_ch_previous}"
        debug "${FUNCNAME[0]}: tags_processed_count: ${tags_processed_count}"
        #pause "Pausa abans d'entrar al for de commits"
        ## Commits part
        arr_authors=()
        for comm_ch_author in $(git log \
          "${tag_ch_previous}".."${tag_ch_current}" \
            --no-merges \
            --pretty=format:"%an" \
            | sort -u)
        do

            echo "  [ ${comm_ch_author} ]" >> "${changelog_git_relpath_filename}"
            #arr_authors+=( "${comm_ch_author}" )

#<< "DESACTIVA"            
            git log "${tag_ch_previous}".."${tag_ch_current}" \
                --pretty=format:"- %ad, %an :  * %h %s" \
                --date=format:'%Y%m%d%H%M%S' \
                | grep -v -E "${commit_pattern_exclude}" \
                | grep ", ${comm_ch_author} :" \
                | sed "s/^- [0-9]\{14\}, ${comm_ch_author} ://" \
                | while IFS= read -r line
                do
                    echo "$line" >> "${changelog_git_relpath_filename}"
                done
                #read -p "Pausa sortint de for 1 commits"
                #FILTRE ARRAY | grep -v -E "$(IFS=\|; echo "${arr_comm_patterns_exclude[*]}")" \
#DESACTIVA
        done
        #read -p "ACABAT for 1 authors"

        ## Write the version footer
        echo >> "${changelog_git_relpath_filename}"
        echo  " -- ${packager_name} <${packager_email}>  ${date_now_long}" \
            >> "${changelog_git_relpath_filename}"
        ## Increment the array position
        tags_processed_count=$((tags_processed_count + 1))
    done


## RECORDA, FILTRE DE MISSATGES DE COMMIT
#git log "${tag_ch_previous}".."${tag_ch_current}" --oneline | sed "s|(tag: ${tag_ch_current})||g' | grep -v -e 'Build release:' -e '(gitignore)' -e 'Increase version strings' -e '(pkg_rootfs)" \
#            >> "${changelog_git_relpath_filename}"
    PAUSE "bbl-git: Finalized changelog file build from git log..."

            #| sed 's/^- [0-9]\{14\}, berbascum : //' \


            #pause "Pausa, comm_ch_author val ${comm_ch_author}"

         #git log "${tag_ch_previous}".."${tag_ch_current}" --pretty=format:"%an %ad %B" --date=format:"%Y%m%d%H%M%S" | awk '{print $1}' | while read line; do
#                pause "Pausa line: $line"
#            done

# Executar git log amb el format desitjat


        # Executar git log amb el format desitjat


#| awk '{$1=""; print substr($0,2)}'
    # Imprimir cada línia
    #| sed 's/berbascum//g' | sed 's/^[^ ]* //'
    #| awk '{print $1}'
    #| cut -d' ' -f1-
    #awk '{print $1}'



             #   pause "commit_ch: ${commit_ch}"
            #--date=format:"%Y%m%d%H%M%S"
            # | grep "^${comm_ch_author} "
              #| sort -k2,2r
          #| sed 's/^${comm_ch_author} //g' | sed 's/^[0-9]* //' >> "${changelog_git_relpath_filename}"
#    pause "Pausa comanda que processa commits"
          #git log --pretty=format:"%an %ad %B"  --date=format:"%Y%m%d%H%M%S" | grep "^${comm_ch_author} "| sort -k2,2r   | sed 's/^${comm_ch_author} //g' | sed 's/^[0-9]* //' >> "${changelog_git_relpath_filename}"
                #| cut -d' ' -f2-
                #| sed 's/^[^ ]* //'



# git log --pretty=format:"%an %h %ad" --date=short | sort -k1,1 -k3,3r



    

<< "DISABLE"
    git log --pretty=format:"%h %an %ae %cn %ce %cD %ci %s" "${prev_last_commit_id}"..."${last_commit_id}" > commits_tmpdir/export.txt
    debug "bbl-git: File commits_tmpdir/export.txt created"
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
	debug2 "bbl-git: Commit header filtered = ${commit_header}"
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
DISABLE

}

fn_bblgit_commit_changes() {
    #file_updated="$1"
    commit_msg="$1"
    #file_updated_status=$(git status | grep "${file_updated}")
    #[ -z "${file_updated}" ] && error "Some went wrong when trying to commit \"${file_updated}\""
    #info "Committing the updated \"${file_updated}\"..."
    git status
    ASK "bbl-git: The above files and dirs will be added and commited. Want to continue? [ y|n ]: "
    [ "${answer}" != "y" ] && abort "bbl-git: Aborted by user!"
    git add -A
    fn_bblgit_check_if_can_sign
    eval "${GIT_COMMIT_CMD}"
}
