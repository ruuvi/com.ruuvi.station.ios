.PHONY: installed_xcodegen installed_swiftgen installed_swiftlint installed_firebase 

# generates xcodeproj for frameworks build configuration
xcodeproj: installed_xcodegen installed_swiftgen installed_swiftlint
	.tools/xcodegen/bin/xcodegen -s project.yml

# install firebase
installed_firebase: .tools/firebase/firebase

.tools/firebase/firebase: scripts/install/install_firebase.sh
	scripts/install/install_firebase.sh
	touch $@

# install swiftgen
installed_swiftlint: .tools/swiftlint/swiftlint

.tools/swiftlint/swiftlint: scripts/install/install_swiftlint.sh
	scripts/install/install_swiftlint.sh
	touch $@

# install swiftgen
installed_swiftgen: .tools/swiftgen/bin/swiftgen

.tools/swiftgen/bin/swiftgen: scripts/install/install_swiftgen.sh
	scripts/install/install_swiftgen.sh
	touch $@

# install xcodegen
installed_xcodegen: .tools/xcodegen/bin/xcodegen

# install xcodegen if not installed
.tools/xcodegen/bin/xcodegen: scripts/install/install_xcodegen.sh
	scripts/install/install_xcodegen.sh
	touch $@

# builds station target with frameworks build configuration for iOS
build: 
	d=$$(date +%s)\
	; xcodebuild -project frameworks.xcodeproj -scheme station -configuration Release -sdk iphoneos17.0 build\
    && echo "Build took $$(($$(date +%s)-d)) seconds"

# sets the build number to current datetime
set_build_number:
	scripts/build/set_build_number.sh project.yml