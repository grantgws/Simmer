import AppKit
import AVFoundation

let DESIGN_W=1280, DESIGN_H=720, S=2, FPS=30
let W=DESIGN_W*S, H=DESIGN_H*S
let dW=CGFloat(DESIGN_W), dH=CGFloat(DESIGN_H)
let outURL=URL(fileURLWithPath:"/tmp/simmer-promo-video.mp4")
let finalURL=URL(fileURLWithPath:NSString(string:"~/Projects/Simmer/assets/simmer-promo.mp4").expandingTildeInPath)
let alertWav=URL(fileURLWithPath:NSString(string:"~/Projects/Simmer/Simmer/Resources/clawd-alert.wav").expandingTildeInPath)
let doneWav=URL(fileURLWithPath:NSString(string:"~/Projects/Simmer/Simmer/Resources/clawd-done.wav").expandingTildeInPath)
let musicWav=URL(fileURLWithPath:"/tmp/simmer-music.wav")

let grids:[String:[String]]=[
 "wA":["..BBBBBBBBBBB..","..BBBBBBBBBBB..","..BBEBBBBBEBB..","BBBBEBBBBBEBBBB","BBBBBBBBBBBBBBB","..BBBBBBBBBBB..","..BBBBBBBBBBB..","...B.B...B.B...","...B.B...B.B..."],
 "wB":["..BBBBBBBBBBB..","..BBBBBBBBBBB..","..BBEBBBBBEBB..","BBBBEBBBBBEBBBB","BBBBBBBBBBBBBBB","..BBBBBBBBBBB..","..BBBBBBBBBBB..","..B.B.....B.B..","..B.B.....B.B.."],
 "action":[".......!.......",".......!.......","...............",".......!.......","..BBBBBBBBBBB..","..BBBBBBBBBBB..","..BBEBBBBBEBB..","BBBBEBBBBBEBBBB","BBBBBBBBBBBBBBB","..BBBBBBBBBBB..","..BBBBBBBBBBB..","...B.B...B.B...","...B.B...B.B..."],
 "eureka":[".BB.........BB.","..B.........B..","..BBBBBBBBBBB..","..BBBBBBBBBBB..","..BBEBBBBBEBB..","..BBBBBBBBBBB..","..BBBBBBBBBBB..","..BBBBBBBBBBB..","..BBBBBBBBBBB..","...B.B...B.B...","...B.B...B.B..."],
]
let clay=NSColor(srgbRed:0xDE/255,green:0x88/255,blue:0x6D/255,alpha:1)
let amber=NSColor(srgbRed:0xF4/255,green:0xB9/255,blue:0x42/255,alpha:1)
func ccol(_ ch:Character,_ a:CGFloat)->NSColor{switch ch{case "E":return NSColor.black.withAlphaComponent(a);case "!":return amber.withAlphaComponent(a);default:return clay.withAlphaComponent(a)}}
func clawd(_ pose:String,cx:CGFloat,cy:CGFloat,cell:CGFloat,alpha:CGFloat=1){let g=grids[pose]!;let rows=g.count,cols=g.map(\.count).max()!;let ox=cx-CGFloat(cols)*cell/2,oy=cy-CGFloat(rows)*cell/2;for (r,l) in g.enumerated(){for (c,ch) in l.enumerated() where ch != "."{ccol(ch,alpha).setFill();NSRect(x:ox+CGFloat(c)*cell,y:oy+CGFloat(rows-1-r)*cell,width:cell,height:cell).fill()}}}
func clamp(_ x:CGFloat,_ a:CGFloat,_ b:CGFloat)->CGFloat{max(a,min(b,x))}
func smooth(_ e0:CGFloat,_ e1:CGFloat,_ x:CGFloat)->CGFloat{let t=clamp((x-e0)/(e1-e0),0,1);return t*t*(3-2*t)}
func lerp(_ a:CGFloat,_ b:CGFloat,_ t:CGFloat)->CGFloat{a+(b-a)*t}
func key(_ u:CGFloat,_ p:[(CGFloat,CGFloat)])->CGFloat{if u<=p.first!.0{return p.first!.1};if u>=p.last!.0{return p.last!.1};for i in 1..<p.count{if u<=p[i].0{return lerp(p[i-1].1,p[i].1,smooth(p[i-1].0,p[i].0,u))}};return p.last!.1}
func fade(_ t:CGFloat,_ d:CGFloat,_ fi:CGFloat=0.4,_ fo:CGFloat=0.4)->CGFloat{min(smooth(0,fi,t),1-smooth(d-fo,d,t))}
func tc(_ s:String,_ sz:CGFloat,_ w:NSFont.Weight,_ c:NSColor,_ cx:CGFloat,_ y:CGFloat,_ a:CGFloat=1){let at:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:sz,weight:w),.foregroundColor:c.withAlphaComponent(a)];let z=(s as NSString).size(withAttributes:at);(s as NSString).draw(at:NSPoint(x:cx-z.width/2,y:y),withAttributes:at)}
func tl(_ s:String,_ sz:CGFloat,_ w:NSFont.Weight,_ c:NSColor,_ x:CGFloat,_ y:CGFloat,_ a:CGFloat=1){let at:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:sz,weight:w),.foregroundColor:c.withAlphaComponent(a)];(s as NSString).draw(at:NSPoint(x:x,y:y),withAttributes:at)}
func trr(_ s:String,_ sz:CGFloat,_ w:NSFont.Weight,_ c:NSColor,_ rx:CGFloat,_ y:CGFloat,_ a:CGFloat=1){let at:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:sz,weight:w),.foregroundColor:c.withAlphaComponent(a)];let z=(s as NSString).size(withAttributes:at);(s as NSString).draw(at:NSPoint(x:rx-z.width,y:y),withAttributes:at)}
func ml(_ s:String,_ sz:CGFloat,_ w:NSFont.Weight,_ c:NSColor,_ x:CGFloat,_ y:CGFloat,_ a:CGFloat=1){let at:[NSAttributedString.Key:Any]=[.font:NSFont.monospacedSystemFont(ofSize:sz,weight:w),.foregroundColor:c.withAlphaComponent(a)];(s as NSString).draw(at:NSPoint(x:x,y:y),withAttributes:at)}
func rr(_ r:NSRect,_ rad:CGFloat,_ c:NSColor){c.setFill();NSBezierPath(roundedRect:r,xRadius:rad,yRadius:rad).fill()}
func hline(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ a:CGFloat){NSColor(white:1,alpha:0.12*a).setFill();NSRect(x:x,y:y,width:w,height:1).fill()}
func hex(_ h:Int,_ a:CGFloat=1)->NSColor{NSColor(srgbRed:CGFloat((h>>16)&0xff)/255,green:CGFloat((h>>8)&0xff)/255,blue:CGFloat(h&0xff)/255,alpha:a)}
func scaled(_ ctr:NSPoint,_ s:CGFloat,_ body:()->Void){NSGraphicsContext.saveGraphicsState();let t=NSAffineTransform();t.translateX(by:ctr.x,yBy:ctr.y);t.scale(by:s);t.translateX(by:-ctr.x,yBy:-ctr.y);t.concat();body();NSGraphicsContext.restoreGraphicsState()}

