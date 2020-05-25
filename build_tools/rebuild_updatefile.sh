#!/usr/bin/env bash

# Rebuild updatefile.txt
# Find all files in addons and cfg
# Remove all starting .
# Add / at the start 
# Add " at start and end
FILES=$(find ./cfg ./addons -type f \
| sed "s|^\.||" \
| sed 's/ / \\ /' \
| sed 's/^/"/;s/$/"/' \
| sed '/regex/G' \
) \
;

# Find template and copy it to the root to replace existing updatefile.txt
find . -name "updatefile-template.txt" -type f -exec cp {} ./updatefile.txt \;

# For each file found, if it's in the scripting folder, list it as a source
# Otherwise list it as a plugin
# Append to updatefile.txt
for FILE in $FILES
    do
        if [[ "$FILE" != *"_custom.cfg"* ]];
        then
            if [[ $FILE == *"scripting"* ]]; 
            then
                echo $'        "Source"        ' $FILE
            else
                echo $'        "Plugin"        ' $FILE
            fi
        fi
    done >> updatefile.txt

# Append closing brackets to updatefile.txt
echo $'\t}' >> updatefile.txt
echo $'}' >> updatefile.txt