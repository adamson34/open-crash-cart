import OCCKit

func runProtocolTests(_ t: Harness) {
    t.section("VSP protocol packing")

    let key = VSPack.keyEvent(HIDKeyEvent(usage: 0x04, modifiers: 0, isDown: true, allReleased: false))
    t.expectEqual(key, [0x6B, 0x04, 0x00, 0x01, 0x00], "keyEvent = 'k' + (usage, mods, down, allUp)")

    let mouse = VSPack.mouseEvent(MouseEvent(buttons: [.left], x: 10, y: -5, wheel: 1, isAbsolute: true))
    t.expectEqual(mouse, [0x6D, 0x01, 0x01, 0x00, 0x0A, 0xFF, 0xFB, 0x00, 0x01],
                  "mouseEvent = 'm' + (absMode, buttons, BE16 x/y/wheel)")

    let mouseRel = VSPack.mouseEvent(MouseEvent(buttons: [.right, .middle], x: 0, y: 0, wheel: 0, isAbsolute: false))
    t.expectEqual(mouseRel, [0x6D, 0x00, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
                  "relative mouse: absMode 0, buttons bitmask right|middle = 6")

    t.expectEqual(VSPack.command(.getStatus), [0x73], "command getStatus = 's'")
    t.expectEqual(VSPack.command(.startVStream), [0x67], "command startVStream = 'g'")

    t.expectEqual(VSProtocol.Endpoint.videoIn, 0x82, "video IN endpoint 0x82")
    t.expectEqual(VSProtocol.Endpoint.streamOut, 0x04, "command OUT endpoint 0x04")
    t.expectEqual(VSProtocol.Endpoint.dataIn, 0x85, "data IN endpoint 0x85")

    // CH9329 HID framing (UVC dongles): 0x57 0xAB 0x00 <cmd> <len> <data> <checksum>.
    let kb = ch9329Frame(cmd: 0x02, data: [0, 0, 0, 0, 0, 0, 0, 0])
    t.expectEqual(kb, [0x57, 0xAB, 0x00, 0x02, 0x08, 0, 0, 0, 0, 0, 0, 0, 0, 0x0C],
                  "CH9329 empty keyboard report frames with correct checksum")
    // LCtrl+LAlt (0x05), Delete (0x4C). Checksum = (0x57+0xAB+0x00+0x02+0x08+0x05+0x4C) & 0xFF = 0x5D.
    let ctrlAltDel = ch9329Frame(cmd: 0x02, data: [0x05, 0, 0x4C, 0, 0, 0, 0, 0])
    t.expectEqual(ctrlAltDel.last, UInt8(0x5D), "CH9329 checksum sums header+cmd+len+data")
}
