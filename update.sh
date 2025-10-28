#!/bin/bash

[ -z "${1}" ] && {
 echo "No version specified... Only maintenance will be done..."
 echo "Usage: ${0} <version>"
 } || {
 wget --no-check-certificate https://download.nextcloud.com/server/releases/nextcloud-${1}.zip || echo "Failed to download version ${1}"
 [ -s "./nextcloud-${1}.zip" ] && {
  unzip -o "./nextcloud-${1}.zip"
  rm "./nextcloud-${1}.zip"
  }
 }

cd nextcloud
occ='sudo -u www-data php --define apc.enable_cli=1 occ'
chown -Rc www-data:www-data .
find ./ -type d ! -perm 750 -exec chmod -c 750 "{}" \;
find ./ -type f ! -perm 640 -exec chmod -c 640 "{}" \;

${occ} upgrade

${occ} db:add-missing-columns
${occ} db:add-missing-indices
${occ} db:add-missing-primary-keys

mysql "nextcloud" -Bse "SELECT CONCAT('ALTER TABLE \`', TABLE_NAME, '\` ROW_FORMAT=DYNAMIC;') FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'nextcloud' AND ENGINE = 'InnoDB' AND NOT LOWER(ROW_FORMAT) LIKE '%dynamic%' " | while read command;
 do
 echo ${command}
 echo ${command} | mysql "nextcloud"
 done

${occ} trashbin:cleanup --all-users
${occ} versions:cleanup

echo "Checking core..."
while :
 do
 [ -z "$(${occ} integrity:check-core)" ] && break
 ${occ} integrity:check-core --output json | grep ^{ | jq -sRr '.EXTRA_FILE? | to_entries[] | select(.value.expected == "") | .key' | xargs -i find . -path './{}' | xargs -i rm -v "{}"
 done

${occ} app:list --output json | grep ^{ | jq -r '.enabled, .disabled | keys[]' | while read app
 do
 echo "Checking app \"${app}\"..."
 while :
  do
  list=$(${occ} integrity:check-app --output json ${app} | grep ^{ | jq -sRr 'fromjson? | .EXTRA_FILE? | to_entries[]? | select(.value.expected == "") | .key')
  [ -z "${list}" ] && break
  echo "${list}" | xargs -i find . -path './apps/'${app}'/{}' | xargs -i rm -v "{}"
  done
 done

${occ} app:update --all
${occ} app_api:app:update --all

[ -n "${1}" ] && ${occ} migrations:preview ${1}

${occ} maintenance:repair --include-expensive

${occ} check
${occ} setupcheck
${occ} status
cd ..