let scrRect=NSRect(x:56,y:50,width:dW-112,height:dH-100)
let menuH:CGFloat=30
let menuY=scrRect.maxY-menuH
let crabX=scrRect.maxX-300
let crabCY=scrRect.maxY-menuH/2
let panelPW:CGFloat=300, panelPadX:CGFloat=16
let panelPX=scrRect.maxX-28-panelPW
func panelTopY(_ open:CGFloat)->CGFloat{menuY-8-lerp(14,0,open)}
let panelCx=panelPX+panelPW/2

let termRect=NSRect(x:scrRect.minX+70,y:scrRect.midY-186,width:590,height:360)
let safariRect=NSRect(x:scrRect.minX+250,y:scrRect.midY-150,width:744,height:420)
let termCenter=NSPoint(x:termRect.midX,y:termRect.midY)
let safariCenter=NSPoint(x:safariRect.midX,y:safariRect.midY)
let tcontentX=termRect.minX+20
let tcontentTop=termRect.maxY-34-20
let tlh:CGFloat=23
func trow(_ i:CGFloat)->CGFloat{tcontentTop-i*tlh}
let boxTop=trow(2)+8
let oneRowPt=NSPoint(x:termRect.minX+80,y:boxTop-118)

func wall(){NSGradient(starting:hex(0xE9E6E2),ending:hex(0xD7D2CC))!.draw(in:NSRect(x:0,y:0,width:dW,height:dH),angle:-90)}
func wallpaper(){
 NSGradient(starting:hex(0x141733),ending:hex(0x241a3a))!.draw(in:scrRect,angle:-72)
 func blob(_ h:Int,_ cx:CGFloat,_ cy:CGFloat,_ r:CGFloat){let g=NSGradient(colors:[hex(h,0.55),hex(h,0.0)])!;g.draw(in:NSBezierPath(ovalIn:NSRect(x:cx-r,y:cy-r,width:2*r,height:2*r)),relativeCenterPosition:.zero)}
 blob(0x4a2f9e,scrRect.minX+160,scrRect.maxY-60,680);blob(0xb23c6e,scrRect.maxX-120,scrRect.maxY-40,640)
 blob(0xc4663f,scrRect.midX+180,scrRect.minY-40,720);blob(0x2f6f9e,scrRect.minX-20,scrRect.minY+120,600);blob(0x6a3fae,scrRect.midX-60,scrRect.midY,520)
}
let dockApps=["/System/Library/CoreServices/Finder.app","/Applications/Safari.app","/System/Applications/Messages.app","/System/Applications/Mail.app","/System/Applications/Notes.app","/System/Applications/Music.app","/System/Applications/Utilities/Terminal.app","/System/Applications/System Settings.app"]
let dockIcons:[NSImage]=dockApps.map{NSWorkspace.shared.icon(forFile:$0)}
let dockISZ:CGFloat=46, dockGAP:CGFloat=10
let dockW=CGFloat(dockApps.count)*dockISZ+CGFloat(dockApps.count-1)*dockGAP+22
let dockX=scrRect.midX-dockW/2, dockY=scrRect.minY+12
func dockIconCenter(_ i:Int)->NSPoint{NSPoint(x:dockX+11+CGFloat(i)*(dockISZ+dockGAP)+dockISZ/2,y:dockY+7+dockISZ/2)}
func dock(_ bounce:CGFloat){
 rr(NSRect(x:dockX,y:dockY,width:dockW,height:dockISZ+14),18,NSColor(white:1,alpha:0.18))
 NSColor(white:1,alpha:0.12).setStroke();let b=NSBezierPath(roundedRect:NSRect(x:dockX,y:dockY,width:dockW,height:dockISZ+14),xRadius:18,yRadius:18);b.lineWidth=1;b.stroke()
 for i in 0..<dockApps.count{let by = i==6 ? bounce*14:0; let ix=dockX+11+CGFloat(i)*(dockISZ+dockGAP);dockIcons[i].draw(in:NSRect(x:ix,y:dockY+7+by,width:dockISZ,height:dockISZ),from:.zero,operation:.sourceOver,fraction:1.0)}
}
func drawBattery(cx:CGFloat,cy:CGFloat){let w:CGFloat=24,h:CGFloat=12;let r=NSRect(x:cx-w/2,y:cy-h/2,width:w,height:h);NSColor.white.setStroke();let p=NSBezierPath(roundedRect:r,xRadius:3,yRadius:3);p.lineWidth=1.3;p.stroke();NSColor.white.setFill();NSBezierPath(roundedRect:r.insetBy(dx:2.5,dy:2.5),xRadius:1.5,yRadius:1.5).fill();NSBezierPath(rect:NSRect(x:r.maxX+1,y:cy-2.5,width:2,height:5)).fill()}
func drawWifi(cx:CGFloat,cy:CGFloat){NSColor.white.setStroke();for rad in [10.0,6.0]{let p=NSBezierPath();p.appendArc(withCenter:NSPoint(x:cx,y:cy-5),radius:CGFloat(rad),startAngle:55,endAngle:125);p.lineWidth=2;p.stroke()};NSColor.white.setFill();NSBezierPath(ovalIn:NSRect(x:cx-2,y:cy-7,width:4,height:4)).fill()}

