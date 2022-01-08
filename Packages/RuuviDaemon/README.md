# RuuviDaemon

[Daemons](https://en.wikipedia.org/wiki/Daemon_(computing)) run in background and perform work that is not triggered by the user.

You can see the list of `RuuviStation` daemons in the [contract](/Sources/RuuviDeamon) folder. 

A great example of the daemon is [RuuviDaemonCloudSync](/Sources/RuuviDaemon/RuuviDaemonCloudSync.swift) who's main responisbility is to keep the app synced with `Ruvuvi Cloud`. 

Basically it does the one thing - call [Service Layer](../RuuviService/README.md) 