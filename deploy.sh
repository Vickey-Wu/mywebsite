#!/bin/sh

# If a command fails then the deploy stops
set -e

printf "Deploying updates to GitHub"

# Build the project.
docker run --rm -it -v $PWD:/src -p 1313:1313 vijaymateti/hugo:latest hugo # if using a theme, replace with `hugo -t <YOURTHEME>`

# Go To Public folder
cd public

# Add changes to git.
git add .

# Commit changes.
msg="rebuilding site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"

# Push source and build repos.
git push origin master
