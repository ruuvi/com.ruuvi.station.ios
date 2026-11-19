# Current-cloud aggregated graph history

Implemented on `feature/cloud-history-aggregation`, based on `origin/main`
`c4a3484f54ed1f3bdf8805463433ec8d94fa2268`. This uses the existing current-cloud
account and API base URL. It does not select the native Go backend.

## Enablement and backend dependency

The **Current cloud aggregated history** switch is the last item in Defaults.
It defaults to off until the matching `POST /history/graph` implementation from
`cloud_main`'s `feature/long-history-aggregation` branch has been deployed to the
chosen cloud environment. No server or app deployment is part of this change.
An unavailable endpoint produces an explicit error; it does not start an
unbounded raw-history download.

The iOS branch requires the backend additions for `absoluteHumidity`, `dewPoint`
and `aqi`, not just the initial graph endpoint. The backend calculates these per
reading before aggregation. Derived humidity matches the existing full-card iOS
graph conversion: calibrated RH and unadjusted temperature. Temperature graphs
apply their own offset. Calibration is included in derived-humidity cache keys.
VOC/NOx warm-up zeroes and zero battery readings are omitted as on main.

## Subscription and storage behavior

Each sensor's `maxHistoryDays` drives its available durations. Shared sensors use
the owner's server-provided allowance. No plan names or account-wide entitlement
assumptions are encoded. A 1095-day allowance permits three years; a 731-day
allowance remains 731 days. The endpoint currently caps a request at 1096 days.
Missing/zero allowance does not grant extended cloud access. The server still
checks authorization, retention and deletion boundaries for every request.

The existing local retention/pruning policy, GATT history and measurement-details
popup remain in place. Graph summaries never enter the measurement database and
are never represented as BLE advertisements. CSV/XLSX export continues to export
stored local measurements; a long cloud graph is not a complete raw-history
export or a new raw-data export endpoint.

## Request and rendering path

`RuuviCloudCanonicalProxy` → `RuuviCloudPure` → `RuuviCloudApiURLSession` sends the
existing authorization header to `POST /history/graph`. Only displayed metrics
are requested. Compact columns are preferred; both point and column responses
use the same validated model. Tokens and history are not logged by this transport.
Responses from a replaced account are rejected; cancelling a graph task cancels
its URLSession request. A response larger than 4 MiB is rejected before JSON
expansion. Shape, alignment, ordering, metric, sensor and time bounds are checked.

`CloudGraphLoader` retains one overview and one detail response, each capped at
1500 buckets. All visible plots share the same request. Zoom/pan requests settle
for 200 ms; active gestures defer replacement. New pans cancel obsolete work, and
request identities reject out-of-order responses. Detail replaces intersecting
coarse buckets rather than double-counting them. Overview bounds and zoom matrices
remain stable during detail replacement. Independent Y scales are preserved.

Recent views can refresh every minute while visible. Historical zoom windows
are refreshed when visited, rather than polled continuously. Server retry delays
are observed; 413 size failures and unavailable/malformed endpoints do not enter
an automatic retry loop. Backgrounding or closing the graph cancels its tasks
and timer. Losing authorization discards its retained cloud data.

The existing DGCharts fork and shared dataset factory render the plots: line,
fill, gap stems/dots, dashed hints, markers, alert shading and dot preferences.
Min/max/count-weighted mean use server statistics; counter plots use `last`.
Long axes use bounded tick counts and include years when needed. The indirect
pinch crash guard is included. Bluetooth-state notifications no longer refresh
and re-emit themselves, while the existing permission-alert checks still run.

## Validation

Run from the iOS repository after generating `Ruuvi.xcodeproj`:

```sh
.tools/xcodegen/bin/xcodegen --spec project.yml
xcodebuild -project Ruuvi.xcodeproj -scheme RuuviCloudAlertTests \
  -destination 'platform=iOS Simulator,id=YOUR_TEST_SIMULATOR' test
xcodebuild -project Ruuvi.xcodeproj -scheme station.graphTests \
  -destination 'platform=iOS Simulator,id=YOUR_TEST_SIMULATOR' test
```

The graph suite includes a synthetic fixture emitted by the real backend
accumulator, checked against the pinned iOS Humidity implementation. Other checks
cover compact/point equivalence, malformed replies, subscription bounds, current
cloud authorization, cancellation, account changes, out-of-order results,
three-year overview/detail/pan/short-window browsing, axis density, preserved
zoom, selected metrics and 32 pixel-identical plot comparisons with main's style.
All test readings and credentials are synthetic.

Final simulator measurements for constructing, laying out and drawing three
plots were about 67 ms for the overview and 60–62 ms for detail replacement;
the one-hour case took about 21 ms. These are Debug simulator timings, include
offscreen image drawing, and exclude server/network latency. They are not device
frame-rate or deployed-cloud performance guarantees.

Live AWS/current-cloud end-to-end timing still requires deployment and an
explicitly authorized development test. No customer account or sensor data was
used for these tests. The initial clean iOS 27.2 and iOS 18.6 boots exceeded
Xcode's boot timeout; tests use the isolated iOS 18.6 device once booted.

Backend companion checks for the iOS additions: 44 focused tests passed,
ESLint and Prettier passed, and changed-function cognitive complexity was at
most 14 (limit 15). The repository-wide TypeScript check still reports the same
20 existing diagnostics in unrelated files. JetBrains inspection tools were not
connected, so IDE inspection is unavailable. No live DynamoDB or Redis test is
claimed.

A cold three-year request can still exceed the backend's bounded read budget
and return 413. The app displays the request to choose a shorter duration; it
does not split it into many concurrent unbounded reads. Deployment validation
must measure real plan resolutions, cold reads, cache reuse and zoom latency.

Final app-hosted simulator result: all 8 tests passed, including 32 pixel-equal
plot combinations, three-year overview/zoom/pan/one-hour browsing, preserved
zoom matrices, bounded axis labels, obsolete-response cancellation, historical
refresh suppression, Retry-After handling and authorization revocation. The
current-cloud contract/client suite passed 35 tests. Restarting only the
disposable test simulator resolved an installer/debugger stall. The user's
signed-in simulators were not used.
