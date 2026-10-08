import SpriteKit
import UIKit

final class GameScene: SKScene, GameFX {

    weak var logic: GameModel?

    private var t: Double = 0
    private var lastUpdate: TimeInterval = 0

    // nodes
    private let world = SKNode()
    private var sky: SKSpriteNode!
    private var sea: SKSpriteNode!
    private var waveLine: SKShapeNode!
    private var bobber: SKNode!
    private var shadow: SKShapeNode!
    private var lineShape: SKShapeNode!
    private var cam: SKCameraNode!
    private var fxLayer = SKNode()
    private var rushTint: SKSpriteNode!
    private var embers: SKEmitterNode!
    private var rodTip = CGPoint(x: 55, y: 140)
    private var rodNode: SKShapeNode!

    // orbit state
    private var orbitSpeed: Double = 0
    private var orbitRadius: Double = 0
    private var orbitAngle: Double = 0
    private var orbitVisible = false
    private var shadowScale: Double = 0.4
    private var fightMode = false

    private var shakeMag: Double = 0
    private var zoomLevel: Double = 1
    private var bobberPos = CGPoint(x: 195, y: 370)
    private var dipOffset: Double = 0
    private var dipVel: Double = 0

    // textures
    private var texCircle: SKTexture!
    private var texStar: SKTexture!
    private var texCoin: SKTexture!
    private var texSpark: SKTexture!
    private var texBeam: SKTexture!
    private var texPillar: SKTexture!
    private var texRect: SKTexture!

    // showtime fx
    private var speedNode: SKNode?
    private var speedMode = 0
    private var speedHue: Double = 0
    private var auraSprite: SKSpriteNode?
    private var auraMode = 0
    private var auraHue: Double = 0

    // MARK: setup

    override func didMove(to view: SKView) {
        size = CGSize(width: 390, height: 844)
        scaleMode = .aspectFill
        anchorPoint = .zero
        backgroundColor = UIColor(red: 0.35, green: 0.65, blue: 0.9, alpha: 1)
        buildTextures()
        buildScene()
    }

