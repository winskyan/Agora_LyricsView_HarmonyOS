/**
 * 用于在ScoringView中实现粒子动画效果
 */

import { LogUtils } from '../../utils/LogUtils';

/**
 * 单个粒子的数据结构
 */
export interface Particle {
  id: string;
  x: number;
  y: number;
  vx: number; // X方向速度
  vy: number; // Y方向速度
  rotation: number;
  rotationSpeed: number;
  scale: number;
  alpha: number;
  life: number; // 生命周期 (0-1)
  maxLife: number; // 最大生命周期 (ms)
  particleType: number; // 粒子类型索引
  startTime: number;
}

/**
 * 范围接口
 */
export interface Range {
  min: number;
  max: number;
}

/**
 * 粒子系统配置
 */
export interface ParticleConfig {
  particlesPerSecond: number; // 每秒发射粒子数
  maxParticles: number; // 最大粒子数
  particleLifetime: number; // 粒子生命周期 (ms)
  speedRange: Range; // 速度范围
  angleRange: Range; // 发射角度范围 (度)
  rotationSpeedRange: Range; // 旋转速度范围
  scaleRange: Range; // 缩放范围
  fadeOutDuration: number; // 淡出持续时间 (ms)
  gravity: number; // 重力加速度
}

/**
 * 粒子系统类 - 对应Android的ParticleSystem
 */
export class ParticleSystem {
  private particles: Particle[] = [];
  private isEmitting: boolean = false;
  private emitX: number = 0;
  private emitY: number = 0;
  private config: ParticleConfig;
  private lastEmitTime: number = 0;
  private particleCounter: number = 0;
  private animationId: number = -1;
  // 延迟停止相关
  private stopDelayTimer: number = -1;
  private shouldStopEmitting: boolean = false;
  private readonly STOP_DELAY_MS: number = 300; // 延长到500ms，确保连续着色时粒子持续生成
  // 默认配置 - 对应Android版本的设置
  private static readonly DEFAULT_CONFIG: ParticleConfig = ParticleSystem.createDefaultConfig();

  private static createDefaultConfig(): ParticleConfig {
    const speedRange: Range = { min: 0.10, max: 0.20 };
    const angleRange: Range = { min: 130, max: 230 };
    const rotationSpeedRange: Range = { min: 90, max: 180 };
    const scaleRange: Range = { min: 0.7, max: 1.6 };

    const config: ParticleConfig = {
      particlesPerSecond: 12,
      maxParticles: 24, // particles.length * 3
      particleLifetime: 900, // 900ms
      speedRange: speedRange, // 对应Android的0.10f, 0.20f
      angleRange: angleRange, // 对应Android的130, 230度
      rotationSpeedRange: rotationSpeedRange, // 对应Android的90, 180
      scaleRange: scaleRange, // 对应Android的0.7f, 1.6f
      fadeOutDuration: 300, // 对应Android的300ms淡出
      gravity: 0.0002 // 重力效果
    };

    return config;
  }

  constructor(config?: Partial<ParticleConfig>) {
    this.config = this.mergeConfig(ParticleSystem.DEFAULT_CONFIG, config);
    LogUtils.d(`ParticleSystem: Initialized with config: ${JSON.stringify(this.config)}`);
  }

  private mergeConfig(defaultConfig: ParticleConfig, userConfig?: Partial<ParticleConfig>): ParticleConfig {
    if (!userConfig) {
      return defaultConfig;
    }

    const merged: ParticleConfig = {
      particlesPerSecond: userConfig.particlesPerSecond ?? defaultConfig.particlesPerSecond,
      maxParticles: userConfig.maxParticles ?? defaultConfig.maxParticles,
      particleLifetime: userConfig.particleLifetime ?? defaultConfig.particleLifetime,
      speedRange: userConfig.speedRange ?? defaultConfig.speedRange,
      angleRange: userConfig.angleRange ?? defaultConfig.angleRange,
      rotationSpeedRange: userConfig.rotationSpeedRange ?? defaultConfig.rotationSpeedRange,
      scaleRange: userConfig.scaleRange ?? defaultConfig.scaleRange,
      fadeOutDuration: userConfig.fadeOutDuration ?? defaultConfig.fadeOutDuration,
      gravity: userConfig.gravity ?? defaultConfig.gravity
    };

    return merged;
  }

