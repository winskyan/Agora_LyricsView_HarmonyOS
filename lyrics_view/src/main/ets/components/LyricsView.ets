import { LyricType } from '../constants/LyricType';
import { LyricMachine, OnLyricListener } from '../internal/LyricMachine';
import { LyricModel } from '../model/LyricModel';
import { LyricsLineModel, Tone } from '../model/LyricsLineModel';
import { EventBus, LyricsEvents } from '../utils/EventBus';
import { LogUtils } from '../utils/LogUtils';

/**
 * Interface for receiving lyrics seeking events.
 * Provides callbacks for tracking touch events and progress changes.
 */
export interface OnLyricsSeekListener {
  /**
   * Called when the lyrics progress changes during seeking.
   * @param progress Current progress in milliseconds
   */
  onProgressChanged(progress: number): void;

  /**
   * Called when the user starts dragging the lyrics.
   */
  onStartTrackingTouch(): void;

  /**
   * Called when the user stops dragging the lyrics.
   */
  onStopTrackingTouch(): void;
}

/**
 * A custom component for displaying karaoke lyrics with various visual effects.
 * Supports features like highlighting current line, scrolling animations,
 * line wrapping, and touch interactions for seeking.
 */
@Component
export struct LyricsView {
  // Core properties
  /** The lyrics state machine managing lyrics progression */
  @State private mLyricMachine: LyricMachine | null = null;
  /** Index of the currently displayed lyrics line */
  @State private mIndexOfCurrentLine: number = -1;
  /** Current timestamp in the lyrics playback */
  @State private mCurrentTime: number = 0;
  // Visual configuration properties (corresponding to attrs.xml)
  /** Text size for normal lyrics lines */
  @Prop textSize: number = 16;
  /** Text size for current line */
  @Prop currentLineTextSize: number = 20;
  /** Text color for current line's normal text */
  @Prop currentLineTextColor: string = '#FFFFFF';
  /** Text color for current line's highlighted portion */
  @Prop currentLineHighlightedTextColor: string = '#FF6B35';
  /** Text color for previous lyrics lines */
  @Prop previousLineTextColor: string = '#999999';
  /** Text color for upcoming lyrics lines */
  @Prop upcomingLineTextColor: string = '#999999';
  /** Vertical spacing between lyrics lines */
  @Prop lineSpacing: number = 12;
  /** Top padding for the entire lyrics view */
  @Prop paddingTop: number = 50;
  /** Text to display when no lyrics are available */
  @Prop labelWhenNoLyrics: string = '暂无歌词';
  /** Whether to enable automatic line wrapping for long lyrics */
  @Prop enableLineWrap: boolean = false;
  /** Whether dragging is enabled */
  @Prop enableDragging: boolean = false;
  /** Whether to show lyrics lines before the current line */
  @Prop enablePreviousLines: boolean = true;
  /** Whether to show lyrics lines after the current line */
  @Prop enableUpcomingLines: boolean = true;
  /** Whether to show the prelude end position indicator */
  @Prop enablePreludeEndPositionIndicator: boolean = true;
  /** Top padding for the prelude end position indicator */
  @Prop preludeEndPositionIndicatorPaddingTop: number = 20;
  /** Radius of the prelude end position indicator dots */
  @Prop preludeEndPositionIndicatorRadius: number = 4;
  /** Color of the prelude end position indicator */
  @Prop preludeEndPositionIndicatorColor: string = '#FF6B35';
  /** Horizontal alignment of lyrics text (0=center, 1=left, 2=right) */
  @Prop textGravity: number = 0;
  // Internal state
  @State private mDraggingInProgress: boolean = false;
  @State private mOffset: number = 0;
  @State private mForceUpdateUi: number = 1; // UPDATE_UI_TYPE_NORMAL
  @State private mCurrentLineTranslateX: number = 0;
  @State private mWidthRatio: number = 1.0;
  @State private targetIndex: number = 0;
  // Listener for lyrics seeking events
  private mOnSeekActionListener: OnLyricsSeekListener | null = null;
  // Event bus instance for global communication
  private eventBus: EventBus = EventBus.getInstance();
  // Update UI type constants
  private static readonly UPDATE_UI_TYPE_NO_NEED: number = 0;
  private static readonly UPDATE_UI_TYPE_NORMAL: number = 1;
  private static readonly UPDATE_UI_TYPE_WITH_ANIMATION: number = 2;

