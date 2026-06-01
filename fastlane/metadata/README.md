# App Store Metadata

This is the live folder used by the `Sync App Store Metadata` workflow.

Each supported App Store Connect locale has a folder here:

```text
fastlane/metadata/en-US/release_notes.txt
fastlane/metadata/en-US/description.txt
fastlane/metadata/fi/release_notes.txt
```

Supported locale folders as of now:

```text
en-US
fi
sv
de-DE
fr-FR
```

These files are the editable source for App Store metadata sync. They are seeded from the current
App Store Connect listing. Update the localized `.txt` files here, review the diff, then run the
`Sync App Store Metadata` workflow.
