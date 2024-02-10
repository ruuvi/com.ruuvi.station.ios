#!/bin/bash

BUILD_APP_DIR=${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}
git clone git@github.com:ruuvi/com.ruuvi.station.ios.keystore.git
if [ $? -eq 0 ]; then
    /bin/cp -rf com.ruuvi.station.ios.keystore/GoogleService-Info.plist "$BUILD_APP_DIR/GoogleService-Info.plist"
    /bin/cp -rf com.ruuvi.station.ios.keystore/Networking.plist "$BUILD_APP_DIR/Networking.plist"
    rm -rf com.ruuvi.station.ios.keystore
else
    if grep -q "{ set your API key here }" $SCRIPT_INPUT_FILE_0; then
        echo "warning: Missing OpenWeatherMap API key. In order to make Virtual Sensors work please obtain API key on https://openweathermap.org and put into station/Classes/Networking/Assembly/Networking.plist"
    fi
    if grep -q "1:925543306936:ios:84f5fda343c52e7671c64d" $SCRIPT_INPUT_FILE_1; then
        echo "warning: Demo GoogleServices credentials. If you want to use your own GoogleServices credentials, please replace the station/Resources/Plists/GoogleService-Info.plist file"
    fi
fi