    private func buildTextures() {
        texCircle = SKTexture(image: drawImage(size: 32) { ctx, s in
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: [0, 1])!
            ctx.drawRadialGradient(grad, startCenter: CGPoint(x: s/2, y: s/2), startRadius: 0,
                                   endCenter: CGPoint(x: s/2, y: s/2), endRadius: s/2, options: [])
        })
        texStar = SKTexture(image: drawImage(size: 48) { ctx, s in
            ctx.setFillColor(UIColor.white.cgColor)
            let path = UIBezierPath()
            let c = CGPoint(x: s/2, y: s/2)
            for i in 0..<8 {
                let r: CGFloat = i % 2 == 0 ? s * 0.48 : s * 0.14
                let a = CGFloat(i) * .pi / 4 - .pi / 2
                let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                i == 0 ? path.move(to: p) : path.addLine(to: p)
            }
            path.close()
            path.fill()
        })
        texCoin = SKTexture(image: drawImage(size: 40) { ctx, s in
            let r = CGRect(x: 4, y: 4, width: s - 8, height: s - 8)
            ctx.setFillColor(UIColor(red: 1, green: 0.82, blue: 0.15, alpha: 1).cgColor)
            ctx.fillEllipse(in: r)
            ctx.setStrokeColor(UIColor(red: 0.75, green: 0.5, blue: 0.05, alpha: 1).cgColor)
            ctx.setLineWidth(3)
            ctx.strokeEllipse(in: r.insetBy(dx: 2, dy: 2))
        })
        texSpark = texCircle
        texBeam = SKTexture(image: drawImage(size: 32) { ctx, s in
            ctx.addEllipse(in: CGRect(x: 0, y: s * 0.24, width: s, height: s * 0.52))
            ctx.clip()
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor.white.withAlphaComponent(0).cgColor,
                                           UIColor.white.cgColor,
                                           UIColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: [0, 0.62, 1])!
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: s / 2), end: CGPoint(x: s, y: s / 2), options: [])
        })
        texPillar = SKTexture(image: drawImageRect(size: CGSize(width: 64, height: 128)) { ctx in
            let g1 = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [UIColor.white.withAlphaComponent(0).cgColor,
                                         UIColor.white.cgColor,
                                         UIColor.white.cgColor,
                                         UIColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                locations: [0, 0.3, 0.7, 1])!
            ctx.drawLinearGradient(g1, start: CGPoint(x: 0, y: 64), end: CGPoint(x: 64, y: 64), options: [])
            ctx.setBlendMode(.destinationIn)
            let g2 = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [UIColor.white.cgColor,
                                         UIColor.white.cgColor,
                                         UIColor.white.withAlphaComponent(0.25).cgColor] as CFArray,
                                locations: [0, 0.7, 1])!
            ctx.drawLinearGradient(g2, start: CGPoint(x: 32, y: 128), end: CGPoint(x: 32, y: 0), options: [])
        })
        texRect = SKTexture(image: drawImageRect(size: CGSize(width: 12, height: 7)) { ctx in
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: 12, height: 7))
        })
    }

    private func drawImage(size: CGFloat, _ draw: (CGContext, CGFloat) -> Void) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: fmt).image { r in
            draw(r.cgContext, size)
        }
    }

    private func drawImageRect(size: CGSize, _ draw: (CGContext) -> Void) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = false
        return UIGraphicsImageRenderer(size: size, format: fmt).image { r in
            draw(r.cgContext)
        }
    }

    private func gradientTexture(top: UIColor, bottom: UIColor, w: Int = 8, h: Int = 256) -> SKTexture {
        let img = UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { r in
            let ctx = r.cgContext
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: h), options: [])
        }
        return SKTexture(image: img)
    }

    private func buildScene() {
        addChild(world)

        // sky
        sky = SKSpriteNode(texture: gradientTexture(top: UIColor(red: 0.4, green: 0.72, blue: 1, alpha: 1),
                                                    bottom: UIColor(red: 0.75, green: 0.92, blue: 1, alpha: 1)),
                           size: CGSize(width: 390, height: 404))
        sky.anchorPoint = .zero
        sky.position = CGPoint(x: 0, y: 440)
        world.addChild(sky)

        // sun
        let sun = SKSpriteNode(texture: texCircle, size: CGSize(width: 90, height: 90))
        sun.position = CGPoint(x: 330, y: 740)
        sun.color = UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1)
        sun.colorBlendFactor = 1
        world.addChild(sun)

        // sea
        sea = SKSpriteNode(texture: gradientTexture(top: UIColor(red: 0.1, green: 0.5, blue: 0.8, alpha: 1),
                                                    bottom: UIColor(red: 0.0, green: 0.22, blue: 0.5, alpha: 1)),
                           size: CGSize(width: 390, height: 440))
        sea.anchorPoint = .zero
        sea.position = .zero
        world.addChild(sea)

        // waves line
        waveLine = SKShapeNode()
        waveLine.strokeColor = UIColor(white: 1, alpha: 0.8)
        waveLine.lineWidth = 3
        waveLine.glowWidth = 6
        waveLine.zPosition = 3
        world.addChild(waveLine)

        // sparkles on water
        for _ in 0..<14 {
            let sp = SKSpriteNode(texture: texCircle, size: CGSize(width: 6, height: 6))
            sp.color = .white
            sp.colorBlendFactor = 1
            sp.alpha = 0.5
            sp.position = CGPoint(x: CGFloat.random(in: 10...380), y: CGFloat.random(in: 60...420))
            sp.run(.repeatForever(.sequence([.fadeAlpha(to: 0.1, duration: Double.random(in: 0.8...2)),
                                             .fadeAlpha(to: 0.7, duration: Double.random(in: 0.8...2))])))
            world.addChild(sp)
        }

        // rod (simple angled stick — bends with line tension during battle)
        rodNode = SKShapeNode(rectOf: CGSize(width: 5, height: 110), cornerRadius: 2)
        rodNode.fillColor = UIColor(red: 0.35, green: 0.2, blue: 0.1, alpha: 1)
        rodNode.strokeColor = .clear
        rodNode.position = CGPoint(x: 48, y: 95)
        rodNode.zRotation = 0.5
        rodNode.zPosition = 6
        world.addChild(rodNode)

        // fish shadow
        shadow = SKShapeNode(ellipseOf: CGSize(width: 70, height: 22))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.3)
        shadow.strokeColor = .clear
        shadow.alpha = 0
        shadow.zPosition = 2
        world.addChild(shadow)

        // line from rod tip to bobber
        lineShape = SKShapeNode()
        lineShape.strokeColor = UIColor(white: 1, alpha: 0.85)
        lineShape.lineWidth = 1.2
        lineShape.zPosition = 7
        world.addChild(lineShape)

        // bobber
        bobber = SKNode()
        let bBot = SKShapeNode(circleOfRadius: 7)
        bBot.fillColor = .white
        bBot.strokeColor = .clear
        bBot.position = CGPoint(x: 0, y: -4)
        let bTop = SKShapeNode(circleOfRadius: 6)
        bTop.fillColor = .red
        bTop.strokeColor = .clear
        bTop.position = CGPoint(x: 0, y: 5)
        let stem = SKShapeNode(rectOf: CGSize(width: 2, height: 12))
        stem.fillColor = .darkGray
        stem.strokeColor = .clear
        stem.position = CGPoint(x: 0, y: 12)
        bobber.addChild(bBot); bobber.addChild(bTop); bobber.addChild(stem)
        bobber.position = bobberPos
        bobber.alpha = 0
        bobber.zPosition = 8
        world.addChild(bobber)

        // fx layer above everything
        fxLayer.zPosition = 20
        world.addChild(fxLayer)

        // rush tint
        rushTint = SKSpriteNode(color: UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1), size: CGSize(width: 390, height: 844))
        rushTint.anchorPoint = .zero
        rushTint.alpha = 0
        rushTint.blendMode = .add
        rushTint.zPosition = 15
        world.addChild(rushTint)

        // embers for rush
        embers = SKEmitterNode()
        embers.particleTexture = texStar
        embers.particleBirthRate = 6
        embers.particleLifetime = 3.5
        embers.particleSpeed = 40
        embers.particleSpeedRange = 20
        embers.emissionAngle = .pi / 2
        embers.emissionAngleRange = 0.6
        embers.particleScale = 0.12
        embers.particleScaleRange = 0.1
        embers.particleAlpha = 0.8
        embers.particleColor = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        embers.particleColorBlendFactor = 1
        embers.particleBlendMode = .add
        embers.particlePositionRange = CGVector(dx: 390, dy: 0)
        embers.position = CGPoint(x: 195, y: 0)
        embers.zPosition = 16
        embers.particleBirthRate = 0
        world.addChild(embers)

        // camera
        cam = SKCameraNode()
        addChild(cam)
        cam.position = CGPoint(x: 195, y: 422)
        camera = cam
    }

    // MARK: update

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate == 0 ? 1.0 / 60 : min(0.05, currentTime - lastUpdate)
        lastUpdate = currentTime
        t += dt
        logic?.tick(dt)

        // wave line
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 440))
        var x: CGFloat = 0
        while x <= 390 {
            let y = 440 + sin(Double(x) * 0.03 + t * 2.2) * 5 + sin(Double(x) * 0.011 + t * 1.3) * 3
            path.addLine(to: CGPoint(x: x, y: y))
            x += 10
        }
        waveLine.path = path

        // bobber bob + dip spring
        dipVel += -dipOffset * 140 * dt - dipVel * 8 * dt
        dipOffset += dipVel * dt
        let submerge = fightMode ? (logic?.tension ?? 0) * 10 : 0
        bobber.position.y = bobberPos.y + CGFloat(sin(t * 3) * 2.5) - CGFloat(dipOffset) - CGFloat(submerge)
        bobber.zRotation = fightMode ? CGFloat((logic?.tension ?? 0) * 0.4) * (t * 8).truncatingRemainder(dividingBy: 2) - 0.2 : 0
        // rod bends as the battle heats up
        let targetBend = fightMode ? 0.5 - CGFloat(logic?.tension ?? 0) * 0.55 : 0.5
        rodNode.zRotation += (targetBend - rodNode.zRotation) * CGFloat(min(1, dt * 5))

        // orbit shadow
        if orbitVisible {
            orbitAngle += orbitSpeed * dt
            shadow.alpha = min(0.85, shadow.alpha + dt * 2)
            if fightMode {
                // fish runs side to side
                let pull = sin(t * 1.7) * 120 + sin(t * 4.3) * 30
                shadow.position = CGPoint(x: bobber.position.x + pull, y: bobber.position.y - 60 - CGFloat(sin(t * 2.3) * 25))
            } else {
                shadow.position = CGPoint(
                    x: bobber.position.x + CGFloat(cos(orbitAngle) * orbitRadius),
                    y: bobber.position.y - 55 + CGFloat(sin(orbitAngle) * orbitRadius * 0.35))
            }
            shadow.xScale = CGFloat(shadowScale) * (1 + 0.06 * sin(t * 7))
            shadow.yScale = CGFloat(shadowScale)
        } else {
            shadow.alpha = max(0, shadow.alpha - dt * 3)
        }

        // line
        let lp = CGMutablePath()
        lp.move(to: rodTip)
        let sag: CGFloat = fightMode ? -6 : 10
        lp.addQuadCurve(to: bobber.position, control: CGPoint(
            x: (rodTip.x + bobber.position.x) / 2, y: max(rodTip.y, bobber.position.y) + sag))
        lineShape.path = lp
        lineShape.alpha = bobber.alpha

        // camera zoom toward bobber + shake
        let targetScale = 1.0 / zoomLevel
        let zt = CGPoint(x: 195 + (bobber.position.x - 195) * min(1, (zoomLevel - 1) * 1.2),
                         y: 422 + (bobber.position.y - 422) * min(1, (zoomLevel - 1) * 1.2))
        cam.position.x += (zt.x - cam.position.x) * CGFloat(min(1, dt * 6))
        cam.position.y += (zt.y - cam.position.y) * CGFloat(min(1, dt * 6))
        cam.xScale += CGFloat(targetScale - cam.xScale) * min(1, dt * 4)
        cam.yScale = cam.xScale
        if shakeMag > 0.05 {
            cam.position.x += CGFloat.random(in: -1...1) * CGFloat(shakeMag)
            cam.position.y += CGFloat.random(in: -1...1) * CGFloat(shakeMag)
            shakeMag *= pow(0.02, dt)
        }

        // rush tint pulse
        if rushTint.alpha > 0.01 {
            rushTint.alpha = 0.10 + 0.06 * sin(t * 4)
        }

        // speed lines drift + rainbow hue cycling
        if let sn = speedNode, sn.alpha > 0.01 {
            sn.zRotation += dt * 0.22
            if speedMode == 4 {
                speedHue = (speedHue + dt * 0.4).truncatingRemainder(dividingBy: 1)
                for (i, child) in sn.children.enumerated() {
                    (child as? SKSpriteNode)?.color = UIColor(
                        hue: (speedHue + Double(i) * 0.11).truncatingRemainder(dividingBy: 1),
                        saturation: 0.85, brightness: 1, alpha: 1)
                }
            }
        }

        // fish shadow aura follows + breathes
        if let aura = auraSprite {
            if auraMode > 0 && shadow.alpha > 0.05 {
                aura.position = shadow.position
                aura.size = CGSize(width: 175 * shadow.xScale, height: 55 * shadow.yScale)
                aura.alpha = shadow.alpha * CGFloat(0.4 + 0.18 * sin(t * 9))
                if auraMode == 4 {
                    auraHue = (auraHue + dt * 0.5).truncatingRemainder(dividingBy: 1)
                    aura.color = UIColor(hue: auraHue, saturation: 0.95, brightness: 1, alpha: 1)
                }
            } else {
                aura.alpha = 0
            }
        }
    }

    // MARK: touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let wasMash = logic?.phase == .mash
        let loc = touches.first?.location(in: self) ?? .zero
        logic?.tapScreen()
        if wasMash { tapRipple(at: loc) }
    }

    // MARK: GameFX

    func resetScene() {
        bobber.alpha = 0
        orbitVisible = false
        fightMode = false
        shadow.alpha = 0
        lineShape.alpha = 0
        bobber.zRotation = 0
        setSpeedLines(0)
        setAura(0)
    }

    func castLure(power: Double) {
        bobber.alpha = 1
        lineShape.alpha = 1
        bobberPos = CGPoint(x: 195 + CGFloat.random(in: -50...50),
                            y: 320 + CGFloat(90 * power))
        let path = UIBezierPath()
        path.move(to: rodTip)
        path.addQuadCurve(to: bobberPos, controlPoint: CGPoint(x: 195, y: bobberPos.y + 260 * power))
        let cg = CGMutablePath()
        cg.addPath(path.cgPath.copy(strokingWithWidth: 1, lineCap: .round, lineJoin: .round, miterLimit: 1))
        bobber.position = rodTip
        bobber.removeAllActions()
        bobber.run(.follow(path.cgPath, asOffset: false, orientToPath: false, duration: 0.45))
    }

    func lureLanded() {
        bobber.position = bobberPos
    }

    func bobberDip(strength: Double) {
        dipVel += 60 * strength
        splashFX(big: strength > 0.7)
    }

    func setOrbit(speed: Double, radius: Double, visible: Bool) {
        orbitSpeed = speed
        orbitRadius = radius
        orbitVisible = visible
    }

    func shadowSize(_ s: Double) {
        shadowScale = 0.35 + s * 0.9
    }

    func zoomTo(_ level: Double) {
        zoomLevel = level
    }

    func shake(_ magnitude: Double) {
        shakeMag = magnitude
    }

    func splashFX(big: Bool) {
        burst(texture: texCircle, at: CGPoint(x: bobber.position.x, y: 442),
              count: big ? 22 : 10, color: .white, speed: big ? 220 : 120,
              life: 0.6, scale: 0.35, spread: .pi, angle: .pi / 2, blend: .alpha)
        // ripple
        let ring = SKShapeNode(circleOfRadius: 6)
        ring.strokeColor = UIColor(white: 1, alpha: 0.9)
        ring.lineWidth = 2
        ring.position = CGPoint(x: bobber.position.x, y: 442)
        ring.zPosition = 19
        fxLayer.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: big ? 9 : 5, duration: 0.7), .fadeOut(withDuration: 0.7)]),
            .removeFromParent()
        ]))
    }

    func sparkleBurst(color: UIColorCompat) {
        burst(texture: texStar, at: bobber.position, count: 26, color: color,
              speed: 200, life: 0.9, scale: 0.28, spread: .pi * 2, angle: .pi / 2, blend: .add)
    }

    func coinRain(_ n: Int) {
        let e = emitter(texture: texCoin, count: n, color: .white, speed: 260, life: 1.8,
                        scale: 0.5, spread: .pi / 2, angle: -.pi / 2, blend: .alpha)
        e.position = CGPoint(x: 195, y: 844)
        e.particlePositionRange = CGVector(dx: 300, dy: 0)
        e.particleRotationSpeed = 6
        e.particleRotationRange = .pi
        fxLayer.addChild(e)
        e.run(.sequence([.wait(forDuration: 2.2), .removeFromParent()]))
        for i in 0..<min(6, n / 4) {
            e.run(.sequence([.wait(forDuration: Double(i) * 0.12),
                             .run { SoundEngine.shared.play("coin") }]))
        }
    }

    func hookLunge() {
        orbitVisible = false
        shadow.position = CGPoint(x: bobber.position.x, y: bobber.position.y - 50)
        shadow.alpha = 0.9
        shadow.run(.sequence([
            .group([.moveBy(x: 0, y: 20, duration: 0.12), .scale(to: CGFloat(shadowScale * 1.4), duration: 0.12)]),
            .scale(to: CGFloat(shadowScale), duration: 0.3)
        ]))
        dipVel += 90
    }

    func lineSnap() {
        // the snapped line recoils — flicker, whip, sparks at the break
        lineShape.strokeColor = UIColor(white: 1, alpha: 0.9)
        lineShape.run(.sequence([
            .repeat(.sequence([
                .fadeAlpha(to: 0.15, duration: 0.04),
                .fadeAlpha(to: 0.9, duration: 0.04)
            ]), count: 3),
            .fadeOut(withDuration: 0.12)
        ]))
        bobber.run(.sequence([
            .group([
                .moveBy(x: Bool.random() ? -170 : 170, y: 0, duration: 0.18),
                .fadeAlpha(to: 0, duration: 0.18)
            ]),
            .run { [weak self] in self?.bobber.alpha = 0 }
        ]))
        burst(texture: texStar, at: bobber.position, count: 16, color: .white,
              speed: 220, life: 0.5, scale: 0.3, spread: .pi * 2, angle: 0, blend: .add)
        shockwave(big: false)
    }

    func setFightLook(struggling: Bool) {
        fightMode = struggling
        if struggling {
            orbitVisible = true
            shadow.alpha = 0.9
        }
    }

    func setRushLook(_ on: Bool) {
        rushTint.run(.fadeAlpha(to: on ? 0.12 : 0, duration: 0.8))
        embers.particleBirthRate = on ? 8 : 0
        let target = on ? UIColor(red: 0.9, green: 0.55, blue: 0.2, alpha: 1) : UIColor(red: 0.4, green: 0.72, blue: 1, alpha: 1)
        sky.texture = gradientTexture(top: target, bottom: on ? UIColor(red: 1, green: 0.85, blue: 0.5, alpha: 1) : UIColor(red: 0.75, green: 0.92, blue: 1, alpha: 1))
    }

    // MARK: 予告演出 (teasers)

    private var cloudTint: SKSpriteNode!
    private var rainTint: SKSpriteNode!
    private var rainEmit: SKEmitterNode!

    private func ensureWeatherNodes() {
        if cloudTint == nil {
            cloudTint = SKSpriteNode(color: UIColor(white: 0.25, alpha: 1), size: CGSize(width: 390, height: 844))
            cloudTint.anchorPoint = .zero
            cloudTint.alpha = 0
            cloudTint.zPosition = 12
            world.addChild(cloudTint)
        }
        if rainTint == nil {
            rainTint = SKSpriteNode(color: UIColor(red: 0.15, green: 0.2, blue: 0.3, alpha: 1), size: CGSize(width: 390, height: 844))
            rainTint.anchorPoint = .zero
            rainTint.alpha = 0
            rainTint.zPosition = 13
            world.addChild(rainTint)
            rainEmit = SKEmitterNode()
            rainEmit.particleTexture = texCircle
            rainEmit.particleBirthRate = 160
            rainEmit.particleLifetime = 1.1
            rainEmit.particleSpeed = 500
            rainEmit.particleSpeedRange = 100
            rainEmit.emissionAngle = -.pi / 2 - 0.15
            rainEmit.emissionAngleRange = 0.08
            rainEmit.particleScale = 0.10
            rainEmit.particleScaleRange = 0.04
            rainEmit.yScale = 7
            rainEmit.particleAlpha = 0.5
            rainEmit.particleColor = UIColor(white: 0.85, alpha: 1)
            rainEmit.particleColorBlendFactor = 1
            rainEmit.particlePositionRange = CGVector(dx: 480, dy: 0)
            rainEmit.position = CGPoint(x: 165, y: 844)
            rainEmit.zPosition = 14
            rainEmit.particleBirthRate = 0
            world.addChild(rainEmit)
        }
    }

    private func fishNode(color: UIColor) -> SKShapeNode {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: -10, y: 0))
        p.addQuadCurve(to: CGPoint(x: 8, y: 0), controlPoint: CGPoint(x: -2, y: 7))
        p.addQuadCurve(to: CGPoint(x: -10, y: 0), controlPoint: CGPoint(x: -2, y: -7))
        p.addLine(to: CGPoint(x: -15, y: 5))
        p.addLine(to: CGPoint(x: -15, y: -5))
        p.close()
        let n = SKShapeNode(path: p.cgPath)
        n.fillColor = color
        n.strokeColor = .clear
        return n
    }

    private func birdNode(golden: Bool) -> SKShapeNode {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: -7, y: 0))
        p.addQuadCurve(to: CGPoint(x: 0, y: 3), controlPoint: CGPoint(x: -3.5, y: 6))
        p.addQuadCurve(to: CGPoint(x: 7, y: 0), controlPoint: CGPoint(x: 3.5, y: 6))
        let n = SKShapeNode(path: p.cgPath)
        n.strokeColor = golden ? UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1) : UIColor(white: 0.2, alpha: 0.9)
        n.lineWidth = golden ? 3 : 2
        n.fillColor = .clear
        n.glowWidth = golden ? 8 : 0
        return n
    }

    func teaserFishJump() {
        let x = CGFloat.random(in: 60...330)
        let y: CGFloat = 442
        let fish = fishNode(color: UIColor(red: 0.5, green: 0.7, blue: 0.9, alpha: 1))
        fish.position = CGPoint(x: x, y: y)
        fish.zPosition = 9
        fish.alpha = 0
        world.addChild(fish)
        let h = CGFloat.random(in: 60...110)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x, y: y))
        path.addQuadCurve(to: CGPoint(x: x + 30, y: y), controlPoint: CGPoint(x: x + 15, y: y + h * 2))
        fish.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.05),
            .group([
                .follow(path.cgPath, asOffset: false, orientToPath: true, duration: 0.75),
                .sequence([.wait(forDuration: 0.55), .fadeOut(withDuration: 0.2)])
            ]),
            .removeFromParent(),
            .run { [weak self] in self?.miniSplash(at: CGPoint(x: x + 30, y: y)) }
        ]))
    }

    private func miniSplash(at p: CGPoint) {
        burst(texture: texCircle, at: p, count: 6, color: .white, speed: 90,
              life: 0.4, scale: 0.22, spread: .pi, angle: .pi / 2, blend: .alpha)
    }

    func teaserBirds(count: Int, golden: Bool) {
        let flock = SKNode()
        flock.zPosition = 5
        world.addChild(flock)
        let baseY = CGFloat.random(in: 560...740)
        for i in 0..<count {
            let b = birdNode(golden: golden)
            let col = i % 2 == 0 ? -1 : 1
            let row = abs(i - 1) / 2 + 1
            b.position = CGPoint(x: -CGFloat(row) * 26, y: CGFloat(col) * CGFloat(row) * 14)
            b.xScale = 1.3; b.yScale = 1.3
            flock.addChild(b)
            b.run(.repeatForever(.sequence([
                .scaleY(to: 0.9, duration: 0.28),
                .scaleY(to: 1.3, duration: 0.28)
            ])))
        }
        flock.position = CGPoint(x: -60, y: baseY)
        let dur = golden ? 7.0 : 5.0
        flock.run(.sequence([
            .moveTo(x: 500, duration: dur),
            .removeFromParent()
        ]))
        if golden {
            // golden bird leaves a sparkle trail — the premium teaser
            let trail = SKEmitterNode()
            trail.particleTexture = texStar
            trail.particleBirthRate = 40
            trail.particleLifetime = 0.8
            trail.particleSpeed = 0
            trail.particleScale = 0.35
            trail.particleScaleSpeed = -0.4
            trail.particleAlpha = 0.9
            trail.particleAlphaSpeed = -1.1
            trail.particleColor = .systemYellow
            trail.particleColorBlendFactor = 1
            trail.particleBlendMode = .add
            trail.position = CGPoint(x: -20, y: 0)
            flock.addChild(trail)
        }
    }

    func teaserRainbow() {
        let g = SKNode()
        g.position = CGPoint(x: 90, y: 445)
        g.zPosition = 4
        g.alpha = 0
        world.addChild(g)
        let colors: [UIColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue]
        for (i, c) in colors.enumerated() {
            let r = 170 - CGFloat(i) * 10
            let arc = UIBezierPath(arcCenter: .zero, radius: r,
                                   startAngle: 0.15, endAngle: .pi - 0.15, clockwise: true)
            let n = SKShapeNode(path: arc.cgPath)
            n.strokeColor = c.withAlphaComponent(0.75)
            n.lineWidth = 9
            n.lineCap = .round
            g.addChild(n)
        }
        g.run(.sequence([
            .fadeAlpha(to: 1, duration: 1.2),
            .wait(forDuration: 3.0),
            .fadeAlpha(to: 0, duration: 1.2),
            .removeFromParent()
        ]))
    }

    func teaserRain(_ on: Bool) {
        ensureWeatherNodes()
        rainEmit.particleBirthRate = on ? 160 : 0
        rainTint.run(.fadeAlpha(to: on ? 0.25 : 0, duration: 0.8))
    }

    func teaserCloud(_ on: Bool) {
        ensureWeatherNodes()
        cloudTint.run(.fadeAlpha(to: on ? 0.3 : 0, duration: 1.2))
    }

    func teaserBoat() {
        let boat = SKNode()
        boat.zPosition = 2.5
        let hull = SKShapeNode(rectOf: CGSize(width: 46, height: 10), cornerRadius: 3)
        hull.fillColor = UIColor(white: 0.15, alpha: 0.75)
        hull.strokeColor = .clear
        let cabin = SKShapeNode(rectOf: CGSize(width: 16, height: 12))
        cabin.fillColor = UIColor(white: 0.2, alpha: 0.75)
        cabin.strokeColor = .clear
        cabin.position = CGPoint(x: -8, y: 10)
        boat.addChild(hull); boat.addChild(cabin)
        let fromLeft = Bool.random()
        boat.position = CGPoint(x: fromLeft ? -40 : 430, y: 446)
        world.addChild(boat)
        boat.run(.sequence([
            .moveTo(x: fromLeft ? 430 : -40, duration: 9),
            .removeFromParent()
        ]))
    }

    func teaserSchool() {
        for i in 0..<6 {
            let f = SKShapeNode(ellipseOf: CGSize(width: 16, height: 6))
            f.fillColor = UIColor.black.withAlphaComponent(0.25)
            f.strokeColor = .clear
            f.zPosition = 2
            let y = CGFloat.random(in: 250...400)
            f.position = CGPoint(x: -20 - CGFloat(i) * 22, y: y)
            world.addChild(f)
            f.run(.sequence([
                .wait(forDuration: Double(i) * 0.12),
                .group([
                    .moveTo(x: 450, duration: Double.random(in: 1.0...1.6)),
                    .sequence([.wait(forDuration: 1.0), .fadeOut(withDuration: 0.4)])
                ]),
                .removeFromParent()
            ]))
        }
    }

    func teaserWaterGlow() {
        let e = emitter(texture: texStar, count: 30, color: UIColor(red: 0.6, green: 0.95, blue: 1, alpha: 1),
                        speed: 14, life: 1.6, scale: 0.3, spread: .pi * 2, angle: .pi / 2, blend: .add)
        e.position = CGPoint(x: 195, y: 430)
        e.particlePositionRange = CGVector(dx: 240, dy: 60)
        e.particleBirthRate = 24
        e.numParticlesToEmit = 60
        world.addChild(e)
        e.run(.sequence([.wait(forDuration: 3), .removeFromParent()]))
    }

    // MARK: 派手演出 (showtime fx)

    /// 集中線 — radiating speed lines streaming toward center.
    /// mode: 0 off / 1 white / 2 red / 3 gold / 4 rainbow-cycle
    func setSpeedLines(_ mode: Int) {
        speedMode = mode
        if mode == 0 {
            speedNode?.run(.fadeOut(withDuration: 0.25), withKey: "speedFade")
            return
        }
        ensureSpeedLines()
        guard let n = speedNode else { return }
        let col: UIColor = [UIColor.white, UIColor.white, .systemRed, .systemYellow, .white][mode]
        for child in n.children { (child as? SKSpriteNode)?.color = col }
        n.run(.fadeAlpha(to: 1, duration: 0.25), withKey: "speedFade")
    }

    private func ensureSpeedLines() {
        guard speedNode == nil else { return }
        let n = SKNode()
        n.position = CGPoint(x: 195, y: 430)
        n.zPosition = 18
        n.alpha = 0
        for i in 0..<26 {
            let a = Double(i) / 26 * .pi * 2 + Double.random(in: -0.08...0.08)
            let r0 = CGFloat.random(in: 380...570)
            let b = SKSpriteNode(texture: texBeam,
                                 size: CGSize(width: CGFloat.random(in: 150...270),
                                              height: CGFloat.random(in: 6...13)))
            b.color = .white
            b.colorBlendFactor = 1
            b.blendMode = .add
            b.alpha = 0
            let dir = CGVector(dx: cos(a), dy: sin(a))
            b.position = CGPoint(x: dir.dx * r0, y: dir.dy * r0)
            b.zRotation = a + .pi
            let travel = CGFloat.random(in: 130...250)
            let dur = Double.random(in: 0.35...0.7)
            let peak = CGFloat.random(in: 0.45...0.85)
            b.run(.repeatForever(.sequence([
                .group([
                    .moveBy(x: -dir.dx * travel, y: -dir.dy * travel, duration: dur),
                    .sequence([
                        .fadeAlpha(to: peak, duration: dur * 0.3),
                        .fadeAlpha(to: 0, duration: dur * 0.7)
                    ])
                ]),
                .moveBy(x: dir.dx * travel, y: dir.dy * travel, duration: 0),
                .wait(forDuration: Double.random(in: 0...0.35))
            ])))
            n.addChild(b)
        }
        world.addChild(n)
        speedNode = n
    }

    /// 魚影オーラ — burning silhouette. mode: 0 off / 1 white / 2 red / 3 gold / 4 rainbow
    func setAura(_ mode: Int) {
        auraMode = mode
        if mode == 0 {
            auraSprite?.run(.fadeOut(withDuration: 0.3), withKey: "auraFade")
            return
        }
        ensureAura()
        let cols: [UIColor] = [.white, .white, .systemRed, .systemYellow, .white]
        auraSprite?.color = cols[mode]
    }

    private func ensureAura() {
        guard auraSprite == nil else { return }
        let a = SKSpriteNode(texture: texCircle, size: CGSize(width: 100, height: 40))
        a.color = .white
        a.colorBlendFactor = 1
        a.blendMode = .add
        a.alpha = 0
        a.zPosition = 2.1
        world.addChild(a)
        auraSprite = a
    }

    /// 稲妻 — jagged bolt from the sky down to the bobber, flickering
    func lightningFX() {
        let end = CGPoint(x: bobber.position.x + CGFloat.random(in: -30...30),
                          y: bobber.position.y + 12)
        let start = CGPoint(x: end.x + CGFloat.random(in: -130...130), y: 880)
        var pts: [CGPoint] = [start]
        let segs = 9
        for i in 1...segs {
            let f = CGFloat(i) / CGFloat(segs)
            pts.append(CGPoint(
                x: start.x + (end.x - start.x) * f + (i == segs ? 0 : CGFloat.random(in: -26...26)),
                y: start.y + (end.y - start.y) * f))
        }
        var branches: [[CGPoint]] = []
        for _ in 0..<Int.random(in: 1...3) {
            var cur = pts[Int.random(in: 3...6)]
            var bp: [CGPoint] = [cur]
            let dx: CGFloat = Bool.random() ? -1 : 1
            for _ in 0..<3 {
                cur = CGPoint(x: cur.x + dx * CGFloat.random(in: 15...42),
                              y: cur.y - CGFloat.random(in: 20...50))
                bp.append(cur)
            }
            branches.append(bp)
        }
        let img = drawImageRect(size: CGSize(width: 390, height: 844)) { ctx in
            func imgPath(_ pts: [CGPoint]) -> CGPath {
                let p = UIBezierPath()
                p.move(to: CGPoint(x: pts[0].x, y: 844 - pts[0].y))
                for pt in pts.dropFirst() {
                    p.addLine(to: CGPoint(x: pt.x, y: 844 - pt.y))
                }
                return p.cgPath
            }
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            let main = imgPath(pts)
            for (w, a) in [(CGFloat(9), CGFloat(0.18)), (CGFloat(4.5), CGFloat(0.42)), (CGFloat(1.6), CGFloat(1))] {
                ctx.setStrokeColor(UIColor(red: 1, green: 1, blue: 0.85, alpha: a).cgColor)
                ctx.setLineWidth(w)
                ctx.addPath(main)
                for b in branches { ctx.addPath(imgPath(b)) }
                ctx.strokePath()
            }
        }
        let bolt = SKSpriteNode(texture: SKTexture(image: img), size: CGSize(width: 390, height: 844))
        bolt.anchorPoint = .zero
        bolt.position = .zero
        bolt.zPosition = 19
        bolt.blendMode = .add
        fxLayer.addChild(bolt)
        bolt.run(.sequence([
            .fadeAlpha(to: 0.15, duration: 0.05),
            .fadeAlpha(to: 1, duration: 0.04),
            .fadeAlpha(to: 0.3, duration: 0.06),
            .fadeAlpha(to: 0.95, duration: 0.04),
            .fadeAlpha(to: 0, duration: 0.38),
            .removeFromParent()
        ]))
        // strike flash on the water
        burst(texture: texCircle, at: CGPoint(x: end.x, y: 445), count: 14,
              color: UIColor(red: 1, green: 1, blue: 0.85, alpha: 1),
              speed: 240, life: 0.45, scale: 0.4, spread: .pi, angle: .pi / 2, blend: .add)
    }

    /// 光の柱 — beam column rising from the sea
    func lightPillar(color: UIColorCompat) {
        let beam = SKSpriteNode(texture: texPillar, size: CGSize(width: 140, height: 430))
        beam.anchorPoint = CGPoint(x: 0.5, y: 0)
        beam.position = CGPoint(x: bobber.position.x, y: 442)
        beam.color = color
        beam.colorBlendFactor = 0.85
        beam.blendMode = .add
        beam.zPosition = 19
        beam.alpha = 0
        beam.yScale = 0.05
        fxLayer.addChild(beam)
        beam.run(.sequence([
            .group([
                .fadeAlpha(to: 1, duration: 0.09),
                .sequence([
                    .scaleY(to: 1.18, duration: 0.14),
                    .scaleY(to: 1, duration: 0.12)
                ])
            ]),
            .wait(forDuration: 0.55),
            .fadeOut(withDuration: 0.4),
            .removeFromParent()
        ]))
        // rising motes inside the pillar
        let motes = emitter(texture: texStar, count: 22, color: color, speed: 300, life: 0.9,
                            scale: 0.3, spread: 0.25, angle: .pi / 2, blend: .add)
        motes.position = CGPoint(x: bobber.position.x, y: 450)
        motes.particlePositionRange = CGVector(dx: 90, dy: 0)
        fxLayer.addChild(motes)
        motes.run(.sequence([.wait(forDuration: 1.3), .removeFromParent()]))
    }

    /// 衝撃波リング — expanding rings, big = triple wave
    func shockwave(big: Bool) {
        let at = CGPoint(x: bobber.position.x, y: max(445, bobber.position.y))
        for i in 0..<(big ? 3 : 1) {
            let ring = SKShapeNode(circleOfRadius: 10)
            ring.strokeColor = UIColor(white: 1, alpha: 0.95)
            ring.fillColor = .clear
            ring.lineWidth = big ? 5 : 3
            ring.glowWidth = big ? 10 : 5
            ring.position = at
            ring.zPosition = 21
            fxLayer.addChild(ring)
            ring.run(.sequence([
                .wait(forDuration: Double(i) * 0.09),
                .group([
                    .scale(to: big ? 16 : 9, duration: 0.5),
                    .fadeOut(withDuration: 0.5)
                ]),
                .removeFromParent()
            ]))
        }
    }

    /// 紙吹雪 — rainbow confetti tumbling down
    func confettiRain(_ n: Int) {
        let colors: [UIColor] = [.systemRed, .systemYellow, .systemGreen, .cyan, .systemPink, .orange]
        for (i, c) in colors.enumerated() {
            let e = emitter(texture: texRect, count: max(4, n / 6), color: c, speed: 210, life: 2.5,
                            scale: 0.55, spread: 0.55, angle: -.pi / 2, blend: .alpha)
            e.position = CGPoint(x: 55 + CGFloat(i) * 56, y: 850)
            e.particlePositionRange = CGVector(dx: 100, dy: 0)
            e.particleRotationSpeed = 7
            e.particleRotationRange = .pi
            e.particleAlphaSpeed = -0.25
            e.particleScaleSpeed = 0
            fxLayer.addChild(e)
            e.run(.sequence([.wait(forDuration: 3.4), .removeFromParent()]))
        }
    }

    /// 星のシャワー — golden stars pouring with the coins
    func starShower(_ n: Int) {
        let e = emitter(texture: texStar, count: n, color: UIColor(red: 1, green: 0.95, blue: 0.6, alpha: 1),
                        speed: 330, life: 1.7, scale: 0.45, spread: .pi / 3, angle: -.pi / 2, blend: .add)
        e.position = CGPoint(x: 195, y: 845)
        e.particlePositionRange = CGVector(dx: 370, dy: 0)
        e.particleRotationSpeed = 5
        fxLayer.addChild(e)
        e.run(.sequence([.wait(forDuration: 2.4), .removeFromParent()]))
    }

    /// 連打タップの波紋
    private func tapRipple(at p: CGPoint) {
        let ring = SKShapeNode(circleOfRadius: 5)
        ring.strokeColor = UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 0.9)
        ring.fillColor = .clear
        ring.lineWidth = 2.5
        ring.glowWidth = 4
        ring.position = p
        ring.zPosition = 22
        fxLayer.addChild(ring)
        ring.run(.sequence([
            .group([
                .scale(to: 4.5, duration: 0.28),
                .fadeOut(withDuration: 0.28)
            ]),
            .removeFromParent()
        ]))
        burst(texture: texStar, at: p, count: 5, color: .systemYellow,
              speed: 130, life: 0.35, scale: 0.18, spread: .pi * 2, angle: .pi / 2, blend: .add)
    }

    // MARK: emitters

    private func burst(texture: SKTexture, at p: CGPoint, count: Int, color: UIColor,
                       speed: Double, life: Double, scale: Double, spread: Double,
                       angle: Double, blend: SKBlendMode) {
        let e = emitter(texture: texture, count: count, color: color, speed: speed, life: life,
                        scale: scale, spread: spread, angle: angle, blend: blend)
        e.position = p
        fxLayer.addChild(e)
        e.run(.sequence([.wait(forDuration: life + 0.4), .removeFromParent()]))
    }

    private func emitter(texture: SKTexture, count: Int, color: UIColor, speed: Double,
                         life: Double, scale: Double, spread: Double, angle: Double,
                         blend: SKBlendMode) -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = texture
        e.particleBirthRate = 1200
        e.numParticlesToEmit = count
        e.particleLifetime = life
        e.particleLifetimeRange = life * 0.4
        e.particleSpeed = speed
        e.particleSpeedRange = speed * 0.5
        e.emissionAngle = angle
        e.emissionAngleRange = spread
        e.particleScale = scale
        e.particleScaleRange = scale * 0.6
        e.particleScaleSpeed = -scale * 0.4
        e.particleAlpha = 1
        e.particleAlphaSpeed = -1 / life
        e.particleColor = color
        e.particleColorBlendFactor = 1
        e.particleBlendMode = blend
        e.particleZPosition = 21
        return e
    }
}
