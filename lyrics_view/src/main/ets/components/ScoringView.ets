import { IScoringAlgorithm } from '../IScoringAlgorithm';
import { OnScoringListener, ScoringMachine } from '../internal/ScoringMachine';
import { ParticleConfig, ParticleRenderer, ParticleSystem, Range } from '../internal/particle';
import { LyricModel } from '../model/LyricModel';
import { LyricsLineModel } from '../model/LyricsLineModel';
import { HighlightSegment, Pitch, PitchStickData } from '../model/PitchLineModel';
import { EventBus, KaraokeEvents, ScoringEvents } from '../utils/EventBus';
import { LogUtils } from '../utils/LogUtils';

/**
 * 评分显示组件 - HarmonyOS版本
 * 对应Android项目中的ScoringView
 * 用于显示卡拉OK评分信息和音调可视化
 */
@Component
export struct ScoringView {
  @Prop viewBackgroundColor: string = '#ffffbb33'; // 可配置的背景颜色
  @Prop leadingLinesColor: string = '#4DFFFFFF'
  @Prop leadingLinesHeight: number = 1
  @Prop pitchIndicatorColor: string = '#F0F0F0F0';
  @Prop pitchIndicatorWidth: number = 3;
  @Prop localPitchIndicatorColor: string = "#F0F0F0F0"
  @Prop localPitchIndicatorRadius: number = 8;
  @Prop pitchStickHeight: number = 4;
  @Prop pitchStickRadius: number = 4;
  @Prop refPitchStickDefaultColor: string = '#99FFFFFF';
  @Prop highlightedPitchStickColor: string = '#FFF44336';
  @Prop initialScore: number = 0;
  @Prop movingPixelsPerMs: number = 0.2;
  @Prop hitScoreThreshold: number = 0.5; // 降低阈值到50分，便于测试粒子动画
  @Prop startPointHorizontalBias: number = 0.4;
  @Prop enableParticleEffect: boolean = true;
  // 状态变量
  @State currentScore: number = 0;
  @State cumulativeScore: number = 0;
  @State localPitch: number = 0; // 原始输入的pitch值（可能有抖动）
  @State inHighlightStatus: boolean = false;
  @State animatedPitch: number = 0; // 平滑后的pitch值（用于UI显示）
  @State animatedProgressMs: number = 0;
  @State preHighlightStatus: boolean = false;
  // 着色相关状态 - 对应Android版本
  private pitchHighlightedTime: number = -1; // 当前着色开始时间
  // UI布局相关
  @State centerXOfStartPoint: number = 0;
  @State viewWidth: number = 0;
  @State viewHeight: number = 0;
  @State pitchIndicatorY: number = 0; // 音调指示器的Y坐标
  @State pitchSticks: PitchStickData[] = []; // 当前可见的pitch条数据
  // 粒子系统相关
  @State particleSystem: ParticleSystem | null = null;
  private emittingInitialized: boolean = false;
  // 内部变量
  private eventBus: EventBus = EventBus.getInstance();
  private scoringMachine: ScoringMachine | null = null;
  private frameLoopRunning: boolean = false;
  private frameTimer: number = -1;

