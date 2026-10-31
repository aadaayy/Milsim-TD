import SpriteKit

/// The battlefield: the map, the positions and the horde, drawn from the game
/// state every frame. The scene also moves the game on, in 60ths of a second
/// times the chosen speed, and turns what happened into effects.
///
/// Scene units: one map tile is `tile` points. The map's rows count down the
/// screen, SpriteKit's y counts up, so `point(_:)` flips them.
final class BattlefieldScene: SKScene {
    static let tile: CGFloat = 64

    private weak var session: GameSession?
    private let game: GameState
    private let level: LevelSpec
    private let sprites: SpriteManifest
    /// Scene points per real meter, so the Blender renders come out true to scale.
    private let pointsPerMeter: CGFloat

    private let ground = SKNode()
    private let actors = SKNode()
    private let effects = SKNode()
    private let overlay = SKNode()

    private var positionNodes: [Int: PositionNode] = [:]
    private var zombieNodes: [Int: ZombieNode] = [:]
    private var slotPads: [SKSpriteNode] = []
    private var commandPostTop: SKSpriteNode?
    private var commandPostBase: SKSpriteNode?
    private var commandPostState = "intact"
    private var selectionNode: SKNode?
    private var drawnSelection: Selection?

    private var lastTime: TimeInterval?
    private var accumulator = 0.0
    /// Game time as the scene has drawn it, for animation frames.
    private var clock = 0.0
    private var atlases: [String: SKTextureAtlas] = [:]
    private var effectFrames: [String: [SKTexture]] = [:]

    init(session: GameSession) {
        self.session = session
        game = session.game
        level = session.level
        sprites = session.content.sprites
        pointsPerMeter = Self.tile / CGFloat(level.tileMeters)
        super.init(size: CGSize(width: CGFloat(level.cols) * Self.tile, height: CGFloat(level.rows) * Self.tile))
        scaleMode = .aspectFit
        anchorPoint = .zero
        backgroundColor = Theme.mapEdgeUI
        for layer in [ground, actors, effects, overlay] { addChild(layer) }
        overlay.zPosition = 50
        effects.zPosition = 500
        buildMap()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("Not used") }

    // MARK: Coordinates and textures

    private func point(_ v: Vec2) -> CGPoint {
        CGPoint(x: CGFloat(v.x) * Self.tile, y: (CGFloat(level.rows) - CGFloat(v.y)) * Self.tile)
    }

    /// A map direction (y down) as a scene direction (y up).
    private func sceneDirection(_ v: Vec2) -> CGVector { CGVector(dx: v.x, dy: -v.y) }

    private func mapPoint(_ p: CGPoint) -> Vec2 {
        Vec2(Double(p.x / Self.tile), Double(level.rows) - Double(p.y / Self.tile))
    }

    /// Nearer the bottom of the screen draws in front.
    private func depth(_ v: Vec2) -> CGFloat { 100 + CGFloat(v.y) }

    private func texture(_ atlas: String, _ name: String) -> SKTexture {
        let a = atlases[atlas] ?? SKTextureAtlas(named: atlas)
        atlases[atlas] = a
        return a.textureNamed(name)
    }

    private func frames(ofEffect name: String) -> [SKTexture] {
        if let cached = effectFrames[name] { return cached }
        let count = sprites.effects[name]?.frames ?? 1
        let textures = (0..<count).map { texture("effects", "\(name)_\($0)") }
        effectFrames[name] = textures
        return textures
    }

    private func meters(_ m: Double) -> CGFloat { CGFloat(m) * pointsPerMeter }

    // MARK: The map

