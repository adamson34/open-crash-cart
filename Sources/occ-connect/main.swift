import Foundation
import OCCKit

setbuf(stdout, nil)   // unbuffered so output streams live even when redirected

// occ-connect — Phase 1 driver.
// Finds a StarTech crash-cart adapter, runs the boot/handshake, and prints the live
// event stream (status, messages). Ctrl-C to stop. No video rendering yet (Phase 3/4).

func hex(_ v: UInt16) -> String { String(format: "0x%04X", v) }

let carts: [(device: DiscoveredDevice, model: AdapterModel)]
do {
    carts = try discoverCrashCartDevices()
} catch {
    FileHandle.standardError.write(Data("USB enumeration failed: \(error)\n".utf8))
    exit(1)
}

guard let (device, model) = carts.first else {
    print("No crash-cart adapter found. Plug one in and try again.")
    exit(1)
}

print("Connecting to \(model.name) at bus \(device.busNumber)/\(device.address)…")

let adapter = StarTechAdapter(device: device)

let task = Task {
    do {
        let events = try await adapter.connect()
        for await event in events {
            switch event {
            case .status(let s):
                print("● status: \(describe(s.state))  kbd=\(s.keyboardOK ? "ok" : "—") "
                    + "leds=\(s.leds.rawValue) fps=\(s.fps) \(String(format: "%.0f", s.bytesPerSecond)) B/s")
            case .frame(let f):
                print("▣ frame \(f.width)×\(f.height)")
            case .message(let m):
                print("· \(m)")
            case .mediaChanged(let name):
                print("💿 media: \(name ?? "ejected")")
            case .disconnected(let reason):
                print("✕ disconnected: \(reason)")
                return
            }
        }
    } catch {
        FileHandle.standardError.write(Data("connect failed: \(error)\n".utf8))
        exit(1)
    }
}

func describe(_ state: AdapterState) -> String {
    switch state {
    case .disconnected:            return "disconnected"
    case .connecting:             return "connecting"
    case .noVideo(let r):         return "no video (\(r))"
    case .live(let w, let h, let hz): return "live \(w)×\(h)@\(hz)Hz"
    }
}

// Keep running until the event stream ends or the user interrupts.
signal(SIGINT) { _ in
    print("\nStopping…")
    exit(0)
}

// Auto-stop after a window so this test driver doesn't run forever.
let stopAfter = ProcessInfo.processInfo.environment["OCC_SECONDS"].flatMap { Double($0) } ?? 20
Timer.scheduledTimer(withTimeInterval: stopAfter, repeats: false) { _ in
    print("\n(auto-stop after \(Int(stopAfter))s)")
    exit(0)
}

RunLoop.main.run()
_ = task
