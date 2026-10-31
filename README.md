# PurgeBar

A tiny macOS menu bar app with one button: **Free Purgeable Space**.

macOS reserves "purgeable" space for things it can throw away on demand: local Time Machine
snapshots, iCloud files that also live in the cloud, and system-managed caches. It normally only
reclaims that space when the disk runs low. PurgeBar asks it to do so now.

## How it works

The button runs, twice:

```
tmutil thinlocalsnapshots / 999999999999999 4
```

This hands a "free as much as possible, maximum urgency" request to macOS's CacheDelete
service (`deleted`), the same mechanism the system uses under disk pressure. No admin
password is needed.

The menu shows available space and an estimate of purgeable space (the difference between
`volumeAvailableCapacityForImportantUsage` and `volumeAvailableCapacity`), and reports how
much was freed afterwards.

## Build

```
./build.sh
```

This produces `PurgeBar.app`. Move it to `/Applications` and add it to
System Settings → General → Login Items if you want it to start at login.

## Caveats

- The purgeable figure is an estimate and won't exactly match Finder.
- macOS decides what is actually released; snapshots reserved for OS updates are kept.
- Local Time Machine snapshots are removed, and evicted iCloud files re-download when opened.
