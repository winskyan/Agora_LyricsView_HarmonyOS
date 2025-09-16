import { LyricType } from '../constants/LyricType';
import { LyricMachine } from '../internal/LyricMachine';
import { LyricModel } from '../model/LyricModel';
import { LyricsLineModel, Tone } from '../model/LyricsLineModel';
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
  /** The current lyrics model containing all lyrics data */
  @State private mLyricsModel: LyricModel | null = null;
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
   * Attaches a lyrics machine to this view.
   * The lyrics machine must be prepared before attaching.
   * @param machine The lyrics machine to attach
   */
  attachToLyricMachine(machine: LyricMachine): void {
    if (!machine.isReady()) {
      throw new Error("Must call LyricMachine.prepare before attaching");
    }
    this.mLyricMachine = machine;
    this.mLyricsModel = machine.getLyricsModel();
    this.forceCheckLineWrap();
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
   * Checks if the lyrics view is uninitialized or has no lyrics data.
   * @param machine The lyrics state machine to check
   * @return true if lyrics are not available or not initialized
   */
  private uninitializedOrNoLyrics(machine: LyricMachine | null): boolean {
    return !machine || !this.mLyricMachine || !this.mLyricsModel ||
      !this.mLyricsModel.lines || this.mLyricsModel.lines.length === 0;
  }

  /**
   * Updates the view based on the current timestamp.
   * Handles line transitions and triggers animations when necessary.
   * @param timestamp Current playback position in milliseconds
   */
  private updateByProgress(timestamp: number): void {
    this.mCurrentTime = timestamp;

    if (this.refreshNoLyrics()) {
      return;
    }

    const line = this.quickSearchLineByTimestamp(this.mCurrentTime);

    if (line < 0 || !this.mLyricsModel || line >= this.mLyricsModel.lines.length) {
      this.mForceUpdateUi = LyricsView.UPDATE_UI_TYPE_NO_NEED;
      return;
    }

    if (line !== this.mIndexOfCurrentLine) {
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
    return this.uninitializedOrNoLyrics(this.mLyricMachine);
  }

  /**
   * Performs binary search to find the lyrics line that should be displayed at the given timestamp.
   * @param time Current timestamp in milliseconds
   * @return Index of the lyrics line to display
   */
  private quickSearchLineByTimestamp(time: number): number {
    if (this.uninitializedOrNoLyrics(this.mLyricMachine) || !this.mLyricsModel) {
      return 0;
    }

    let left = 0;
    let right = this.mLyricsModel.lines.length - 1;

    while (left <= right) {
      const middle = Math.floor((left + right) / 2);
      const middleTime = this.mLyricsModel.lines[middle].getStartTime();

      if (time < middleTime) {
        right = middle - 1;
      } else {
        if (middle + 1 >= this.mLyricsModel.lines.length ||
          time < this.mLyricsModel.lines[middle + 1].getStartTime()) {
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
    this.mLyricMachine = null;
    this.mLyricsModel = null;
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
    if (!this.mLyricsModel || !this.mLyricsModel.lines || this.mLyricsModel.lines.length === 0) {
      return;
    }
    if (this.mLyricsModel.type === LyricType.LRC) {
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
    if (!this.mLyricsModel || !this.mLyricsModel.lines) {
      return -1;
    }
    return this.mLyricsModel.lines.indexOf(line);
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
    if (!this.mLyricsModel) {
      return 0;
    }
    return Math.ceil((this.mLyricsModel.preludeEndPosition - this.mCurrentTime) / 1000);
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
    if (this.enablePreludeEndPositionIndicator && this.mLyricsModel && this.getPreludeCountDown() > 0) {
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
      if (this.uninitializedOrNoLyrics(this.mLyricMachine)) {
        this.NoLyricsBuilder()
      } else {
        Scroll() {
          Column() {
            if (this.mLyricsModel && this.mLyricsModel.lines) {
              // 添加顶部空白，确保第一行可以居中显示
              Blank()
                .height(200)

              ForEach(this.mLyricsModel.lines, (line: LyricsLineModel, index: number) => {
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
            if (this.mLyricsModel && this.targetIndex >= 0 &&
              this.targetIndex < this.mLyricsModel.lines.length) {
              const targetLine = this.mLyricsModel.lines[this.targetIndex];
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
  }
}