    private func buildMap() {
        var random = SeededRandom(seed: 9)

        // Grass, in big seamless squares.
        let grass = texture("terrain", "grass")
        let square: CGFloat = 256
        var y: CGFloat = 0
        while y < size.height {
            var x: CGFloat = 0
            while x < size.width {
                let node = SKSpriteNode(texture: grass, size: CGSize(width: square + 1, height: square + 1))
                node.anchorPoint = .zero
                node.position = CGPoint(x: x, y: y)
                ground.addChild(node)
                x += square
            }
            y += square
        }

        // The road: overlapping soft patches of dirt along the path.
        let track = game.track
        var d = 0.0
        while d <= track.length + 0.3 {
            let patch = SKSpriteNode(texture: texture("terrain", "dirt_\(1 + Int(random.next() * 2))"))
            let s = Self.tile * CGFloat(random.next(in: 1.15...1.4))
            patch.size = CGSize(width: s, height: s)
            patch.zRotation = CGFloat(random.next() * .pi * 2)
            patch.position = point(track.point(at: d))
            patch.zPosition = 1
            ground.addChild(patch)
            d += 0.3
        }

        // Trampled ground around the Command Post.
        for i in 0..<9 {
            let angle = Double(i) / 9 * .pi * 2
            let spot = level.commandPost + Vec2(cos(angle) * 0.9, sin(angle) * 0.7)
            let patch = SKSpriteNode(texture: texture("terrain", "dirt_\(1 + i % 2)"))
            patch.size = CGSize(width: Self.tile * 1.7, height: Self.tile * 1.7)
            patch.zRotation = CGFloat(random.next() * .pi * 2)
            patch.position = point(spot)
            patch.zPosition = 1
            ground.addChild(patch)
        }

        // Build pads.
        for (i, slot) in game.slots.enumerated() {
            let pad = SKSpriteNode(texture: texture("terrain", "build_pad"))
            pad.size = CGSize(width: Self.tile * 1.2, height: Self.tile * 1.2)
            pad.position = point(slot)
            pad.zPosition = 2
            pad.name = "slot-\(i)"
            ground.addChild(pad)
            slotPads.append(pad)
        }

        // Trees and buildings.
        for row in 0..<level.rows {
            for col in 0..<level.cols {
                let center = Vec2(Double(col) + 0.5, Double(row) + 0.5)
                switch level.tile(col: col, row: row) {
                case .forest:
                    for _ in 0..<2 {
                        let spot = center + Vec2(random.next(in: -0.28...0.28), random.next(in: -0.28...0.28))
                        let tree = SKSpriteNode(texture: texture("terrain", "tree_\(Int(random.next() * 4))"))
                        let s = Self.tile * CGFloat(random.next(in: 0.95...1.25))
                        tree.size = CGSize(width: s, height: s)
                        tree.position = point(spot)
                        tree.zPosition = depth(spot) + 0.4
                        actors.addChild(tree)
                    }
                case .tinRoof, .flatRoof:
                    let tin = level.tile(col: col, row: row) == .tinRoof
                    let roof = SKSpriteNode(texture: texture("terrain", tin ? "roof_tin" : "roof_flat"))
                    roof.size = tin ? CGSize(width: Self.tile * 1.25, height: Self.tile * 1.0)
                                    : CGSize(width: Self.tile * 1.15, height: Self.tile * 1.15)
                    roof.position = point(center)
                    roof.zPosition = depth(center)
                    actors.addChild(roof)
                default:
                    break
                }
            }
        }

        // The Command Post, scaled to fit its three tiles.
        if let cp = sprites.structures["command_post"] {
            let k = min(1, 2.9 * Self.tile / meters(cp.baseM[0]))
            let base = SKSpriteNode(texture: texture(cp.atlas, "\(cp.atlas)_base"))
            base.size = CGSize(width: meters(cp.baseM[0]) * k, height: meters(cp.baseM[1]) * k)
            base.position = point(level.commandPost)
            base.zPosition = depth(level.commandPost)
            let top = SKSpriteNode(texture: texture(cp.atlas, "\(cp.atlas)_n_intact"))
            top.size = CGSize(width: meters(cp.cellM[0]) * k, height: meters(cp.cellM[1]) * k)
            top.position = CGPoint(x: meters(cp.offsetM[0]) * k, y: meters(cp.offsetM[1]) * k)
            top.zPosition = 0.1
            base.addChild(top)
            actors.addChild(base)
            commandPostBase = base
            commandPostTop = top
        }
    }

    // MARK: Frames

    override func update(_ currentTime: TimeInterval) {
        guard let session else { return }
        let real = lastTime.map { min(currentTime - $0, 0.1) } ?? 0
        lastTime = currentTime
        let scale = session.timeScale
        let dt = real * scale
        actors.speed = CGFloat(scale)
        effects.speed = CGFloat(scale)

        accumulator += dt
        let step = 1.0 / 60
        var events: [GameEvent] = []
        while accumulator >= step {
            events += game.tick(step)
            accumulator -= step
        }
        clock += dt
        for event in events { draw(event) }
        syncZombies(dt)
        syncPositions()
        syncCommandPost()
        syncSelection(session.selection)
        session.handle(events)
    }

