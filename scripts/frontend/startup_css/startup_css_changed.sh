#!/bin/sh

echo "-----------------------------------------------------------"
echo "If you run into any issues with Startup CSS generation"
echo "please check out the feedback issue:"
echo ""
echo "https://gitlab.com/gitlab-org/gitlab/-/issues/331812"
echo "-----------------------------------------------------------"

startup_glob="*stylesheets/startup*"

echo "Staging changes to '${startup_glob}' so we can check for untracked files..."
git add ${startup_glob}

if [ -n "$(git diff HEAD --name-only -- ${startup_glob})" ]; then
  diff=$(git diff HEAD -- ${startup_glob})
  cat <<EOF

Startup CSS changes detected!

It looks like there have been recent changes which require
regenerating the Startup CSS files.

**What should I do now?**

IMPORTANT: Please make sure to update your MR title with "[RUN AS-IF-FOSS]" and start a new MR pipeline

To fix this job, consider one of the following options:

  1. Regenerating locally with "yarn run generate:startup_css".
  2. Copy and apply the following diff:

----- start diff -----
$diff

----- end diff -------
EOF

  exit 1
fi
