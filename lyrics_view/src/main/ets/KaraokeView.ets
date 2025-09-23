import { IKaraokeEvent } from './IKaraokeEvent';
import { IScoringAlgorithm } from './IScoringAlgorithm';
import { LyricsParser } from './internal/parser/LyricsParser';
import { LyricModel } from './model/LyricModel';
import { EventBus, KaraokeEvents, LyricsEvents, ScoringEvents } from './utils/EventBus';
import { LogUtils } from './utils/LogUtils';

/**
 * 卡拉OK主控制器 - HarmonyOS版本
 * 对应Android项目中的KaraokeView
 * 管理歌词显示、评分和不同组件之间的同步
 */
export class KaraokeView {
  /**
   * 卡拉OK事件监听器
   */
  private mKaraokeEvent?: IKaraokeEvent;
  /**
   * 事件总线实例
   */
  private eventBus: EventBus = EventBus.getInstance();
  // 组件ready状态管理
  private componentReadyStates: Map<string, boolean> = new Map();
  private integratedComponents: Set<string> = new Set();
  private karaokeReadyFired: boolean = false;
  private componentDetectionTimer?: number;
  /**
   * 是否已销毁
   */
  private isDestroyed: boolean = false;
  // 事件监听器引用，用于后续移除
  private dragStartListener = () => {
    LogUtils.d('KaraokeView: Drag start received');
  };
  private dragEndListener = (finalProgress: number) => {
    LogUtils.d(`KaraokeView: Drag end received: ${finalProgress}ms`);
    if (this.mKaraokeEvent) {
      this.mKaraokeEvent.onDragTo(finalProgress);
    }
  };
  private lyricsComponentReadyListener = () => {
    LogUtils.d('KaraokeView: LyricsView component ready');
    this.handleComponentReady('LyricsView');
  };
  private scoringComponentReadyListener = () => {
    LogUtils.d('KaraokeView: ScoringView component ready');
    this.handleComponentReady('ScoringView');
  };
  private componentDetectionListener = (componentName: string) => {
    if (componentName != KaraokeEvents.COMPONENT_DETECTION_REQUEST) {
      LogUtils.d(`KaraokeView: Component detected: ${componentName}`);
      this.integratedComponents.add(componentName);
    }
  };

  /**
   * 默认构造函数
   */
  constructor() {
    this.initialize();
  }

  /**
   * 初始化卡拉OK组件，包括歌词和评分机器
   */
  private initialize(): void {
    if (this.isDestroyed) {
      LogUtils.w('KaraokeView initialize called on destroyed instance');
      return;
    }

    LogUtils.d('KaraokeView initialize');
    LogUtils.enableLog(true, true);

    // 设置拖拽事件监听
    this.setupDragEventListeners();

    // 设置组件ready事件监听
    this.setupComponentReadyListeners();

    // 启动组件检测
    this.startComponentDetection();
  }

  /**
   * 设置拖拽事件监听器
   */
  private setupDragEventListeners(): void {
    // 监听拖拽开始事件
    this.eventBus.on(LyricsEvents.DRAG_START, this.dragStartListener);

    // 监听拖拽结束事件
    this.eventBus.on(LyricsEvents.DRAG_END, this.dragEndListener);
  }

  /**
   * 设置组件ready事件监听器
   */
  private setupComponentReadyListeners(): void {
    // 监听歌词组件ready事件
    this.eventBus.on(LyricsEvents.COMPONENT_READY, this.lyricsComponentReadyListener);

    // 监听评分组件ready事件
    this.eventBus.on(ScoringEvents.COMPONENT_READY, this.scoringComponentReadyListener);

    // 监听组件检测响应
    this.eventBus.on(KaraokeEvents.COMPONENT_DETECTION, this.componentDetectionListener);
  }