  /**
   * Bind lyrics drag event callback to receive state or event callbacks during dragging.
   * @param onSeekActionListener Callback for lyrics drag events
   */
  setSeekListener(onSeekActionListener: OnLyricsSeekListener): void {
    this.mOnSeekActionListener = onSeekActionListener;
  }

  /**
   * Set whether to allow vertical scrolling
   * @param enable true to enable vertical scrolling, false to disable
   */
  setEnableDragging(enable: boolean): void {
    LogUtils.d("setEnableDragging enable: " + enable);
    this.enableDragging = enable;
  }

  /**
   * Requests a refresh of the UI.
   * Updates the progress and triggers a redraw if necessary.
   */
  requestRefreshUi(): void {
    if (this.mLyricMachine) {
      this.updateByProgress(this.mLyricMachine.getCurrentLyricProgress());
    }
  }

  /**
   * Resets the view to its initial state.
   * Clears all loaded lyrics and internal state.
   */
  reset(): void {
    this.resetInternal();
  }

  /**
   * 完全重置，包括清理 LyricMachine 引用
   * 仅在组件销毁或需要完全清理时调用
   */
  resetCompletely(): void {
    this.mLyricMachine = null;
    this.resetInternal();
  }

  /**
   * Checks if the lyrics view is uninitialized or has no lyrics data.
   * @return true if lyrics are not available or not initialized
   */
  private uninitializedOrNoLyrics(): boolean {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    return !this.mLyricMachine || !lyricsModel ||
      !lyricsModel.lines || lyricsModel.lines.length === 0;
  }

  /**
   * Updates the view based on the current timestamp.
   * Handles line transitions and triggers animations when necessary.
   * @param timestamp Current playback position in milliseconds
   */
  private updateByProgress(timestamp: number): void {
    this.mCurrentTime = timestamp;
    const lyricsModel = this.mLyricMachine?.getLyricsModel();

    if (this.refreshNoLyrics()) {
      LogUtils.d('LyricsView: No lyrics available, showing no lyrics message');
      return;
    }

    const line = this.quickSearchLineByTimestamp(this.mCurrentTime);
    LogUtils.d(`LyricsView: Found line index=${line}, current line=${this.mIndexOfCurrentLine}`);

    if (line < 0 || !lyricsModel || line >= lyricsModel.lines.length) {
      LogUtils.d('LyricsView: Invalid line index, no UI update needed');
      this.mForceUpdateUi = LyricsView.UPDATE_UI_TYPE_NO_NEED;
      return;
    }

    if (line !== this.mIndexOfCurrentLine) {
      LogUtils.d(`LyricsView: Line changed from ${this.mIndexOfCurrentLine} to ${line}`);
      this.mForceUpdateUi = LyricsView.UPDATE_UI_TYPE_NORMAL | LyricsView.UPDATE_UI_TYPE_WITH_ANIMATION;
      this.mIndexOfCurrentLine = line;
      // 触发滚动到当前行
      this.scrollToCurrentLine();
    }
  }

  /**
   * 滚动到当前行，使其居中显示
   */
  private scrollToCurrentLine(): void {
    // 在HarmonyOS中，我们通过状态变化来触发滚动
    // 这里可以添加滚动逻辑，暂时通过UI更新来实现
  }

  /**
   * Refreshes the "No Lyrics" display state.
   * @return true if no lyrics are available and refresh was performed
   */
  private refreshNoLyrics(): boolean {
    return this.uninitializedOrNoLyrics();
  }

  /**
   * Performs binary search to find the lyrics line that should be displayed at the given timestamp.
   * @param time Current timestamp in milliseconds
   * @return Index of the lyrics line to display
   */
  private quickSearchLineByTimestamp(time: number): number {
    if (this.uninitializedOrNoLyrics()) {
      return 0;
    }

    let left = 0;
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (!lyricsModel) {
      return 0;
    }
    let right = lyricsModel.lines.length - 1;

    while (left <= right) {
      const middle = Math.floor((left + right) / 2);
      const middleTime = lyricsModel.lines[middle].getStartTime();

      if (time < middleTime) {
        right = middle - 1;
      } else {
        if (middle + 1 >= lyricsModel.lines.length ||
          time < lyricsModel.lines[middle + 1].getStartTime()) {
          return middle;
        }
        left = middle + 1;
      }
    }

    return 0;
  }