func stateInfo(_ s:String)->(String,String,String){switch s{case "action":return("action","Action needed","Claude needs you — permission or input");case "done":return("eureka","Done","Claude finished its turn");default:return("wA","Working","building the project")}}

func drawPanel(state:String,open:CGFloat,highlightFirst:Bool){
 let a=open;let topY=panelTopY(open);let ph:CGFloat=306
 NSColor(white:0,alpha:0.30*a).setFill();NSBezierPath(roundedRect:NSRect(x:panelPX,y:topY-ph-6,width:panelPW,height:ph),xRadius:14,yRadius:14).fill()
 rr(NSRect(x:panelPX,y:topY-ph,width:panelPW,height:ph),14,NSColor(white:0.15,alpha:0.98*a))
 let (pose,headline,detail)=stateInfo(state)
 var y=topY-16
 clawd(pose,cx:panelPX+panelPadX+24,cy:y-24,cell:3.0,alpha:a)
 tl(headline,17,.semibold,.white,panelPX+panelPadX+58,y-20,a);tl(detail,12,.regular,NSColor(white:0.7,alpha:1),panelPX+panelPadX+58,y-38,a)
 y-=60;hline(panelPX+panelPadX,y,panelPW-2*panelPadX,a);y-=14
 tl("Sessions",12,.bold,NSColor(white:0.65,alpha:1),panelPX+panelPadX,y-12,a);y-=26
 let rows:[(String,NSColor,String)]=state=="done" ? [("Explore Mac app…",.systemGreen,"done"),("Testing number 2",.systemOrange,"working")] : (state=="action" ? [("Explore Mac app…",.systemYellow,"needs you"),("Testing number 2",.systemOrange,"working")] : [("Explore Mac app…",.systemOrange,"working"),("Testing number 2",.systemGreen,"done")])
 for (i,(nm,dot,st)) in rows.enumerated(){
  if i==0 && highlightFirst{rr(NSRect(x:panelPX+8,y:y-22,width:panelPW-16,height:30),8,NSColor(white:1,alpha:0.14*a))}
  dot.withAlphaComponent(a).setFill();NSBezierPath(ovalIn:NSRect(x:panelPX+panelPadX+2,y:y-12,width:9,height:9)).fill()
  tl(nm,15,.regular,.white,panelPX+panelPadX+22,y-15,a);trr(st,13,.regular,NSColor(white:0.6,alpha:1),panelPX+panelPW-panelPadX,y-15,a);y-=36}
 hline(panelPX+panelPadX,y,panelPW-2*panelPadX,a);y-=14
 tl("✓",13,.bold,NSColor.systemGreen,panelPX+panelPadX,y-13,a);tl("Connected to Claude Code",13,.regular,NSColor.systemGreen,panelPX+panelPadX+18,y-13,a);y-=30
 hline(panelPX+panelPadX,y,panelPW-2*panelPadX,a);y-=14
 tl("Launch at login",14,.regular,.white,panelPX+panelPadX,y-14,a)
 let tw:CGFloat=34,th:CGFloat=20,tx=panelPX+panelPW-panelPadX-tw,ty=y-18
 rr(NSRect(x:tx,y:ty,width:tw,height:th),th/2,NSColor.systemGreen.withAlphaComponent(a));NSColor.white.withAlphaComponent(a).setFill();NSBezierPath(ovalIn:NSRect(x:tx+tw-th+2,y:ty+2,width:th-4,height:th-4)).fill();y-=30
 hline(panelPX+panelPadX,y,panelPW-2*panelPadX,a);y-=12
 tl("Simmer · for Claude Code",11,.regular,NSColor(white:0.5,alpha:1),panelPX+panelPadX,y-11,a);tl("Runs entirely on your Mac",11,.regular,NSColor(white:0.5,alpha:1),panelPX+panelPadX,y-25,a)
}