  /**
   * 开始在指定位置发射粒子 - 对应Android的emit方法
   */
  emit(x: number, y: number, particlesPerSecond?: number): void {
    this.emitX = x;
    this.emitY = y;
    if (particlesPerSecond !== undefined) {
      this.config.particlesPerSecond = particlesPerSecond;
    }
    this.isEmitting = true;

    // 立即创建第一个粒子，不等待发射间隔
    if (this.particles.length < this.config.maxParticles) {
      this.createParticle();
    }

    this.lastEmitTime = Date.now();

    if (this.animationId === -1) {
      this.startAnimation();
    }
  }

  /**
   * 更新发射点位置 - 对应Android的updateEmitPoint方法
   */
  updateEmitPoint(x: number, y: number): void {
    this.emitX = x;
    this.emitY = y;
  }

  /**
   * 恢复发射 - 对应Android的resumeEmitting方法
   */
  resumeEmitting(): void {
    // 清除延迟停止定时器和标记
    if (this.stopDelayTimer !== -1) {
      clearTimeout(this.stopDelayTimer);
      this.stopDelayTimer = -1;
    }
    this.shouldStopEmitting = false;

    if (!this.isEmitting) {
      this.isEmitting = true;
      // 立即创建第一个粒子，不等待发射间隔
      if (this.particles.length < this.config.maxParticles) {
        this.createParticle();
      }
      this.lastEmitTime = Date.now();

      // 确保动画循环正在运行
      if (this.animationId === -1) {
        this.startAnimation();
      }
    } else {
      // 如果已经在发射但粒子很少，也立即创建一个粒子
      if (this.particles.length < 3 && this.particles.length < this.config.maxParticles) {
        this.createParticle();
      }
      this.lastEmitTime = Date.now();
    }
  }

  /**
   * 停止发射 - 对应Android的stopEmitting方法
   * 使用延迟停止机制，避免粒子发射被过快中断
   */
  stopEmitting(): void {
    // 如果已经不在发射或已经设置了停止标记，直接返回
    if (!this.isEmitting || this.shouldStopEmitting) {
      return;
    }

    // 设置延迟停止标记
    this.shouldStopEmitting = true;

    // 清除之前的延迟定时器
    if (this.stopDelayTimer !== -1) {
      clearTimeout(this.stopDelayTimer);
    }

    // 设置延迟停止定时器
    this.stopDelayTimer = setTimeout(() => {
      this.isEmitting = false;
      this.shouldStopEmitting = false;
      this.stopDelayTimer = -1;
    }, this.STOP_DELAY_MS);
  }

  /**
   * 取消粒子系统 - 对应Android的cancel方法
   */
  cancel(): void {
    this.isEmitting = false;
    this.particles = [];

    // 清除延迟停止定时器
    if (this.stopDelayTimer !== -1) {
      clearTimeout(this.stopDelayTimer);
      this.stopDelayTimer = -1;
    }
    this.shouldStopEmitting = false;

    if (this.animationId !== -1) {
      clearTimeout(this.animationId);
      this.animationId = -1;
    }
    LogUtils.d('ParticleSystem: Cancelled');
  }

  /**
   * 获取当前所有活跃的粒子
   */
  getParticles(): Particle[] {
    return this.particles;
  }

  /**
   * 设置粒子系统配置
   */
  setConfig(config: Partial<ParticleConfig>): void {
    this.config = this.mergeConfig(this.config, config);
  }

  /**
   * 设置旋转速度范围 - 对应Android的setRotationSpeedRange
   */
  setRotationSpeedRange(min: number, max: number): ParticleSystem {
    const range: Range = { min: min, max: max };
    this.config.rotationSpeedRange = range;
    return this;
  }