  /**
   * 启动组件检测 - 自动发现哪些组件被集成了
   */
  private startComponentDetection(): void {
    LogUtils.d('KaraokeView: Starting component detection');

    // 发送检测信号，集成的组件会响应
    this.eventBus.emit(KaraokeEvents.COMPONENT_DETECTION, KaraokeEvents.COMPONENT_DETECTION_REQUEST);

    // 给组件一些时间来响应检测信号
    this.componentDetectionTimer = setTimeout(() => {
      this.finalizeComponentDetection();
    }, 100); // 100ms应该足够组件响应
  }

  /**
   * 完成组件检测，确定哪些组件被集成了
   */
  private finalizeComponentDetection(): void {
    LogUtils.d(`KaraokeView: Component detection completed. Integrated components: ${Array.from(this.integratedComponents)
      .join(', ')}`);

    // 如果没有检测到任何组件，可能是组件还没有初始化，延迟重试
    if (this.integratedComponents.size === 0) {
      LogUtils.d('KaraokeView: No components detected yet, retrying in 500ms');
      this.componentDetectionTimer = setTimeout(() => {
        this.startComponentDetection();
      }, 500);
      return;
    }

    // 初始化检测到的组件的ready状态
    this.integratedComponents.forEach(componentName => {
      this.componentReadyStates.set(componentName, false);
    });

    LogUtils.d(`KaraokeView: Waiting for ${this.integratedComponents.size} components to be ready`);
  }

  /**
   * 处理组件ready事件
   */
  private handleComponentReady(componentName: string): void {
    // 如果组件不在集成列表中，说明检测还没完成，先添加到集成列表
    if (!this.integratedComponents.has(componentName)) {
      LogUtils.d(`KaraokeView: Component ${componentName} ready before detection completed, adding to integrated list`);
      this.integratedComponents.add(componentName);
      this.componentReadyStates.set(componentName, true);
    } else {
      this.componentReadyStates.set(componentName, true);
    }

    LogUtils.d(`KaraokeView: Component ${componentName} is ready`);
    this.checkAllComponentsReady();
  }

  /**
   * 检查所有集成的组件是否都ready了
   */
  private checkAllComponentsReady(): void {
    if (this.karaokeReadyFired) {
      return; // 已经发布过事件了
    }

    // 检查是否所有集成的组件都ready了
    let allReady = true;
    for (const componentName of this.integratedComponents) {
      if (!this.componentReadyStates.get(componentName)) {
        allReady = false;
        break;
      }
    }

    if (allReady && this.integratedComponents.size > 0) {
      LogUtils.d(`KaraokeView: All ${this.integratedComponents.size} components are ready, firing onKaraokeReady event`);
      this.karaokeReadyFired = true;

      // 清理检测定时器
      if (this.componentDetectionTimer) {
        clearTimeout(this.componentDetectionTimer);
        this.componentDetectionTimer = undefined;
      }

      // 发布onKaraokeReady事件
      if (this.mKaraokeEvent) {
        try {
          this.mKaraokeEvent.onKaraokeReady();
        } catch (error) {
          LogUtils.e(`KaraokeView: Error in onKaraokeReady callback: ${error}`);
        }
      }
    } else {
      const readyComponents = Array.from(this.integratedComponents).filter(name =>
      this.componentReadyStates.get(name)
      );
      LogUtils.d(`KaraokeView: ${readyComponents.length}/${this.integratedComponents.size} components ready: ${readyComponents.join(', ')}`);
    }
  }


  /**
   * Parse lyrics data from file path or byte array
   *
   * @param lyricSource              Lyrics file path (string) or byte data (Uint8Array)
   * @param pitchSource              Pitch file path (string) or byte data (Uint8Array), optional
   * @param includeCopyrightSentence Whether to include copyright information
   * @param lyricOffset              Timing offset for lyrics
   * @return Parsed lyrics model
   */
  static parseLyrics(
    lyricSource: string | Uint8Array,
    pitchSource?: string | Uint8Array,
    includeCopyrightSentence: boolean = true,
    lyricOffset: number = 0
  ): LyricModel | null {
    LogUtils.d(`KaraokeView parseLyrics lyricSource type:${typeof lyricSource}, pitchSource type:${typeof pitchSource}, includeCopyrightSentence:${includeCopyrightSentence}, lyricOffset:${lyricOffset}`);

    try {
      // 根据输入类型分发处理逻辑
      if (typeof lyricSource === 'string') {
        // 处理文件路径
        const pitchPath = typeof pitchSource === 'string' ? pitchSource : undefined;
        return LyricsParser.parseFile(lyricSource, pitchPath, includeCopyrightSentence, lyricOffset);
      } else if (lyricSource instanceof Uint8Array) {
        // 处理字节数组
        const pitchData = pitchSource instanceof Uint8Array ? pitchSource : undefined;
        return LyricsParser.parseLyricData(lyricSource, pitchData, includeCopyrightSentence, lyricOffset);
      } else {
        LogUtils.e('Invalid lyric source type. Expected string or Uint8Array.');
        return null;
      }
    } catch (error) {
      LogUtils.e(`parseLyrics error: ${error}`);
      return null;
    }
  }