  /**
   * Resets all internal state variables to their default values.
   */
  private resetInternal(): void {
    // 注意：不要重置 mLyricMachine，因为它可能正在调用这个方法
    // this.mLyricMachine = null; // 移除这行，避免循环依赖
    // mLyricsModel removed - now using mLyricMachine.getLyricsModel()
    this.mIndexOfCurrentLine = -1;
    this.mForceUpdateUi = LyricsView.UPDATE_UI_TYPE_NORMAL;
    this.mCurrentTime = 0;
    this.mOffset = 0;
    this.targetIndex = 0;
    this.mCurrentLineTranslateX = 0;
  }

  /**
   * Set whether to enable automatic lyrics line wrapping
   * @param enable true to enable automatic line wrapping, false to use horizontal scrolling
   */
  setEnableLineWrap(enable: boolean): void {
    LogUtils.d("setEnableLineWrap enable:" + enable);
    if (this.enableLineWrap !== enable) {
      this.enableLineWrap = enable;
      this.forceCheckLineWrap();
      this.mForceUpdateUi = LyricsView.UPDATE_UI_TYPE_NORMAL;
    }
  }

  /**
   * Force check line wrap based on lyric type
   */
  private forceCheckLineWrap(): void {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (!lyricsModel || !lyricsModel.lines || lyricsModel.lines.length === 0) {
      return;
    }
    if (lyricsModel.type === LyricType.LRC) {
      this.enableLineWrap = true;
    }
  }

