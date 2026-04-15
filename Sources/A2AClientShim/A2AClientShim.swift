// A2AClientShim.swift
//
// Re-export trampoline. The actual A2AClient lives in
// https://github.com/tolgaki/a2a-swift — this module exists only so that
// existing consumers of `a2a-client-swift` can keep their SPM declaration
// unchanged while we migrate to the new repo.
//
// When you `import A2AClient`, you get the A2AClient (and transitively
// A2ACore) exported by the `a2a-swift` package, not any local code.
// There is no local code in this module.

@_exported import A2AClient