func windowChrome(_ r:NSRect,_ title:String,_ titleBarColor:NSColor,_ light:Bool){
 NSColor(white:0,alpha:0.34).setFill();NSBezierPath(roundedRect:r.offsetBy(dx:0,dy:-9),xRadius:13,yRadius:13).fill()
 rr(r,13, light ? hex(0xF5F4F6):hex(0x0c0c11,0.99))
 rr(NSRect(x:r.minX,y:r.maxY-34,width:r.width,height:34),13,titleBarColor)
 for (k,c) in [hex(0xFF5F57),hex(0xFEBC2E),hex(0x28C840)].enumerated(){c.setFill();NSBezierPath(ovalIn:NSRect(x:r.minX+16+CGFloat(k)*20,y:r.maxY-22,width:12,height:12)).fill()}
 tc(title,12.5,.medium, light ? NSColor(white:0.35,alpha:1):NSColor(white:0.8,alpha:1), r.midX, r.maxY-24)
}
let spinWords=["Simmering","Baking","Brewing","Whisking","Percolating"]
func drawTerminalWindow(_ u:CGFloat){
 windowChrome(termRect,"✳ claude — ~/Projects/Simmer",hex(0x1b1b22),false)
 let clip=NSBezierPath(roundedRect:termRect.insetBy(dx:1,dy:1),xRadius:12,yRadius:12);NSGraphicsContext.saveGraphicsState();clip.setClip()
 let dim=NSColor(white:0.62,alpha:1),txt=NSColor(white:0.92,alpha:1),green=hex(0x3ddc84),org=hex(0xE8A87C)
 ml("> build the project and fix any errors",13.5,.regular,dim,tcontentX,trow(0))
 ml("● I'll run the build and check for issues.",13.5,.regular,txt,tcontentX,trow(1))
 if u<3.0{let w=spinWords[Int(u*1.5)%spinWords.count];ml("✳ \(w)… (\(Int(u))s · esc to interrupt)",13.5,.regular,org,tcontentX,trow(2))}
 else if u<7.2{
  let pa=smooth(3.0,3.3,u)*(1-smooth(7.0,7.2,u))
  let bx=termRect.minX+16,bw=termRect.width-32,bh:CGFloat=196,byy=boxTop-bh
  rr(NSRect(x:bx,y:byy,width:bw,height:bh),10,hex(0x16161d,pa));NSColor(white:1,alpha:0.10*pa).setStroke();let bb=NSBezierPath(roundedRect:NSRect(x:bx,y:byy,width:bw,height:bh),xRadius:10,yRadius:10);bb.lineWidth=1;bb.stroke()
  ml("Bash command",12.5,.semibold,NSColor(white:0.6,alpha:1),bx+18,boxTop-24,pa)
  ml("npm run build",13.5,.regular,txt,bx+18,boxTop-48,pa);ml("Build the production bundle",12.5,.regular,dim,bx+18,boxTop-68,pa)
  ml("Do you want to proceed?",13.5,.regular,txt,bx+18,boxTop-100,pa)
  let press=smooth(6.6,7.0,u)
  rr(NSRect(x:bx+10,y:boxTop-124,width:bw-20,height:24),6,hex(0xE8A87C,(0.16+0.20*press)*pa))
  ml("❯ 1. Yes",13.5,.semibold,org,bx+18,boxTop-120,pa);ml("  2. Yes, and don't ask again this session",13.5,.regular,dim,bx+18,boxTop-144,pa);ml("  3. No, and tell Claude what to do differently",13.5,.regular,dim,bx+18,boxTop-166,pa)
  if press>0{let kp=NSRect(x:bx+bw-66,y:boxTop-128,width:26,height:26);rr(kp,5,hex(0x2a2a33,pa));NSColor(white:1,alpha:0.2*pa).setStroke();NSBezierPath(roundedRect:kp,xRadius:5,yRadius:5).stroke();ml("1",14,.bold,NSColor.white.withAlphaComponent(pa),kp.minX+9,kp.minY+6)}
 } else {
  ml("● Bash(npm run build)",13.5,.regular,txt,tcontentX,trow(2),smooth(7.2,7.4,u))
  let el=Int(max(0,u-7.2))
  if u<11.5{let w=spinWords[Int(u*1.5)%spinWords.count];ml("  ⎿ ✳ \(w)… (\(el)s · ↑ \(el*340) tokens · esc to interrupt)",13,.regular,org,tcontentX,trow(3),smooth(7.4,7.6,u))}
  else{ml("  ⎿ Ran in 4.1s",13,.regular,dim,tcontentX,trow(3),1)}
  ml("     > vite build",13,.regular,dim,tcontentX,trow(4),smooth(8.6,8.9,u))
  ml("     ✓ 142 modules transformed",13,.regular,green,tcontentX,trow(5),smooth(9.4,9.7,u))
  ml("     dist/index.html   1.24 kB",13,.regular,dim,tcontentX,trow(6),smooth(10.1,10.4,u))
  if u>=11.5{
   ml("     ✓ built in 3.24s",13,.regular,green,tcontentX,trow(7),smooth(11.5,11.8,u))
   ml("● Build succeeded — no errors. The app is ready to run.",13.5,.regular,txt,tcontentX,trow(8),smooth(11.9,12.3,u))
   ml("> ",13.5,.regular,txt,tcontentX,trow(9),smooth(12.5,12.7,u))
   if u>12.6{let blink=(Int(u*2)%2==0) ?CGFloat(1):CGFloat(0.25);rr(NSRect(x:tcontentX+16,y:trow(9)-2,width:9,height:16),1,NSColor.white.withAlphaComponent(blink))}
  }
 }
 NSGraphicsContext.restoreGraphicsState()
}
func drawSafari(){
 windowChrome(safariRect,"",hex(0xE7E5E8),true)
 // toolbar contents
 ml("‹  ›",14,.regular,NSColor(white:0.45,alpha:1),safariRect.minX+92,safariRect.maxY-25)
 let pill=NSRect(x:safariRect.midX-150,y:safariRect.maxY-28,width:300,height:21);rr(pill,10,NSColor(white:1,alpha:1))
 tc("claude.com/claude-code",12,.regular,NSColor(white:0.4,alpha:1),safariRect.midX,safariRect.maxY-25)
 // page content
 let cx=safariRect.minX, top=safariRect.maxY-34
 rr(NSRect(x:cx,y:safariRect.minY,width:safariRect.width,height:top-safariRect.minY),0,.white)
 // nav
 tl("✻ Claude",15,.bold,NSColor(white:0.15,alpha:1),cx+28,top-34)
 tl("Product     Research     Company",12.5,.regular,NSColor(white:0.45,alpha:1),cx+safariRect.width-300,top-34)
 // hero
 let hero=NSRect(x:cx+28,y:top-250,width:safariRect.width-56,height:180)
 NSGradient(starting:hex(0xE8C9B4),ending:hex(0xD98E6A))!.draw(in:NSBezierPath(roundedRect:hero,xRadius:14,yRadius:14),angle:-50)
 tl("Claude Code",30,.bold,.white,hero.minX+28,hero.midY+6)
 tl("Build software, faster.",16,.regular,NSColor(white:1,alpha:0.92),hero.minX+28,hero.midY-26)
 // body lines + cards
 for i in 0..<3{rr(NSRect(x:cx+28,y:top-285-CGFloat(i)*18,width:CGFloat(i==2 ?280:safariRect.width-90),height:8),4,NSColor(white:0.82,alpha:1))}
 for i in 0..<3{rr(NSRect(x:cx+28+CGFloat(i)*((safariRect.width-56)/3),y:safariRect.minY+24,width:(safariRect.width-56)/3-16,height:70),10,NSColor(white:0.95,alpha:1));rr(NSRect(x:cx+44+CGFloat(i)*((safariRect.width-56)/3),y:safariRect.minY+74,width:60,height:8),4,NSColor(white:0.8,alpha:1))}
}
func cursorArrow(_ p:NSPoint,_ a:CGFloat,_ press:CGFloat){let s=lerp(1.0,0.86,press);let path=NSBezierPath();func pt(_ dx:CGFloat,_ dy:CGFloat)->NSPoint{NSPoint(x:p.x+dx*s,y:p.y-dy*s)};path.move(to:pt(0,0));path.line(to:pt(0,19));path.line(to:pt(4.2,14.5));path.line(to:pt(7.4,21));path.line(to:pt(10.2,19.8));path.line(to:pt(7,13.4));path.line(to:pt(12.6,13));path.close();NSColor.black.withAlphaComponent(0.9*a).setStroke();path.lineWidth=3.2;path.stroke();NSColor.white.withAlphaComponent(a).setFill();path.fill()}
func ripple(_ p:NSPoint,_ prog:CGFloat){let r=lerp(5,30,prog);let a=(1-prog)*0.6;NSColor.white.withAlphaComponent(a).setStroke();let c=NSBezierPath(ovalIn:NSRect(x:p.x-r,y:p.y-r,width:2*r,height:2*r));c.lineWidth=2.5;c.stroke()}

