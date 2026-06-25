import Foundation

/// Backend for the StarTech NOTECONS02 (Digital Multitools) USB crash-cart adapter.
///
/// Transport mirrors the proven three-channel model: a writer thread drains a prioritized
/// command queue to bulk EP 0x04, a response thread reads status/heartbeats from EP 0x83,
/// and a video thread reads the frame stream from EP 0x82 into the decoder. All device
/// behavior here is a clean-room reimplementation from the wire protocol in PROTOCOL.md.
public final class StarTechAdapter: CrashCartAdapter, @unchecked Sendable {

    /// Derived from the built-in profile (BC-1.04.020): no hardcoded VID/PID, no force-unwrap.
    /// If the built-in is ever absent, falls back to a zero-value model (matching fails closed).
    public static let model: AdapterModel = {
        let p = ProfileStore.builtIns.first { $0.id == "startech-notecons02" }
        return AdapterModel(id: "startech-notecons02",
                            name: p?.name ?? "StarTech NOTECONS02",
                            vendorID: p?.vid ?? 0,
                            productIDs: p?.pids ?? [])
    }()

    public static func canDrive(_ device: DiscoveredDevice) -> Bool {
        device.vendorID == model.vendorID && model.productIDs.contains(device.productID)
    }

    /// Pure: device-reported video throughput. `ticks` is a millisecond counter; 0 → 0 (BC-1.06.007).
    public static func computeBytesPerSecond(words: UInt32, ticks: UInt16) -> Double {
        ticks > 0 ? Double(words) * 16.0 * 1000.0 / Double(ticks) : 0
    }

    /// Pure: derive the high-level `AdapterState` from STATUS fields (BC-1.06.007).
    public static func deriveState(fpgaLoaded: Bool, noVideo: UInt8,
                                   width: Int, height: Int, hz: Int) -> AdapterState {
        if let reason = NoVideoReason(rawValue: noVideo), reason != .ok {
            return .noVideo(reason)
        }
        if fpgaLoaded, width > 0, height > 0 {
            return .live(width: width, height: height, hz: hz)
        }
        return .connecting
    }

    private let target: DiscoveredDevice
    private let generation: Int
    private let profile: HardwareProfile?
    private let decoder: StarTechVideoDecoding
    private var device: USBDevice?

    private let queue = CommandQueue()
    private let mediaLock = NSLock()
    private var media: VirtualMedia?
    private var continuation: AsyncStream<AdapterEvent>.Continuation?
    private let running = AtomicFlag(true)
    private var threads: [Thread] = []

    // Cached status to emit only on change.
    private var lastStatus = AdapterStatus()

    // Keyframe-on-desync latch (touched only on the video thread): at most one outstanding
    // doIFrame request between clean decodes (BC-1.02.018).
    private var keyframeRequested = false

    public init(device: DiscoveredDevice, profile: HardwareProfile? = nil,
                decoder: StarTechVideoDecoding = StarTechTileDecoder()) {
        self.target = device
        self.profile = profile
        self.decoder = decoder
        // PID 0x8463 is the gen-2 unit; 0x8460 is gen-1.
        self.generation = device.productID == 0x8463 ? 2 : 1
    }

    // MARK: CrashCartAdapter

    public func connect() async throws -> AsyncStream<AdapterEvent> {
        let dev = try USBDevice.open(matching: target)
        try dev.claimInterface(VSProtocol.interfaceNumber)
        self.device = dev

        let stream = AsyncStream<AdapterEvent> { continuation in
            self.continuation = continuation
            continuation.onTermination = { @Sendable _ in }
        }

        emit(.message("Connected to \(Self.model.name) — initializing…"))
        if !dev.isHighSpeedOrBetter {
            emit(.message("Warning: not a High-Speed USB link — video will be slow."))
        }

        startThread("OpenCrashCart-Writer", writerLoop)
        startThread("OpenCrashCart-Response", responseLoop)
        startThread("OpenCrashCart-Video", videoLoop)

        // Boot/handshake on a background thread so connect() returns promptly.
        startThread("OpenCrashCart-Boot") { [weak self] in self?.boot() }

        return stream
    }

    public func send(key: HIDKeyEvent) {
        queue.enqueue(VSPack.keyEvent(key), priority: .input)
    }

    public func send(mouse: MouseEvent) {
        queue.enqueue(VSPack.mouseEvent(mouse), priority: .input)
    }

    public func requestKeyframe() {
        queue.enqueue(VSPack.command(.doIFrame), priority: .control)
    }

