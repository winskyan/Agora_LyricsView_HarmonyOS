import { IScoringAlgorithm } from '../IScoringAlgorithm';
import { OnScoringListener, ScoringMachine } from '../internal/ScoringMachine';
import { LyricModel } from '../model/LyricModel';
import { LyricsLineModel } from '../model/LyricsLineModel';
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
  @Prop localPitchIndicatorColor: string = "#F0F0F0F0"
  @Prop pitchIndicatorWidth: number = 3;
  @Prop pitchIndicatorRadius: number = 8;
  @Prop pitchStickHighlightedColor: string = '#FFF44336';
  @Prop pitchStickHeight: number = 4;
  @Prop initialScore: number = 0;
  @Prop movingPixelsPerMs: number = 0.4;
  @Prop hitScoreThreshold: number = 0.7;
  @Prop startPointHorizontalBias: number = 0.4;
  @Prop offProgressTimeThreshold: number = 1000;
  @Prop enableParticleEffect: boolean = true;
  @Prop refPitchStickDefaultColor: string = '#9C27B0';
  // 状态变量
  @State currentScore: number = 0;
  @State cumulativeScore: number = 0;
  @State localPitch: number = 0;
  @State inHighlightStatus: boolean = false;
  @State animatedPitch: number = 0;
  @State animatedProgressMs: number = 0;
  @State preHighlightStatus: boolean = false;
  // UI布局相关
  @State centerXOfStartPoint: number = 0;
  @State viewWidth: number = 0;
  @State viewHeight: number = 0;
  @State pitchIndicatorY: number = 0; // 音调指示器的Y坐标
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
      //this.buildOverPastWall()

      // 第3层：竖直起始线（最上层，确保可见）
      this.buildStartLine()

      // 参考音调条（根据歌词pitch数据）
      //this.buildPitchSticks()

      // 用户音调指示器
      this.buildLocalPitchIndicator()
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

      // 通知外部组件ScoringView已准备好
      setTimeout(() => {
        LogUtils.d('ScoringView: Ready for events, emitting COMPONENT_READY');
        this.eventBus.emit(ScoringEvents.COMPONENT_READY);
      }, 10);
    })
    .onDisAppear(() => {
      LogUtils.d('ScoringView: Component disappearing, cleaning up');
      this.removeEventListeners();
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
          direction: GradientDirection.Left, // 从左到右的渐变
          colors: [
            ['rgba(255, 255, 255, 0)', 0], // 左边界 - 完全透明白色
            ['rgba(36, 198, 255, 0.12)', 1]// 右边界 - 12%透明度的蓝色
          ]
        })
        .position({ x: 0, y: 0 })
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
   * 构建音调条 - 静态示例音调条
   */
  @Builder
  buildPitchSticks() {
    // 暂时显示静态的音调条作为示例
    if (this.viewWidth > 0 && this.viewHeight > 0) {
      Row() {
        Rect()
          .width(60)
          .height(this.pitchStickHeight)
          .fill('#9C27B0') // 紫色音调条
          .borderRadius(2)
          .margin({ left: 10, right: 5 })

        Rect()
          .width(40)
          .height(this.pitchStickHeight)
          .fill('#9C27B0')
          .borderRadius(2)
          .margin({ left: 5, right: 5 })

        Rect()
          .width(50)
          .height(this.pitchStickHeight)
          .fill('#9C27B0')
          .borderRadius(2)
          .margin({ left: 5, right: 10 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .position({ x: 0, y: this.viewHeight / 2 })
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
      Circle({ width: this.pitchIndicatorRadius * 2, height: this.pitchIndicatorRadius * 2 })
        .fill(this.localPitchIndicatorColor)
        .strokeWidth(2)
        .position({
          x: this.centerXOfStartPoint - this.pitchIndicatorRadius,
          y: this.pitchIndicatorY - this.pitchIndicatorRadius
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
      targetY = this.viewHeight - this.pitchIndicatorRadius;
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
    if (targetY < this.pitchIndicatorRadius) {
      targetY += this.pitchIndicatorRadius;
    }
    if (targetY > this.viewHeight - this.pitchIndicatorRadius) {
      targetY -= this.pitchIndicatorRadius;
    }

    return targetY;
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

      // 平滑动画更新
      const tauMs = 120; // 平滑常数
      const dtMs = 16; // 假设60fps
      const alpha = 1 - Math.exp(-dtMs / tauMs);

      // 平滑更新动画音调
      this.animatedPitch = this.animatedPitch + (this.localPitch - this.animatedPitch) * alpha;

      // 更新音调指示器的Y坐标
      this.pitchIndicatorY = this.calculateYForPitchIndicator();

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
  }

  /**
   * 更新音调和得分
   */
  updatePitchAndScore(pitch: number, score: number): void {
    this.localPitch = pitch;
    this.inHighlightStatus = score >= this.hitScoreThreshold * 100;
  }

  /**
   * 重置音调指示器和动画
   */
  resetPitchIndicatorAndAnimation(): void {
    this.inHighlightStatus = false;
    this.localPitch = 0;
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
}
