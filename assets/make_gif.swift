import AppKit
import ImageIO
import UniformTypeIdentifiers

// ---- Clawd poses (same grids as the app) ----
let grids: [String: [String]] = [
    "wA": ["..BBBBBBBBBBB..","..BBBBBBBBBBB..","..BBEBBBBBEBB..","BBBBEBBBBBEBBBB",
           "BBBBBBBBBBBBBBB","..BBBBBBBBBBB..","..BBBBBBBBBBB..","...B.B...B.B...","...B.B...B.B..."],
    "wB": ["..BBBBBBBBBBB..","..BBBBBBBBBBB..","..BBEBBBBBEBB..","BBBBEBBBBBEBBBB",
           "BBBBBBBBBBBBBBB","..BBBBBBBBBBB..","..BBBBBBBBBBB..","..B.B.....B.B..","..B.B.....B.B.."],
    "sleep": [".............Z.","............Z..","..BBBBBBBBBBB..","..BBBBBBBBBBB..","..BBBBBBBBBBB..",
              "BBBBEBBBBBEBBBB","BBBBBBBBBBBBBBB","..BBBBBBBBBBB..","..BBBBBBBBBBB..","...B.B...B.B...","...B.B...B.B..."],
    "action": [".......!.......",".......!.......","...............",".......!.......","..BBBBBBBBBBB..",
               "..BBBBBBBBBBB..","..BBEBBBBBEBB..","BBBBEBBBBBEBBBB","BBBBBBBBBBBBBBB","..BBBBBBBBBBB..","..BBBBBBBBBBB..","...B.B...B.B...","...B.B...B.B..."],
    "eureka": [".BB.........BB.","..B.........B..","..BBBBBBBBBBB..","..BBBBBBBBBBB..","..BBEBBBBBEBB..",
               "..BBBBBBBBBBB..","..BBBBBBBBBBB..","..BBBBBBBBBBB..","..BBBBBBBBBBB..","...B.B...B.B...","...B.B...B.B..."],
]
let body  = NSColor(srgbRed: 0xDE/255, green: 0x88/255, blue: 0x6D/255, alpha: 1)
let eye   = NSColor.black
let zzz   = NSColor(white: 0.75, alpha: 0.9)
let alert = NSColor(srgbRed: 0xF4/255, green: 0xB9/255, blue: 0x42/255, alpha: 1)
func col(_ ch: Character) -> NSColor { ch=="E" ? eye : ch=="Z" ? zzz : ch=="!" ? alert : body }

let W = 760, H = 240, scale = 2

func scene(pose: String, text: String) -> CGImage {
    let pxW = W*scale, pxH = H*scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pxW, pixelsHigh: pxH,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ctx
    ctx.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

    // soft background
    let bg = NSGradient(starting: NSColor(srgbRed:0.98,green:0.95,blue:0.92,alpha:1),
                        ending:   NSColor(srgbRed:0.96,green:0.90,blue:0.86,alpha:1))!
    bg.draw(in: NSRect(x:0,y:0,width:W,height:H), angle: -90)

    // title
    let title = "Simmer — a menu-bar companion for Claude Code"
    (title as NSString).draw(at: NSPoint(x: 40, y: H-46),
        withAttributes: [.font: NSFont.systemFont(ofSize: 17, weight: .semibold),
                         .foregroundColor: NSColor(white:0.30,alpha:1)])

    // dark "menu bar" capsule
    let cap = NSRect(x: 40, y: 92, width: CGFloat(W)-80, height: 56)
    NSColor(white: 0.12, alpha: 1).setFill()
    NSBezierPath(roundedRect: cap, xRadius: 14, yRadius: 14).fill()

    // clock at far right of the capsule
    let clock = "9:41"
    let clockAttr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 16, weight: .medium),
                                                     .foregroundColor: NSColor.white]
    let clockW = (clock as NSString).size(withAttributes: clockAttr).width
    (clock as NSString).draw(at: NSPoint(x: cap.maxX - 22 - clockW, y: cap.midY-9), withAttributes: clockAttr)

    // Clawd + status text, placed to the left of the clock
    let g = grids[pose]!
    let rows = g.count, cols = g.map(\.count).max()!
    let cell: CGFloat = 2.4
    let artW = CGFloat(cols)*cell, artH = CGFloat(rows)*cell
    let textAttr: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 16, weight: .regular),
                                                    .foregroundColor: NSColor.white]
    let tW = (text as NSString).size(withAttributes: textAttr).width
    let blockW = artW + (text.isEmpty ? 0 : 8 + tW)
    var x = cap.maxX - 22 - clockW - 30 - blockW   // sit left of the clock
    let oy = cap.midY - artH/2
    for (r,line) in g.enumerated() {
        for (c,ch) in line.enumerated() where ch != "." {
            col(ch).setFill()
            NSRect(x: x + CGFloat(c)*cell, y: oy + (CGFloat(rows-1-r))*cell, width: cell, height: cell).fill()
        }
    }
    x += artW + 8
    if !text.isEmpty {
        (text as NSString).draw(at: NSPoint(x: x, y: cap.midY-9), withAttributes: textAttr)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.cgImage!
}

// ---- frame timeline ----
let frames: [(String,String,Double)] = [
    ("sleep","",1.1),
    ("wA","Simmering…",0.4),("wB","Simmering…",0.4),
    ("wA","Pondering…",0.4),("wB","Pondering…",0.4),
    ("wA","Brewing…",0.4),("wB","Brewing…",0.4),
    ("action","Action needed",1.9),
    ("eureka","Done",1.7),
    ("sleep","",0.8),
]

// ---- write animated GIF ----
let gifURL = URL(fileURLWithPath: "/tmp/simmer-demo.gif")
let dest = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for (pose,text,delay) in frames {
    let img = scene(pose: pose, text: text)
    CGImageDestinationAddImage(dest, img, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
}
CGImageDestinationFinalize(dest)
print("wrote \(gifURL.path)")

// ---- also export stills for the README ----
func savePNG(_ pose: String, _ text: String, _ name: String) {
    let img = scene(pose: pose, text: text)
    let rep = NSBitmapImageRep(cgImage: img)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "/tmp/\(name).png"))
}
savePNG("wB","Brewing…","shot-working")
savePNG("action","Action needed","shot-action")
savePNG("eureka","Done","shot-done")
print("wrote stills")
