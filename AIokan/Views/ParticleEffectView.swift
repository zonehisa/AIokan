//
//  ParticleEffectView.swift
//  AIokan
//
//  Created by 佐藤幸久 on 2025/03/01.
//

import SwiftUI

struct ParticleEffectView: View {
    @State private var particles: [Particle] = []
    @State private var isAnimating = false
    var onCompletion: () -> Void // アニメーション終了時のコールバック
    
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGPoint
        var rotation: Double
        var rotationSpeed: Double
        var scale: CGFloat
        var color: Color
        var opacity: Double
        var lifetime: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 紙吹雪
                ForEach(particles) { particle in
                    Rectangle()
                        .fill(particle.color)
                        .frame(width: 5, height: 5)
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .rotationEffect(.degrees(particle.rotation))
                        .position(particle.position)
                }
            }
            .onAppear {
                isAnimating = true // ビューが表示されたらアニメーション開始
                createParticles(geometry: geometry)
            }
            .onChange(of: isAnimating) { newValue in
                if newValue {
                    createParticles(geometry: geometry)
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private func createParticles(geometry: GeometryProxy) {
        particles = []
        let size = geometry.size
        let centerX = size.width / 2
        let centerY = size.height / 4
        
        for _ in 0..<100 {
            let angle = Double.random(in: 0..<360)
            let speed = Double.random(in: 10..<25)
            let velocity = CGPoint(
                x: speed * cos(angle * .pi / 180),
                y: speed * sin(angle * .pi / 180)
            )
            
            let particle = Particle(
                position: CGPoint(x: centerX, y: centerY),
                velocity: velocity,
                rotation: Double.random(in: 0..<360),
                rotationSpeed: Double.random(in: -15..<15),
                scale: CGFloat.random(in: 0.5..<1.5),
                color: [Color.red, Color.yellow, Color.blue, Color.green, Color.purple].randomElement()!,
                opacity: 1.0,
                lifetime: Double.random(in: 0.8..<2.5)
            )
            particles.append(particle)
        }
        
        animateParticles()
    }
    
    private func animateParticles() {
        var time: Double = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            time += 0.016
            var allDone = true
            
            for i in 0..<particles.count {
                var particle = particles[i]
                particle.position.x += particle.velocity.x
                particle.position.y += particle.velocity.y + 1.0 * time
                particle.rotation += particle.rotationSpeed
                particle.opacity = max(0, 1.0 - time / particle.lifetime)
                
                if particle.opacity > 0 {
                    allDone = false
                }
                particles[i] = particle
            }
            
            if allDone {
                timer.invalidate()
                isAnimating = false
                particles = []
                onCompletion() // アニメーション終了時にコールバックを呼ぶ
            }
        }
        timer.fire()
    }
}
