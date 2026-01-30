#!/bin/bash

################################################################################
# Nextcloud Updater Script
#
# Description: Automated script for updating and maintaining Nextcloud installations
# Author: Swiftyhu
# Repository: https://github.com/Swiftyhu/nextcloud-updater
# License: GPL-3.0
#
# Usage: ./update.sh [version] [options]
# Options:
#   --web-user USER       Web server user (default: www-data)
#   --web-group GROUP     Web server group (default: www-data)
#   --db-name NAME        Database name (default: nextcloud)
#   --nextcloud-dir DIR   Nextcloud directory name (default: nextcloud)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# WARNING: ALWAYS BACKUP YOUR DATA BEFORE RUNNING THIS SCRIPT!
#
################################################################################

# ===== CONFIGURATION =====
# Edit these values or use command line options
WEB_USER="www-data"
WEB_GROUP="www-data"
DB_NAME="nextcloud"
NEXTCLOUD_DIR="nextcloud"
DIR_PERMS="750"
FILE_PERMS="640"
# =========================

COLOR_BLUE=""
COLOR_GREEN=""
COLOR_RED=""
COLOR_YELLOW=""
COLOR_RESET=""
: "${NO_COLOR:=}"

[ -t 1 -o -n "${NO_COLOR}" ] && {
    ESC="$(printf '\033')"
    COLOR_BLUE="${ESC}[1;34m"
    COLOR_GREEN="${ESC}[1;32m"
    COLOR_RED="${ESC}[1;31m"
    COLOR_YELLOW="${ESC}[1;33m"
    COLOR_RESET="${ESC}[0m"
    }    

SCRIPT_NAME=$(basename "${0}")

_print() {
    level="${1}"
    color="${2}"
    shift 2
    printf '%s%s [%s] %s: %s%s\n' "${color}" "$(date '+%Y-%m-%dT%H:%M:%S%z')" "${level}" "${SCRIPT_NAME}" "${*}" "${COLOR_RESET}" >&2
    }

_ok() {
    _print "    OK" "${COLOR_GREEN}" "$@"
    }

_info() {
    _print "  INFO" "${COLOR_BLUE}" "$@"
    }

_done() {
    _print "  DONE" "${COLOR_GREEN}" "DONE"
    exit 0
    }

_warn() {
    _print "  WARN" "${COLOR_YELLOW}" "$@"
    }

_err() {
    _print " ERROR" "${COLOR_RED}" "$@"
    exit 1
    }

_dircheck() {
    [ -z "${1}" ] && _err 'Directory is not specified!!!'
    [ -d "${1}" ] || _err 'Directory not accessible: "'${1}'"'
    }

_occcheck() {
    [ -s "occ" ] || _err 'Occ command not found or not executable in Nextcloud directory!!!'
    }

# Parse command line arguments
VERSION=""
while [[ ${#} -gt 0 ]]; do
    case ${1} in
        --web-user)
            WEB_USER="${2}"
            shift 2
            ;;
        --web-group)
            WEB_GROUP="${2}"
            shift 2
            ;;
        --db-name)
            DB_NAME="${2}"
            shift 2
            ;;
        --nextcloud-dir)
            NEXTCLOUD_DIR="${2}"
            shift 2
            ;;
        --help|-h)
            _info "Usage: ${SCRIPT_NAME} [version] [options]"
            _info ""
            _info "Description: Automated script for updating and maintaining Nextcloud installations"
            _info ""
            _info "Options:"
            _info "  --web-user USER       Web server user (default: www-data)"
            _info "  --web-group GROUP     Web server group (default: www-data)"
            _info "  --db-name NAME        Database name (default: nextcloud)"
            _info "  --nextcloud-dir DIR   Nextcloud directory name (default: nextcloud)"
            _info "  --help, -h            Show this help message"
            _info ""
            _info "Examples:"
            _info "  ${SCRIPT_NAME} 31.2.0                                          # Update to version 31.2.0"
            _info "  ${SCRIPT_NAME}                                                 # Maintenance only"
            _info "  ${SCRIPT_NAME} 31.2.0 --web-user nginx --web-group nginx       # Custom user/group"
            _info "  ${SCRIPT_NAME} 31.2.0 --web-user nginx --db-name nc_db         # Custom settings"
            exit 0
            ;;
        *)
            [ -z "${VERSION}" ] && [[ "${1}" != --* ]] && {
                VERSION="${1}"
            }
            shift
            ;;
    esac
