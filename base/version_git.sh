#!/bin/sh
# This file is a part of Julia. License is MIT: http://julialang.org/license

# This file collects git info and create a julia file with the GIT_VERSION_INFO struct

echo "# This file was autogenerated in base/version_git.sh"
echo "struct GitVersionInfo"
echo "    commit::AbstractString"
echo "    commit_short::AbstractString"
echo "    branch::AbstractString"
echo "    build_number::Int"
echo "    date_string::AbstractString"
echo "    tagged_commit::Bool"
echo "    fork_master_distance::Int"
echo "    fork_master_timestamp::Float64"
echo "end"
echo ""

cd $1

# If the script didn't ask not to use git info
if [  "$#" = "2"  -a "$2" = "NO_GIT" ]; then
    # this comment is used in base/Makefile to distinguish boilerplate
    echo "# Default output if git is not available."
    echo "const GIT_VERSION_INFO = GitVersionInfo(\"\" ,\"\" ,\"\" ,0 ,\"\" ,true ,0 ,0.)"
    exit 0
fi
# Collect temporary variables
origin=$(git config -l 2>/dev/null | grep 'remote\.\w*\.url.*JuliaLang/julia' | sed -n 's/remote\.\([a-zA-Z]*\)\..*/\1\//p')
if [ -z "$origin" ]; then
    origin="origin/"
fi
git_time=$(git log -1 --pretty=format:%ct)

#collect the contents
commit=$(git rev-parse HEAD)
commit_short=$(git rev-parse --short HEAD)
if [ -n "$(git status --porcelain)" ]; then
    # append dirty mark '*' if the repository has uncommited changes
    commit_short="$commit_short"*
fi
branch=$(git branch | sed -n '/\* /s///p')

topdir=$(git rev-parse --show-toplevel)
verchanged=$(git blame -L ,1 -sl -- "$topdir/VERSION" | cut -f 1 -d " ")
if [ $verchanged = 0000000000000000000000000000000000000000 ]; then
    # uncommited change to VERSION
    build_number=0
else
    build_number=$(git rev-list --count HEAD "^$verchanged")
fi

date_string=$git_time
case $(uname) in
  Darwin | FreeBSD)
    date_string="$(/bin/date -jr $git_time -u '+%Y-%m-%d %H:%M %Z')"
    ;;
  MINGW*)
    git_time=$(git log -1 --pretty=format:%ci)
    date_string="$(/bin/date --date="$git_time" -u '+%Y-%m-%d %H:%M %Z')"
    ;;
  *)
    date_string="$(/bin/date --date="@$git_time" -u '+%Y-%m-%d %H:%M %Z')"
    ;;
esac
if [ $(git describe --tags --exact-match 2> /dev/null) ]; then
    tagged_commit="true"
else
    tagged_commit="false"
fi
fork_master_distance=$(git rev-list HEAD ^"$(echo $origin)master" | wc -l | sed -e 's/[^[:digit:]]//g')
fork_master_timestamp=$(git show -s $(git merge-base HEAD $(echo $origin)master) --format=format:"%ct")

# Check for errrors and emit default value for missing numbers.
if [ -z "$build_number" ]; then
    build_number="-1"
fi
if [ -z "$fork_master_distance" ]; then
    fork_master_distance="-1"
fi
if [ -z "$fork_master_timestamp" ]; then
    fork_master_timestamp="0"
fi

echo "const GIT_VERSION_INFO = GitVersionInfo("
echo "    \"$commit\","
echo "    \"$commit_short\","
echo "    \"$branch\","
echo "    $build_number,"
echo "    \"$date_string\","
echo "    $tagged_commit,"
echo "    $fork_master_distance,"
echo "    $fork_master_timestamp."
echo ")"
