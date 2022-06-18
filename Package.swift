// swift-tools-version:5.3

import PackageDescription

let package = Package(
	name: "git-two",
	platforms: [.iOS(.v13), .macOS(.v10_15)],
	products: [
        .library(name: "GitTwo", targets: ["GitTwo"]),
	],
	dependencies: [],
	targets: [
        .systemLibrary(name: "Clibgit2"),
		.binaryTarget(
			name: "libgit2",
			url: "https://github.com/amine2233/libgit2-spm/releases/download/v1.2.0/libgit2.zip",
			checksum: "00432343fa1b7bc4ccdbebe8a2ccb246b75592f59e4a31edc3f7868c114d29bc"
		),
		.binaryTarget(
			name: "libssh2",
			url: "https://github.com/amine2233/libgit2-spm/releases/download/v1.2.0/libssh2.zip",
			checksum: "e10fc4f2dd83ba4998aed619eef82f02dd28a9a19b8aff11b62e62ca0951b05a"
		),
		.binaryTarget(
			name: "libssl",
			url: "https://github.com/amine2233/libgit2-spm/releases/download/v1.2.0/libssl.zip",
			checksum: "b03321b3d183a827c07e2fd778bd63ad1742e50fea651a561d02708108806204"
		),
		.binaryTarget(
			name: "libcrypto",
			url: "https://github.com/amine2233/libgit2-spm/releases/download/v1.2.0/libcrypto.zip",
			checksum: "05174ed4d28e17f03a6f527521fc2bd17a7ce977525321780203489e33c7ad55"
		),
        .target(
            name: "GitTwo",
            dependencies: [
                .target(name: "Clibgit2"),
                .target(name: "libgit2"),
                .target(name: "libssh2"),
                .target(name: "libssl"),
                .target(name: "libcrypto"),
            ],
            linkerSettings: [
                .linkedLibrary("iconv"),
                .linkedLibrary("z")
            ]
        ),
        .testTarget(
            name: "GitTwoTests",
            dependencies: ["GitTwo"]),
	]
)