let macDur:CGFloat=17.0
// window front schedule
func frontState(_ u:CGFloat)->(Bool,CGFloat){let tr:[(CGFloat,Bool)]=[(0,false),(5.8,true),(8.4,false),(14.0,true)];var cur=false,st:CGFloat=0;for (tt,tf) in tr{if u>=tt{cur=tf;st=tt}};return (cur,smooth(st,st+0.35,u))}
func camAt(_ u:CGFloat)->(CGFloat,CGFloat,CGFloat){
 let z=key(u,[(0,1.0),(3.0,1.0),(3.8,1.12),(5.5,1.12),(6.3,1.05),(8.4,1.0),(11.4,1.0),(11.9,1.12),(13.7,1.12),(14.3,1.06),(macDur,1.06)])
 let fx=key(u,[(0,scrRect.midX),(3.0,scrRect.midX),(3.8,panelCx-30),(5.5,panelCx-30),(6.3,scrRect.midX-20),(8.4,scrRect.midX),(11.4,scrRect.midX),(11.9,panelCx-30),(13.7,panelCx-30),(14.3,scrRect.midX-70),(macDur,scrRect.midX-70)])
 let fy=key(u,[(0,scrRect.midY),(3.8,menuY-128),(5.5,menuY-128),(6.3,scrRect.midY),(8.4,scrRect.midY),(11.9,menuY-128),(13.7,menuY-128),(14.3,scrRect.midY+6),(macDur,scrRect.midY+6)])
 return (z,fx,fy)
}
func drawMacShot(_ u:CGFloat){
 let state = u<3.0 ? "working" : (u<7.2 ? "action" : (u<11.5 ? "working":"done"))
 let pf=smooth(4.4,4.8,u)*(1-smooth(5.5,5.8,u))
 let pd=smooth(12.8,13.2,u)*(1-smooth(13.7,14.0,u))
 let panel=max(pf,pd)
 let pstate = u<9.0 ? "action":"done"
 let hlrow = (u>=5.3 && u<5.8) || (u>=13.5 && u<14.0)
 let bez=scrRect.insetBy(dx:-12,dy:-12)
 NSColor(white:0,alpha:0.20).setFill();NSBezierPath(roundedRect:bez.offsetBy(dx:0,dy:-10),xRadius:30,yRadius:30).fill()
 rr(bez,30,hex(0x0a0a0c))
 let clip=NSBezierPath(roundedRect:scrRect,xRadius:20,yRadius:20);clip.setClip()
 wallpaper()
 dock(0)
 // windows
 let (termFront,raise)=frontState(u)
 if termFront{drawSafari();scaled(termCenter,lerp(0.97,1,raise)){drawTerminalWindow(u)}}
 else{drawTerminalWindow(u);scaled(safariCenter,lerp(0.97,1,raise)){drawSafari()}}
 // menu bar
 NSColor(white:0,alpha:0.30).setFill();NSRect(x:scrRect.minX,y:menuY,width:scrRect.width,height:menuH).fill()
 rr(NSRect(x:scrRect.midX-70,y:scrRect.maxY-20,width:140,height:24),11,hex(0x040406))
 tl("\u{F8FF}",16,.regular,.white,scrRect.minX+18,menuY+7);tl("Safari",14,.bold,.white,scrRect.minX+46,menuY+8);tl("File   Edit   View",14,.regular,NSColor(white:1,alpha:0.85),scrRect.minX+106,menuY+8)
 trr("Wed  9:41 PM",14,.regular,.white,scrRect.maxX-20,menuY+8);drawBattery(cx:scrRect.maxX-130,cy:menuY+menuH/2);drawWifi(cx:scrRect.maxX-168,cy:menuY+menuH/2)
 // crab pulse on chimes
 for ct in [3.0,11.5]{let pr=smooth(ct,ct+0.45,u)*(1-smooth(ct+0.45,ct+1.2,u));if pr>0{let r=lerp(14,30,1-pr+smooth(ct,ct+0.45,u));NSColor.white.withAlphaComponent(0.5*pr).setStroke();let c=NSBezierPath(ovalIn:NSRect(x:crabX-r,y:crabCY-r,width:2*r,height:2*r));c.lineWidth=2;c.stroke()}}
 let (mpose,_,_)=stateInfo(state)
 let wig = state=="working" ? (Int(u*4)%2==0 ?"wA":"wB") : mpose
 clawd(wig,cx:crabX,cy:menuY+menuH/2,cell:1.6,alpha:1)
 let mtext = state=="working" ? "Simmering…" : (state=="action" ? "Action needed":"Done")
 tl(mtext,14,.regular,.white,crabX+14,menuY+8)
 NSGraphicsContext.current?.cgContext.resetClip()
 if panel>0{drawPanel(state:pstate,open:panel,highlightFirst:hlrow)}
 // cursor: Safari → click crab → click session (terminal up) → answer 1 → back to Safari → click crab → click session (output)
 let sess=NSPoint(x:panelPX+90,y:menuY-118), crabPt=NSPoint(x:crabX,y:crabCY), safClick=NSPoint(x:safariCenter.x+120,y:safariCenter.y)
 let cx=key(u,[(0,safariCenter.x),(3.6,safariCenter.x),(4.4,crabPt.x),(4.9,crabPt.x),(5.4,sess.x),(5.8,sess.x),(6.6,oneRowPt.x),(7.2,oneRowPt.x),(7.8,safClick.x),(8.4,safClick.x),(12.2,safClick.x),(12.8,crabPt.x),(13.3,crabPt.x),(13.8,sess.x),(14.0,sess.x),(macDur,sess.x)])
 let cy=key(u,[(0,safariCenter.y),(3.6,safariCenter.y),(4.4,crabPt.y),(4.9,crabPt.y),(5.4,sess.y),(5.8,sess.y),(6.6,oneRowPt.y),(7.2,oneRowPt.y),(7.8,safClick.y),(8.4,safClick.y),(12.2,safClick.y),(12.8,crabPt.y),(13.3,crabPt.y),(13.8,sess.y),(14.0,sess.y),(macDur,sess.y)])
 let ca=1-smooth(16.2,16.8,u)
 var press:CGFloat=0;for ct in [4.4,5.8,7.0,8.4,12.8,14.0]{press=max(press,smooth(CGFloat(ct)-0.12,CGFloat(ct),u)*(1-smooth(CGFloat(ct),CGFloat(ct)+0.14,u)))}
 if ca>0{cursorArrow(NSPoint(x:cx,y:cy),ca,press)}
 let rips:[(CGFloat,NSPoint)]=[(4.4,crabPt),(5.8,sess),(7.0,oneRowPt),(8.4,safClick),(12.8,crabPt),(14.0,sess)]
 for (ct,pt) in rips{let pr=smooth(ct,ct+0.45,u);if pr>0 && pr<1{ripple(pt,pr)}}
}
func caption(_ u:CGFloat){
 let caps:[(CGFloat,CGFloat,String)]=[
  (0.3,2.8,"You're in Safari — Claude works in the background."),
  (3.3,5.2,"A chime — Clawd, top-right: “Action needed.”"),
  (5.5,7.6,"Tap it in Clawd — your terminal jumps up. Pick 1."),
  (8.6,11.0,"Back to Safari…"),
  (11.7,13.4,"…then “ding,” it's done."),
  (14.1,16.6,"Tap the session in Clawd — land on the result."),
 ]
 for (s0,s1,txt) in caps where u>=s0-0.4 && u<=s1+0.4{let a=fade(u-s0,s1-s0);let yoff=lerp(10,0,smooth(s0,s0+0.5,u));let font=NSFont.systemFont(ofSize:22,weight:.medium);let tw=(txt as NSString).size(withAttributes:[.font:font]).width;let cy:CGFloat=104+yoff;rr(NSRect(x:dW/2-tw/2-22,y:cy-9,width:tw+44,height:38),19,NSColor(white:0.05,alpha:0.44*a));tc(txt,22,.medium,.white,dW/2,cy,a)}
}
func vignette(){NSGradient(colors:[NSColor(white:0,alpha:0),NSColor(white:0,alpha:0.22)])!.draw(in:NSBezierPath(rect:NSRect(x:0,y:0,width:dW,height:dH)),relativeCenterPosition:.zero)}
func darkCard(){NSGradient(starting:hex(0x1b1620),ending:hex(0x0d0b11))!.draw(in:NSRect(x:0,y:0,width:dW,height:dH),angle:-90)}

