// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Caliper",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "CaliperCore", targets: ["CaliperCore"]),
        .library(name: "CaliperRuntimeAdapters", targets: ["RuntimeAdapters"]),
        .library(name: "CaliperTelemetry", targets: ["Telemetry"]),
        .library(name: "CaliperDashboards", targets: ["Dashboards"]),
        .library(name: "CaliperExporters", targets: ["Exporters"]),
        .library(name: "CaliperValidators", targets: ["Validators"]),
        .library(name: "CaliperWorkloads", targets: ["Workloads"]),
        .library(
            name: "Caliper",
            targets: [
                "CaliperCore",
                "RuntimeAdapters",
                "Telemetry",
                "Dashboards",
                "Exporters",
                "Validators",
                "Workloads"
            ]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/open-telemetry/opentelemetry-swift-core.git", from: "2.4.1")
    ],
    targets: [
        .target(
            name: "CaliperCore",
            path: "Packages/CaliperCore/Sources/CaliperCore"
        ),
        .target(
            name: "Telemetry",
            dependencies: ["CaliperCore"],
            path: "Packages/Telemetry/Sources/Telemetry"
        ),
        .target(
            name: "Validators",
            dependencies: ["CaliperCore"],
            path: "Packages/Validators/Sources/Validators"
        ),
        .target(
            name: "Exporters",
            dependencies: [
                "CaliperCore",
                "Telemetry",
                .product(name: "OpenTelemetryApi", package: "opentelemetry-swift-core"),
                .product(name: "OpenTelemetrySdk", package: "opentelemetry-swift-core")
            ],
            path: "Packages/Exporters/Sources/Exporters"
        ),
        .target(
            name: "RuntimeAdapters",
            dependencies: ["CaliperCore"],
            path: "Packages/RuntimeAdapters/Sources/RuntimeAdapters"
        ),
        .target(
            name: "Dashboards",
            dependencies: ["CaliperCore", "Telemetry"],
            path: "Packages/Dashboards/Sources/Dashboards"
        ),
        .target(
            name: "Workloads",
            dependencies: ["CaliperCore", "Telemetry", "Validators"],
            path: "Packages/Workloads/Sources/Workloads"
        ),
        .testTarget(
            name: "CaliperCoreTests",
            dependencies: ["CaliperCore", "Telemetry", "Validators"],
            path: "Tests/CaliperCoreTests"
        )
    ]
)
