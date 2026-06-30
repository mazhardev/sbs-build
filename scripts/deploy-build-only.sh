#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
out_dir="$repo_root/out"
deploy_branch="gh-pages"
commit_message="Deploy static site build"

cd "$repo_root"

echo "Building static export..."
npm run build

if [ ! -d "$out_dir" ]; then
  echo "Build output folder was not found: $out_dir" >&2
  exit 1
fi

touch "$out_dir/.nojekyll"

remote="$(git remote get-url origin)"
if [ -z "$remote" ]; then
  echo "Git remote 'origin' was not found." >&2
  exit 1
fi

temp_root="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
deploy_dir="$(mktemp -d "${temp_root}/sbs-gh-pages.XXXXXX")"
deploy_dir="$(cd "$deploy_dir" && pwd -P)"

case "$deploy_dir/" in
  "$temp_root"/*) ;;
  *)
    echo "Refusing to use deployment directory outside temp: $deploy_dir" >&2
    exit 1
    ;;
esac

echo "Preparing $deploy_branch branch in temp..."
git clone --branch "$deploy_branch" --single-branch "$remote" "$deploy_dir"

find "$deploy_dir" -mindepth 1 -maxdepth 1 ! -name ".git" -exec rm -rf -- {} +

echo "Copying only out/ into $deploy_branch..."
cp -R "$out_dir"/. "$deploy_dir"/

global_name="$(git config --global user.name || true)"
global_email="$(git config --global user.email || true)"
if [ -z "$global_name" ]; then
  git -C "$deploy_dir" config user.name "Codex"
fi
if [ -z "$global_email" ]; then
  git -C "$deploy_dir" config user.email "codex@openai.com"
fi

git -C "$deploy_dir" add -A
pending="$(git -C "$deploy_dir" status --porcelain)"
if [ -z "$pending" ]; then
  echo "No deployment changes to commit."
  exit 0
fi

echo "Committing and pushing build output..."
git -C "$deploy_dir" commit -m "$commit_message"
git -C "$deploy_dir" push origin "$deploy_branch"

echo "Done. Only out/ was pushed to $deploy_branch."