let titleDur:CGFloat=2.4, outroDur:CGFloat=3.2
let total=titleDur+macDur+outroDur, macStart=titleDur
let alertAt=macStart+3.0, doneAt=macStart+11.5
func frame(_ t:CGFloat)->CGImage{
 let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:W,pixelsHigh:H,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 let ctx=NSGraphicsContext(bitmapImageRep:rep)!;NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=ctx
 let base=NSAffineTransform();base.scale(by:CGFloat(S));base.concat()
 if t<titleDur{darkCard();let a=fade(t,titleDur);clawd("wA",cx:dW/2,cy:dH/2+74,cell:9,alpha:a);tc("Simmer",76,.bold,.white,dW/2,dH/2-62,a);tc("a menu-bar companion for Claude Code",23,.regular,hex(0xB9A9C2),dW/2,dH/2-100,a)}
 else if t<titleDur+macDur{let u=t-macStart;wall();NSGraphicsContext.saveGraphicsState();let (z,fx,fy)=camAt(u);let cam=NSAffineTransform();cam.translateX(by:dW/2,yBy:dH/2);cam.scale(by:z);cam.translateX(by:-fx,yBy:-fy);cam.concat();drawMacShot(u);NSGraphicsContext.restoreGraphicsState();vignette();caption(u)}
 else{darkCard();let a=fade(t-(titleDur+macDur),outroDur);clawd("eureka",cx:dW/2,cy:dH/2+66,cell:7.5,alpha:a);tc("Simmer",60,.bold,.white,dW/2,dH/2-52,a);tc("Free · Open source · for Claude Code",24,.regular,hex(0xB9A9C2),dW/2,dH/2-92,a)}
 NSGraphicsContext.restoreGraphicsState();return rep.cgImage!
}
try? FileManager.default.removeItem(at:outURL)
let writer=try! AVAssetWriter(outputURL:outURL,fileType:.mp4)
let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:W,AVVideoHeightKey:H,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:9_000_000]]);input.expectsMediaDataInRealTime=false
let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:Int(kCVPixelFormatType_32ARGB),kCVPixelBufferWidthKey as String:W,kCVPixelBufferHeightKey as String:H])
writer.add(input);writer.startWriting();writer.startSession(atSourceTime:.zero)
let nframes=Int(total*CGFloat(FPS));var f=0
while f<nframes{if input.isReadyForMoreMediaData{let img=frame(CGFloat(f)/CGFloat(FPS));var pb:CVPixelBuffer?;CVPixelBufferPoolCreatePixelBuffer(nil,adaptor.pixelBufferPool!,&pb);CVPixelBufferLockBaseAddress(pb!,[]);let cg=CGContext(data:CVPixelBufferGetBaseAddress(pb!),width:W,height:H,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(pb!),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedFirst.rawValue)!;cg.draw(img,in:CGRect(x:0,y:0,width:W,height:H));CVPixelBufferUnlockBaseAddress(pb!,[]);adaptor.append(pb!,withPresentationTime:CMTime(value:CMTimeValue(f),timescale:CMTimeScale(FPS)));f+=1}else{usleep(2000)}}
input.markAsFinished();let sem=DispatchSemaphore(value:0);writer.finishWriting{sem.signal()};sem.wait();print("video \(total)s")
let comp=AVMutableComposition();let vA=AVURLAsset(url:outURL)
let vT=comp.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid)!
try! vT.insertTimeRange(CMTimeRange(start:.zero,duration:vA.duration),of:vA.tracks(withMediaType:.video).first!,at:.zero)
let music=comp.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid)!
let mA=AVURLAsset(url:musicWav);if let s=mA.tracks(withMediaType:.audio).first{try? music.insertTimeRange(CMTimeRange(start:.zero,duration:CMTimeMinimum(mA.duration,vA.duration)),of:s,at:.zero)}
let sfx=comp.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid)!
for (wav,at) in [(alertWav,alertAt),(doneWav,doneAt)]{let aA=AVURLAsset(url:wav);if let s=aA.tracks(withMediaType:.audio).first{try? sfx.insertTimeRange(CMTimeRange(start:.zero,duration:aA.duration),of:s,at:CMTime(seconds:Double(at),preferredTimescale:600))}}
let mix=AVMutableAudioMix();let mp=AVMutableAudioMixInputParameters(track:music);mp.setVolume(0.5,at:.zero);mix.inputParameters=[mp]
try? FileManager.default.removeItem(at:finalURL)
let ex=AVAssetExportSession(asset:comp,presetName:AVAssetExportPresetHighestQuality)!;ex.outputURL = finalURL;ex.outputFileType = .mp4;ex.audioMix=mix
let sem2=DispatchSemaphore(value:0);ex.exportAsynchronously{sem2.signal()};sem2.wait();print("final \(ex.status.rawValue)")
