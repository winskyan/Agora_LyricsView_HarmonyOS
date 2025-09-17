import { LyricType } from '../constants/LyricType';
import { LyricMachine, OnLyricListener } from '../internal/LyricMachine';
import { LyricModel } from '../model/LyricModel';
import { LyricsLineModel, Tone } from '../model/LyricsLineModel';
import { EventBus, LyricsEvents } from '../utils/EventBus';
import { LogUtils } from '../utils/LogUtils';

/**
 * 物理显示行接口
 * 表示一个逻辑歌词行分割后的物理显示行
 */
interface DisplayLine {
  text: string;
  tones: Tone[];
  startTime: number;
  endTime: number;
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
  // 横向滚动相关状态
  @State private mLastRightOfRectClip: number = 0; // 上次高亮区域的右边界
  @State private mRectClipWidth: number = 0; // 当前高亮区域宽度
  // Actual component dimensions measured dynamically
  @State private actualViewHeight: number = 400; // 默认值，会被实际测量值覆盖
  @State private actualViewWidth: number = 300; // 默认值，会被实际测量值覆盖
  // 拖拽相关状态
  @State private dragOffset: number = 0; // 拖拽偏移量
  @State private initialTouchY: number = 0; // 初始触摸Y坐标
  @State private currentTouchY: number = 0; // 当前触摸Y坐标
  @State private dragLineOffset: number = 0; // 拖拽时的歌词行偏移量
  @State private originalCurrentLineIndex: number = -1; // 拖拽开始时的原始当前行索引
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
  // 文本滚动相关状态
  @State private textScrollOffset: number = 0; // 当前文本滚动偏移
  @State private isTextScrolling: boolean = false; // 是否正在滚动文本
  @State private textScrollTimer: number = -1; // 文本滚动定时器
  // Scroll controller for auto-scrolling
  private scroller: Scroller = new Scroller();
  // Text scroll controller for horizontal scrolling
  private textScroller: Scroller = new Scroller();
  // 当前行的滚动偏移状态（用于调试日志）
  @State private currentLineScrollOffset: number = 0;
  // Event bus instance for global communication
  private eventBus: EventBus = EventBus.getInstance();
  // Update UI type constants
  private static readonly UPDATE_UI_TYPE_NO_NEED: number = 0;
  private static readonly UPDATE_UI_TYPE_NORMAL: number = 1;
  private static readonly UPDATE_UI_TYPE_WITH_ANIMATION: number = 2;

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

      // 停止之前行的文本滚动
      this.stopTextScrollAnimation();

      // 触发行变化动画
      this.triggerLineChangeAnimation(this.mIndexOfCurrentLine, line);

      this.previousLineIndex = this.mIndexOfCurrentLine;
      this.mIndexOfCurrentLine = line;
      this.mForceUpdateUi = LyricsView.UPDATE_UI_TYPE_NORMAL | LyricsView.UPDATE_UI_TYPE_WITH_ANIMATION;

      // 启动新当前行的文本滚动
      const lyricsModel = this.mLyricMachine?.getLyricsModel();
      if (lyricsModel && lyricsModel.lines && line >= 0 && line < lyricsModel.lines.length) {
        this.startTextScrollAnimation(lyricsModel.lines[line]);
      }

