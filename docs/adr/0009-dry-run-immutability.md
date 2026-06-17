# Dry-run mode must never change any state

`--dry-run` prints the fully-resolved invocation that would occur and exits without executing it. No side effects are permitted: no container is launched, no image is built or removed, no files are written. If the image is absent or stale during a dry-run, run.sh reports what would happen ("image absent — would build") without triggering the build.

The alternative — allowing §07 image management to run fully during dry-run on the grounds that a usable image is a prerequisite, not a side effect — was rejected. Building an image is a significant, slow, disk-consuming operation. A user running `--dry-run` to inspect a command before executing it would be surprised to find the image rebuilt as a side effect. The invariant "dry-run changes nothing" is easier to reason about and trust than "dry-run changes only prerequisites."
