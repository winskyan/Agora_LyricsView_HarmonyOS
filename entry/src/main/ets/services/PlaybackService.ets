import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'PlaybackService';

/**
 * 播放服务回调接口
 */
export interface PlaybackCallback {
  onProgressUpdate?: (progress: number) => void;
  onStateChange?: (isPlaying: boolean) => void;
  onPitchUpdate?: (pitch: number) => void;
}

/**
 * 播放服务
 * 负责播放控制和进度管理
 */
export class PlaybackService {
  private timer: number = -1;
  private currentTime: number = 0;
  private isPlaying: boolean = false;
  private lastPitch: number = 50;
  // 回调函数
  private callbacks: PlaybackCallback = {};

  /**
   * 设置回调函数
   */
  setCallbacks(callbacks: PlaybackCallback): void {
    this.callbacks = callbacks;
  }

  /**
   * 开始播放
   */
  start(): void {
    if (this.isPlaying) {
      return;
    }

    this.isPlaying = true;
    this.notifyStateChange();

    // 使用 20ms 间隔的定时器，更精确地模拟播放
    this.timer = setInterval(() => {
      this.currentTime += 20; // 每 20ms 增加 20ms

      // 生成平滑的 pitch 变化
      this.generateSmoothPitch();

      // 通知回调
      this.callbacks.onProgressUpdate?.(this.currentTime);
      this.callbacks.onPitchUpdate?.(this.lastPitch);

      // 模拟播放结束（3分钟）
      if (this.currentTime >= 180000) {
        this.stop();
      }
    }, 20); // 20ms 间隔

    this.logDebug('Playback started');
  }

  /**
   * 暂停播放
   */
  pause(): void {
    this.isPlaying = false;
    this.notifyStateChange();

    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }

    this.logDebug('Playback paused');
  }

  /**
   * 停止播放
   */
  stop(): void {
    this.pause();
    this.currentTime = 0;

    // 通知进度重置
    this.callbacks.onProgressUpdate?.(this.currentTime);

    this.logDebug('Playback stopped');
  }

  /**
   * 跳转到指定位置
   */
  seekTo(position: number): void {
    this.currentTime = position;

    // 通知进度更新
    this.callbacks.onProgressUpdate?.(this.currentTime);

    this.logDebug(`Seeked to: ${position}ms`);
  }

  /**
   * 获取当前播放时间
   */
  getCurrentTime(): number {
    return this.currentTime;
  }

  /**
   * 获取播放状态
   */
  getIsPlaying(): boolean {
    return this.isPlaying;
  }

  /**
   * 销毁服务
   */
  destroy(): void {
    this.stop();
    this.callbacks = {};

    this.logDebug('PlaybackService destroyed');
  }

  /**
   * 生成平滑的 pitch 变化
   */
  private generateSmoothPitch(): void {
    const maxChange = 10;
    const change = (Math.random() - 0.5) * 2 * maxChange;
    this.lastPitch = Math.max(0, Math.min(100, this.lastPitch + change));
  }

  /**
   * 通知状态变化
   */
  private notifyStateChange(): void {
    this.callbacks.onStateChange?.(this.isPlaying);
  }

  /**
   * 调试日志
   */
  private logDebug(message: string): void {
    hilog.debug(0x0000, TAG, `%{public}s`, message);
  }
}