    /// Plays the game ahead without drawing, for the automatic checks' screenshots.
    func fastForward(seconds: Double) {
        var t = 0.0
        while t < seconds && !game.isOver {
            _ = game.tick(1.0 / 60)
            t += 1.0 / 60
        }
        // Walk the new crowd to a mid-stride frame.
        clock += seconds
    }

    func positionsChanged() {
        drawnSelection = nil
    }

    private func draw(_ event: GameEvent) {
        switch event {
        case .shot(let id, _, _, let to):
            guard let node = positionNodes[id], let p = game.position(id: id) else { return }
            node.lastShot = clock
            let aim = sceneDirection(p.aim)
            let muzzle = CGPoint(x: node.position.x + node.turretOffset.x + aim.dx * Self.tile * 0.42,
                                 y: node.position.y + node.turretOffset.y + aim.dy * Self.tile * 0.42)
            let target = point(to)
            let angle = atan2(aim.dy, aim.dx) - .pi / 2
            play("muzzle_flash", at: muzzle, size: meters(0.75) * 1.3, rotation: angle, z: depth(p.center) + 1)
            shootTracer(from: muzzle, to: target, angle: angle)
            let jitter = CGPoint(x: target.x + CGFloat.random(in: -4...4), y: target.y + CGFloat.random(in: 2...10))
            play("hit_puff", at: jitter, size: meters(0.75) * 1.4, rotation: 0, z: 0)
        case .killed(let id, let type, let at, let heading):
            guard let node = zombieNodes.removeValue(forKey: id) else { return }
            node.die(texture: { self.texture(type, $0) }, sprite: sprites.zombies[type],
                     facing: Facing(fourWay: heading), at: point(at))
        case .breached(let id):
            zombieNodes.removeValue(forKey: id)?.removeFromParent()
            if let base = commandPostBase {
                play("explosion_small", at: CGPoint(x: base.position.x + CGFloat.random(in: -30...30), y: base.position.y + 40),
                     size: meters(2.5) * 0.8, rotation: 0, z: 0)
                let shake = SKAction.sequence([.moveBy(x: 4, y: 0, duration: 0.04), .moveBy(x: -8, y: 0, duration: 0.08),
                                               .moveBy(x: 4, y: 0, duration: 0.04)])
                base.run(shake)
            }
        default:
            break
        }
    }

    private func play(_ effect: String, at position: CGPoint, size: CGFloat, rotation: CGFloat, z: CGFloat) {
        let textures = frames(ofEffect: effect)
        guard let first = textures.first else { return }
        let node = SKSpriteNode(texture: first, size: CGSize(width: size, height: size))
        node.position = position
        node.zRotation = rotation
        node.zPosition = z
        node.blendMode = effect == "muzzle_flash" ? .add : .alpha
        effects.addChild(node)
        let fps = sprites.effects[effect]?.fps ?? 20
        node.run(.sequence([.animate(with: textures, timePerFrame: 1 / max(fps, 1)), .removeFromParent()]))
    }

    private func shootTracer(from: CGPoint, to: CGPoint, angle: CGFloat) {
        let streak = SKSpriteNode(texture: frames(ofEffect: "tracer").first)
        streak.size = CGSize(width: meters(0.125) * 1.6, height: meters(1.25) * 0.8)
        streak.position = from
        streak.zRotation = angle
        streak.zPosition = 2
        streak.blendMode = .add
        effects.addChild(streak)
        let distance = hypot(to.x - from.x, to.y - from.y)
        let time = min(max(Double(distance / (Self.tile * 30)), 0.03), 0.12)
        streak.run(.sequence([.move(to: to, duration: time), .removeFromParent()]))
    }

