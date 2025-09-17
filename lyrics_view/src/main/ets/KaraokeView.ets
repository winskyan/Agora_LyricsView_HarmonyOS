import { IKaraokeEvent } from './IKaraokeEvent';
import { IScoringAlgorithm } from './internal/ScoringMachine';
import { LyricsParser } from './internal/parser/LyricsParser';
import { LyricModel } from './model/LyricModel';
import { EventBus, LyricsEvents, ScoringEvents } from './utils/EventBus';
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
   * 应用上下文 - HarmonyOS版本
   * 对应Android项目中的Context
   */
  private mContext?: Context;
  /**
   * 事件总线实例
   */
  private eventBus: EventBus = EventBus.getInstance();

  /**
   * 默认构造函数
   */
  constructor();

  /**
   * 构造函数 - 带上下文
   * @param context 应用上下文
   */
  constructor(context: Context);

  constructor(param1?: Context) {
    if (param1) {
      this.mContext = param1;
      LogUtils.d('KaraokeView created with Context');
    } else {
      LogUtils.d('KaraokeView created with default constructor');
    }
    this.initialize();
  }

  /**
   * 初始化卡拉OK组件，包括歌词和评分机器
   */
  private initialize(): void {
    LogUtils.d('KaraokeView initialize');
    // 启用日志功能（如果有上下文）
    if (this.mContext) {
      // 自动使用应用私有目录，类似Android的getExternalFilesDir
      LogUtils.enableLog(this.mContext, true, true);
    }

    // 设置拖拽事件监听
    this.setupDragEventListeners();
  }

  /**
   * 设置拖拽事件监听器
   */
  private setupDragEventListeners(): void {
    // 监听拖拽开始事件
    this.eventBus.on(LyricsEvents.DRAG_START, () => {
      LogUtils.d('KaraokeView: Drag start received');
    });

    // 监听拖拽结束事件
    this.eventBus.on(LyricsEvents.DRAG_END, (finalProgress: number) => {
      LogUtils.d(`KaraokeView: Drag end received: ${finalProgress}ms`);
      if (this.mKaraokeEvent) {
        this.mKaraokeEvent.onDragTo(finalProgress);
      }
    });
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
  setLyricData(model: LyricModel, usingInternalScoring: boolean = true): void {
    LogUtils.d(`KaraokeView setLyricData model lines:${model.lines.length} usingInternalScoring:${usingInternalScoring}`);
    // 通过事件总线通知组件
    this.eventBus.emit(LyricsEvents.SET_LYRIC_DATA, model);
    this.eventBus.emit(ScoringEvents.SET_LYRIC_DATA, model);
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
    if (speakerPitch < 0 || speakerPitch > 5000) {
      LogUtils.w(`Invalid speaker pitch: ${speakerPitch}, expected 0-5000 Hz`);
    }
    if (pitchScore < 0 || pitchScore > 100) {
      LogUtils.w(`Invalid pitch score: ${pitchScore}, expected 0.0-100.0`);
    }
    if (progressInMs < 0) {
      LogUtils.w(`Invalid progress: ${progressInMs}, expected >= 0`);
    }

    LogUtils.d(`setPitch speakerPitch:${speakerPitch.toFixed(2)}Hz, pitchScore:${pitchScore.toFixed(1)}%, progressInMs:${Math.floor(progressInMs)}ms`);
  }

  /**
   * Set current song progress (should be called every 20ms)
   * Note: Can be obtained from the player's current progress
   *
   * @param progress Current song progress in milliseconds
   */
  setProgress(progress: number): void {
    LogUtils.d(`KaraokeView:setProgress progress:${progress}`);
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
    LogUtils.d(`setKaraokeEvent event:${event}`);
    this.mKaraokeEvent = event;
  }

  /**
   * Set custom scoring algorithm
   *
   * @param algorithm Custom scoring algorithm implementation
   */
  setScoringAlgorithm(algorithm: IScoringAlgorithm): void {
    LogUtils.d(`setScoringAlgorithm algorithm:${algorithm}`);
  }

  /**
   * Set scoring difficulty level
   *
   * @param level Scoring difficulty level
   */
  setScoringLevel(level: number): void {
    LogUtils.d(`setScoringLevel level:${level}`);
  }

  // /**
  //  * Add custom logger
  //  *
  //  * @param logger Logger implementation to add
  //  */
  // addLogger(logger: any): void {
  //   // TODO: 实现日志记录器添加逻辑
  //   LogUtils.i('addLogger not implemented yet');
  // }
  //
  // /**
  //  * Remove custom logger
  //  *
  //  * @param logger Logger implementation to remove
  //  */
  // removeLogger(logger: any): void {
  //   // TODO: 实现日志记录器移除逻辑
  //   LogUtils.i('removeLogger not implemented yet');
  // }
  //
  // /**
  //  * Remove all custom loggers
  //  */
  // removeAllLogger(): void {
  //   // TODO: 实现移除所有日志记录器逻辑
  //   LogUtils.i('removeAllLogger not implemented yet');
  // }
}
