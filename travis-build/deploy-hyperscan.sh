#!/bin/bash

# Ensure to exit on all kinds of errors
set -eu
set -o pipefail

echo "Checking rebuild command..."
# Check if commit message contains #rebuild cimmand
if [ -n "$(grep '#rebuild' <<< "$TRAVIS_COMMIT_MESSAGE")" ]  ; then
    HYPERSCAN_VERSION=$(<.hyperscan-version)
    echo "Version changed to $HYPERSCAN_VERSION. Compiling and deploying new shared libraries"
    echo "Cloning the hyperscan code"
    git clone -b $HYPERSCAN_VERSION --depth 1 https://github.com/intel/hyperscan.git /tmp/hyperscan
    echo "Running build script for $TRAVIS_OS_NAME"
    bash travis-build/build-$TARGET_OS-$TARGET_ARCH.sh
    cd $TRAVIS_BUILD_DIR
    echo "Decrypt deployment key"
    openssl aes-256-cbc -K $encrypted_1acfec761134_key -iv $encrypted_1acfec761134_iv -in travis-build/hyperscan-builder.enc -out /tmp/hyperscan-builder -d
    chmod 600 /tmp/hyperscan-builder
    eval `ssh-agent -s`
    ssh-add /tmp/hyperscan-builder
    git add src/main/resources
    git checkout $TRAVIS_BRANCH
    git config user.name "cerebuild Bot"
    git config user.email "mg@devleads.io"
    git commit -m "Add shared libraries for hyperscan $HYPERSCAN_VERSION ($TARGET_OS $TARGET_ARCH) [ci skip]"
    REPO=`git config remote.origin.url`
    SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}
    mkdir -p ~/.ssh
    cat travis-build/github-hostkey >> ~/.ssh/known_hosts
    git pull --rebase $SSH_REPO $TRAVIS_BRANCH
    git push $SSH_REPO $TRAVIS_BRANCH
else
    echo "No rebuild command detected"
fi
