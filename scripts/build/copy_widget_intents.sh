#!/bin/sh
set -eu

# SiriKit discovers configuration definitions in extension bundles. The shared
# framework generates the Swift types once; each extension also needs the resources.
widget_framework="${BUILT_PRODUCTS_DIR}/RuuviWidgets.framework"
extension_resources="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
for localization in Base en de fi fr pl sv; do
    mkdir -p "${extension_resources}/${localization}.lproj"
    if [ "$localization" = Base ]; then
        resource=RuuviWidgetsConfiguration.intentdefinition
    else
        resource=RuuviWidgetsConfiguration.strings
    fi
    cp "${widget_framework}/${localization}.lproj/${resource}" "${extension_resources}/${localization}.lproj/${resource}"
done
