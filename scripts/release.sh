#!/usr/bin/env bash

set -euxo pipefail

version=$1

WORKFLOW=${WORKFLOW:-release.yaml}
GITHUB_SERVER_URL=${GITHUB_SERVER_URL:-https://github.com}
GITHUB_REPOSITORY=$(gh repo view --json nameWithOwner --jq ".nameWithOwner")
GITHUB_REPOSITORY_OWNER=${GITHUB_REPOSITORY%/*}
GITHUB_REPOSITORY_NAME=${GITHUB_REPOSITORY#*/}

git tag -m "chore: release $version" "$version"
git push origin "$version"

# Get a workflow run id
sleep 10 # Wait for the workflow run to start
run_id=$(gh run list -w "$WORKFLOW" -L 1 --json databaseId --jq '.[].databaseId')

# Wait until the workflow run completes
gh run watch --exit-status "$run_id"

# Work on a temporary directory
tempdir=$(mktemp -d)
echo "[INFO] Temporary directory: $tempdir" >&2
cd "$tempdir"
# Download the GitHub Actions Artifact
echo "[INFO] Downloading GitHub Actions Artifact" >&2
gh run download -R "$GITHUB_REPOSITORY" "$run_id" --pattern goreleaser

# Push homebrew
echo "[INFO] Checking out homebrew-${GITHUB_REPOSITORY_NAME}" >&2
git clone --depth 1 "$GITHUB_SERVER_URL/${GITHUB_REPOSITORY_OWNER}/homebrew-${GITHUB_REPOSITORY_NAME}"
cp goreleaser/*.rb "homebrew-${GITHUB_REPOSITORY_NAME}"
pushd "homebrew-${GITHUB_REPOSITORY_NAME}"
echo "[INFO] Commit and push homebrew-${GITHUB_REPOSITORY_NAME}" >&2
git add *.rb
git commit -m "Brew formula update for $GITHUB_REPOSITORY_NAME version $version"
git push origin main
popd

# Push scoop
