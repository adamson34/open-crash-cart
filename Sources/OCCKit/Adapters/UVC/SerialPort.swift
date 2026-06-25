import Foundation

/// Minimal blocking serial port (POSIX termios), raw 8N1. Used to talk to a CH9329
/// USB-serial HID controller.
final class SerialPort {
    private var fd: Int32 = -1

    init?(path: String, baud: Int) {
        let f = path.withCString { open($0, O_RDWR | O_NOCTTY | O_NONBLOCK) }
        guard f >= 0 else { return nil }
        var settings = termios()
        guard tcgetattr(f, &settings) == 0 else { Foundation.close(f); return nil }
        cfmakeraw(&settings)
        cfsetispeed(&settings, speed_t(baud))
        cfsetospeed(&settings, speed_t(baud))
        settings.c_cflag |= tcflag_t(CLOCAL | CREAD)
        guard tcsetattr(f, TCSANOW, &settings) == 0 else { Foundation.close(f); return nil }
        _ = fcntl(f, F_SETFL, 0)   // switch to blocking writes
        fd = f
    }

    func writeBytes(_ bytes: [UInt8]) {
        guard fd >= 0 else { return }
        bytes.withUnsafeBytes { buf in
            guard let base = buf.baseAddress else { return }
            var offset = 0
            while offset < buf.count {
                let n = write(fd, base.advanced(by: offset), buf.count - offset)
                if n <= 0 { break }
                offset += n
            }
        }
    }

    func close() {
        if fd >= 0 { Foundation.close(fd); fd = -1 }
    }
    deinit { close() }
}
