# Working in this repo

## Commits

Make atomic commits: each commit should be one logical change, independently
understandable and revertible, with a message that explains it. Don't bundle
unrelated changes (e.g. a new feature + an unrelated one-line tweak found
along the way) into a single commit — split them, even if that means staging
and committing selectively rather than `git add -A` in one shot.

When multiple pending changes touch the same file for unrelated reasons,
split them anyway (edit/commit one hunk, then edit/commit the next) rather
than committing them together for convenience.