  /**
   * 设置缩放范围 - 对应Android的setScaleRange
   */
  setScaleRange(min: number, max: number): ParticleSystem {
    const range: Range = { min: min, max: max };
    this.config.scaleRange = range;
    return this;
  }

  /**
   * 设置速度模块和角度范围 - 对应Android的setSpeedModuleAndAngleRange
   */
  setSpeedModuleAndAngleRange(minSpeed: number, maxSpeed: number, minAngle: number, maxAngle: number): ParticleSystem {
    const speedRange: Range = { min: minSpeed, max: maxSpeed };
    const angleRange: Range = { min: minAngle, max: maxAngle };
    this.config.speedRange = speedRange;
    this.config.angleRange = angleRange;
    return this;
  }

  /**
   * 设置淡出效果 - 对应Android的setFadeOut
   */
  setFadeOut(duration: number): ParticleSystem {
    this.config.fadeOutDuration = duration;
    return this;
  }

  /**
   * 启动动画循环
   */
  private startAnimation(): void {
    const animate = () => {
      if (this.particles.length === 0 && !this.isEmitting) {
        this.animationId = -1;
        return;
      }

      this.updateParticles();
      this.animationId = setTimeout(animate, 16); // 60fps
    };
    animate();
  }

  /**
   * 更新粒子状态
   */
  private updateParticles(): void {
    const now = Date.now();
    const deltaTime = 16; // 16ms per frame

    // 发射新粒子
    if (this.isEmitting && this.particles.length < this.config.maxParticles) {
      const timeSinceLastEmit = now - this.lastEmitTime;
      const emitInterval = 1000 / this.config.particlesPerSecond;

      if (timeSinceLastEmit >= emitInterval) {
        this.createParticle();
        this.lastEmitTime = now;
      }
    }

    // 更新现有粒子
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const particle = this.particles[i];
      const age = now - particle.startTime;

      // 检查粒子是否应该被移除
      if (age >= particle.maxLife) {
        this.particles.splice(i, 1);
        continue;
      }

      // 更新粒子位置
      particle.x += particle.vx * deltaTime;
      particle.y += particle.vy * deltaTime;

      // 应用重力
      particle.vy += this.config.gravity * deltaTime;

      // 更新旋转
      particle.rotation += particle.rotationSpeed * deltaTime;

      // 更新生命周期和透明度
      particle.life = age / particle.maxLife;

      // 淡出效果
      const fadeOutStart = 1 - (this.config.fadeOutDuration / particle.maxLife);
      if (particle.life > fadeOutStart) {
        const fadeProgress = (particle.life - fadeOutStart) / (1 - fadeOutStart);
        particle.alpha = 1 - fadeProgress;
      } else {
        particle.alpha = 1;
      }
    }
  }

  /**
   * 创建新粒子
   */
  private createParticle(): void {
    const angle = this.randomBetween(this.config.angleRange.min, this.config.angleRange.max);
    const speed = this.randomBetween(this.config.speedRange.min, this.config.speedRange.max);
    const angleRad = (angle * Math.PI) / 180;

    const particle: Particle = {
      id: `particle_${this.particleCounter++}`,
      x: this.emitX,
      y: this.emitY,
      vx: Math.cos(angleRad) * speed,
      vy: Math.sin(angleRad) * speed,
      rotation: 0,
      rotationSpeed: this.randomBetween(this.config.rotationSpeedRange.min, this.config.rotationSpeedRange.max),
      scale: this.randomBetween(this.config.scaleRange.min, this.config.scaleRange.max),
      alpha: 1,
      life: 0,
      maxLife: this.config.particleLifetime,
      particleType: Math.floor(Math.random() * 8), // 8种不同的粒子类型
      startTime: Date.now()
    };

    this.particles.push(particle);
  }

  /**
   * 生成指定范围内的随机数
   */
  private randomBetween(min: number, max: number): number {
    return min + Math.random() * (max - min);
  }
}
