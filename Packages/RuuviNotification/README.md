# RuuviNotification

Local sensor notifications and cloud alert notification actions.

Cloud alerts use the APNs category `com.ruuvi.station.alerts.cloud`, with the
localized **Disable this alarm** action (`com.ruuvi.station.alerts.cloud.disable`).
The cloud SNS/FCM publisher supplies this category through `notification.click_action`.

Local and cloud disable actions use `alarm_notification_disable`, the same key
and translation entry as Android in `station.localization/station.localization.json`.
The cloud category contains only the disable action. All three sound alerts
(`soundInstant`, `soundAverage`, and `soundPeak`) are supported separately.
The generic legacy cloud `sound` type has no matching iOS model or disable action.

The action reads the sensor MAC from `id`, the cloud alert type from `alertType`,
and the receiving account from `email` in the notification's `userInfo`. It only
acts for the current signed-in session and a matching stored cloud sensor.
The request changes only the enabled state; saved thresholds, movement counters,
offline delay and description remain unchanged on the server. Missing local alert
settings do not block the update. Local state changes only after cloud success in
the same session. The callback waits for the update and any retry persistence; a
request that fails after an account switch is not queued for the new account.
Ordinary notification taps retain sensor
navigation, and local alert actions retain their existing categories.

Local **Mute** uses the configured alert mute interval (60 minutes by default).
Notifications are suppressed until that expiry; the repeat-notification limit
still applies independently after the mute expires.

The notification service extension preserves the category while formatting the
notification. A matching cloud deployment is required for incoming pushes to
show the new action.

## Tests

Generate the Xcode project using `scripts/generate_project.sh`, then run the
`RuuviNotificationTests` scheme on an installed iOS simulator. This test target
has no app host; storage and cloud requests in its action tests are faked.
Mute regressions cover active and expired mutes and the independent repeat limit.
Run `RuuviCloudAlertTests` as well for retry persistence and account-switch coverage.

```sh
xcodebuild test -project Ruuvi.xcodeproj -scheme RuuviNotificationTests \
  -destination 'platform=iOS Simulator,name=<simulator name>' CODE_SIGNING_ALLOWED=NO
```

On-device acceptance should cover long-pressing a delivered push, disabling the
selected alert while the app is in the background, keeping other alerts enabled,
and tapping a notification normally. Also check account changes, shared sensors,
movement and offline alerts, and delivery failures. Unit tests do not establish
APNs delivery or notification action presentation on a physical device.