  /**
   * Reset all components (通过事件总线)
   */
  reset(): void {
    if (this.checkDestroyed()) {
      return;
    }

    LogUtils.d('KaraokeView reset');

    // 通过事件总线通知组件重置
    this.eventBus.emit(LyricsEvents.RESET);
    this.eventBus.emit(ScoringEvents.RESET);
  }

  /**
   * Set lyrics data and initialize scoring system
   *
   * @param model                Lyrics model containing timing and text data
   * @param usingInternalScoring Whether to use internal scoring algorithm
   */
  setLyricData(model: LyricModel, usingInternalScoring: boolean = false): void {
    if (this.checkDestroyed()) {
      return;
    }

    LogUtils.d(`KaraokeView setLyricData model lines:${model.lines.length} usingInternalScoring:${usingInternalScoring}`);
    // 通过事件总线通知组件
    this.eventBus.emit(LyricsEvents.SET_LYRIC_DATA, model);
    this.eventBus.emit(ScoringEvents.SET_LYRIC_DATA, model, usingInternalScoring);
  }

  /**
   * Set real-time pitch data from microphone input
   * Note: Can be obtained from AgoraRTC DRM callback method 'onPitch' (50ms interval)
   *
   * @param speakerPitch Current pitch value from singer (Hz, typically 80-2000)
   * @param pitchScore   Current pitch score (0.0 to 100.0, float precision)
   * @param progressInMs Current progress timestamp in milliseconds (integer)
   */
  setPitch(speakerPitch: number, pitchScore: number, progressInMs: number): void {
    if (this.checkDestroyed()) {
      return;
    }

    if (speakerPitch < 0 || speakerPitch > 5000) {
      LogUtils.w(`Invalid speaker pitch: ${speakerPitch}, expected 0-5000 Hz`);
    }
    if (pitchScore < 0 || pitchScore > 100) {
      LogUtils.w(`Invalid pitch score: ${pitchScore}, expected 0.0-100.0`);
    }
    if (progressInMs < 0) {
      LogUtils.w(`Invalid progress: ${progressInMs}, expected >= 0`);
    }

    LogUtils.d(`KaraokeView:setPitch speakerPitch:${speakerPitch.toFixed(2)}, pitchScore:${pitchScore.toFixed(1)}, progressInMs:${Math.floor(progressInMs)}ms`);

    // 通过事件总线发送音高数据给ScoringView
    this.eventBus.emit(ScoringEvents.SET_PITCH, speakerPitch, pitchScore, progressInMs);
  }

  /**
   * Set current song progress (should be called every 20ms)
   * Note: Can be obtained from the player's current progress
   *
   * @param progress Current song progress in milliseconds
   */
  setProgress(progress: number): void {
    if (this.checkDestroyed()) {
      return;
    }

    //LogUtils.d(`KaraokeView:setProgress progress:${progress}`);
    // 通过事件总线通知组件
    this.eventBus.emit(LyricsEvents.SET_PROGRESS, progress);
    this.eventBus.emit(ScoringEvents.SET_PROGRESS, progress);
  }