    private func syncZombies(_ dt: Double) {
        var alive = Set<Int>()
        for zombie in game.zombies {
            alive.insert(zombie.id)
            guard let sprite = sprites.zombies[zombie.type], let spec = game.catalog.zombie(zombie.type) else { continue }
            let node: ZombieNode
            if let existing = zombieNodes[zombie.id] {
                node = existing
            } else {
                node = ZombieNode(size: CGSize(width: meters(sprite.cellM[0] * spec.drawScale),
                                               height: meters(sprite.cellM[1] * spec.drawScale)),
                                  barWidth: Self.tile * 0.5)
                node.walkClock = Double(zombie.id % 7) / 7
                actors.addChild(node)
                zombieNodes[zombie.id] = node
            }
            let at = game.track.position(of: zombie)
            node.position = point(at)
            node.zPosition = depth(at) + 0.3
            node.walkClock += dt * zombie.currentSpeed / max(zombie.speed, 0.01)
            let walk = sprite.anims["walk"]
            let count = walk?.frames ?? 1
            let frame = Int(node.walkClock * (walk?.fps ?? 8)) % max(count, 1)
            let facing = Facing(direction: game.track.direction(at: zombie.distance))
            node.body.texture = texture(sprite.atlas, "\(sprite.atlas)_walk_\(frame)_\(facing.rawValue)")
            node.setHealth(zombie.health / zombie.maxHealth)
        }
        for (id, node) in zombieNodes where !alive.contains(id) {
            node.removeFromParent()
            zombieNodes[id] = nil
        }
    }

    private func syncPositions() {
        var present = Set<Int>()
        for position in game.positions {
            present.insert(position.id)
            guard let level = game.levelSpec(of: position), let sprite = sprites.positions[level.sprite] else { continue }
            var node = positionNodes[position.id]
            if node?.spriteName != level.sprite {
                node?.removeFromParent()
                let made = PositionNode(sprite: sprite, fitting: Self.tile * 1.6, pointsPerMeter: pointsPerMeter,
                                        texture: { self.texture(sprite.atlas, $0) })
                made.position = point(position.center)
                made.zPosition = depth(position.center)
                actors.addChild(made)
                positionNodes[position.id] = made
                node = made
            }
            guard let node else { continue }
            let facing = Facing(direction: position.aim).rawValue
            let firing = clock - node.lastShot < 0.14
            let frames = sprite.frames
            let frame = firing && frames.count > 1 ? frames[1 + Int(clock * 18) % (frames.count - 1)] : frames[0]
            node.top.texture = texture(sprite.atlas, "\(sprite.atlas)_\(facing)_\(frame)")
        }
        for (id, node) in positionNodes where !present.contains(id) {
            node.removeFromParent()
            positionNodes[id] = nil
        }
    }

    private func syncCommandPost() {
        let share = Double(game.commandPostHealth) / Double(max(level.commandPostHealth, 1))
        let state = share <= 0 ? "destroyed" : share < 0.5 ? "damaged" : "intact"
        guard state != commandPostState, let top = commandPostTop else { return }
        commandPostState = state
        top.texture = texture("command_post", "command_post_n_\(state)")
    }

    private func syncSelection(_ selection: Selection) {
        guard selection != drawnSelection else { return }
        drawnSelection = selection
        selectionNode?.removeFromParent()
        selectionNode = nil
        for pad in slotPads {
            pad.removeAllActions()
            pad.colorBlendFactor = 0
            pad.setScale(1)
        }
        switch selection {
        case .none:
            break
        case .slot(let index):
            guard slotPads.indices.contains(index) else { return }
            let pad = slotPads[index]
            pad.color = Theme.sandUI
            pad.colorBlendFactor = 0.5
            pad.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.45), .scale(to: 1.0, duration: 0.45)])))
            let ring = SKShapeNode(circleOfRadius: Self.tile * 0.62)
            ring.strokeColor = Theme.sandUI
            ring.lineWidth = 2.5
            ring.position = pad.position
            overlay.addChild(ring)
            selectionNode = ring
        case .position(let id):
            guard let p = game.position(id: id), let spec = game.levelSpec(of: p) else { return }
            let ring = SKShapeNode(circleOfRadius: CGFloat(spec.range) * Self.tile)
            ring.fillColor = UIColor(white: 1, alpha: 0.08)
            ring.strokeColor = Theme.sandUI.withAlphaComponent(0.85)
            ring.lineWidth = 2
            ring.position = point(p.center)
            overlay.addChild(ring)
            selectionNode = ring
        }
    }

    // MARK: Touch

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let session, let touch = touches.first, !game.isOver else { return }
        let at = mapPoint(touch.location(in: self))
        if let p = game.positions.min(by: { $0.center.distance(to: at) < $1.center.distance(to: at) }),
           p.center.distance(to: at) < 0.75 {
            session.selection = session.selection == .position(p.id) ? .none : .position(p.id)
            return
        }
        if let index = game.slots.indices.min(by: { game.slots[$0].distance(to: at) < game.slots[$1].distance(to: at) }),
           game.slots[index].distance(to: at) < 0.75 {
            session.selection = session.selection == .slot(index) ? .none : .slot(index)
            return
        }
        session.selection = .none
    }
}