    public func autoTuneVideo() {
        queue.enqueue(VSPack.command(.autophase), priority: .control)
        queue.enqueue(VSPack.command(.doIFrame), priority: .control)
    }

    // MARK: Video adjustments (MISC values)

    /// MISC index per the VSP protocol: phase=0, posX=1, posY=2, noise=3, flatness=4.
    /// Note: the app's user-facing "sharpness" control maps to the protocol's index-4 "flatness".
    private static func miscIndex(_ a: VideoAdjustment) -> UInt8? {
        switch a {
        case .phase: return 0
        case .horizontal: return 1
        case .vertical: return 2
        case .noise: return 3
        case .sharpness: return 4
        }
    }

    public func setVideoAdjustment(_ a: VideoAdjustment, value: Int) {
        guard let idx = Self.miscIndex(a) else { return }
        let clamped = max(-128, min(255, value))
        let byte = UInt8(clamped < 0 ? 256 + clamped : clamped)
        queue.enqueue([VSProtocol.Command.setMisc.rawValue, idx, byte], priority: .control)
    }

    public func saveVideoAdjustment(_ a: VideoAdjustment) {
        guard let idx = Self.miscIndex(a) else { return }
        queue.enqueue([VSProtocol.Command.saveMisc.rawValue, idx], priority: .control)
    }

    public func resetVideoAdjustment(_ a: VideoAdjustment) {
        guard let idx = Self.miscIndex(a) else { return }
        queue.enqueue([VSProtocol.Command.defaultMisc.rawValue, idx], priority: .control)
    }

    public func setDDCPreset(_ preset: DDCPreset) {
        // VSP_SET_DDC + chr(which) advertises a preset EDID to the target.
        queue.enqueue([VSProtocol.Command.setDDC.rawValue, UInt8(preset.rawValue)], priority: .control)
        queue.enqueue(VSPack.command(.getVersions), priority: .control)
    }

    // MARK: Virtual media

    public func mountMedia(path: String, asCDROM: Bool) {
        guard let m = VirtualMedia(path: path, cdrom: asCDROM) else {
            emit(.message("Could not open disk image."))
            return
        }
        mediaLock.lock(); media?.close(); media = m; mediaLock.unlock()
        // VSP_FT_CON + pack('<BL', mediaType, blockCount). mediaType: 1=disk, 2=cdrom.
        var msg: [UInt8] = [VSProtocol.Command.ftConnect.rawValue, asCDROM ? 2 : 1]
        msg += le32(m.blockCount)
        queue.enqueue(msg, priority: .control)
        emit(.message("Mounted \(m.name) — \(m.blockCount) × \(m.blockSize)-byte blocks"))
        emit(.mediaChanged(name: m.name))
    }

    public func ejectMedia() {
        queue.enqueue(VSPack.command(.ftDisconnect), priority: .control)
        if closeMedia() {
            emit(.message("Ejected disk image."))
            emit(.mediaChanged(name: nil))
        }
    }

    /// Close any mounted media. Returns true if media was present. Synchronous so it's safe
    /// to call from `disconnect()` (NSLock can't be used in an async context).
    @discardableResult
    private func closeMedia() -> Bool {
        mediaLock.lock(); defer { mediaLock.unlock() }
        let had = media != nil
        media?.close(); media = nil
        return had
    }

    /// Device wants to read blocks from our image and forward them to the target.
    private func handleFtRead(_ args: [UInt8]) {
        guard args.count >= 8, let dev = device else { return }
        let start = readLE32(args, 0)
        let length = Int(readLE32(args, 4))
        mediaLock.lock(); let m = media; mediaLock.unlock()
        guard let m else { return }
        let bytes = [UInt8](m.read(startBlock: start, length: length))
        var off = 0
        while off < bytes.count, running.get() {
            let end = min(off + 65536, bytes.count)
            do { try dev.bulkWrite(endpoint: VSProtocol.Endpoint.dataOut, data: Array(bytes[off..<end]), timeoutMs: 4000) }
            catch { break }
            off = end
        }
    }

    /// Target wrote blocks; pull them from the device and store into our image.
    private func handleFtWrite(_ args: [UInt8]) {
        guard args.count >= 8, let dev = device else { return }
        let start = readLE32(args, 0)
        var remaining = Int(readLE32(args, 4))
        mediaLock.lock(); let m = media; mediaLock.unlock()
        guard let m else { return }
        var collected = [UInt8]()
        while remaining > 0, running.get() {
            let want = min(remaining, 65536)
            guard let chunk = try? dev.bulkRead(endpoint: VSProtocol.Endpoint.dataIn, maxLength: want, timeoutMs: 4000),
                  !chunk.isEmpty else { break }
            collected += chunk
            remaining -= chunk.count
        }
        m.write(startBlock: start, data: Data(collected))
    }