  /**
   * Set event listener for karaoke callbacks
   *
   * @param event Karaoke event listener
   */
  setKaraokeEvent(event: IKaraokeEvent): void {
    if (this.checkDestroyed()) {
      return;
    }

    LogUtils.d(`setKaraokeEvent event:${event}`);
    this.mKaraokeEvent = event;
  }

  /**
   * Set custom scoring algorithm
   *
   * @param algorithm Custom scoring algorithm implementation
   */
  setScoringAlgorithm(algorithm: IScoringAlgorithm): void {
    if (this.checkDestroyed()) {
      return;
    }

    LogUtils.d(`setScoringAlgorithm algorithm:${algorithm}`);

    // 通过事件总线发送评分算法给ScoringView
    this.eventBus.emit(ScoringEvents.SET_SCORING_ALGORITHM, algorithm);
  }

  /**
   * Set scoring difficulty level
   *
   * @param level Scoring difficulty level
   */
  setScoringLevel(level: number): void {
    if (this.checkDestroyed()) {
      return;
    }

    LogUtils.d(`setScoringLevel level:${level}`);

    // 通过事件总线发送评分难度给ScoringView
    this.eventBus.emit(ScoringEvents.SET_SCORING_LEVEL, level);
  }

  /**
   * 主动销毁KaraokeView
   * 清理所有资源，包括事件监听器、定时器等
   * 调用此方法后，KaraokeView实例将不可再使用
   */
  destroy(): void {
    if (this.isDestroyed) {
      LogUtils.w('KaraokeView destroy called on already destroyed instance');
      return;
    }

    LogUtils.d('KaraokeView destroy called - cleaning up resources');
    this.doDestroy();
  }

  /**
   * 内部销毁逻辑
   * 执行实际的资源清理工作
   */
  private doDestroy(): void {
    try {
      // 标记为已销毁
      this.isDestroyed = true;

      // 清理定时器
      if (this.componentDetectionTimer !== undefined) {
        clearTimeout(this.componentDetectionTimer);
        this.componentDetectionTimer = undefined;
        LogUtils.d('KaraokeView: Cleared component detection timer');
      }

      // 移除所有事件监听器
      this.removeAllEventListeners();

      // 通过事件总线通知所有组件销毁
      this.eventBus.emit(LyricsEvents.DESTROY);
      this.eventBus.emit(ScoringEvents.DESTROY);
      this.eventBus.emit(KaraokeEvents.DESTROY);

      // 清理状态管理
      this.componentReadyStates.clear();
      this.integratedComponents.clear();
      this.karaokeReadyFired = false;

      // 清理事件监听器引用
      this.mKaraokeEvent = undefined;

      // 销毁日志系统
      LogUtils.destroy();

      LogUtils.d('KaraokeView: Destroy completed successfully');
    } catch (error) {
      LogUtils.e(`KaraokeView: Error during destroy: ${error}`);
    }
  }

  /**
   * 移除所有事件监听器
   */
  private removeAllEventListeners(): void {
    try {
      // 移除拖拽事件监听器
      this.eventBus.off(LyricsEvents.DRAG_START, this.dragStartListener);
      this.eventBus.off(LyricsEvents.DRAG_END, this.dragEndListener);

      // 移除组件ready事件监听器
      this.eventBus.off(LyricsEvents.COMPONENT_READY, this.lyricsComponentReadyListener);
      this.eventBus.off(ScoringEvents.COMPONENT_READY, this.scoringComponentReadyListener);
      this.eventBus.off(KaraokeEvents.COMPONENT_DETECTION, this.componentDetectionListener);

      LogUtils.d('KaraokeView: All event listeners removed');
    } catch (error) {
      LogUtils.e(`KaraokeView: Error removing event listeners: ${error}`);
    }
  }

  /**
   * 检查是否已销毁
   * @returns true if destroyed, false otherwise
   */
  getIsDestroyed(): boolean {
    return this.isDestroyed;
  }

  /**
   * 为所有公共方法添加销毁状态检查
   */
  private checkDestroyed(): boolean {
    if (this.isDestroyed) {
      LogUtils.w('KaraokeView: Operation called on destroyed instance');
      return true;
    }
    return false;
  }
}
