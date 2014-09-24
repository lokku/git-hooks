#!/bin/bash

# This update hook's purpose is to make sure that commits don't disappear from
# "git log --first-parent master" server-side. This often happens when people
# run "git pull" without --rebase.

# Please don't modify this file outside of version control

# TODO: make it work with empty repo


refname="$1"
oldrev="$2"
newrev="$3"

# --- Safety check
if [ -z "$GIT_DIR" ]; then
    echo "Don't run this script from the command line." >&2
    echo " (if you want, you could supply GIT_DIR then run" >&2
    echo "  $0 <ref> <oldrev> <newrev>)" >&2
    exit 1
fi

if [ -z "$refname" -o -z "$oldrev" -o -z "$newrev" ]; then
	echo "Usage: $0 <ref> <oldrev> <newrev>" >&2
	exit 1
fi

# We only want to enforce this hook on master:
if [ "$refname" != "refs/heads/master" ] ; then
    exit 0
fi

# Just in case:
if [ "$oldrev" = "$newrev" ] ; then
    exit 0
fi

# Now we want to check if $oldrev has disappeared from 'git log --first-parent
# "$newrev"' by running:
#
#   git rev-list --first-parent "$newrev" | grep -q "^$oldrev$"
#
# This is slow, because git rev-list prints out a large number of commits
# SHA1s. Running this command should be equivalent, but optimized:
#
#   git rev-list --first-parent "$oldrev^..$newrev" | grep -q "^$oldrev$"
#
# Note the ^ in the rev-list command.

if git rev-list --first-parent "$oldrev"^.."$newrev" | grep -q "^$oldrev$" ; then
    true
else
    echo "Error: this push hides some commits previously displayed in \"git log --first-parent $refname\" on the server's side" >&2
    echo "" >&2
    branchname="$(printf %s "$refname" | sed 's!^refs/heads/!!')"
    echo "This probably happened because you ran "git pull" without the --rebase flag (or because you ran "git push -f" after deleting previously published commits)." >&2
    echo "To fix the first problem, run these two commands client-side before pushing, replacing \"origin\" with the appropriate remote name:" >&2
    echo "    # Update refs/remotes/origin/$branchname on the local machine to match the server's value" >&2
    echo "    git fetch origin +refs/heads/$branchname:refs/remotes/origin/$branchname" >&2
    echo "    # Rebase unpublished commits on published history:" >&2
    echo "    git rebase origin/$branchname" >&2
    echo "This will linearize the unpublished history, there are other solutions if you want to keep merge commits." >&2
    echo "Check the result with \"git log --graph\" before pushing again." >&2
    exit 1
fi

# Do not allow "Merge branch 'master'" commit messages either in the --first-parent history.
#
# Hopefully, the vast majority of these case would have been caught by the earlier check.

if git log --first-parent --format=%s "$oldrev".."$newrev" | grep -q "^Merge branch 'master'" ; then
    echo "Error: this push includes some commits in master's --first-parent history with the commit message \"Merge branch 'master'\"" >&2
    exit 1
fi

exit 0
