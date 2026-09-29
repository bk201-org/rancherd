# BuildKit Go cache

This local composite action sets up a Buildx builder and persists its Go module
and compilation cache mounts using GitHub Actions cache. It requires a checkout
and a Linux runner with Docker and passwordless sudo (used by cache-dance).
Call it once per job before building.

```yaml
- uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4

- name: Set up Go build cache
  id: go-cache
  uses: ./.github/actions/setup-buildkit-go-cache

- name: Build
  env:
    BUILDX_BUILDER: ${{ steps.go-cache.outputs.builder }}
  run: make build MK_REPO_ID=ci
```

The defaults match rancherd's Dockerfile with `MK_REPO_ID=ci`. Both Docker builds
and cache injection must use the returned `builder`. Other repositories can
override `module-cache-target`, `module-cache-id`, `build-cache-target`, and
`build-cache-id` to match their Dockerfile mounts and Go environment.

`cache-prefix` defaults to `rancherd`. `dependency-file` defaults to `go.sum`
and accepts a workspace-relative glob. Cache keys include the runner OS,
architecture, job ID, dependency hash, and commit. Restore prefixes reuse the
latest cache for the same dependencies, then fall back to the same job's cache
when dependencies change. Each new commit can save updated compiled packages.

At successful job completion, nested action post steps extract the mounts,
save the host directories, and remove the builder, in that order. An exact
cache hit skips extraction because that immutable entry already exists.
A failure in a later job step also prevents saving the updated cache.

Host cache data lives under `.cache/buildkit`, with temporary extraction files
under `.cache/buildkit-scratch`. Keep `.cache` excluded from Git and the Docker
build context. These patterns are already present in rancherd.

Only cache-mount contents are persisted; Docker image layer caching is separate.
