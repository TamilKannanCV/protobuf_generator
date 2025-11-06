# protobuf_generator
[![Pub](https://img.shields.io/pub/v/protobuf_generator.svg)](https://pub.dev/packages/protobuf_generator)
[![package publisher](https://img.shields.io/pub/publisher/protobuf_generator.svg)](https://pub.dev/packages/protobuf_generator/publisher)

A flutter generator package to compile [Protocol Buffer](https://developers.google.com/protocol-buffers)
files to Dart source code using [build_runner](https://github.com/protocolbuffers/protobuf) (i.e.
the Dart build pipline) without needing to manually install the [protoc](https://github.com/protocolbuffers/protobuf)
compiler or the Dart Protobuf plugin [protoc_plugin](https://github.com/protocolbuffers/protobuf).

The `protobuf_generator` package downloads the necessary Protobuf dependencies and `googleapis` for your platform to a
temporary local directory.

## Installation

Add the necessary dependencies to your `pubspec.yaml` file:

```yaml
dependencies:
  protobuf: <latest>
  protoc_plugin: <latest>

dev_dependencies:
  build_runner: <latest>
  protobuf_generator: <latest>
```

## Configuration

You must add your `.proto` files to a `build.yaml` file next to the `pubspec.yaml`:

```yaml
targets:
  $default:
    sources:
      - $package$
      - lib/**
      - proto/** # Your .proto directory
```

This will use the default configuration for the `protobuf_generator`.

You may also configure custom options:

```yaml
targets:
  $default:
    sources:
      - $package$
      - lib/$lib$
      - proto/**
    builders:
      protobuf_generator:
        options:
          # The version of the Protobuf compiler to use.
          # (Default: "27.2", make sure to use quotation marks)
          protobuf_version: "27.2"
          
          # The version of the Dart protoc_plugin package to use.
          # (Default: "21.1.2", make sure to use quotation marks)
          protoc_plugin_version: "21.1.2"

          # Directory which is treated as the root of all Protobuf files.
          # (Default: "proto/")
          proto_root_dir: "proto/"

          # Include paths given to the Protobuf compiler during compilation.
          # (Default: ["proto/"])
          proto_paths:
            - "proto/"

          # The root directory for generated Dart output files.
          # (Default: "lib/src/proto")
          dart_out_dir: "lib/src/generated"

          # Use the "protoc" command that's available on the PATH instead of downloading one
          # (Default: false)
          use_installed_protoc: false

          # Whether or not the protoc_plugin Dart scripts should be precompiled for better performance.
          # (Default: true)
          precompile_protoc_plugin: true

          # Whether or not to generate the descriptor file for the proto files
          # (Default: false)
          generate_descriptor_file: false

          # Whether or not to generate gRPC service stubs (.pbgrpc.dart files)
          # (Default: false)
          generate_grpc: false
          # GitHub repositories configuration
          # GitHub repositories containing proto files to include
          github_repos:
            # Simple format - just the repository URL (uses 'main' branch and repository root)
            - "https://github.com/owner/proto-definitions"
            
            # Full format with branch and single subdirectory
            - url: "https://github.com/grpc/grpc-proto"
              branch: "master"
              paths:
                - "grpc"
              
            # Another example with a specific tag/branch
            - url: "https://github.com/envoyproxy/protoc-gen-validate"
              branch: "v0.10.1"
              paths:
                - "api/v1"
              
            # SSH format also supported
            - url: "git@github.com:company/internal-protos.git"
              branch: "main"
              paths:
                - "api/v1"
                - "api/v2"
              
            # Custom GitHub domain (GitHub Enterprise) examples
            - url: "git@cred.github.com:dreamplug-tech/protorepo.git"
              branch: "master"
            - url: "https://enterprise.github.com/company/repo"
              branch: "main"
```

## Using Only GitHub Repositories

If you want to use only GitHub repositories without any local proto files, you can:

1. Create a dummy trigger file (e.g., `github_trigger.proto`) with basic proto content
2. Configure `github_repos` in your `build.yaml` as shown above
3. Include the dummy trigger file in the `sources` list
4. Run `dart run build_runner build` to generate code from the GitHub repositories

**Step 1: Create dummy trigger file** (`github_trigger.proto`):
```protobuf
syntax = "proto3";

package trigger;

// This is a dummy file to trigger build_runner for GitHub-only repositories
message GithubTrigger {
  string dummy = 1;
}
```

**Step 2: Configure build.yaml for GitHub-only setup:**

```yaml
targets:
  $default:
    builders:
      protobuf_generator:
        options:
          dart_path: "lib/src/generated"
          proto_paths: []  # No local proto files
          github_repos:
            - url: "https://github.com/grpc/grpc-proto"
              branch: "master"
              paths:
                - "grpc"
        sources:
          - github_trigger.proto  # Include the dummy trigger file
```

The dummy trigger file is required because build_runner needs actual source files to execute. The generator will detect this special file and process only the GitHub repositories, ignoring the trigger file itself during protobuf generation.

## Running

Once everything is set up, you may simply run the `build_runner` package:

```bash
dart run build_runner build
```

The `build_runner` sometimes caches results longer than it should, so in some cases, it may be necessary to delete the `.dart_tool/build` directory.


## Contributing

If you have read up till here, then 🎉🎉🎉. There are couple of ways in which you can contribute to
the growing community of `protobuf_generator.dart`.

- Pick up any issue marked with ["good first issue"](https://github.com/TamilKannanCV/protobuf_generator/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
- Propose any feature, enhancement
- Report a bug
- Fix a bug
- Write and improve some **documentation**. Documentation is super critical and its importance
  cannot be overstated!
- Send in a Pull Request 😊