/// A built position: the base, with the crew and weapon turning on top.
final class PositionNode: SKNode {
    let spriteName: String
    let top: SKSpriteNode
    let turretOffset: CGPoint
    var lastShot = -10.0

    init(sprite: SpriteManifest.TurretSprite, fitting: CGFloat, pointsPerMeter: CGFloat, texture: (String) -> SKTexture) {
        spriteName = sprite.atlas
        let ppm = pointsPerMeter
        let k = min(1, fitting / (CGFloat(max(sprite.baseM[0], sprite.baseM[1])) * ppm))
        let base = SKSpriteNode(texture: texture("\(sprite.atlas)_base"))
        base.size = CGSize(width: CGFloat(sprite.baseM[0]) * ppm * k, height: CGFloat(sprite.baseM[1]) * ppm * k)
        top = SKSpriteNode(texture: texture("\(sprite.atlas)_n_\(sprite.frames.first ?? "idle")"))
        top.size = CGSize(width: CGFloat(sprite.cellM[0]) * ppm * k, height: CGFloat(sprite.cellM[1]) * ppm * k)
        turretOffset = CGPoint(x: CGFloat(sprite.offsetM[0]) * ppm * k, y: CGFloat(sprite.offsetM[1]) * ppm * k)
        top.position = turretOffset
        top.zPosition = 0.1
        super.init()
        addChild(base)
        addChild(top)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("Not used") }
}

/// A zombie: its body and a small health bar that shows once it's hurt.
final class ZombieNode: SKNode {
    let body: SKSpriteNode
    private let bar: SKSpriteNode
    private let fill: SKSpriteNode
    private let barWidth: CGFloat
    var walkClock = 0.0

    init(size: CGSize, barWidth: CGFloat) {
        body = SKSpriteNode(color: .clear, size: size)
        self.barWidth = barWidth
        bar = SKSpriteNode(color: UIColor(white: 0, alpha: 0.55), size: CGSize(width: barWidth + 2, height: 5))
        fill = SKSpriteNode(color: Theme.healthUI, size: CGSize(width: barWidth, height: 3))
        super.init()
        addChild(body)
        bar.position = CGPoint(x: 0, y: BattlefieldScene.tile * 0.42)
        bar.zPosition = 50
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: -barWidth / 2, y: 0)
        bar.addChild(fill)
        bar.isHidden = true
        addChild(bar)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("Not used") }

    func setHealth(_ share: Double) {
        bar.isHidden = share >= 0.999
        fill.size.width = barWidth * CGFloat(max(0, min(1, share)))
    }

    /// Plays the death animation for the nearest facing, holds the body, then fades it out.
    func die(texture: (String) -> SKTexture, sprite: SpriteManifest.ZombieSprite?, facing: Facing, at: CGPoint) {
        bar.isHidden = true
        position = at
        guard let sprite, let death = sprite.anims["death"] else {
            run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
            return
        }
        let dir = death.dirs.contains(facing.rawValue) ? facing.rawValue : (death.dirs.first ?? "s")
        let frames = (0..<death.frames).map { texture("\(sprite.atlas)_death_\($0)_\(dir)") }
        zPosition -= 0.2
        body.run(.animate(with: frames, timePerFrame: 1 / max(death.fps, 1)))
        run(.sequence([.wait(forDuration: Double(death.frames) / max(death.fps, 1) + 1.6),
                       .fadeOut(withDuration: 0.6), .removeFromParent()]))
    }
}
