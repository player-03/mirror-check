mirror-check
============
Compares two files to check if they accurately mirror one another.

This version is specifically designed to check FeathersUI classes, but could be used for other tasks by editing [_Mirror.hx_](mirror/Mirror.hx).

Be aware that it's very limited, I basically programmed a diff checker from scratch with no prior experience.

Usage
-----

```bash
# Compares two given files, printing any lines that don't seem to match.
# Note: this isn't very intelligent, so can mistakenly flag lines that are fine.
# Use your own judgement.
$ haxelib run mirror-check path/to/File1.hx path/to/File2.hx

# Generates a file containing the mirrored version of the input.
$ haxelib run mirror-check path/to/File1.hx --output path/to/OutputFile1.hx

# Compares the two given files, as above, then generates a file containing the
# mirrored version of File1.hx. This file will be rearranged to be as close as
# possible to File2.hx, making it easier to compare in an external program.
# Caution: This will omit lines that don't seem to match.
$ haxelib run mirror-check path/to/File1.hx path/to/File2.hx --output MirroredFile1.hx
```

Be aware that none of these options are suitable for use in an automated workflow. They take too many shortcuts and fail to account for too many situations. Always check the output yourself.
