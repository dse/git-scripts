# git-scripts

Some git scripts I wrote.  The following may not be a comprehensive
list of them.

## git-ab

Compares two branches, telling you how many commits the first branch
is ahead and/or behind the second.

Can compare three branches, similarly comparing the second and third
branches.

Used by `git-ab-flow` for `git flow` projects.

## git-ab-flow

Compares each local branch in your repository to its upstream, and
compares each branch's upstream to `origin/develop`.

## git-all

Executes a `git` subcommand in each Git repository found by
recursively searching a directory tree that itself is not a Git
repository.

## git-diff-commit

Executes `git diff` on a single commit.  Does not take arguments other
than commits.

## git-difff

A `git diff` wrapper that excludes whitespace differences, added or
deleted files, and certain binary files as well as other files whose
diffs might not be useful to you.

## git-difff-commit

Executes the `git difff` wrapper, also included in this repository, on
a single commit.  Does not take arguments other than commits.

## git-for-each-branch

Executes a `git` subcommand for each branch you have checked out in
your repository.  Does not run `git checkout` before running the
supplied `git` subcommand.

Used by `git-ab-flow` for `git flow` projects.

## Other Peoples' Git Scripts

Hat-tip for `git-ab` and `git-each-branch` goes out to:<br>
<https://gist.github.com/vitalk/8639831>

An advanced version of the above, on steroids:<br>
<https://github.com/bill-auger/git-branch-status>

Some more git scripts:<br>
https://github.com/jwiegley/git-scripts
