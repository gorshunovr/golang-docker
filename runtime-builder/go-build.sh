#!/bin/bash

# Copyright 2017 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

# go-build.sh runs Go build in the workspace.

usage() { echo "Usage: $0 <workspace_directory>"; exit 1; }

set -e

workspace="$1"
if [ -z "${workspace}" ]; then
    usage
fi

if [ -z "${GO_VERSION}" -o -z "${DEBIAN_TAG}" ]; then
    echo "Missing env variable(s): GO_VERSION='${GO_VERSION}', DEBIAN_TAG='${DEBIAN_TAG}'."
    exit 1
fi

export PATH=/usr/local/go/bin:"${PATH}"
export GOPATH="${workspace}"/_gopath

cd "${workspace}"

# Move application files into a temporary staging directory, dependencies excluded.
staging=$(mktemp -d staging.XXXX)
find . -mindepth 1 -maxdepth 1 ! -name "${staging}" ! -name "$(basename $GOPATH)" -exec mv {} "${staging}"/ \;

# Create a bin/ directory containing all the binaries we need in the final image
mkdir bin
cd "${staging}"
go build -o "${workspace}"/bin/app -tags appenginevm
cd "${workspace}"

mv /usr/local/bin/go-run.sh "${workspace}"/bin/
mv /usr/local/bin/go-cloud-debug "${workspace}"/bin/
mv "${staging}" "${workspace}"/app

# Generate the final image in which the app runs.
cat > Dockerfile <<EOF
FROM gcr.io/google_appengine/debian8:$DEBIAN_TAG

LABEL go_version="${GO_VERSION}"

COPY bin/ /usr/local/bin/
COPY app/ /app/

WORKDIR /app
ENTRYPOINT ["go-run.sh", "/usr/local/bin/app"]
EOF