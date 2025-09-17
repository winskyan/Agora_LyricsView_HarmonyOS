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
  @Prop paddingTop: number = 5;
  /** Text to display when no lyrics are available */
  @Prop labelWhenNoLyrics: string = '暂无歌词';
  /** Whether to enable automatic line wrapping for long lyrics */
  @Prop enableLineWrap: boolean = false;
  /** Whether dragging is enabled */
  @Prop enableDragging: boolean = true;
  /** Whether to show lyrics lines before the current line */
  @Prop enablePreviousLines: boolean = true;
  /** Whether to show lyrics lines after the current line */
  @Prop enableUpcomingLines: boolean = true;
  /** Whether to show the prelude end position indicator */
  @Prop enablePreludeEndPositionIndicator: boolean = true;
  /** Top padding for the prelude end position indicator */
  @Prop preludeEndPositionIndicatorPaddingTop: number = 3;
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
  // Actual component height measured dynamically
  @State private actualViewHeight: number = 400; // 默认值，会被实际测量值覆盖
  // 动画状态管理
  @State private isAnimating: boolean = false;
  @State private animationKey: number = 0; // 用于强制重新渲染动画
  @State private previousLineIndex: number = -1; // 记录上一行索引，用于动画判断
  @State private transitioningFromIndex: number = -1; // 正在过渡的原当前行索引
  @State private transitioningFromY: number = 0; // 过渡行的起始Y位置
  @State private transitioningToY: number = 0; // 过渡行的目标Y位置
  @State private newCurrentTransitioning: boolean = false; // 新当前行是否正在过渡
  @State private newCurrentFromY: number = 0; // 新当前行的起始Y位置
  @State private newCurrentToY: number = 0; // 新当前行的目标Y位置
  @State private styleTransitioning: boolean = false; // 样式是否正在过渡
  // Scroll controller for auto-scrolling
  private scroller: Scroller = new Scroller();
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

    if (line < 0 || !lyricsModel || line >= lyricsModel.lines.length) {
      LogUtils.d('LyricsView: Invalid line index, no UI update needed');
      this.mForceUpdateUi = LyricsView.UPDATE_UI_TYPE_NO_NEED;
      return;
    }

    if (line !== this.mIndexOfCurrentLine) {
      LogUtils.d(`LyricsView: Line changed from ${this.mIndexOfCurrentLine} to ${line}`);

      // 触发行变化动画
      this.triggerLineChangeAnimation(this.mIndexOfCurrentLine, line);

      this.previousLineIndex = this.mIndexOfCurrentLine;
      this.mIndexOfCurrentLine = line;
      this.mForceUpdateUi = LyricsView.UPDATE_UI_TYPE_NORMAL | LyricsView.UPDATE_UI_TYPE_WITH_ANIMATION;

      LogUtils.d(`LyricsView: Current line updated to ${line}, animation triggered`);
    }
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
    this.mForceUpdateUi = LyricsView.UPDATE_UI_TYPE_NORMAL;
    this.mCurrentTime = 0;
    this.mOffset = 0;
    this.targetIndex = 0;
    this.mCurrentLineTranslateX = 0;
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
   * 触发行变化动画
   */
  private triggerLineChangeAnimation(fromLine: number, toLine: number): void {
    if (fromLine === toLine) {
      return;
    }

    this.isAnimating = true;
    this.transitioningFromIndex = fromLine; // 记录原当前行
    this.newCurrentTransitioning = true; // 新当前行开始过渡
    this.styleTransitioning = false; // 样式过渡稍后开始

    const lineHeight = this.getLineHeight();
    const centerY = (this.actualViewHeight / 2) - (lineHeight / 2);

    // === 原当前行过渡设置 ===
    const oldCurrentIndex = fromLine;
    const offsetFromOldCurrent = fromLine - oldCurrentIndex; // 应该是0
    this.transitioningFromY = centerY + (offsetFromOldCurrent * lineHeight);

    // 计算原当前行的目标位置（基于新的当前行索引）
    const newCurrentIndex = toLine;
    const offsetFromNewCurrent = fromLine - newCurrentIndex; // 通常是-1（上一行）
    const oldTargetY = centerY + (offsetFromNewCurrent * lineHeight);

    // 先设置为起始位置
    this.transitioningToY = this.transitioningFromY;

    // === 新当前行过渡设置 ===
    // 新当前行从下一行位置开始
    const offsetFromNewCurrentToNext = 1; // 下一行
    this.newCurrentFromY = centerY + (offsetFromNewCurrentToNext * lineHeight);
    this.newCurrentToY = this.newCurrentFromY; // 先设置为起始位置

    this.animationKey = Date.now(); // 更新动画键值，强制重新渲染

    // 延迟一帧后开始位置动画
    setTimeout(() => {
      if (this.isAnimating) {
        // 原当前行移动到上一行
        this.transitioningToY = oldTargetY;
        // 新当前行移动到中心
        this.newCurrentToY = centerY;
      }
    }, 16);

    // 位置动画开始后很快开始样式过渡，创造重叠效果
    setTimeout(() => {
      if (this.isAnimating) {
        this.styleTransitioning = true; // 开始样式过渡
      }
    }, 150); // 位置动画开始150ms后开始样式过渡

    // 动画完成后清除状态
    setTimeout(() => {
      this.isAnimating = false;
      this.transitioningFromIndex = -1; // 清除过渡状态
      this.newCurrentTransitioning = false; // 清除新当前行过渡状态
      this.styleTransitioning = false; // 清除样式过渡状态
    }, 500); // 总动画时长：150ms延迟 + 300ms样式动画 + 50ms缓冲
  }

  /**
   * 计算行动画延迟（错开动画）
   */
  private getAnimationDelay(index: number): number {
    if (!this.isAnimating) {
      return 0; // 非动画状态时无延迟
    }

    const distance = Math.abs(index - this.mIndexOfCurrentLine);
    // 当前行无延迟，其他行根据距离递增延迟
    if (distance === 0) {
      return 0; // 当前行立即开始动画
    } else {
      // 距离越远延迟越大，但使用更小的增量避免过长延迟
      return Math.min(distance * 15, 80); // 最大80ms延迟
    }
  }

  /**
   * 计算歌词行的Y位置
   */
  private calculateLineYPosition(index: number): number {
    const offsetFromCurrent = index - this.mIndexOfCurrentLine;
    const lineHeight = this.getLineHeight();
    // 当前行在视图中心，其他行相对偏移
    const centerY = (this.actualViewHeight / 2) - (lineHeight / 2); // 减去行高的一半，确保行居中
    return centerY + (offsetFromCurrent * lineHeight);
  }

  /**
   * 计算歌词行高度
   */
  private getLineHeight(): number {
    return this.currentLineTextSize + this.lineSpacing;
  }

  /**
   * 计算可以显示的最大行数（上下各一半）
   */
  private getMaxVisibleLines(): number {
    const lineHeight = this.getLineHeight();
    const availableHeight = this.actualViewHeight;
    return Math.floor(availableHeight / lineHeight);
  }

  /**
   * 判断歌词行是否在可视范围内
   */
  private isLineVisible(index: number): boolean {
    const offsetFromCurrent = Math.abs(index - this.mIndexOfCurrentLine);
    const maxVisibleLines = this.getMaxVisibleLines();
    // 限制显示范围：当前行上下各显示一定数量的行
    const maxOffset = Math.floor(maxVisibleLines / 2);
    return offsetFromCurrent <= maxOffset;
  }

  /**
   * 渐进式高亮歌词行Builder - 实现卡拉OK风格的流畅高亮效果
   */
  @Builder
  EnhancedLyricsLineBuilder(line: LyricsLineModel, index: number) {
    // 渲染所有行，但使用透明度控制可见性，确保动画连续性
    if (index === this.mIndexOfCurrentLine && this.newCurrentTransitioning) {
      // 新当前行正在过渡：使用新当前行过渡效果
      this.NewCurrentLineTransitionBuilder(line, index)
    } else if (index === this.mIndexOfCurrentLine) {
      // 当前行：使用渐进式高亮效果
      this.ProgressiveHighlightLineBuilder(line, index)
    } else if (index === this.transitioningFromIndex && this.isAnimating) {
      // 正在过渡的原当前行：使用过渡高亮效果
      this.TransitioningHighlightLineBuilder(line, index)
    } else {
      // 非当前行：普通显示
      this.NormalLineBuilder(line, index)
    }
  }

  /**
   * 渐进式高亮行Builder
   */
  @Builder
  ProgressiveHighlightLineBuilder(line: LyricsLineModel, index: number) {
    Stack() {
      // 背景文字（正常颜色）
      Row() {
        Text(this.getLineText(line))
          .fontSize(this.currentLineTextSize)
          .fontColor(this.currentLineTextColor)
          .fontWeight(FontWeight.Bold)
          .textAlign(this.getTextAlign())
          .width('100%')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      // 高亮文字（使用clip实现渐进效果）
      Row() {
        Text(this.getLineText(line))
          .fontSize(this.currentLineTextSize)
          .fontColor(this.currentLineHighlightedTextColor)
          .fontWeight(FontWeight.Bold)
          .textAlign(this.getTextAlign())
          .width('100%')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .clip(true)
      .clipShape(new Rect({
        width: `${this.calculateLineProgress(line) * 100}%`,
        height: '100%'
      }))
      .animation({
        duration: 50, // 更快的高亮响应
        curve: Curve.Linear,
        iterations: 1,
        playMode: PlayMode.Normal
      })
    }
    .width('100%')
    .height(this.getLineHeight())
    .position({ x: 0, y: this.calculateLineYPosition(index) })
    .opacity(this.getLineOpacity(index))
    .scale({
      x: this.getLineScale(index),
      y: this.getLineScale(index)
    })
    .animation({
      duration: 400, // 统一动画时长
      delay: this.getAnimationDelay(index), // 错开动画延迟
      curve: Curve.EaseInOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }

  /**
   * 过渡普通行Builder - 处理原当前行以普通行样式从当前位置移动到目标位置
   */
  @Builder
  TransitioningHighlightLineBuilder(line: LyricsLineModel, index: number) {
    // 直接显示为普通行，不显示高亮效果
    Row() {
      Text(this.getLineText(line))
        .fontSize(this.textSize) // 使用普通行字体大小
        .fontColor(this.getNormalLineColor(index)) // 使用普通行颜色
        .fontWeight(FontWeight.Normal) // 使用普通行字重
        .textAlign(this.getTextAlign())
        .width('100%')
    }
    .width('100%')
    .height(this.getLineHeight())
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .position({
      x: 0,
      y: this.getTransitioningYPosition() // 使用动画插值位置
    })
    .opacity(this.getLineOpacity(index))
    .scale({
      x: this.getTransitioningLineScale(index),
      y: this.getTransitioningLineScale(index)
    })
    .animation({
      duration: 400, // 位置和缩放动画
      curve: Curve.EaseInOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }

  /**
   * 新当前行过渡Builder - 处理从下一行位置移动到中心并变为高亮样式
   */
  @Builder
  NewCurrentLineTransitionBuilder(line: LyricsLineModel, index: number) {
    Stack() {
      // 背景文字（平滑过渡样式）
      Row() {
        Text(this.getLineText(line))
          .fontSize(this.getTransitioningFontSize())
          .fontColor(this.getTransitioningTextColor())
          .fontWeight(this.getTransitioningFontWeight())
          .textAlign(this.getTextAlign())
          .width('100%')
          .animation({
            duration: 300, // 样式过渡动画
            curve: Curve.EaseInOut,
            iterations: 1,
            playMode: PlayMode.Normal
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      // 高亮文字（渐进显示）
      if (this.styleTransitioning) {
        Row() {
          Text(this.getLineText(line))
            .fontSize(this.currentLineTextSize)
            .fontColor(this.currentLineHighlightedTextColor)
            .fontWeight(FontWeight.Bold)
            .textAlign(this.getTextAlign())
            .width('100%')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .clip(true)
        .clipShape(new Rect({
          width: `${this.calculateLineProgress(line) * 100}%`,
          height: '100%'
        }))
        .opacity(this.getHighlightOpacity())
        .animation({
          duration: 300, // 高亮渐入动画
          curve: Curve.EaseInOut,
          iterations: 1,
          playMode: PlayMode.Normal
        })
      }
    }
    .width('100%')
    .height(this.getLineHeight())
    .position({
      x: 0,
      y: this.getNewCurrentYPosition() // 使用新当前行的位置
    })
    .opacity(this.getLineOpacity(index))
    .scale({
      x: this.getNewCurrentScale(),
      y: this.getNewCurrentScale()
    })
    .animation({
      duration: 400, // 位置和缩放动画
      curve: Curve.EaseInOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }

  /**
   * 普通行Builder
   */
  @Builder
  NormalLineBuilder(line: LyricsLineModel, index: number) {
    Row() {
      Text(this.getLineText(line))
        .fontSize(this.textSize)
        .fontColor(this.getNormalLineColor(index))
        .fontWeight(FontWeight.Normal)
        .textAlign(this.getTextAlign())
        .width('100%')
    }
    .width('100%')
    .height(this.getLineHeight())
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .position({ x: 0, y: this.calculateLineYPosition(index) })
    .opacity(this.getLineOpacity(index))
    .scale({
      x: this.getLineScale(index),
      y: this.getLineScale(index)
    })
    .animation({
      duration: 400, // 统一动画时长，与高亮行保持一致
      delay: this.getAnimationDelay(index), // 错开动画延迟
      curve: Curve.EaseInOut,
      iterations: 1,
      playMode: PlayMode.Normal
    })
  }

  /**
   * 计算当前行的高亮进度（0-1之间）
   */
  private calculateLineProgress(line: LyricsLineModel): number {
    if (!line.tones || line.tones.length === 0) {
      return 0;
    }

    const lineStartTime = line.getStartTime();
    const lineEndTime = line.getEndTime();

    if (this.mCurrentTime < lineStartTime) {
      return 0;
    } else if (this.mCurrentTime >= lineEndTime) {
      return 1;
    } else {
      return (this.mCurrentTime - lineStartTime) / (lineEndTime - lineStartTime);
    }
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
   * 计算行的透明度（基于距离当前行的远近）
   */
  private getLineOpacity(index: number): number {
    const distance = Math.abs(index - this.mIndexOfCurrentLine);
    const maxVisibleLines = this.getMaxVisibleLines();
    const maxDistance = Math.floor(maxVisibleLines / 2);

    if (distance === 0) {
      return 1.0; // 当前行完全不透明
    } else if (distance <= maxDistance) {
      // 使用更平滑的透明度渐变
      const fadeRatio = distance / maxDistance;
      return Math.max(0.2, 1.0 - (fadeRatio * 0.7)); // 从1.0渐变到0.3
    } else if (distance <= maxDistance + 1) {
      // 边界行使用很低的透明度，确保平滑过渡
      return 0.1;
    } else {
      return 0.0; // 超出范围的行完全透明
    }
  }

  /**
   * 计算行的缩放比例
   */
  private getLineScale(index: number): number {
    if (index === this.mIndexOfCurrentLine) {
      return 1.1; // 当前行稍微放大，突出显示
    } else {
      const distance = Math.abs(index - this.mIndexOfCurrentLine);
      // 距离当前行越远，缩放越小，但保持最小值
      return Math.max(0.95, 1.0 - (distance * 0.03));
    }
  }

  /**
   * 计算过渡行的缩放比例
   */
  private getTransitioningLineScale(index: number): number {
    // 过渡行直接使用目标位置的缩放比例（普通行大小）
    const distance = Math.abs(index - this.mIndexOfCurrentLine);
    return Math.max(0.95, 1.0 - (distance * 0.03));
  }

  /**
   * 获取过渡行的Y位置（使用动画插值）
   */
  private getTransitioningYPosition(): number {
    // 初始时返回起始位置，动画会自动插值到目标位置
    return this.transitioningToY;
  }

  /**
   * 获取新当前行的Y位置
   */
  private getNewCurrentYPosition(): number {
    return this.newCurrentToY;
  }

  /**
   * 获取新当前行的缩放比例
   */
  private getNewCurrentScale(): number {
    if (this.styleTransitioning) {
      return 1.1; // 样式过渡时使用当前行缩放
    } else {
      return 1.0; // 位置过渡时使用普通行缩放
    }
  }

  /**
   * 获取高亮层的透明度
   */
  private getHighlightOpacity(): number {
    return this.styleTransitioning ? 1.0 : 0.0;
  }

  /**
   * 获取过渡中的字体大小
   */
  private getTransitioningFontSize(): number {
    if (this.styleTransitioning) {
      return this.currentLineTextSize; // 过渡到当前行字体大小
    } else {
      return this.textSize; // 开始时使用普通行字体大小
    }
  }

  /**
   * 获取过渡中的文字颜色
   */
  private getTransitioningTextColor(): string {
    if (this.styleTransitioning) {
      return this.currentLineTextColor; // 过渡到当前行颜色
    } else {
      return this.upcomingLineTextColor; // 开始时使用未唱行颜色
    }
  }

  /**
   * 获取过渡中的字体粗细
   */
  private getTransitioningFontWeight(): FontWeight {
    if (this.styleTransitioning) {
      return FontWeight.Bold; // 过渡到当前行字重
    } else {
      return FontWeight.Normal; // 开始时使用普通行字重
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
        // 使用 Stack 来支持绝对定位
        Stack() {
          if (this.mLyricMachine?.getLyricsModel()?.lines) {
            ForEach(this.mLyricMachine?.getLyricsModel()?.lines, (line: LyricsLineModel, index: number) => {
              this.EnhancedLyricsLineBuilder(line, index)
            })
          }
        }
        .width('100%')
        .height('100%')
        .alignContent(Alignment.TopStart) // 从顶部开始定位
      }
    }
    .width('100%')
    .height('90%')
    .margin({ top: this.paddingTop })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      // 动态获取组件实际高度
      if (newValue.height && typeof newValue.height === 'number') {
        this.actualViewHeight = newValue.height;
        LogUtils.d(`LyricsView: Component height measured: ${this.actualViewHeight}`);
        // 高度变化后，位置会自动重新计算，不需要手动滚动
      }
    })
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
