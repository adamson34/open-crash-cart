import Foundation
import OCCKit

// OpenCrashCart test suite — run with `swift run occ-tests`.
print("OpenCrashCart — test suite")

let t = Harness()
runTileDecoderTests(t)
runProtocolTests(t)
runKeymapTests(t)
runTypingTests(t)
runProfileTests(t)
runGunzipTests(t)
runRegistryTests(t)
t.finish()