      LogUtils.d(`LyricsView: Current line updated to ${line}, animation triggered`);
    }

    // 横向滚动现在由startTextScrollAnimation的定时器处理，无需在这里额外检查
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
    this.mLastRightOfRectClip = 0;
    this.mRectClipWidth = 0;

    // 停止文本滚动动画
    this.stopTextScrollAnimation();

    LogUtils.d(`LyricsView: 🔄 resetInternal called - currentLineScrollOffset reset to: ${this.currentLineScrollOffset}`);
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
        .textAlign(this.getTextAlign())
    }
    .width('100%')
    .height('100%')
    .justifyContent(this.getRowJustifyContent())
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
   * 根据textGravity获取Row的对齐方式
   */
  private getRowJustifyContent(): FlexAlign {
    switch (this.textGravity) {
      case 1:
        return FlexAlign.Start; // left
      case 2:
        return FlexAlign.End; // right
      default:
        return FlexAlign.Center; // center
    }
  }

  /**
   * 根据textGravity获取Alignment对齐方式
   */
  private getAlignment(): Alignment {
    switch (this.textGravity) {
      case 1:
        return Alignment.Start; // left
      case 2:
        return Alignment.End; // right
      default:
        return Alignment.Center; // center
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

    LogUtils.d(`LyricsView: 🎬 Animation state set - isAnimating: ${this.isAnimating}, transitioningFromIndex: ${this.transitioningFromIndex}, newCurrentTransitioning: ${this.newCurrentTransitioning}, mIndexOfCurrentLine: ${this.mIndexOfCurrentLine}`);

    // 记录组件选择逻辑
    LogUtils.d(`LyricsView: 🎭 Component selection - Line ${this.transitioningFromIndex} will use TransitioningHighlightLineBuilder`);
    LogUtils.d(`LyricsView: 🎭 Component selection - Line ${this.mIndexOfCurrentLine} will use NewCurrentLineTransitionBuilder (newCurrentTransitioning: ${this.newCurrentTransitioning})`);

    const lineHeight = this.getLineHeight();
    const centerY = (this.actualViewHeight / 2) - (lineHeight / 2);

    // === 原当前行过渡设置 ===
    // 原当前行从中心位置开始
    this.transitioningFromY = centerY;

    // 计算原当前行的目标位置
    // 原当前行(fromLine)在新布局中应该位于上一行位置
    // 上一行位置 = 中心位置 - 一个行高
    const oldTargetY = centerY - lineHeight;

    LogUtils.d(`LyricsView: 🎬 Animation START - fromLine: ${fromLine}, toLine: ${toLine}, centerY: ${centerY}, lineHeight: ${lineHeight}, oldTargetY: ${oldTargetY}`);

    // 设置起始位置
    this.transitioningFromY = centerY; // 过渡行起始位置：中心
    this.newCurrentFromY = centerY + lineHeight; // 新当前行起始位置：下一行

    // 设置目标位置
    this.transitioningToY = oldTargetY; // 过渡行目标位置：上一行
    this.newCurrentToY = centerY; // 新当前行目标位置：中心

    this.animationKey = Date.now(); // 更新动画键值，强制重新渲染

    LogUtils.d(`LyricsView: 📍 Position setup - Transitioning: ${this.transitioningFromY} -> ${this.transitioningToY} (diff: ${this.transitioningToY -
    this.transitioningFromY})`);
    LogUtils.d(`LyricsView: 📍 Position setup - NewCurrent: ${this.newCurrentFromY} -> ${this.newCurrentToY} (diff: ${this.newCurrentToY -
    this.newCurrentFromY})`);
    LogUtils.d(`LyricsView: ⏰ Animation key set to: ${this.animationKey}`);

    // 位置动画开始后很快开始样式过渡，创造重叠效果
    setTimeout(() => {
      if (this.isAnimating) {
        this.styleTransitioning = true; // 开始样式过渡
      }
    }, 150); // 位置动画开始150ms后开始样式过渡

    // 动画完成后清除状态
    setTimeout(() => {
      LogUtils.d(`LyricsView: 🏁 Animation END - Clearing animation states`);
      this.isAnimating = false;
      this.transitioningFromIndex = -1; // 清除过渡状态
      this.newCurrentTransitioning = false; // 清除新当前行过渡状态
      this.styleTransitioning = false; // 清除样式过渡状态
      LogUtils.d(`LyricsView: 🏁 Animation states cleared - Line ${this.mIndexOfCurrentLine} now using ProgressiveHighlightLineBuilder`);
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
   * 计算歌词行的Y位置（简化版本，使用基本间距）
   */
  private calculateLineYPosition(index: number): number {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (!lyricsModel || !lyricsModel.lines || index < 0 || index >= lyricsModel.lines.length) {
      return 0;
    }

    // 统一的位置计算逻辑
    let currentLineIndex = this.mIndexOfCurrentLine;
    let additionalOffset = 0;

    // 获取当前行的实际高度用于居中计算
    const currentLine = lyricsModel.lines[currentLineIndex];
    const currentLineHeight = currentLine ?
    this.getDynamicLineHeight(currentLine, this.currentLineTextSize) :
    this.getLineHeight();
    const centerY = (this.actualViewHeight / 2) - (currentLineHeight / 2);

    if (this.mDraggingInProgress && this.originalCurrentLineIndex >= 0) {
      // 拖拽时：使用原始当前行作为基准，加上拖拽偏移
      currentLineIndex = this.originalCurrentLineIndex;
      additionalOffset = this.dragLineOffset * currentLineHeight;

      // 调试信息：输出位置计算详情
      if (index < 5) {
        LogUtils.d(`LyricsView: Drag calc - Line ${index}, originalIndex: ${this.originalCurrentLineIndex}, dragOffset: ${this.dragLineOffset}, additionalOffset: ${additionalOffset.toFixed(1)}`);
      }
    }

    // 动态位置计算：累积每行的实际高度
    let yPosition = centerY;

    if (index === currentLineIndex) {
      // 当前行：在中心位置
      yPosition = centerY + additionalOffset;
      LogUtils.d(`LyricsView: 📐 calculateLineYPosition - Line ${index} (CURRENT): centerY=${centerY.toFixed(1)}, additionalOffset=${additionalOffset.toFixed(1)}, result=${yPosition.toFixed(1)}`);
    } else if (index < currentLineIndex) {
      // 上方的行：累积计算向上的偏移
      let totalOffset = 0;
      for (let i = currentLineIndex - 1; i >= index; i--) {
        const line = lyricsModel.lines[i];
        if (line) {
          const lineHeight = this.getDynamicLineHeight(line, this.textSize);
          totalOffset += lineHeight;
        }
      }
      yPosition = centerY - totalOffset + additionalOffset;
      LogUtils.d(`LyricsView: 📐 calculateLineYPosition - Line ${index} (ABOVE): centerY=${centerY.toFixed(1)}, totalOffset=${totalOffset.toFixed(1)}, additionalOffset=${additionalOffset.toFixed(1)}, result=${yPosition.toFixed(1)}`);
    } else {
      // 下方的行：累积计算向下的偏移
      let totalOffset = currentLineHeight; // 从当前行底部开始
      for (let i = currentLineIndex + 1; i <= index; i++) {
        const line = lyricsModel.lines[i];
        if (line) {
          const lineHeight = this.getDynamicLineHeight(line, this.textSize);
          if (i === index) {
            // 目标行：不加上自己的高度，因为yPosition是顶部位置
            break;
          }
          totalOffset += lineHeight;
        }
      }
      yPosition = centerY + totalOffset + additionalOffset;
      LogUtils.d(`LyricsView: 📐 calculateLineYPosition - Line ${index} (BELOW): centerY=${centerY.toFixed(1)}, totalOffset=${totalOffset.toFixed(1)}, additionalOffset=${additionalOffset.toFixed(1)}, result=${yPosition.toFixed(1)}`);
    }

    // 添加边界检查，确保歌词行不会完全移出视图
    const targetLine = lyricsModel.lines[index];
    const targetLineHeight = targetLine ?
    this.getDynamicLineHeight(targetLine,
      index === this.mIndexOfCurrentLine ? this.currentLineTextSize : this.textSize) :
    this.getLineHeight();

    const minY = -targetLineHeight * 0.5;
    const maxY = this.actualViewHeight + targetLineHeight * 0.5;

    const clampedY = Math.max(minY, Math.min(maxY, yPosition));

    // 如果位置被限制了，输出调试信息
    if (this.mDraggingInProgress && Math.abs(clampedY - yPosition) > 1) {
      LogUtils.d(`LyricsView: Line ${index} position clamped from ${yPosition.toFixed(1)} to ${clampedY.toFixed(1)}`);
    }

    return clampedY;
  }

  /**
   * 计算歌词行高度
   */
  private getLineHeight(): number {
    return this.currentLineTextSize + this.lineSpacing;
  }

  /**
   * 动态计算特定歌词行的实际显示高度
   * 只有当文本真的需要多行时才增加高度
   */
  private getDynamicLineHeight(line: LyricsLineModel, fontSize: number): number {
    if (!this.shouldEnableLineWrap() || !line) {
      return fontSize + this.lineSpacing;
    }

    const text = this.getLineText(line);
    if (!text || text.length === 0) {
      return fontSize + this.lineSpacing;
    }

    // 估算文本宽度
    const textWidth = this.measureTextWidth(text, fontSize);
    const availableWidth = this.actualViewWidth;

    if (availableWidth <= 0 || textWidth <= availableWidth) {
      // 一行就能显示完，使用标准行高
      return fontSize + this.lineSpacing;
    } else {
      // 需要多行显示，计算实际需要的行数
      const estimatedLines = Math.ceil(textWidth / availableWidth);
      const actualLines = Math.min(estimatedLines, 3); // 最多3行
      return (fontSize * actualLines) + this.lineSpacing;
    }
  }

  /**
   * 将歌词行按显示宽度分割成多个物理行
   */
  private splitLineIntoDisplayLines(line: LyricsLineModel, fontSize: number): DisplayLine[] {
    if (!this.shouldEnableLineWrap() || !line || !line.tones || line.tones.length === 0) {
      return [{
        text: this.getLineText(line),
        tones: line.tones || [],
        startTime: line.getStartTime(),
        endTime: line.getEndTime()
      }];
    }

    const availableWidth = this.actualViewWidth;
    if (availableWidth <= 0) {
      return [{
        text: this.getLineText(line),
        tones: line.tones || [],
        startTime: line.getStartTime(),
        endTime: line.getEndTime()
      }];
    }

    const result: DisplayLine[] = [];
    let currentLineText = '';
    let currentLineTones: Tone[] = [];
    let currentLineStartTime = line.getStartTime();
    let currentLineEndTime = line.getStartTime();

    for (let i = 0; i < line.tones.length; i++) {
      const tone = line.tones[i];
      const testText = currentLineText + tone.word;
      const testWidth = this.measureTextWidth(testText, fontSize);

      if (testWidth <= availableWidth || currentLineText === '') {
        // 当前行还能容纳这个字符，或者这是第一个字符
        currentLineText += tone.word;
        currentLineTones.push(tone);
        currentLineEndTime = tone.end;
      } else {
        // 当前行已满，开始新行
        if (currentLineText !== '') {
          result.push({
            text: currentLineText,
            tones: [...currentLineTones],
            startTime: currentLineStartTime,
            endTime: currentLineEndTime
          });
        }

        // 开始新行
        currentLineText = tone.word;
        currentLineTones = [tone];
        currentLineStartTime = tone.begin;
        currentLineEndTime = tone.end;
      }
    }

    // 添加最后一行
    if (currentLineText !== '') {
      result.push({
        text: currentLineText,
        tones: [...currentLineTones],
        startTime: currentLineStartTime,
        endTime: currentLineEndTime
      });
    }

    return result.length > 0 ? result : [{
      text: this.getLineText(line),
      tones: line.tones || [],
      startTime: line.getStartTime(),
      endTime: line.getEndTime()
    }];
  }

  /**
   * 计算多行歌词中特定物理行的高亮进度
   */
  private calculateDisplayLineProgress(displayLine: DisplayLine, currentTime: number): number {
    if (!displayLine.tones || displayLine.tones.length === 0) {
      return 0;
    }

    if (currentTime < displayLine.startTime) {
      return 0;
    }

    if (currentTime >= displayLine.endTime) {
      return 1;
    }

    // 在这个物理行的时间范围内，计算字符级别的进度
    let highlightedChars = 0;
    for (const tone of displayLine.tones) {
      if (currentTime >= tone.end) {
        highlightedChars += tone.word.length;
      } else if (currentTime >= tone.begin) {
        // 部分高亮当前字符
        const charProgress = (currentTime - tone.begin) / (tone.end - tone.begin);
        highlightedChars += tone.word.length * charProgress;
        break;
      } else {
        break;
      }
    }

    return Math.min(highlightedChars / displayLine.text.length, 1);
  }

  /**
   * 改进的文本宽度估算方法
   * 根据字符类型进行更精确的估算
   */
  private measureTextWidth(text: string, fontSize: number): number {
    let estimatedWidth = 0;

    let isChinese = false;

    for (let i = 0; i < text.length; i++) {
      const char = text.charAt(i);
      if (/[\u4e00-\u9fa5]/.test(char)) {
        // 中文字符，宽度约等于字体大小
        estimatedWidth += fontSize;
        isChinese = true;
      } else if (/[a-zA-Z0-9]/.test(char)) {
        // 英文字母和数字，宽度约为字体大小的0.5倍
        estimatedWidth += fontSize * 0.5;
      } else {
        // 标点符号和其他字符，宽度约为字体大小的0.3倍
        if (isChinese) {
          estimatedWidth += fontSize;
        } else {
          estimatedWidth += fontSize * 0.5;
        }
      }
    }

    return estimatedWidth;
  }

  /**
   * 检测文本是否需要滚动（超出容器宽度）
   */
  private isTextOverflowing(text: string, fontSize: number): boolean {
    const actualTextWidth = this.measureTextWidth(text, fontSize);
    const availableWidth = this.actualViewWidth; // 使用完整宽度
    const isOverflowing = actualTextWidth > availableWidth;

    LogUtils.d(`LyricsView: 📏 Text overflow check - text: "${text.substring(0,
      20)}...", length: ${text.length}, fontSize: ${fontSize}, actualWidth: ${actualTextWidth.toFixed(1)}, availableWidth: ${availableWidth.toFixed(1)}, overflowing: ${isOverflowing}, enableLineWrap: ${this.shouldEnableLineWrap()}`);

    // 为了测试，降低滚动触发阈值
    if (!this.shouldEnableLineWrap()) {
      // 对于不换行模式，如果文本长度超过5个字符就认为需要滚动（便于测试）
      if (text.length > 5) {
        LogUtils.d(`LyricsView: 🔧 Force overflow for testing - text length: ${text.length} > 5, fontSize: ${fontSize}`);
        return true;
      }
    }

    return isOverflowing;
  }

  /**
   * 计算文本滚动偏移量
   * 让正在播放的部分始终保持在视图中央
   */
  private calculateTextScrollOffset(line: LyricsLineModel, progress: number): number {
    const text = this.getLineText(line);
    const fontSize = this.currentLineTextSize; // 确保使用当前行字体大小
    const actualTextWidth = this.measureTextWidth(text, fontSize); // 使用精确测量
    const containerWidth = this.actualViewWidth;

    // 为了测试，即使文本不是很长也允许滚动
    if (actualTextWidth <= containerWidth * 0.8) { // 降低阈值，80%就开始滚动
      return 0; // 文本不够长，无需滚动
    }

    // 计算当前播放位置的像素偏移
    const currentPlayPosition = actualTextWidth * progress;
    const halfContainerWidth = containerWidth / 2;

    // 让当前播放位置保持在容器中央
    let targetOffset = currentPlayPosition - halfContainerWidth;

    // 限制滚动范围：不能滚动到负值，也不能超过最大滚动距离
    const maxScrollOffset = actualTextWidth - containerWidth;
    targetOffset = Math.max(0, Math.min(targetOffset, maxScrollOffset));

    return targetOffset;
  }

  /**
   * 启动文本滚动动画
   */
  private startTextScrollAnimation(line: LyricsLineModel): void {
    const text = this.getLineText(line);
    LogUtils.d(`LyricsView: 🚀 startTextScrollAnimation called - text: "${text.substring(0,
      30)}...", enableLineWrap: ${this.shouldEnableLineWrap()}`);

    // 重置滚动偏移，为新行准备
    this.currentLineScrollOffset = 0;

    if (this.shouldEnableLineWrap()) {
      LogUtils.d(`LyricsView: ❌ Line wrap enabled, skipping scroll animation`);
      return; // 启用换行时不需要滚动
    }

    if (!this.isTextOverflowing(text, this.currentLineTextSize)) {
      LogUtils.d(`LyricsView: ❌ Text not overflowing, skipping scroll animation`);
      return; // 文本不超长时不需要滚动
    }

    this.isTextScrolling = true;
    this.textScrollOffset = 0;
    // currentLineScrollOffset 已经在上面重置了

    // 清除之前的定时器
    if (this.textScrollTimer !== -1) {
      clearInterval(this.textScrollTimer);
    }

    LogUtils.d(`LyricsView: ✅ Starting text scroll animation for line: "${text.substring(0,
      20)}...", textLength: ${text.length}, fontSize: ${this.currentLineTextSize}, viewWidth: ${this.actualViewWidth}`);

    // 启动滚动定时器，每50ms更新一次以获得更流畅的效果
    this.textScrollTimer = setInterval(() => {
      if (!this.isTextScrolling) {
        LogUtils.d(`LyricsView: ⏹️ Scroll timer stopped - isTextScrolling: false`);
        return;
      }

      const progress = this.calculateLineProgress(line);
      const targetOffset = this.calculateTextScrollOffset(line, progress);

      // 使用textScroller.scrollTo实现真正的滚动
      if (Math.abs(this.currentLineScrollOffset - targetOffset) > 0.5) {
        const oldOffset = this.currentLineScrollOffset;
        this.currentLineScrollOffset = targetOffset;

        // 使用Scroller进行滚动
        this.textScroller.scrollTo({
          xOffset: targetOffset,
          yOffset: 0,
          animation: {
            duration: 100,
            curve: Curve.EaseOut
          }
        });

        LogUtils.d(`LyricsView: 🔄 Scroll update - progress: ${(progress *
          100).toFixed(1)}%, oldOffset: ${oldOffset.toFixed(1)}px, newOffset: ${targetOffset.toFixed(1)}px, scrollTo: ${targetOffset.toFixed(1)}px`);
      }
    }, 50);
  }

  /**
   * 停止文本滚动动画
   */
  private stopTextScrollAnimation(): void {
    if (this.textScrollTimer !== -1) {
      clearInterval(this.textScrollTimer);
      this.textScrollTimer = -1;
    }
    this.isTextScrolling = false;
    this.textScrollOffset = 0;
    this.mCurrentLineTranslateX = 0; // 重置水平滚动偏移
    // 重置滚动位置到开始
    this.textScroller.scrollTo({
      xOffset: 0,
      yOffset: 0
    });
    LogUtils.d(`LyricsView: 🛑 Text scroll animation stopped and reset to start`);
  }

  /**
   * 检查是否需要应用横向滚动（参考Android版本实现）
   * 当高亮部分和剩余部分都大于视图宽度的一半时，开始滚动
   */
  private checkIfXTranslationShouldApply(line: LyricsLineModel): void {
    if (this.shouldEnableLineWrap()) {
      this.mCurrentLineTranslateX = 0; // 换行模式下不需要横向滚动
      this.updateScrollPosition(0);
      return;
    }

    const text = this.getLineText(line);
    const fontSize = this.currentLineTextSize;
    const textWidth = text.length * fontSize * 0.6; // 估算文本总宽度
    const viewWidth = this.actualViewWidth;
    const halfViewWidth = viewWidth / 2;

    // 检查文本是否超长
    if (!this.isLyricsLineOverlong(textWidth)) {
      this.mCurrentLineTranslateX = 0;
      this.updateScrollPosition(0);
      return;
    }

    // 计算当前高亮区域宽度
    const progress = this.calculateLineProgress(line);
    const currentHighlightWidth = textWidth * progress;
    this.mRectClipWidth = currentHighlightWidth;

    // Android版本的滚动逻辑：
    // 1. 高亮部分大于视图宽度的一半
    // 2. 剩余部分也大于视图宽度的一半
    if (currentHighlightWidth > halfViewWidth &&
      (textWidth - currentHighlightWidth) > halfViewWidth) {

      // 计算目标滚动位置：让当前播放位置保持在屏幕中央
      const targetScrollX = currentHighlightWidth - halfViewWidth;

      // 限制滚动范围
      const maxScroll = textWidth - viewWidth;
      this.mCurrentLineTranslateX = Math.max(0, Math.min(maxScroll, targetScrollX));

      // 应用滚动
      this.updateScrollPosition(this.mCurrentLineTranslateX);

      LogUtils.d(`LyricsView: Horizontal scroll - progress: ${(progress *
        100).toFixed(1)}%, highlightWidth: ${currentHighlightWidth.toFixed(1)}, targetScrollX: ${targetScrollX.toFixed(1)}, actualScrollX: ${this.mCurrentLineTranslateX.toFixed(1)}`);
    } else {
      this.mCurrentLineTranslateX = 0;
      this.updateScrollPosition(0);
    }

    // 更新上次高亮区域右边界
    this.mLastRightOfRectClip = currentHighlightWidth;
  }

  /**
   * 更新滚动位置
   */
  private updateScrollPosition(scrollX: number): void {
    if (this.textScroller) {
      this.textScroller.scrollTo({
        xOffset: scrollX,
        yOffset: 0
      });
    }
  }

  /**
   * 检查歌词行是否超长（需要横向滚动）
   */
  private isLyricsLineOverlong(textWidth: number): boolean {
    return textWidth > this.actualViewWidth;
  }

  /**
   * 计算高亮区域宽度（像素值）
   */
  private calculateHighlightWidthPx(line: LyricsLineModel): number {
    const progress = this.calculateLineProgress(line);
    const text = this.getLineText(line);
    const fontSize = this.currentLineTextSize;
    const totalWidth = text.length * fontSize * 0.6;
    return totalWidth * progress;
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
    // 计算该行的实际Y位置
    const lineY = this.calculateLineYPosition(index);
    const lineHeight = this.getLineHeight();

    // 判断行是否在视图范围内（包含部分可见）
    const lineTop = lineY;
    const lineBottom = lineY + lineHeight;
    const viewTop = -lineHeight * 0.5; // 允许稍微超出上边界
    const viewBottom = this.actualViewHeight + lineHeight * 0.5; // 允许稍微超出下边界

    // 如果行的任何部分在扩展视图范围内，就认为是可见的
    const isVisible = lineBottom > viewTop && lineTop < viewBottom;

    // 在拖拽时输出详细调试信息
    if (this.mDraggingInProgress && index < 10) {
      LogUtils.d(`LyricsView: Line ${index} - Y: ${lineY.toFixed(1)}, Top: ${lineTop.toFixed(1)}, Bottom: ${lineBottom.toFixed(1)}, ViewTop: ${viewTop}, ViewBottom: ${viewBottom}, Visible: ${isVisible}`);
    }

    return isVisible;
  }

  /**
   * 判断是否应该渲染某一行（基于enablePreviousLines和enableUpcomingLines开关）
   */
  private shouldRenderLine(index: number): boolean {
    // 确定当前参考行索引
    const currentIndex = this.mDraggingInProgress && this.originalCurrentLineIndex >= 0
      ? this.originalCurrentLineIndex
      : this.mIndexOfCurrentLine;

    // 当前行始终渲染
    if (index === currentIndex) {
      return true;
    }

    // 检查是否是之前的行
    if (index < currentIndex) {
      return this.enablePreviousLines;
    }

    // 检查是否是未来的行
    if (index > currentIndex) {
      return this.enableUpcomingLines;
    }

    return true;
  }

  /**
   * 统计并记录当前可见的行数（调试用）
   */
  private logVisibleLinesCount(): void {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (!lyricsModel || !lyricsModel.lines) {
      return;
    }

    let visibleCount = 0;
    let renderedCount = 0;
    const visibleLines: number[] = [];
    const renderedLines: number[] = [];

    for (let i = 0; i < lyricsModel.lines.length; i++) {
      if (this.shouldRenderLine(i)) {
        renderedCount++;
        renderedLines.push(i);

        if (this.isLineVisible(i)) {
          visibleCount++;
          visibleLines.push(i);
        }
      }
    }

    LogUtils.d(`LyricsView: Rendered lines: ${renderedCount}, Visible lines: ${visibleCount}, Total: ${lyricsModel.lines.length}, Previous: ${this.enablePreviousLines}, Upcoming: ${this.enableUpcomingLines}`);

    // 如果没有可见行，这是一个问题
    if (visibleCount === 0) {
      LogUtils.d(`LyricsView: WARNING - No visible lines! ViewHeight: ${this.actualViewHeight}, LineHeight: ${this.getLineHeight()}`);
    }
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
   * 检查是否应该启用换行（LRC格式默认启用）
   */
  private shouldEnableLineWrap(): boolean {
    // 如果明确设置了enableLineWrap，使用设置值
    if (this.enableLineWrap !== undefined) {
      return this.enableLineWrap;
    }

    // 检查是否是LRC格式（通过检查歌词模型的类型）
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (lyricsModel && lyricsModel.type === LyricType.LRC) {
      LogUtils.d(`LyricsView: LRC format detected, enabling line wrap by default`);
      return true; // LRC格式默认启用换行
    }

    LogUtils.d(`LyricsView: Non-LRC format or no lyrics model, disabling line wrap by default`);
    return false; // 其他格式默认不启用换行
  }

  /**
   * 渐进式高亮行Builder
   */
  @Builder
  ProgressiveHighlightLineBuilder(line: LyricsLineModel, index: number) {
    if (this.shouldEnableLineWrap()) {
      // 启用换行模式
      this.WrappedHighlightLineBuilder(line, index);
    } else {
      // 滚动模式
      this.ScrollingHighlightLineBuilder(line, index);
    }
  }

  /**
   * 换行高亮行Builder
   */
  @Builder
  WrappedHighlightLineBuilder(line: LyricsLineModel, index: number) {
    Stack() {
      // 背景文字（正常颜色）
      Column() {
        ForEach(this.splitLineIntoDisplayLines(line, this.currentLineTextSize),
          (displayLine: DisplayLine, displayIndex: number) => {
            Row() {
              Text(displayLine.text)
                .fontSize(this.currentLineTextSize)
                .fontColor(this.currentLineTextColor)
                .fontWeight(FontWeight.Bold)
                .textAlign(this.getTextAlign())
                .width('100%')
                .maxLines(1) // 每个物理行都是单行
                .textOverflow({ overflow: TextOverflow.None })
            }
            .width('100%')
            .justifyContent(this.getRowJustifyContent())
            .height(this.currentLineTextSize)
          }, (displayLine: DisplayLine, displayIndex: number) => `${index}_bg_${displayIndex}`)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      // 高亮文字（逐行渐进高亮）
      Column() {
        ForEach(this.splitLineIntoDisplayLines(line, this.currentLineTextSize),
          (displayLine: DisplayLine, displayIndex: number) => {
            Row() {
              Text(displayLine.text)
                .fontSize(this.currentLineTextSize)
                .fontColor(this.currentLineHighlightedTextColor)
                .fontWeight(FontWeight.Bold)
                .textAlign(this.getTextAlign())
                .width('100%')
                .maxLines(1) // 每个物理行都是单行
                .textOverflow({ overflow: TextOverflow.None })
            }
            .width('100%')
            .justifyContent(this.getRowJustifyContent())
            .height(this.currentLineTextSize)
            .clip(true)
            .clipShape(new Rect({
              width: `${this.calculateDisplayLineProgress(displayLine, this.mCurrentTime) * 100}%`,
              height: '100%'
            }))
            .animation({
              duration: 50, // 更快的高亮响应
              curve: Curve.Linear,
              iterations: 1,
              playMode: PlayMode.Normal
            })
          }, (displayLine: DisplayLine, displayIndex: number) => `${index}_fg_${displayIndex}`)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height(this.getDynamicLineHeight(line, this.currentLineTextSize))
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
   * 滚动高亮行Builder（单行显示，支持横向滚动动画）
   */
  @Builder
  ScrollingHighlightLineBuilder(line: LyricsLineModel, index: number) {
    // 使用Scroll组件实现真正的横向滚动
    Scroll(this.textScroller) {
      Stack() {
        // 背景文字（正常颜色，单行显示）
        Text(this.getLineText(line))
          .fontSize(this.currentLineTextSize)
          .fontColor(this.currentLineTextColor)
          .fontWeight(FontWeight.Bold)
          .textAlign(this.getTextAlign())
          .maxLines(1) // 单行显示
          .textOverflow({ overflow: TextOverflow.None }) // 不显示省略号
          .width('auto') // 让文本自然宽度
          .onAppear(() => {
            LogUtils.d(`LyricsView: 🎨 Background text rendered - scrollOffset: ${this.currentLineScrollOffset}, text: "${this.getLineText(line)
              .substring(0, 15)}..."`);
          })

        // 高亮文字（使用clip实现渐进效果）
        Text(this.getLineText(line))
          .fontSize(this.currentLineTextSize)
          .fontColor(this.currentLineHighlightedTextColor)
          .fontWeight(FontWeight.Bold)
          .textAlign(this.getTextAlign())
          .maxLines(1) // 单行显示
          .textOverflow({ overflow: TextOverflow.None }) // 不显示省略号
          .width('auto') // 让文本自然宽度
          .clip(true)
          .clipShape(new Rect({
            width: `${this.calculateLineProgress(line) * 100}%`, // 使用百分比确保正确对齐
            height: '100%'
          }))
          .animation({
            duration: 50, // 更快的高亮响应
            curve: Curve.Linear,
            iterations: 1,
            playMode: PlayMode.Normal
          })
      }
      .alignContent(this.getAlignment())
    }
    .scrollable(ScrollDirection.Horizontal) // 水平滚动
    .scrollBar(BarState.Off) // 隐藏滚动条
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
    // 根据enableLineWrap决定显示方式
    if (this.shouldEnableLineWrap()) {
      // 换行模式：支持多行显示
      Row() {
        Text(this.getLineText(line))
          .fontSize(this.textSize) // 使用普通行字体大小
          .fontColor(this.getNormalLineColor(index)) // 使用普通行颜色
          .fontWeight(FontWeight.Normal) // 使用普通行字重
          .textAlign(this.getTextAlign())
          .width('100%')
          .maxLines(3) // 最多3行
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height(this.getDynamicLineHeight(line, this.textSize))
      .justifyContent(this.getRowJustifyContent())
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
    } else {
      // 不换行模式：使用Scroll组件避免字体变化时的闪动
      Scroll() {
        Stack() {
          Text(this.getLineText(line))
            .fontSize(this.textSize) // 使用普通行字体大小
            .fontColor(this.getNormalLineColor(index)) // 使用普通行颜色
            .fontWeight(FontWeight.Normal) // 使用普通行字重
            .textAlign(this.getTextAlign()) // 左对齐
            .maxLines(1) // 单行显示
            .textOverflow({ overflow: TextOverflow.None }) // 不显示省略号
            .width('auto') // 让文本自然宽度
        }
        .alignContent(this.getAlignment())
      }
      .scrollable(ScrollDirection.Horizontal) // 水平滚动
      .scrollBar(BarState.Off) // 隐藏滚动条
      .width('100%')
      .height(this.getLineHeight())
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
  }

  /**
   * 新当前行过渡Builder - 处理从下一行位置移动到中心并变为高亮样式
   */
  @Builder
  NewCurrentLineTransitionBuilder(line: LyricsLineModel, index: number) {
    // 根据enableLineWrap决定显示方式
    if (this.shouldEnableLineWrap()) {
      // 换行模式：使用Stack布局
      Stack() {
        // 背景文字（平滑过渡样式）
        Row() {
          Text(this.getLineText(line))
            .fontSize(this.getTransitioningFontSize())
            .fontColor(this.getTransitioningTextColor())
            .fontWeight(this.getTransitioningFontWeight())
            .textAlign(this.getTextAlign())
            .width('100%')
            .maxLines(3) // 最多3行
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .animation({
              duration: 300, // 样式过渡动画
              curve: Curve.EaseInOut,
              iterations: 1,
              playMode: PlayMode.Normal
            })
        }
        .width('100%')
        .justifyContent(this.getRowJustifyContent())

        // 高亮文字（渐进显示）- 始终显示，但在动画期间使用相同的字体大小
        Row() {
          Text(this.getLineText(line))
            .fontSize(this.getTransitioningFontSize()) // 使用相同的过渡字体大小，确保完全对齐
            .fontColor(this.currentLineHighlightedTextColor)
            .fontWeight(this.getTransitioningFontWeight()) // 使用相同的过渡字重
            .textAlign(this.getTextAlign())
            .width('100%')
            .maxLines(3) // 最多3行
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .animation({
              duration: 300, // 样式过渡动画，与背景文字同步
              curve: Curve.EaseInOut,
              iterations: 1,
              playMode: PlayMode.Normal
            })
        }
        .width('100%')
        .justifyContent(this.getRowJustifyContent())
        .clip(true)
        .clipShape(new Rect({
          width: `${this.calculateLineProgress(line) * 100}%`,
          height: '100%'
        }))
        .opacity(this.styleTransitioning ? 1.0 : 0.0) // 样式过渡开始后才显示高亮
        .animation({
          duration: 300, // 高亮渐入动画
          curve: Curve.EaseInOut,
          iterations: 1,
          playMode: PlayMode.Normal
        })
      }
      .width('100%')
      .height(this.getDynamicLineHeight(line, this.currentLineTextSize))
      .alignContent(this.getAlignment())
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
    } else {
      // 不换行模式：使用Scroll组件避免闪动
      Scroll(this.textScroller) {
        Stack() {
          // 背景文字（单行显示）
          Text(this.getLineText(line))
            .fontSize(this.getTransitioningFontSize())
            .fontColor(this.getTransitioningTextColor())
            .fontWeight(this.getTransitioningFontWeight())
            .textAlign(this.getTextAlign()) // 左对齐
            .maxLines(1) // 单行显示
            .textOverflow({ overflow: TextOverflow.None }) // 不显示省略号
            .width('auto') // 让文本自然宽度
            .animation({
              duration: 300, // 样式过渡动画
              curve: Curve.EaseInOut,
              iterations: 1,
              playMode: PlayMode.Normal
            })

          // 高亮文字（渐进显示，单行）- 始终显示，但在动画期间使用相同的字体大小
          Text(this.getLineText(line))
            .fontSize(this.getTransitioningFontSize()) // 使用相同的过渡字体大小，确保完全对齐
            .fontColor(this.currentLineHighlightedTextColor)
            .fontWeight(this.getTransitioningFontWeight()) // 使用相同的过渡字重
            .textAlign(this.getTextAlign()) // 左对齐
            .maxLines(1) // 单行显示
            .textOverflow({ overflow: TextOverflow.None }) // 不显示省略号
            .width('auto') // 让文本自然宽度
            .clip(true)
            .clipShape(new Rect({
              width: `${this.calculateLineProgress(line) * 100}%`,
              height: '100%'
            }))
            .opacity(this.styleTransitioning ? 1.0 : 0.0) // 样式过渡开始后才显示高亮
            .animation({
              duration: 300, // 高亮渐入动画
              curve: Curve.EaseInOut,
              iterations: 1,
              playMode: PlayMode.Normal
            })
        }
        .alignContent(this.getAlignment())
      }
      .scrollable(ScrollDirection.Horizontal) // 水平滚动
      .scrollBar(BarState.Off) // 隐藏滚动条
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
  }

  /**
   * 普通行Builder
   */
  @Builder
  NormalLineBuilder(line: LyricsLineModel, index: number) {
    if (this.shouldEnableLineWrap()) {
      // 换行模式：普通行支持换行
      this.WrappedNormalLineBuilder(line, index);
    } else {
      // 不换行模式：普通行单行显示，不显示省略号
      this.SingleLineNormalBuilder(line, index);
    }
  }

  /**
   * 换行普通行Builder
   */
  @Builder
  WrappedNormalLineBuilder(line: LyricsLineModel, index: number) {
    Row() {
      Text(this.getLineText(line))
        .fontSize(this.textSize)
        .fontColor(this.getNormalLineColor(index))
        .fontWeight(FontWeight.Normal)
        .textAlign(this.getTextAlign())
        .width('100%')
        .maxLines(3) // 最多3行
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .height(this.getDynamicLineHeight(line, this.textSize))
    .justifyContent(this.getRowJustifyContent())
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
   * 单行普通行Builder（不换行，不显示省略号）
   */
  @Builder
  SingleLineNormalBuilder(line: LyricsLineModel, index: number) {
    Stack() {
      Text(this.getLineText(line))
        .fontSize(this.textSize)
        .fontColor(this.getNormalLineColor(index))
        .fontWeight(FontWeight.Normal)
        .textAlign(this.getTextAlign())
        .maxLines(1) // 单行显示
        .textOverflow({ overflow: TextOverflow.None }) // 不显示省略号
        .width('auto') // 让文本自然宽度
    }
    .width('100%')
    .height(this.getLineHeight())
    .alignContent(this.getAlignment())
    .clip(true) // 裁剪超出部分，不显示省略号
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
   * 基于字符级别的精确进度计算
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
    }

    // 基于字符级别的进度计算
    let totalChars = 0;
    let playedChars = 0;

    for (const tone of line.tones) {
      const charLength = tone.word.length;
      totalChars += charLength;

      if (this.mCurrentTime >= tone.begin) {
        if (this.mCurrentTime >= tone.end) {
          // 整个字符都已播放
          playedChars += charLength;
        } else {
          // 字符正在播放中，计算部分进度
          const toneProgress = (this.mCurrentTime - tone.begin) / (tone.end - tone.begin);
          playedChars += charLength * toneProgress;
        }
      }
    }

    return totalChars > 0 ? Math.min(1, playedChars / totalChars) : 0;
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
   * 计算行的透明度（基于可见性和距离当前行的远近）
   */
  private getLineOpacity(index: number): number {
    // 首先检查是否应该渲染该行
    if (!this.shouldRenderLine(index)) {
      return 0.0; // 如果开关禁用了该行，完全透明
    }

    const isVisible = this.isLineVisible(index);

    // 保底机制：如果拖拽时，确保当前行附近的行至少是可见的
    if (this.mDraggingInProgress) {
      const currentIndex =
        this.originalCurrentLineIndex >= 0 ? this.originalCurrentLineIndex : this.mIndexOfCurrentLine;
      const distance = Math.abs(index - currentIndex);

      // 强制显示当前行附近的几行，即使位置计算有问题
      if (distance <= 2) {
        return distance === 0 ? 1.0 : 0.8;
      }
    }

    // 如果不可见，返回透明
    if (!isVisible) {
      return 0.0;
    }

    // 可见的行根据距离当前行的远近计算透明度
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
    // 在动画刚开始时返回起始位置，然后快速切换到目标位置触发动画
    // 使用animationKey来判断是否是新动画的开始
    const currentTime = Date.now();
    const timeSinceAnimation = currentTime - this.animationKey;
    const isInStartPhase = timeSinceAnimation < 50;
    const position = isInStartPhase ? this.transitioningFromY : this.transitioningToY;

    LogUtils.d(`LyricsView: 🔄 getTransitioningYPosition - phase: ${isInStartPhase ? 'START' :
      'TARGET'}, position: ${position}, timeSince: ${timeSinceAnimation}ms, fromY: ${this.transitioningFromY}, toY: ${this.transitioningToY}`);

    return position;
  }

  /**
   * 获取新当前行的Y位置
   */
  private getNewCurrentYPosition(): number {
    // 在动画刚开始时返回起始位置，然后快速切换到目标位置触发动画
    const currentTime = Date.now();
    const timeSinceAnimation = currentTime - this.animationKey;
    const isInStartPhase = timeSinceAnimation < 50;
    const position = isInStartPhase ? this.newCurrentFromY : this.newCurrentToY;

    LogUtils.d(`LyricsView: 🆕 getNewCurrentYPosition - phase: ${isInStartPhase ? 'START' :
      'TARGET'}, position: ${position}, timeSince: ${timeSinceAnimation}ms, fromY: ${this.newCurrentFromY}, toY: ${this.newCurrentToY}`);

    return position;
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
   * 根据触摸Y坐标计算对应的歌词行索引
   * @param touchY 触摸点的Y坐标
   * @return 对应的歌词行索引，如果无效则返回-1
   */
  private calculateLineIndexByTouchY(touchY: number): number {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (!lyricsModel || !lyricsModel.lines || lyricsModel.lines.length === 0) {
      return -1;
    }

    const lineHeight = this.getLineHeight();
    const centerY = (this.actualViewHeight / 2) - (lineHeight / 2);

    // 计算触摸点相对于当前行中心的偏移
    const offsetFromCenter = touchY - centerY;
    const lineOffset = Math.round(offsetFromCenter / lineHeight);

    // 计算目标行索引
    const targetLineIndex = this.mIndexOfCurrentLine + lineOffset;

    // 确保索引在有效范围内
    if (targetLineIndex >= 0 && targetLineIndex < lyricsModel.lines.length) {
      return targetLineIndex;
    }

    return -1;
  }

  /**
   * 根据歌词行索引获取对应的开始时间
   * @param lineIndex 歌词行索引
   * @return 对应的开始时间（毫秒），如果无效则返回-1
   */
  private getLineStartTime(lineIndex: number): number {
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (!lyricsModel || !lyricsModel.lines || lineIndex < 0 || lineIndex >= lyricsModel.lines.length) {
      return -1;
    }

    return lyricsModel.lines[lineIndex].getStartTime();
  }

  /**
   * 处理拖拽开始事件
   * @param touchY 初始触摸Y坐标
   */
  private handleDragStart(touchY: number): void {
    if (!this.enableDragging) {
      return;
    }

    LogUtils.d('LyricsView: Drag start');
    this.mDraggingInProgress = true;
    this.initialTouchY = touchY;
    this.currentTouchY = touchY;
    this.dragOffset = 0;
    this.dragLineOffset = 0;
    this.originalCurrentLineIndex = this.mIndexOfCurrentLine; // 记录拖拽开始时的当前行

    // 通过EventBus通知拖拽开始
    this.eventBus.emit(LyricsEvents.DRAG_START);
  }

  /**
   * 处理拖拽移动事件
   * @param touchY 当前触摸Y坐标
   */
  private handleDragMove(touchY: number): void {
    if (!this.enableDragging || !this.mDraggingInProgress) {
      return;
    }

    this.currentTouchY = touchY;
    // 计算Y轴移动距离
    const deltaY = touchY - this.initialTouchY;

    // 根据Y轴移动距离计算歌词行偏移量
    // 使用实际的歌词行高度来计算偏移量
    const lineHeight = this.getLineHeight();
    const rawLineOffset = Math.round(deltaY / lineHeight);

    // 计算拖拽边界限制
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (lyricsModel && lyricsModel.lines) {
      // 计算更保守的边界限制
      const totalLines = lyricsModel.lines.length;

      // 向上拖拽限制：不能超过第一行
      const maxUpwardOffset = this.originalCurrentLineIndex;

      // 向下拖拽限制：不能超过最后一行
      const maxDownwardOffset = totalLines - 1 - this.originalCurrentLineIndex;

      // 限制拖拽偏移量在安全范围内
      this.dragLineOffset = Math.max(-maxDownwardOffset, Math.min(maxUpwardOffset, rawLineOffset));

      LogUtils.d(`LyricsView: Dragging, deltaY: ${deltaY}, rawOffset: ${rawLineOffset}, limitedOffset: ${this.dragLineOffset}, bounds: [${-maxDownwardOffset}, ${maxUpwardOffset}]`);

      // 统计可见行数（调试用）
      this.logVisibleLinesCount();

      // 强制触发UI更新，让可见性检查生效
      this.mForceUpdateUi = LyricsView.UPDATE_UI_TYPE_NORMAL;
    } else {
      this.dragLineOffset = 0;
    }
  }

  /**
   * 处理拖拽结束事件
   * @param touchY 最终触摸点的Y坐标
   */
  private handleDragEnd(touchY: number): void {
    if (!this.enableDragging) {
      return;
    }

    LogUtils.d('LyricsView: Drag end');
    this.mDraggingInProgress = false;

    // 计算最终的目标行索引
    const lyricsModel = this.mLyricMachine?.getLyricsModel();
    if (lyricsModel && lyricsModel.lines) {
      const finalLineIndex = this.originalCurrentLineIndex - this.dragLineOffset;
      const clampedIndex = Math.max(0, Math.min(finalLineIndex, lyricsModel.lines.length - 1));
      const startTime = this.getLineStartTime(clampedIndex);

      if (startTime >= 0) {
        LogUtils.d(`LyricsView: Final drag line ${clampedIndex}, time ${startTime}ms`);

        // 通过EventBus通知最终拖拽位置
        this.eventBus.emit(LyricsEvents.DRAG_END, startTime);
      } else {
        LogUtils.d('LyricsView: Failed to get start time for final position');
      }
    } else {
      LogUtils.d('LyricsView: No lyrics model available');
    }

    // 重置拖拽状态
    this.dragOffset = 0;
    this.initialTouchY = 0;
    this.currentTouchY = 0;
    this.dragLineOffset = 0;
    this.originalCurrentLineIndex = -1;
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
      .justifyContent(this.getRowJustifyContent())
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
              // 根据开关决定是否绘制该行
              if (this.shouldRenderLine(index)) {
                this.EnhancedLyricsLineBuilder(line, index)
              }
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
    .onTouch((event: TouchEvent) => {
      if (!this.enableDragging) {
        return false;
      }

      switch (event.type) {
        case TouchType.Down:
          this.handleDragStart(event.touches[0].y);
          return true;
        case TouchType.Move:
          this.handleDragMove(event.touches[0].y);
          return true;
        case TouchType.Up:
        case TouchType.Cancel:
          this.handleDragEnd(event.touches[0].y);
          return true;
        default:
          return false;
      }
    })
    .onAreaChange((oldValue: Area, newValue: Area) => {
      // 动态获取组件实际尺寸
      if (newValue.height && typeof newValue.height === 'number') {
        this.actualViewHeight = newValue.height;
        LogUtils.d(`LyricsView: Component height measured: ${this.actualViewHeight}`);
        // 高度变化后，位置会自动重新计算，不需要手动滚动
      }
      if (newValue.width && typeof newValue.width === 'number') {
        this.actualViewWidth = newValue.width;
        LogUtils.d(`LyricsView: Component width measured: ${this.actualViewWidth}`);
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
