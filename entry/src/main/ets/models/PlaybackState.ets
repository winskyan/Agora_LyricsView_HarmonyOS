/**
 * 播放状态模型
 * 使用 @ObservedV2 实现响应式状态管理
 */
@ObservedV2
export class PlaybackState {
  /** 当前播放时间 (ms) */
  @Trace currentTime: number = 0;
  /** 播放进度显示文本 */
  @Trace playingProgress: string = '0ms';
  /** 是否正在播放 */
  @Trace isPlaying: boolean = false;
  /** 是否为原唱模式 */
  @Trace isOriginalTrack: boolean = true;
  /** 上一次的 pitch 值 */
  @Trace lastPitch: number = 50;

  /**
   * 重置播放状态
   */
  reset(): void {
    this.currentTime = 0;
    this.playingProgress = '0ms';
    this.isPlaying = false;
    this.lastPitch = 50;
  }

  /**
   * 更新播放进度
   */
  updateProgress(time: number): void {
    this.currentTime = time;
    this.playingProgress = `${time}ms`;
  }

  /**
   * 设置播放状态
   */
  setPlayingState(isPlaying: boolean): void {
    this.isPlaying = isPlaying;
  }

  /**
   * 切换原唱/伴奏模式
   */
  toggleOriginalTrack(): void {
    this.isOriginalTrack = !this.isOriginalTrack;
  }

  /**
   * 更新 pitch 值
   */
  updatePitch(pitch: number): void {
    this.lastPitch = Math.max(0, Math.min(100, pitch));
  }
}