  build() {
    // 主要的音调可视化区域 - 使用相对布局而非绝对定位
    Stack({ alignContent: Alignment.TopStart }) {
      // 第1层：背景线条（最底层）
      this.buildBackgroundLines()

      // 第2层：渐变遮罩区域（在背景线条之上，在起始线之下）
      this.buildOverPastWall()

      // 第3层：竖直起始线（最上层，确保可见）
      this.buildStartLine()

      // 参考音调条（根据歌词pitch数据）
      this.buildPitchSticks()

      // 用户音调指示器
      this.buildLocalPitchIndicator()

      // 粒子效果层（最顶层）
      if (this.enableParticleEffect && this.particleSystem) {
        ParticleRenderer({ particleSystem: $particleSystem })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.viewBackgroundColor) // 可配置的背景颜色，默认#ffffbb33
    .onAreaChange((oldValue: Area, newValue: Area) => {
      // 更新视图尺寸和计算起始点位置
      this.viewWidth = Number(newValue.width);
      this.viewHeight = Number(newValue.height);
      this.centerXOfStartPoint = this.viewWidth * this.startPointHorizontalBias;
      LogUtils.d(`ScoringView: Area changed - width: ${this.viewWidth}, height: ${this.viewHeight}, centerX: ${this.centerXOfStartPoint}`);
    })
    .onAppear(() => {
      LogUtils.d('ScoringView: Component appeared, setting up event listeners');
      this.setupEventListeners();
      this.initParticleSystem();

      // 通知外部组件ScoringView已准备好
      setTimeout(() => {
        LogUtils.d('ScoringView: Ready for events, emitting COMPONENT_READY');
        this.eventBus.emit(ScoringEvents.COMPONENT_READY);
      }, 10);
    })
    .onDisAppear(() => {
      LogUtils.d('ScoringView: Component disappearing, cleaning up');
      this.removeEventListeners();
      this.cleanupParticleSystem();
    })
  }

  /**
   * 构建背景线条 - 使用相对布局，不依赖绝对坐标
   */
  @Builder
  buildBackgroundLines() {
    // 方案1：使用Column + justifyContent均匀分布
    Column() {
      // 6条线，创建5个等分区域
      Line().width('100%').height(this.leadingLinesHeight).backgroundColor(this.leadingLinesColor)
      Blank() // 自动填充空间
      Line().width('100%').height(this.leadingLinesHeight).backgroundColor(this.leadingLinesColor)
      Blank()
      Line().width('100%').height(this.leadingLinesHeight).backgroundColor(this.leadingLinesColor)
      Blank()
      Line().width('100%').height(this.leadingLinesHeight).backgroundColor(this.leadingLinesColor)
      Blank()
      Line().width('100%').height(this.leadingLinesHeight).backgroundColor(this.leadingLinesColor)
      Blank()
      Line().width('100%').height(this.leadingLinesHeight).backgroundColor(this.leadingLinesColor)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.SpaceBetween) // 均匀分布
  }

  /**
   * 构建渐变遮罩墙 - 对应Android的drawOverPastWall
   * 从mCenterXOfStartPoint到左边界的线性渐变
   */
  @Builder
  buildOverPastWall() {
    if (this.centerXOfStartPoint > 0 && this.viewWidth > 0 && this.viewHeight > 0) {
      Rect()
        .width(this.centerXOfStartPoint)
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Right, // 从左到右的渐变
          colors: [
            ['#1F24C6FF', 0], // 左边界
            ['#00FFFFFF', 1]// 右边界
          ]
        })
        .position({ x: 0, y: 0 })
        .opacity(0.15)
    }
  }

  /**
   * 构建起始线 - 对应Android的drawStartLine
   * 在mCenterXOfStartPoint位置绘制竖直线，使用pitchIndicatorColor
   */
  @Builder
  buildStartLine() {
    if (this.centerXOfStartPoint > 0 && this.viewWidth > 0 && this.viewHeight > 0) {
      Line()
        .startPoint([this.centerXOfStartPoint, 0])
        .endPoint([this.centerXOfStartPoint, this.viewHeight])
        .stroke(this.pitchIndicatorColor) // 使用pitchIndicatorColor，对应Android实现
        .strokeWidth(this.pitchIndicatorWidth)
    }
  }

  /**
   * 构建音调条 - 对应Android的drawPitchSticks
   * 根据歌词pitch数据和当前进度动态绘制音调条，支持分段着色
   */
  @Builder
  buildPitchSticks() {
    if (this.viewWidth > 0 && this.viewHeight > 0 && this.pitchSticks.length > 0) {
      // 使用ForEach渲染所有可见的pitch条
      ForEach(this.pitchSticks, (stick: PitchStickData, index: number) => {
        Stack() {
          // 1. 绘制基础pitch条（默认颜色）
          Rect()
            .width(stick.width)
            .height(stick.height)
            .fill(this.refPitchStickDefaultColor)
            .borderRadius(this.pitchStickRadius)

          // 2. 绘制已着色的段落（对应Android的highlightPartMap逻辑）
          ForEach(stick.highlightSegments, (segment: HighlightSegment, segIndex: number) => {
            Rect()
              .width(segment.endX - segment.startX)
              .height(stick.height)
              .fill(this.highlightedPitchStickColor)
              .borderRadius(this.pitchStickRadius)
              .position({
                x: segment.startX - stick.x, // 相对于stick的位置
                y: 0
              })
          }, (segment: HighlightSegment, segIndex: number) => `highlight_${index}_${segIndex}_${segment.startTime}`)

          // 3. 绘制当前正在着色的部分（实时着色）
          if (stick.isCurrentPitch && stick.isHighlighted) {
            Rect()
              .width(this.calculateCurrentHighlightWidth(stick))
              .height(stick.height)
              .fill(this.highlightedPitchStickColor)
              .borderRadius(this.pitchStickRadius)
              .position({
                x: this.calculateCurrentHighlightStartX(stick) - stick.x,
                y: 0
              })
          }
        }
        .position({
          x: stick.x,
          y: stick.y
        })
      }, (stick: PitchStickData, index: number) => `pitch_${index}_${stick.x}_${stick.y}`)
    }
  }

  /**
   * 构建用户音调指示器 - 对应Android的drawLocalPitchIndicator
   * 在起始线位置绘制圆形指示器，Y坐标根据当前音调计算
   */
  @Builder
  buildLocalPitchIndicator() {
    if (this.centerXOfStartPoint > 0 && this.viewWidth > 0 && this.viewHeight > 0 && this.pitchIndicatorY >= 0) {
      // 使用Circle作为音调指示器，位置在起始线上，Y坐标根据pitch计算
      Circle({ width: this.localPitchIndicatorRadius * 2, height: this.localPitchIndicatorRadius * 2 })
        .fill(this.localPitchIndicatorColor)
        .strokeWidth(2)
        .position({
          x: this.centerXOfStartPoint - this.localPitchIndicatorRadius,
          y: this.pitchIndicatorY - this.localPitchIndicatorRadius
        })
    }
  }

  /**
   * 计算音调指示器的Y坐标 - 对应Android的getYForPitchIndicator
   * 根据当前音调值和音调范围计算在视图中的Y位置
   */
  private calculateYForPitchIndicator(): number {
    let targetY = 0;

    if (this.scoringMachine == null || !this.scoringMachine.isReady()) {
      // 未初始化时，指示器在底部
      targetY = this.viewHeight - this.localPitchIndicatorRadius;
    } else if (this.animatedPitch >= this.scoringMachine.getMinimumRefPitch() &&
      this.scoringMachine.getMaximumRefPitch() != 0) {
      // 有有效音调值时，根据音调范围计算位置
      const realPitchMax = this.scoringMachine.getMaximumRefPitch() + 5;
      const realPitchMin = this.scoringMachine.getMinimumRefPitch() - 5;
      const itemHeightPerPitchLevel = this.viewHeight / (realPitchMax - realPitchMin);
      targetY = (realPitchMax - this.animatedPitch) * itemHeightPerPitchLevel;
    } else if (this.animatedPitch < this.scoringMachine.getMinimumRefPitch()) {
      // 音调过低时，指示器在底部
      targetY = this.viewHeight;
    }

    // 边界限制，确保指示器不会超出视图范围
    if (targetY < this.localPitchIndicatorRadius) {
      targetY += this.localPitchIndicatorRadius;
    }
    if (targetY > this.viewHeight - this.localPitchIndicatorRadius) {
      targetY -= this.localPitchIndicatorRadius;
    }

    return targetY;
  }

  /**
   * 获取渲染进度 - 对应Android的getRenderProgressMs()
   * 使用平滑的animatedProgressMs而不是直接的机器进度
   */
  private getRenderProgressMs(): number {
    return Math.round(this.animatedProgressMs);
  }

  /**
   * 设置事件监听器
   */
  private setupEventListeners(): void {
    LogUtils.d('ScoringView: Setting up event listeners');

    // 初始化ScoringMachine
    this.initScoringMachine();

    // 响应组件检测请求
    this.eventBus.on(KaraokeEvents.COMPONENT_DETECTION, (request: string) => {
      if (request === KaraokeEvents.COMPONENT_DETECTION_REQUEST) {
        LogUtils.d('ScoringView: Responding to component detection');
        this.eventBus.emit(KaraokeEvents.COMPONENT_DETECTION, KaraokeEvents.COMPONENT_SCORING_VIEW);
      }
    });

    // 监听歌词数据设置事件
    this.eventBus.on(ScoringEvents.SET_LYRIC_DATA, (lyricModel: LyricModel, usingInternalScoring: boolean) => {
      if (this.scoringMachine) {
        this.scoringMachine.prepare(lyricModel, usingInternalScoring);
        LogUtils.d(`ScoringView: Lyric data prepared in ScoringMachine with usingInternalScoring: ${usingInternalScoring}`);
      } else {
        LogUtils.e('ScoringView: ScoringMachine is null when receiving SET_LYRIC_DATA event');
      }
    });

    this.eventBus.on(ScoringEvents.SET_PROGRESS, (progress: number) => {
      if (this.scoringMachine) {
        this.scoringMachine.setLyricProgress(progress);
      }
    });

    // 监听音高数据设置事件
    this.eventBus.on(ScoringEvents.SET_PITCH, (speakerPitch: number, pitchScore: number, progressInMs: number) => {
      if (this.scoringMachine) {
        this.scoringMachine.setPitch(speakerPitch, pitchScore, progressInMs);
      }
    });

    // 监听评分算法设置事件
    this.eventBus.on(ScoringEvents.SET_SCORING_ALGORITHM, (algorithm: IScoringAlgorithm) => {
      LogUtils.d('ScoringView: Received SET_SCORING_ALGORITHM event');
      if (this.scoringMachine) {
        this.scoringMachine.setScoringAlgorithm(algorithm);
        LogUtils.d('ScoringView: Scoring algorithm set successfully');
      } else {
        LogUtils.e('ScoringView: ScoringMachine is null when receiving SET_SCORING_ALGORITHM event');
      }
    });

    // 监听评分难度设置事件
    this.eventBus.on(ScoringEvents.SET_SCORING_LEVEL, (level: number) => {
      LogUtils.d(`ScoringView: Received SET_SCORING_LEVEL event, level: ${level}`);
      if (this.scoringMachine) {
        this.scoringMachine.setScoringLevel(level);
        LogUtils.d(`ScoringView: Scoring level set to ${level} successfully`);
      } else {
        LogUtils.e('ScoringView: ScoringMachine is null when receiving SET_SCORING_LEVEL event');
      }
    });
  }

  /**
   * 移除事件监听器
   */
  private removeEventListeners(): void {
    LogUtils.d('ScoringView: Removing event listeners');
    this.stopFrameLoop();
  }

  /**
   * 初始化ScoringMachine
   */
  private initScoringMachine(): void {
    if (!this.scoringMachine) {
      LogUtils.d('ScoringView: Creating new ScoringMachine');

      /**
       * ScoringMachine监听器实现类
       */
      class ScoringViewListener implements OnScoringListener {
        private scoringView: ScoringView;

        constructor(scoringView: ScoringView) {
          this.scoringView = scoringView;
        }

        onLineFinished(line: LyricsLineModel, score: number, cumulativeScore: number, index: number,
          lineCount: number): void {
          LogUtils.d(`ScoringView: Line finished - score: ${score}, cumulative: ${cumulativeScore}`);
          this.scoringView.handleLineFinished(score, cumulativeScore);
        }

        resetUi(): void {
          LogUtils.d('ScoringView: resetUi called from ScoringMachine');
          this.scoringView.resetPitchIndicatorAndAnimation();
        }

        requestRefreshUi(): void {
          this.scoringView.requestRefreshUi();
        }

        onPitchAndScoreUpdate(speakerPitch: number, scoreAfterNormalization: number, progress: number): void {
          this.scoringView.updatePitchAndScore(speakerPitch, scoreAfterNormalization);
        }
      }

      const listener = new ScoringViewListener(this);
      this.scoringMachine = new ScoringMachine(listener);

      // 设置初始分数
      this.scoringMachine.setInitialScore(this.initialScore);

      LogUtils.d('ScoringView: ScoringMachine created successfully');

      // 启动帧循环用于动画更新
      this.startFrameLoopIfNeeded();
    } else {
      LogUtils.d('ScoringView: ScoringMachine already exists');
    }
  }

  /**
   * 处理行完成事件
   */
  handleLineFinished(score: number, cumulativeScore: number): void {
    this.currentScore = score;
    this.cumulativeScore = cumulativeScore;
    this.resetPitchIndicatorAndAnimationWhenFullLineFinished(score);
  }

  /**
   * 启动帧循环（用于动画更新）
   */
  private startFrameLoopIfNeeded(): void {
    if (this.frameLoopRunning) {
      return;
    }

    this.frameLoopRunning = true;

    const frameLoop = () => {
      if (!this.frameLoopRunning) {
        return;
      }

      // 指数平滑算法 - 完全对应Android版本的实现
      // 对应Java: float tauMs = 120f; float alpha = 1f - (float) Math.exp(-dtMs / tauMs);
      const tauMs = 120; // 平滑常数，对应Java版本的120f
      const dtMs = 16; // 帧间隔16ms (60fps)
      const alpha = 1 - Math.exp(-dtMs / tauMs);

      // 指数平滑更新pitch值 - 对应Java: mAnimatedPitch = mAnimatedPitch + (mLocalPitch - mAnimatedPitch) * alpha
      const oldAnimatedPitch = this.animatedPitch;
      this.animatedPitch = this.animatedPitch + (this.localPitch - this.animatedPitch) * alpha;

      // 更新音调指示器的Y坐标
      this.pitchIndicatorY = this.calculateYForPitchIndicator();

      // 更新pitch条数据
      this.updatePitchSticks();

      // 更新粒子发射点位置
      this.updateParticleEmissionPoint();

      // 平滑更新动画进度
      if (this.scoringMachine) {
        const machineProgress = this.scoringMachine.getCurrentPitchProgress();
        if (Math.abs(this.animatedProgressMs - machineProgress) > 2000) {
          this.animatedProgressMs = machineProgress; // 大跳跃时直接设置
        } else {
          this.animatedProgressMs = this.animatedProgressMs + (machineProgress - this.animatedProgressMs) * alpha;
        }
      }

      // 继续下一帧
      this.frameTimer = setTimeout(frameLoop, 16); // 约60fps
    };

    frameLoop();
  }

  /**
   * 停止帧循环
   */
  private stopFrameLoop(): void {
    this.frameLoopRunning = false;
    if (this.frameTimer !== -1) {
      clearTimeout(this.frameTimer);
      this.frameTimer = -1;
    }
  }

  /**
   * 重置评分显示
   */
  reset(): void {
    this.localPitch = 0;
    this.animatedPitch = 0;
    this.animatedProgressMs = 0;
    this.inHighlightStatus = false;
    this.preHighlightStatus = false;
    this.currentScore = 0;
    this.cumulativeScore = 0;
    this.pitchSticks = [];
  }

  /**
   * 更新音调和得分 - 对应Android的updatePitchAndScore
   * 只更新原始pitch值，平滑处理由帧循环负责
   */
  updatePitchAndScore(pitch: number, score: number): void {
    this.localPitch = pitch;

    this.inHighlightStatus = score >= this.hitScoreThreshold * 100;

    this.assureParticleAnimation(this.inHighlightStatus);

    this.startFrameLoopIfNeeded();
  }

  /**
   * 计算当前着色段的宽度 - 对应Android的实时着色逻辑
   */
  private calculateCurrentHighlightWidth(stick: PitchStickData): number {
    if (this.pitchHighlightedTime === -1) {
      return 0;
    }

    // 对应Android的40ms一段着色逻辑
    const INTERVAL_AUDIO_PCM = 40; // 40ms间隔
    const renderProgress = this.getRenderProgressMs();
    const highlightEndX = this.centerXOfStartPoint - this.movingPixelsPerMs * INTERVAL_AUDIO_PCM;
    const highlightStartX =
      this.centerXOfStartPoint + (this.pitchHighlightedTime - renderProgress) * this.movingPixelsPerMs;

    return Math.max(0, highlightEndX - highlightStartX);
  }

  /**
   * 计算当前着色段的起始X坐标
   */
  private calculateCurrentHighlightStartX(stick: PitchStickData): number {
    if (this.pitchHighlightedTime === -1) {
      return stick.x;
    }

    const renderProgress = this.getRenderProgressMs();
    return this.centerXOfStartPoint + (this.pitchHighlightedTime - renderProgress) * this.movingPixelsPerMs;
  }

  /**
   * 更新pitch条数据 - 对应Android的drawPitchSticks逻辑
   * 实现分段着色和持久着色效果
   */
  private updatePitchSticks(): void {
    if (!this.scoringMachine) {
      LogUtils.d('ScoringView: No scoring machine');
      this.pitchSticks = [];
      return;
    }

    if (!this.scoringMachine.isReady()) {
      LogUtils.d('ScoringView: Scoring machine not ready');
      this.pitchSticks = [];
      return;
    }

    if (!this.scoringMachine.hasPitchData()) {
      LogUtils.d('ScoringView: No pitch data available');
      this.pitchSticks = [];
      return;
    }

    const renderProgress = this.getRenderProgressMs();
    const pitchLines = this.scoringMachine.getPitchLines();

    if (!pitchLines || pitchLines.length === 0) {
      LogUtils.d('ScoringView: No pitch lines available');
      this.pitchSticks = [];
      return;
    }

    const realPitchMax = this.scoringMachine.getMaximumRefPitch() + 5;
    const realPitchMin = this.scoringMachine.getMinimumRefPitch() - 5;
    const stickHeightPerPitchLevel = (this.viewHeight - this.pitchStickHeight) / (realPitchMax - realPitchMin);

    const newPitchSticks: PitchStickData[] = [];

    // 遍历所有pitch行
    for (let i = 0; i < pitchLines.length; i++) {
      const line = pitchLines[i];
      const pitches = line.pitches;

      if (!pitches || pitches.length === 0) {
        continue;
      }

      // 检查是否在可见范围内
      const lineStartTime = line.getStartTime();
      const lineEndTime = line.getEndTime();

      if (Math.abs(renderProgress - lineEndTime) * this.movingPixelsPerMs >= this.viewWidth &&
        Math.abs(renderProgress - lineStartTime) * this.movingPixelsPerMs >= this.viewWidth &&
        !(renderProgress >= lineStartTime && renderProgress <= lineEndTime)) {
        continue; // 不在可见范围内
      }

      // 遍历该行的所有pitch
      for (let pitchIndex = 0; pitchIndex < pitches.length; pitchIndex++) {
        const pitch = pitches[pitchIndex];

        // 计算pitch条的X坐标和宽度
        const pixelsAwayFromPilot = (pitch.begin - renderProgress) * this.movingPixelsPerMs;
        const x = this.centerXOfStartPoint + pixelsAwayFromPilot;
        const width = this.movingPixelsPerMs * pitch.getDuration();
        const endX = x + width;

        // 视口裁剪：跳过不可见的pitch条
        if (endX <= 0) {
          // 当pitch条移出屏幕时，重置高亮状态
          pitch.resetHighlight();
          continue;
        }
        if (x >= this.viewWidth) {
          break;
        }

        // 计算Y坐标
        const y = (realPitchMax - pitch.pitch) * stickHeightPerPitchLevel;

        // 判断是否为当前正在演唱的pitch
        const isCurrentPitch = renderProgress >= pitch.begin && renderProgress <= pitch.end;

        // 处理着色逻辑 - 对应Android的highlightPartMap逻辑
        this.processHighlightLogic(pitch, isCurrentPitch, renderProgress);

        // 构建着色段数据
        const highlightSegments = this.buildHighlightSegments(pitch, renderProgress, x, width);

        // 判断是否高亮（基于演唱状态）
        const isHighlighted = isCurrentPitch && this.inHighlightStatus;

        newPitchSticks.push({
          x: x,
          y: y,
          width: width,
          height: this.pitchStickHeight,
          pitch: pitch.pitch,
          isHighlighted: isHighlighted,
          isCurrentPitch: isCurrentPitch,
          highlightSegments: highlightSegments
        });
      }
    }

    this.pitchSticks = newPitchSticks;
  }

  /**
   * 处理着色逻辑 - 对应Android的highlightPartMap处理
   */
  private processHighlightLogic(pitch: Pitch, isCurrentPitch: boolean, renderProgress: number): void {
    const INTERVAL_AUDIO_PCM = 40; // 40ms间隔，对应Android的Constants.INTERVAL_AUDIO_PCM

    if (!isCurrentPitch) {
      // 不是当前pitch时，完成所有未完成的着色段
      const keys = Array.from(pitch.highlightPartMap.keys());
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        const value = pitch.highlightPartMap.get(key);
        if (value === null) {
          pitch.highlightPartMap.set(key, { first: key, second: pitch.end });
        }
      }
    }

    if (isCurrentPitch) {
      if (this.inHighlightStatus) {
        // 开始新的着色段
        if (!this.preHighlightStatus) {
          this.pitchHighlightedTime = renderProgress;
          if (renderProgress - pitch.begin < INTERVAL_AUDIO_PCM) {
            this.pitchHighlightedTime = pitch.begin;
          }
          this.preHighlightStatus = this.inHighlightStatus;
        }

        // 记录着色段开始
        if (!pitch.highlightPartMap.has(this.pitchHighlightedTime)) {
          pitch.highlightPartMap.set(this.pitchHighlightedTime, null);
        }
      } else {
        // 结束着色段
        this.preHighlightStatus = false;
        if (this.pitchHighlightedTime !== -1) {
          pitch.highlightPartMap.set(this.pitchHighlightedTime, {
            first: this.pitchHighlightedTime,
            second: renderProgress
          });
          this.pitchHighlightedTime = -1;
        }
      }
    } else {
      // 不是当前pitch时重置状态
      if (this.preHighlightStatus) {
        this.preHighlightStatus = false;
      }
      if (this.pitchHighlightedTime !== -1) {
        this.pitchHighlightedTime = -1;
      }
    }
  }

  /**
   * 构建着色段数据 - 将highlightPartMap转换为UI可用的HighlightSegment数组
   */
  private buildHighlightSegments(pitch: Pitch, renderProgress: number, pitchX: number,
    pitchWidth: number): HighlightSegment[] {
    const segments: HighlightSegment[] = [];

    // 只处理已经移动到起始线左侧的pitch条
    if (pitchX < this.centerXOfStartPoint) {
      const keys = Array.from(pitch.highlightPartMap.keys());
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        const value = pitch.highlightPartMap.get(key);
        if (value !== null && value !== undefined) {
          // 完成的着色段
          const highlightStartTime = value.first;
          const highlightEndTime = value.second;

          const highlightStartX =
            this.centerXOfStartPoint + (highlightStartTime - renderProgress) * this.movingPixelsPerMs;
          const highlightEndX = highlightStartX + this.movingPixelsPerMs * (highlightEndTime - highlightStartTime);

          // 确保着色段在pitch条范围内
          const clampedStartX = Math.max(highlightStartX, pitchX);
          const clampedEndX = Math.min(highlightEndX, pitchX + pitchWidth);

          if (clampedEndX > clampedStartX) {
            segments.push({
              startX: clampedStartX,
              endX: clampedEndX,
              startTime: highlightStartTime,
              endTime: highlightEndTime
            });
          }
        } else {
          // 正在进行的着色段（当前正在唱）
          if (pitch.begin <= renderProgress && renderProgress <= pitch.end) {
            const highlightStartTime = key;
            const highlightStartX =
              this.centerXOfStartPoint + (highlightStartTime - renderProgress) * this.movingPixelsPerMs;
            const highlightEndX = this.centerXOfStartPoint;

            const clampedStartX = Math.max(highlightStartX, pitchX);
            const clampedEndX = Math.min(highlightEndX, pitchX + pitchWidth);

            if (clampedEndX > clampedStartX) {
              segments.push({
                startX: clampedStartX,
                endX: clampedEndX,
                startTime: highlightStartTime,
                endTime: renderProgress
              });
            }
          }
        }
      }
    }

    return segments;
  }

  /**
   * 重置音调指示器和动画
   */
  resetPitchIndicatorAndAnimation(): void {
    this.inHighlightStatus = false;
    this.localPitch = 0;
    this.pitchHighlightedTime = -1; // 重置着色时间
  }

  /**
   * 当整行完成时重置音调指示器和动画
   */
  resetPitchIndicatorAndAnimationWhenFullLineFinished(score: number): void {
    if (score === 0) {
      this.inHighlightStatus = false;
      this.localPitch = 0;
    }
  }

  /**
   * 请求刷新UI
   */
  requestRefreshUi(): void {
    // UI会自动更新
  }

  /**
   * 创建粒子配置
   */
  private createParticleConfig(): Partial<ParticleConfig> {
    const speedRange: Range = { min: 1.0, max: 3.0 }; // 增加速度，使粒子更容易看到
    const angleRange: Range = { min: 130, max: 230 };
    const rotationSpeedRange: Range = { min: 90, max: 180 };
    const scaleRange: Range = { min: 1.0, max: 2.0 }; // 增加大小，使粒子更容易看到

    const config: Partial<ParticleConfig> = {
      particlesPerSecond: 20, // 增加发射频率，便于测试
      maxParticles: 24,
      particleLifetime: 900, // 对应Android的900ms
      speedRange: speedRange, // 对应Android的setSpeedModuleAndAngleRange
      angleRange: angleRange, // 对应Android的130, 230度
      rotationSpeedRange: rotationSpeedRange, // 对应Android的setRotationSpeedRange
      scaleRange: scaleRange, // 对应Android的setScaleRange
      fadeOutDuration: 300 // 对应Android的setFadeOut(300)
    };

    return config;
  }

  /**
   * 初始化粒子系统 - 对应Android的initParticleSystem
   */
  private initParticleSystem(): void {
    if (this.enableParticleEffect) {
      LogUtils.d('ScoringView: Initializing particle system');
      this.particleSystem = new ParticleSystem(this.createParticleConfig());
      LogUtils.d('ScoringView: Particle system initialized successfully');
    }
  }

  /**
   * 清理粒子系统
   */
  private cleanupParticleSystem(): void {
    if (this.particleSystem) {
      LogUtils.d('ScoringView: Cleaning up particle system');
      this.particleSystem.cancel();
      this.particleSystem = null;
      this.emittingInitialized = false;
    }
  }

  /**
   * 确保粒子动画效果 - 对应Android的assureAnimationForPitchIndicator
   */
  private assureParticleAnimation(inHighlightStatus: boolean): void {

    if (!this.enableParticleEffect || !this.particleSystem) {
      LogUtils.d(`ScoringView: Particle animation skipped - enableParticleEffect: ${this.enableParticleEffect}, particleSystem: ${this.particleSystem !==
        null}`);
      return;
    }

    if (inHighlightStatus) {
      if (!this.emittingInitialized) {
        const emitX = this.centerXOfStartPoint;
        const emitY = this.pitchIndicatorY;

        this.particleSystem.emit(emitX, emitY); // 使用配置中的发射频率
        this.emittingInitialized = true;
      } else {
        // 更新发射点位置
        this.particleSystem.updateEmitPoint(this.centerXOfStartPoint, this.pitchIndicatorY);
      }

      this.particleSystem.resumeEmitting();
    } else {
      // 分数低于阈值，停止发射粒子
      if (this.particleSystem) {
        this.particleSystem.stopEmitting();
      }
    }
  }

  /**
   * 更新粒子发射点位置 - 在帧循环中调用
   */
  private updateParticleEmissionPoint(): void {
    if (this.enableParticleEffect && this.particleSystem && this.inHighlightStatus) {
      // 平滑更新粒子发射点位置 - 对应Android的帧循环中的粒子位置更新
      this.particleSystem.updateEmitPoint(this.centerXOfStartPoint, this.pitchIndicatorY);
    }
  }
}
