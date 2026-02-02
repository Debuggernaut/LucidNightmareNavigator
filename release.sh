#!/bin/bash

ADDON="LucidNightmareNavigator"
TOC="${ADDON}.toc"

ZIP="${ADDON}.zip"

# Create clean zip with proper folder structure, only tracked files (no .git)
git archive --format=zip --prefix="${ADDON}/" --output="$ZIP" HEAD

echo "Created $ZIP"
echo "Size: $(du -h "$ZIP" | cut -f1)"
