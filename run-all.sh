#!/bin/bash -xeu

export BATCH_MODE=1
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

"${SCRIPTPATH}/up-no-archives.sh"
"${SCRIPTPATH}/up-with-archives.sh"
"${SCRIPTPATH}/up-archives-after-workflow.sh"

diff -y wf-final-archive.yaml wf-final-archive-after-workflow.yaml
