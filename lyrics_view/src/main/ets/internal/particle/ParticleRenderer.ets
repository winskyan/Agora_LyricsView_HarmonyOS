/**
 * 粒子渲染器 - 用于在HarmonyOS中渲染粒子效果
 * 对应Android版本的粒子绘制功能
 */

import { LogUtils } from '../../utils/LogUtils';
import { Particle, ParticleSystem } from './ParticleSystem';

/**
 * 粒子渲染组件
 * 使用HarmonyOS的UI组件系统渲染粒子
 */
@Component
export struct ParticleRenderer {
  @Link particleSystem: ParticleSystem | null;
  @State particles: Particle[] = [];
  @Prop particleColors: string[] = [
    '#FFD700', // 金色
    '#FF6B35', // 橙色
    '#F7931E', // 橙黄色
    '#FFE135', // 黄色
    '#C5E063', // 黄绿色
    '#9BC53D', // 绿色
    '#5BA8F2', // 蓝色
    '#9B59B6'// 紫色
  ];
  @Prop particleSize: number = 20; // 增加粒子基础大小，便于测试
  private updateTimer: number = -1;

  build() {
    Stack() {
      // 使用ForEach渲染所有粒子
      ForEach(this.particles, (particle: Particle, index: number) => {
        this.buildParticle(particle)
      }, (particle: Particle) => particle.id)

      // 添加调试信息显示
      if (this.particles.length > 0) {
        Text(`粒子数: ${this.particles.length}`)
          .fontSize(12)
          .fontColor('#FF0000')
          .backgroundColor('#FFFFFF80')
          .padding(4)
          .borderRadius(4)
          .position({ x: 10, y: 10 })
      }
    }
    .width('100%')
      .height('100%')
      .onAppear(() => {
        LogUtils.d('ParticleRenderer: Component appeared, starting update loop');
        this.startUpdateLoop();
      })
      .onDisAppear(() => {
        LogUtils.d('ParticleRenderer: Component disappearing, stopping update loop');
        this.stopUpdateLoop();
      })
  }

  /**
   * 构建单个粒子
   */
  @Builder
  buildParticle(particle: Particle) {
    // 使用不同的形状表示不同类型的粒子
    if (particle.particleType % 3 === 0) {
      // 圆形粒子
      Circle({ width: this.particleSize * particle.scale, height: this.particleSize * particle.scale })
        .fill(this.particleColors[particle.particleType % this.particleColors.length])
        .opacity(particle.alpha)
        .rotate({ angle: particle.rotation })
        .position({
          x: particle.x - (this.particleSize * particle.scale) / 2,
          y: particle.y - (this.particleSize * particle.scale) / 2
        })
    } else if (particle.particleType % 3 === 1) {
      // 矩形粒子
      Rect()
        .width(this.particleSize * particle.scale)
        .height(this.particleSize * particle.scale)
        .fill(this.particleColors[particle.particleType % this.particleColors.length])
        .opacity(particle.alpha)
        .rotate({ angle: particle.rotation })
        .borderRadius(2)
        .position({
          x: particle.x - (this.particleSize * particle.scale) / 2,
          y: particle.y - (this.particleSize * particle.scale) / 2
        })
    } else {
      // 星形粒子（使用多边形模拟）
      this.buildStarParticle(particle)
    }
  }