  /**
   * Renders the no lyrics state
   */
  @Builder
  NoLyricsBuilder() {
    Column() {
      Text(this.labelWhenNoLyrics)
        .fontSize(this.currentLineTextSize)
        .fontColor(this.currentLineHighlightedTextColor)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  /**
   * Determines if a tone should be highlighted based on current progress
   */
  private shouldHighlightTone(tone: Tone, progress: number): boolean {
    return progress >= tone.begin && progress < tone.end;
  }

  /**
   * Gets the complete text of a lyrics line
   */
  private getLineText(line: LyricsLineModel): string {
    if (line.tones && line.tones.length > 0) {
      return line.tones.map(tone => tone.word).join('');
    }
    return '';
  }

  /**
   * Gets the index of a lyrics line
   */
  private getLineIndex(line: LyricsLineModel): number {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (!lyricsModel || !lyricsModel.lines) {
      return -1;
    }
    return lyricsModel.lines.indexOf(line);
  }

  /**
   * Gets text alignment based on textGravity property
   */
  private getTextAlign(): TextAlign {
    switch (this.textGravity) {
      case 1:
        return TextAlign.Start; // left
      case 2:
        return TextAlign.End; // right
      default:
        return TextAlign.Center; // center
    }
  }

  /**
   * Gets the countdown value for prelude indicator
   */
  private getPreludeCountDown(): number {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (!lyricsModel) {
      return 0;
    }
    return Math.ceil((lyricsModel.preludeEndPosition - this.mCurrentTime) / 1000);
  }

  /**
   * 增强版歌词行Builder - 实现高亮、居中、滚动效果
   */
  @Builder
  EnhancedLyricsLineBuilder(line: LyricsLineModel, index: number) {
    Row() {
      Text() {
        if (line.tones && line.tones.length > 0) {
          // 当前行：显示唱过的部分为高亮，未唱的部分为正常颜色
          if (index === this.mIndexOfCurrentLine) {
            ForEach(line.tones, (tone: Tone, toneIndex: number) => {
              Span(tone.word)
                .fontSize(this.currentLineTextSize)
                .fontColor(this.getCurrentLineCharColor(tone))
                .fontWeight(FontWeight.Bold)
            })
          } else {
            // 非当前行：统一颜色显示
            ForEach(line.tones, (tone: Tone, toneIndex: number) => {
              Span(tone.word)
                .fontSize(this.textSize)
                .fontColor(this.getNormalLineColor(index))
            })
          }
        } else {
          // 如果没有音调数据，显示整行文本
          Span(this.getLineText(line))
            .fontSize(index === this.mIndexOfCurrentLine ? this.currentLineTextSize : this.textSize)
            .fontColor(index === this.mIndexOfCurrentLine ? this.currentLineTextColor : this.getNormalLineColor(index))
            .fontWeight(index === this.mIndexOfCurrentLine ? FontWeight.Bold : FontWeight.Normal)
        }
      }
      .textAlign(TextAlign.Center)
      .width('100%')
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({
      bottom: index === this.mIndexOfCurrentLine ? 16 : 8,
      top: index === this.mIndexOfCurrentLine ? 8 : 4
    })
    // 当前行添加背景效果
    .backgroundColor(index === this.mIndexOfCurrentLine ? 'rgba(255, 255, 255, 0.1)' : Color.Transparent)
    .borderRadius(8)
    .padding({
      left: 16,
      right: 16,
      top: index === this.mIndexOfCurrentLine ? 12 : 8,
      bottom: index === this.mIndexOfCurrentLine ? 12 : 8
    })
    // 添加动画效果
    .animation({
      duration: 300,
      curve: Curve.EaseInOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }

  /**
   * 获取当前行字符颜色（实现高亮逻辑）
   */
  private getCurrentLineCharColor(tone: Tone): string {
    // 当前行的高亮逻辑：唱过的部分全部高亮
    if (this.mCurrentTime >= tone.begin) {
      return this.currentLineHighlightedTextColor; // 高亮颜色
    } else {
      return this.currentLineTextColor; // 当前行正常颜色
    }
  }

  /**
   * 获取普通行颜色
   */
  private getNormalLineColor(index: number): string {
    if (index < this.mIndexOfCurrentLine) {
      return this.previousLineTextColor; // 已唱过的行
    } else {
      return this.upcomingLineTextColor; // 未唱的行
    }
  }

  /**
   * Renders the prelude end position indicator
   */
  @Builder
  PreludeIndicatorBuilder() {
    if (this.enablePreludeEndPositionIndicator && this.mLyricMachine?.getLyricsModel() &&
      this.getPreludeCountDown() > 0) {
      Row() {
        // Indicator 1
        Circle({
          width: this.preludeEndPositionIndicatorRadius * 2,
          height: this.preludeEndPositionIndicatorRadius * 2
        })
          .fill(this.preludeEndPositionIndicatorColor)

        if (this.getPreludeCountDown() >= 2) {
          // Indicator 2
          Circle({
            width: this.preludeEndPositionIndicatorRadius * 2,
            height: this.preludeEndPositionIndicatorRadius * 2
          })
            .fill(this.preludeEndPositionIndicatorColor)
            .margin({ left: this.preludeEndPositionIndicatorRadius * 2 })
        }

        if (this.getPreludeCountDown() >= 3) {
          // Indicator 3 (with blinking effect)
          Circle({
            width: this.preludeEndPositionIndicatorRadius * 2,
            height: this.preludeEndPositionIndicatorRadius * 2
          })
            .fill(this.preludeEndPositionIndicatorColor)
            .margin({ left: this.preludeEndPositionIndicatorRadius * 2 })
            .opacity((this.getPreludeCountDown() % 2 === 1 || this.mCurrentTime < 2000) ? 1 : 0)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: this.preludeEndPositionIndicatorPaddingTop })
    }
  }

  build() {
    Column() {
      // Prelude indicator
      this.PreludeIndicatorBuilder()

      // Main lyrics content
      if (this.uninitializedOrNoLyrics()) {
        this.NoLyricsBuilder()
      } else {
        Scroll() {
          Column() {
            if (this.mLyricMachine?.getLyricsModel()?.lines) {
              // 添加顶部空白，确保第一行可以居中显示
              Blank()
                .height(200)

              ForEach(this.mLyricMachine?.getLyricsModel()?.lines, (line: LyricsLineModel, index: number) => {
                this.EnhancedLyricsLineBuilder(line, index)
              })

              // 添加底部空白，确保最后一行可以居中显示
              Blank()
                .height(200)
            }
          }
          .width('100%')
          .padding({ top: this.paddingTop })
        }
        .width('100%')
        .height('100%')
        .scrollable(this.enableDragging ? ScrollDirection.Vertical : ScrollDirection.None)
        .scrollBar(BarState.Off) // 隐藏滚动条
        .onScrollFrameBegin((offset: number, state: ScrollState) => {
          if (this.enableDragging) {
            this.mOffset += offset;
          }
          return { offsetRemain: offset };
        })
        .onScrollStart(() => {
          if (this.enableDragging && this.mOnSeekActionListener) {
            this.mDraggingInProgress = true;
            this.mOnSeekActionListener.onStartTrackingTouch();
          }
        })
        .onScrollStop(() => {
          if (this.enableDragging && this.mOnSeekActionListener) {
            this.mDraggingInProgress = false;
            // Calculate target line based on scroll position
            if (this.mLyricMachine?.getLyricsModel()?.lines && this.targetIndex >= 0 &&
              this.targetIndex < this.mLyricMachine.getLyricsModel()!.lines.length) {
              const targetLine = this.mLyricMachine.getLyricsModel()!.lines[this.targetIndex];
              this.updateByProgress(targetLine.getStartTime());
              this.mOnSeekActionListener.onProgressChanged(targetLine.getStartTime());
              this.mOnSeekActionListener.onStopTrackingTouch();
            }
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .onAppear(() => {
      LogUtils.d('LyricsView: Component appeared, setting up event listeners');
      this.setupEventListeners();

      // 通知外部组件LyricsView已准备好
      setTimeout(() => {
        LogUtils.d('LyricsView: Ready for events');
      }, 10);
    })
    .onDisAppear(() => {
      LogUtils.d('LyricsView: Component disappearing, cleaning up');
      this.removeEventListeners();
      this.resetCompletely(); // 完全清理
    })
  }

  /**
   * 设置事件监听器
   */
  private setupEventListeners(): void {
    LogUtils.d('LyricsView: Setting up event listeners');

    // 初始化LyricMachine
    this.initLyricMachine();

    // 监听歌词数据设置事件
    const setLyricDataHandler = (lyricModel: LyricModel) => {
      if (this.mLyricMachine) {
        this.mLyricMachine.prepare(lyricModel);
        // mLyricsModel removed - data now managed by mLyricMachine
        this.forceCheckLineWrap();
        LogUtils.d(`LyricsView: Lyric data set successfully, getLyricsModel: ${!!this.mLyricMachine.getLyricsModel()}`);
      } else {
        LogUtils.e('LyricsView: mLyricMachine is null when receiving SET_LYRIC_DATA event');
      }
    };
    this.eventBus.on(LyricsEvents.SET_LYRIC_DATA, setLyricDataHandler);

    // 监听进度更新事件
    this.eventBus.on(LyricsEvents.SET_PROGRESS, (progress: number) => {
      LogUtils.d(`LyricsView: Received SET_PROGRESS event: ${progress}`);
      if (this.mLyricMachine) {
        this.mLyricMachine.setProgress(progress);
      }
    });

    // 监听重置事件
    this.eventBus.on(LyricsEvents.RESET, () => {
      LogUtils.d('LyricsView: Received RESET event');
      if (this.mLyricMachine) {
        this.mLyricMachine.reset();
      }
    });

    // 监听刷新UI事件
    this.eventBus.on(LyricsEvents.REQUEST_REFRESH, () => {
      LogUtils.d('LyricsView: Received REQUEST_REFRESH event');
      this.requestRefreshUi();
    });
  }

  /**
   * 移除事件监听器
   */
  private removeEventListeners(): void {
    LogUtils.d('LyricsView: Removing event listeners');
    // 这里可以添加具体的移除逻辑，但由于EventBus是单例，
    // 我们可能需要保存回调函数的引用来正确移除
  }

  /**
   * 初始化LyricMachine
   */
  private initLyricMachine(): void {
    // 创建LyricMachine并准备数据
    if (!this.mLyricMachine) {
      LogUtils.d('LyricsView: Creating new LyricMachine');

      // 创建一个简单的监听器实现
      class LyricListenerImpl implements OnLyricListener {
        private lyricsView: LyricsView;

        constructor(lyricsView: LyricsView) {
          this.lyricsView = lyricsView;
        }

        resetUi(): void {
          LogUtils.d('LyricsView: resetUi called');
          this.lyricsView.reset();
        }

        requestRefreshUi(): void {
          this.lyricsView.requestRefreshUi();
        }
      }

      const listener = new LyricListenerImpl(this);
      this.mLyricMachine = new LyricMachine(listener);
      LogUtils.d(`LyricsView: LyricMachine created successfully, initial ready state: ${this.mLyricMachine.isReady()}`);
    } else {
      LogUtils.d('LyricsView: LyricMachine already exists');
    }
  }
}