done

# Version update logic
[ -z "${VERSION}" ] && {
    _warn "No version specified..."
    _warn "Only maintenance will be done..."
    _info "Usage: ${SCRIPT_NAME} <version>"
} || {
    wget https://download.nextcloud.com/server/releases/nextcloud-${VERSION}.zip || _warn "Failed to download version ${VERSION}"
    [ -s "./nextcloud-${VERSION}.zip" ] && {
        unzip -o "./nextcloud-${VERSION}.zip"
        rm "./nextcloud-${VERSION}.zip"
    }
}

_dircheck "${NEXTCLOUD_DIR}"
cd ${NEXTCLOUD_DIR}
_occcheck
occ="sudo -u ${WEB_USER} php --define apc.enable_cli=1 occ"
_info "Setting permissions..."
chown -Rc ${WEB_USER}:${WEB_GROUP} .
find ./ -type d ! -perm ${DIR_PERMS} -exec chmod -c ${DIR_PERMS} "{}" \;
find ./ -type f ! -perm ${FILE_PERMS} -exec chmod -c ${FILE_PERMS} "{}" \;

_info "Starting Nextcloud update and maintenance..."
${occ} upgrade

_info "Updating database schema..."   
${occ} db:add-missing-columns
_info "Adding missing indices..."
${occ} db:add-missing-indices
_info "Adding missing primary keys..."
${occ} db:add-missing-primary-keys

_info "Converting InnoDB tables to DYNAMIC row format..."
mysql "${DB_NAME}" -Bse "SELECT CONCAT('ALTER TABLE \`', TABLE_NAME, '\` ROW_FORMAT=DYNAMIC;') FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '${DB_NAME}' AND ENGINE = 'InnoDB' AND NOT LOWER(ROW_FORMAT) LIKE '%dynamic%' " | while read command
    do
        _info "Executing MySQL command: \"${command}\""
        echo "${command}" | mysql "${DB_NAME}"
    done

_info "Cleaning up old data..."
${occ} trashbin:cleanup --all-users
_info "Cleaning up old versions..."
${occ} versions:cleanup

_info "Checking core..."
while :
    do
        [ -z "$(${occ} integrity:check-core)" ] && break
        ${occ} integrity:check-core --output json | grep ^{ | jq -sRr '.EXTRA_FILE? | to_entries[] | select(.value.expected == "") | .key' | xargs -i find . -path './{}' | xargs -i rm -v "{}"
    done

${occ} app:list --output json | grep ^{ | jq -r '.enabled, .disabled | keys[]' | while read app
    do
    _info "Checking app \"${app}\"..."
    while :
        do
            list=$(${occ} integrity:check-app --output json ${app} | grep ^{ | jq -sRr 'fromjson? | .EXTRA_FILE? | to_entries[]? | select(.value.expected == "") | .key')
            [ -z "${list}" ] && break
            echo "${list}" | xargs -i find . -path './apps/'${app}'/{}' | xargs -i rm -v "{}"
        done
    done

_info "Updating apps..."
${occ} app:update --all
${occ} app_api:app:update --all

[ -n "${VERSION}" ] && {
    _info "Finalizing update to version ${VERSION}..."
    ${occ} migrations:preview ${VERSION}
    ${occ} migrations:execute ${VERSION}
    }

_info "Running maintenance repairs..."
${occ} maintenance:repair --include-expensive

_info "Final system checks..."
${occ} check
${occ} setupcheck
${occ} status

cd - >/dev/null

_done
