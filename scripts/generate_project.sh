#!/bin/sh

# Check if the resources exists and if not - touch them
if [ ! -f "Common/RuuviLocalization/Sources/Resources/en.lproj/Localizable.strings" ]; then
    echo "Creating $localizableStrings because it does not exist."

    mkdir -p "./Common/RuuviLocalization/Sources/Resources/de.lproj"
    touch "./Common/RuuviLocalization/Sources/Resources/de.lproj/Localizable.strings"

    mkdir -p "./Common/RuuviLocalization/Sources/Resources/en.lproj"
    touch "./Common/RuuviLocalization/Sources/Resources/en.lproj/Localizable.strings"

    mkdir -p "./Common/RuuviLocalization/Sources/Resources/fi.lproj"
    touch "./Common/RuuviLocalization/Sources/Resources/fi.lproj/Localizable.strings"

    mkdir -p "./Common/RuuviLocalization/Sources/Resources/fr.lproj"
    touch "./Common/RuuviLocalization/Sources/Resources/fr.lproj/Localizable.strings"

    mkdir -p "./Common/RuuviLocalization/Sources/Resources/ru.lproj"
    touch "./Common/RuuviLocalization/Sources/Resources/ru.lproj/Localizable.strings"

    mkdir -p "./Common/RuuviLocalization/Sources/Resources/sv.lproj"
    touch "./Common/RuuviLocalization/Sources/Resources/sv.lproj/Localizable.strings"
fi

.tools/xcodegen/bin/xcodegen -s project.yml