  /**
   * 构建星形粒子
   */
  @Builder
  buildStarParticle(particle: Particle) {
    // 使用多个小圆形组成星形效果
    Stack() {
      // 中心圆
      Circle({ width: this.particleSize * particle.scale * 0.6, height: this.particleSize * particle.scale * 0.6 })
        .fill(this.particleColors[particle.particleType % this.particleColors.length])

      // 四个方向的小圆
      Circle({ width: this.particleSize * particle.scale * 0.3, height: this.particleSize * particle.scale * 0.3 })
        .fill(this.particleColors[particle.particleType % this.particleColors.length])
        .position({ x: this.particleSize * particle.scale * 0.4, y: 0 })

      Circle({ width: this.particleSize * particle.scale * 0.3, height: this.particleSize * particle.scale * 0.3 })
        .fill(this.particleColors[particle.particleType % this.particleColors.length])
        .position({ x: -this.particleSize * particle.scale * 0.4, y: 0 })

      Circle({ width: this.particleSize * particle.scale * 0.3, height: this.particleSize * particle.scale * 0.3 })
        .fill(this.particleColors[particle.particleType % this.particleColors.length])
        .position({ x: 0, y: this.particleSize * particle.scale * 0.4 })

      Circle({ width: this.particleSize * particle.scale * 0.3, height: this.particleSize * particle.scale * 0.3 })
        .fill(this.particleColors[particle.particleType % this.particleColors.length])
        .position({ x: 0, y: -this.particleSize * particle.scale * 0.4 })
    }
    .opacity(particle.alpha)
      .rotate({ angle: particle.rotation })
      .position({
        x: particle.x - (this.particleSize * particle.scale) / 2,
        y: particle.y - (this.particleSize * particle.scale) / 2
      })
  }

  /**
   * 启动更新循环
   */
  private startUpdateLoop(): void {
    if(this.updateTimer !== -1) {
    return;
  }

  const updateLoop = () => {
    if (this.particleSystem) {
      // 从粒子系统获取最新的粒子数据
      const newParticles = this.particleSystem.getParticles();
      const oldCount = this.particles.length;
      this.particles = [...newParticles];

      // 每秒输出一次粒子数量，避免日志过多
      if (Date.now() % 1000 < 16) {
        LogUtils.d(`ParticleRenderer: Updated particles count: ${this.particles.length} (was ${oldCount})`);
        if (this.particles.length > 0) {
          const firstParticle = this.particles[0];
          LogUtils.d(`ParticleRenderer: First particle at (${firstParticle.x}, ${firstParticle.y}), alpha: ${firstParticle.alpha}, scale: ${firstParticle.scale}`);
        }
      }
    } else {
      this.particles = [];
      if (Date.now() % 1000 < 16) {
        LogUtils.d(`ParticleRenderer: No particle system available`);
      }
    }

    // 继续下一帧更新
    this.updateTimer = setTimeout(updateLoop, 16); // 60fps
  };

  updateLoop();
}

  /**
   * 停止更新循环
   */
  private stopUpdateLoop(): void {
  if(this.updateTimer !== -1) {
  clearTimeout(this.updateTimer);
  this.updateTimer = -1;
}
  }
}

/**
 * 简化版粒子渲染器 - 用于性能敏感的场景
 */
@Component
export struct SimpleParticleRenderer {
  @Link particleSystem: ParticleSystem | null;
  @State particles: Particle[] = [];
  @Prop particleColor: string = '#FFD700'; // 统一的粒子颜色
  @Prop particleSize: number = 8;
  private updateTimer: number = -1;

  build() {
    Stack() {
      ForEach(this.particles, (particle: Particle, index: number) => {
        Circle({ width: this.particleSize * particle.scale, height: this.particleSize * particle.scale })
          .fill(this.particleColor)
          .opacity(particle.alpha)
          .position({
            x: particle.x - (this.particleSize * particle.scale) / 2,
            y: particle.y - (this.particleSize * particle.scale) / 2
          })
      }, (particle: Particle) => particle.id)
    }
    .width('100%')
      .height('100%')
      .onAppear(() => {
        this.startUpdateLoop();
      })
      .onDisAppear(() => {
        this.stopUpdateLoop();
      })
  }

  private startUpdateLoop(): void {
    if(this.updateTimer !== -1) {
    return;
  }

  const updateLoop = () => {
    if (this.particleSystem) {
      this.particles = [...this.particleSystem.getParticles()];
    } else {
      this.particles = [];
    }
    this.updateTimer = setTimeout(updateLoop, 16);
  };

  updateLoop();
}

  private stopUpdateLoop(): void {
  if(this.updateTimer !== -1) {
  clearTimeout(this.updateTimer);
  this.updateTimer = -1;
}
  }
}
