# RuuviDaemon

[Daemons](https://en.wikipedia.org/wiki/Daemon_(computing)) run in background and perform work that is not triggered by the user.

You can see the list of `RuuviStation` daemons in the [contract](Sources/RuuviDaemon) folder. 

A great example of the daemon is [RuuviDaemonCloudSync](Sources/RuuviDaemon/RuuviDaemonCloudSync.swift) who's main responisbility is to keep the app synced with `Ruvuvi Cloud`. 

Basically it does the one thing - calls [Service Layer](../RuuviService/README.md) to load and store data. Presentation Layer is being notified about sync by observing [RuuviReactor](../RuuviReactor/README.md). 