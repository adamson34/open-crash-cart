import Foundation
import Czlib

public enum GzipError: Error, CustomStringConvertible {
    case initFailed(Int32)
    case inflateFailed(Int32)
    public var description: String {
        switch self {
        case .initFailed(let rc):    return "zlib inflateInit2 failed (\(rc))"
        case .inflateFailed(let rc): return "zlib inflate failed (\(rc))"
        }
    }
}

/// Inflate a gzip (or zlib) stream using the system zlib. Used to expand the adapter's
/// FPGA bitstream, which ships gzip-compressed in the vendor's data files.
public func gunzip(_ input: [UInt8]) throws -> [UInt8] {
    var strm = z_stream()
    // windowBits = 47 (32 + 15) → auto-detect gzip or zlib wrapper.
    let initRC = inflateInit2_(&strm, 47, zlibVersion(), Int32(MemoryLayout<z_stream>.size))
    guard initRC == Z_OK else { throw GzipError.initFailed(initRC) }
    defer { inflateEnd(&strm) }

    var output = [UInt8]()
    output.reserveCapacity(input.count * 4)
    let chunkSize = 1 << 16
    var outChunk = [UInt8](repeating: 0, count: chunkSize)
    var inputCopy = input

    let result: Int32 = inputCopy.withUnsafeMutableBufferPointer { inPtr -> Int32 in
        strm.next_in = inPtr.baseAddress
        strm.avail_in = uInt(inPtr.count)
        var rc: Int32 = Z_OK
        repeat {
            rc = outChunk.withUnsafeMutableBufferPointer { outPtr -> Int32 in
                strm.next_out = outPtr.baseAddress
                strm.avail_out = uInt(outPtr.count)
                let r = inflate(&strm, Z_NO_FLUSH)
                let produced = outPtr.count - Int(strm.avail_out)
                if produced > 0 { output.append(contentsOf: outPtr[0..<produced]) }
                return r
            }
        } while rc == Z_OK
        return rc
    }

    guard result == Z_STREAM_END else { throw GzipError.inflateFailed(result) }
    return output
}
