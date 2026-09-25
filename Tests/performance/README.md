# Local performance measurements

Run a signed release app on an otherwise steady logged-in desktop. Quit ordinary
Paper instances before measuring. Do not open Paper's controls, switch apps, sleep,
run display fixtures, or run several Paper measurement instances during a sample.
Record other background work as a confounder. These are process measurements, not a
whole-device energy comparison.

```sh
python3 Tests/performance/measure.py --app outputs/Paper.app --scenario active --seconds 600 --excluded-app com.Ebullioscopic.Atoll --evidence outputs/Paper-energy-active.json
python3 Tests/performance/measure.py --app outputs/Paper.app --scenario paused --seconds 300 --excluded-app com.Ebullioscopic.Atoll --evidence outputs/Paper-energy-paused.json
python3 Tests/performance/measure.py --app outputs/Paper.app --scenario off --seconds 300 --evidence outputs/Paper-energy-off.json
```

Each sample uses a temporary preferences suite, ten seconds of settling, and
five-second kernel-counter observations. The report records the exact executable
SHA, OS, settings, CPU time, wakeups, physical memory, disk I/O, and the kernel's
`ri_energy_nj` delta. CPU is percent of one core. Energy excludes WindowServer,
the panel/GPU and other processes; it cannot establish battery drain or wall power.
Zero energy delta is reported as unavailable, not as zero power. The counter probe
uses the current SDK's `rusage_info_v6`; this developer tool does not set Paper's
minimum supported OS. `powermetrics` additionally requires administrator access.

The benchmark compiles the unchanged pinned renderer with optimization and checks
all 26 textures at 1× and 2×. Each cold render is followed by 100 cache hits, which
must not regenerate its field:

```sh
mkdir -p dist/test-tools
swiftc -O Sources/Paper/Vendor/Deckle/CustomPaper.swift Sources/Paper/Vendor/Deckle/TexturePreset.swift Sources/Paper/Vendor/Deckle/TextureRenderer.swift Tests/performance/main.swift -o dist/test-tools/RendererBenchmark
dist/test-tools/RendererBenchmark outputs/Paper-renderer-benchmark.json
```

Use `swift test` for the existing bounded-cache stress and byte-fidelity tests.
Do not add unstable timing thresholds to correctness tests. A cold render or a
cache-hit benchmark does not prove app responsiveness under every workload.

## Prepared whole-device discharge run

This remains physical qualification, deferred by the user for the 1.0 release.
Quit ordinary Paper instances, unplug power, fix brightness/power mode, close
background work and keep the desktop awake without changing those settings
between phases. The runner refuses AC power and observes raw battery capacity;
it does not request administrator access or alter power settings.

```sh
python3 Tests/performance/battery.py --app outputs/Paper.app --phase-seconds 600 --evidence outputs/Paper-battery-discharge.json
```

Four phases use off/on/on/off order with 30 seconds of settling each. Minimum
450 seconds per phase means at least 32 minutes total; default is 42 minutes.
Samples remain local and intentionally omit battery serial/identity. Repeat on
another day with comparable conditions; tiny capacity differences, changing
workload/temperature or sleep make the result inconclusive. Process counters and
whole-device discharge measure different things; neither alone isolates the
texture compositor's energy cost.