    private func le32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
    }
    private func readLE32(_ b: [UInt8], _ i: Int) -> UInt32 {
        UInt32(b[i]) | (UInt32(b[i+1]) << 8) | (UInt32(b[i+2]) << 16) | (UInt32(b[i+3]) << 24)
    }

    public func disconnect() async {
        running.set(false)
        closeMedia()
        queue.close()
        device?.close()
        continuation?.yield(.disconnected(reason: "Closed by user"))
        continuation?.finish()
        continuation = nil
    }

    // MARK: Boot sequence

    private func boot() {
        // Initial handshake: request versions + status, then start the video stream.
        queue.enqueue(VSPack.command(.getVersions), priority: .control)
        queue.enqueue(VSPack.command(.getStatus), priority: .control)
        queue.enqueue(VSPack.command(.startVStream), priority: .control)

        do {
            let bitstream = try profile.map { try StarTechFirmware.loadFPGABitstream(profile: $0) }
                ?? StarTechFirmware.loadFPGABitstream(generation: generation)
            emit(.message("Uploading FPGA bitstream (\(bitstream.count / 1024) KB)…"))
            uploadFPGA(bitstream)
        } catch {
            emit(.message("FPGA load skipped: \(error)"))
        }
    }

    /// Stream the FPGA bitstream as 'f' blocks: command + be16(seq) + be16(len) + 507-byte
    /// payload (zero-padded). A terminating len-0 block signals the end, per the protocol.
    private func uploadFPGA(_ data: [UInt8]) {
        let blockSize = VSProtocol.fpgaBlockSize
        var seq: UInt16 = 0
        var offset = 0
        while running.get() {
            let end = min(offset + blockSize, data.count)
            let chunk = Array(data[offset..<end])          // empty on final pass
            var payload = chunk
            if payload.count < blockSize {
                payload += [UInt8](repeating: 0, count: blockSize - payload.count)
            }
            var msg: [UInt8] = [VSProtocol.Command.fpgaData.rawValue]
            msg += be16u(seq)
            msg += be16u(UInt16(chunk.count))
            msg += payload
            queue.enqueue(msg, priority: .control)
            if chunk.isEmpty { break }
            offset = end
            seq &+= 1
        }
    }

    // MARK: Thread loops

    private func writerLoop() {
        guard let device else { return }
        while running.get(), let msg = queue.take() {
            do {
                try device.bulkWrite(endpoint: VSProtocol.Endpoint.streamOut, data: msg)
            } catch USBTransportError.disconnected {
                return died("USB write: device disconnected")
            } catch {
                // Transient write errors: keep going; the device may recover.
                continue
            }
        }
    }

    private func responseLoop() {
        guard let device else { return }
        while running.get() {
            do {
                let packet = try device.bulkRead(endpoint: VSProtocol.Endpoint.streamIn,
                                                 maxLength: 64, timeoutMs: 2000)
                guard let cmd = packet.first else { continue }
                handleResponse(command: cmd, args: Array(packet.dropFirst()))
            } catch USBTransportError.timeout {
                continue
            } catch USBTransportError.disconnected {
                return died("Device disconnected")
            } catch {
                continue
            }
        }
    }

    private func videoLoop() {
        guard let device else { return }
        while running.get() {
            do {
                let chunk = try device.bulkRead(endpoint: VSProtocol.Endpoint.videoIn,
                                                maxLength: 65536, timeoutMs: 2000)
                if chunk.isEmpty { continue }
                if let frame = decoder.ingest(chunk) {
                    emit(.frame(frame))
                }
                // Request a keyframe on desync, but at most one outstanding between clean
                // frames (BC-1.02.018) — avoids flooding the control queue under sustained desync.
                if decoder.needsKeyframe {
                    if !keyframeRequested {
                        queue.enqueue(VSPack.command(.doIFrame), priority: .control)
                        keyframeRequested = true
                    }
                } else {
                    keyframeRequested = false
                }
            } catch USBTransportError.timeout {
                continue
            } catch USBTransportError.disconnected {
                return died("Device disconnected")
            } catch {
                continue
            }
        }
    }

    // MARK: Response handling

    private func handleResponse(command: UInt8, args: [UInt8]) {
        guard let response = VSProtocol.Response(rawValue: command) else { return }
        switch response {
        case .status:
            parseStatus(args)
        case .heartbeat:
            // Echo the heartbeat payload back to keep the link alive.
            var echo: [UInt8] = [VSProtocol.Response.heartbeat.rawValue]
            echo += args
            queue.enqueue(echo, priority: .control)
        case .fpgaGood:
            emit(.message("FPGA loaded."))
            queue.enqueue(VSPack.command(.getStatus), priority: .control)
        case .fpgaBad:
            emit(.message("FPGA load failed: \(asciiz(args))"))
        case .firmwareFail:
            emit(.message("Firmware upgrade failed: \(asciiz(args))"))
        case .autophaseDone:
            emit(.message("Autophase complete."))
        case .ftRead:
            handleFtRead(args)
        case .ftWrite:
            handleFtWrite(args)
        case .ftStartStop:
            // bits & 3 == 2 means the target ejected the media.
            if let c = args.first, (c & 3) == 2 { ejectMedia() }
        case .versions, .vmodeDetails, .selftestDone, .ftMediaRemove, .channelSet, .debug:
            // Parsed in later phases (firmware/diagnostics). Ignored for core KVM.
            break
        }
    }

    /// Parse a STATUS message (`mStatusCC1` = 29 bytes / `mStatusCC2` = 35 bytes, big-endian).
    private func parseStatus(_ args: [UInt8]) {
        let miscLen: Int
        switch args.count {
        case 35: miscLen = 15      // CC2
        case 29: miscLen = 9       // CC1
        default: return            // unexpected size — ignore
        }
        var r = ByteReader(args)
        let fpgaLoaded  = r.u8()
        _ = r.u8()                 // fpgaPowered
        let kbdType     = r.u8()
        let kmOkay      = r.u8()
        let leds        = r.u8()
        let noVideo     = r.u8()
        let w           = Int(r.u16())
        let h           = Int(r.u16())
        let hz          = Int(r.u8())
        _ = r.u8()                 // pixPerClk
        _ = r.u8()                 // savedPos
        let ticks       = Int(r.u16())
        let words       = Int(r.u32())
        let fps         = Int(r.u8())
        let misc        = r.bytes(miscLen)   // manual tuning values
        func signed(_ b: UInt8) -> Int { b >= 128 ? Int(b) - 256 : Int(b) }
        var adjustments: [VideoAdjustment: Int] = [:]
        if misc.count > 0 { adjustments[.phase]      = Int(misc[0]) }
        if misc.count > 1 { adjustments[.horizontal] = signed(misc[1]) }
        if misc.count > 2 { adjustments[.vertical]   = signed(misc[2]) }
        if misc.count > 3 { adjustments[.noise]      = Int(misc[3]) }
        if misc.count > 4 { adjustments[.sharpness]  = Int(misc[4]) }

        let state = Self.deriveState(fpgaLoaded: fpgaLoaded != 0, noVideo: noVideo,
                                     width: w, height: h, hz: hz)
        if case .live(let lw, let lh, _) = state { decoder.setActiveSize(width: lw, height: lh) }

        var status = AdapterStatus()
        status.state = state
        status.keyboardOK = kmOkay != 0
        status.keyboardType = KeyboardEmulation(rawValue: kbdType) ?? .usb
        status.leds = KeyboardLEDs(rawValue: leds)
        status.fps = fps
        status.bytesPerSecond = Self.computeBytesPerSecond(words: UInt32(words), ticks: UInt16(ticks))
        status.adjustments = adjustments

        if status.differs(from: lastStatus) {
            lastStatus = status
            emit(.status(status))
        }
    }

    // MARK: Helpers

    private func startThread(_ name: String, _ body: @escaping @Sendable () -> Void) {
        let t = Thread { body() }
        t.name = name
        t.stackSize = 1 << 20
        threads.append(t)
        t.start()
    }

    private func emit(_ event: AdapterEvent) {
        continuation?.yield(event)
    }

    private func died(_ reason: String) {
        guard running.get() else { return }
        running.set(false)
        queue.close()
        continuation?.yield(.disconnected(reason: reason))
        continuation?.finish()
        continuation = nil
    }

    private func be16u(_ v: UInt16) -> [UInt8] { [UInt8(v >> 8), UInt8(v & 0xFF)] }
}

private extension AdapterStatus {
    func differs(from other: AdapterStatus) -> Bool {
        state != other.state || keyboardOK != other.keyboardOK ||
        keyboardType != other.keyboardType || leds != other.leds || fps != other.fps ||
        adjustments != other.adjustments
    }
}
