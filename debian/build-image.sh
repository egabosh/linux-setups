#!/bin/bash

. /etc/bash/gaboshlib.include

g_lockfile
g_nice
g_all-to-syslog

cd /data-crypt/share/github/linux-setups/debian

if [ $(find version -mmin -1430) ]
then
  g_echo_error_exit "Last version younger then 24 hours"
fi

if cat ~/.docker/config.json | jq '.auths["ghcr.io"]' -e > /dev/null 
then 
  echo "Logged in" >/dev/null
else
  g_echo_warn "Please first log in with:
echo APIKEY | docker login ghcr.io -u egabosh --password-stdin"
  exit 1
fi

version=$(cat version)
version=$((version+1))

docker logout
set -e
docker login ghcr.io

for edition in debian
do
  date
  g_echo "====== Building ghcr.io/egabosh/${edition}:0.${version}"
  set -x
  docker buildx ls | grep -q $edition || docker buildx create --name $edition
  docker buildx use --builder $edition --default
  builddate=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  description="debian patched by egabosh (https://github.com/egabosh/linux-setups/debian/basics)"
  time docker buildx build \
   -f Dockerfile \
   --platform linux/amd64,linux/arm64 \
   -t ghcr.io/egabosh/${edition}:0.${version} \
   -t ghcr.io/egabosh/${edition}:latest \
   --build-arg VERSION=0.$version \
   --build-arg BUILD_DATE=$builddate \
   --build-arg DESCRIPTION="$description" \
   --annotation "index,manifest:org.opencontainers.image.source=https://github.com/egabosh/linux-setups" \
   --annotation "index,manifest:org.opencontainers.image.description=$description" \
   --annotation "index,manifest:org.opencontainers.image.version=0.$version" \
   --annotation "index,manifest:org.opencontainers.image.authors=Oliver Bohlen (aka olli/egabosh)" \
   --annotation "index,manifest:org.opencontainers.image.licenses=GPL-3.0 (for gaboshlib in /etc/bash/gaboshlib)" \
   --annotation "index,manifest:org.opencontainers.image.created=$builddate" \
   --annotation "index,manifest:org.opencontainers.image.vendor=egabosh" \
   --annotation "index,manifest:org.opencontainers.image.documentation=https://github.com/egabosh/linux-setups#readme" \
   --annotation "index,manifest:org.opencontainers.image.base.name=Debian Linux" \
   --annotation "index,manifest:org.opencontainers.image.base.licenses=Various, see https://www.debian.org/legal/licenses/" \
   --push .
  set +x
done

echo $version >version
git commit -m "new image version" version
git push origin main
g_echo "====== ghcr.io/egabosh/${edition}:0.${version} released!!!"

