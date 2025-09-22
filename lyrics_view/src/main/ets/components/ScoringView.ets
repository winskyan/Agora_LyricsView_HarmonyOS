import { OnScoringListener, ScoringMachine } from '../internal/ScoringMachine';
import { IScoringAlgorithm } from '../IScoringAlgorithm';
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
  // 配置参数 (对应Android attrs.xml)
  @Prop pitchIndicatorColor: string = '#FF6B35';
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
  @State private currentScore: number = 0;
  @State private cumulativeScore: number = 0;
  @State private localPitch: number = 0;
  @State private inHighlightStatus: boolean = false;
  @State private animatedPitch: number = 0;
  @State private animatedProgressMs: number = 0;
  @State private preHighlightStatus: boolean = false;
  // 内部变量
  private eventBus: EventBus = EventBus.getInstance();
  private scoringMachine: ScoringMachine | null = null;
  private frameLoopRunning: boolean = false;
  private frameTimer: number = -1;

  build() {
    Column() {
      // 得分显示区域
      Row() {
        Text(`当前得分: ${this.currentScore}`)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .margin({ right: 20 })

        Text(`累计得分: ${this.cumulativeScore}`)
          .fontSize(16)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(10)

      // 音调指示器区域
      Row() {
        Text('音调指示器')
          .fontSize(14)
          .fontColor('#CCCCCC')
          .margin({ right: 10 })

        // 简化的音调指示器
        Circle({ width: this.pitchIndicatorRadius * 2, height: this.pitchIndicatorRadius * 2 })
          .fill(this.inHighlightStatus ? this.pitchStickHighlightedColor : this.pitchIndicatorColor)
          .opacity(this.localPitch > 0 ? 1 : 0.3)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(10)

      // 音调条显示区域（简化版本）
      Column() {
        Text('音调可视化区域')
          .fontSize(12)
          .fontColor('#999999')
          .textAlign(TextAlign.Center)

        // 简化的音调条显示
        Row() {
          ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], (index: number) => {
            Rect()
              .width(20)
              .height(this.pitchStickHeight)
              .fill(this.refPitchStickDefaultColor)
              .margin({ left: 2, right: 2 })
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding(10)
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1A1A1A')
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

    // 监听播放进度设置事件
    this.eventBus.on(ScoringEvents.SET_PROGRESS, (progress: number) => {
      if (this.scoringMachine) {
        this.scoringMachine.setLyricProgress(progress);
      }
    });

    // 监听重置事件
    this.eventBus.on(ScoringEvents.RESET, () => {
      LogUtils.d('ScoringView: Received RESET event');
      this.reset();
      if (this.scoringMachine) {
        this.scoringMachine.reset();
      }
    });

    // 监听刷新UI事件
    this.eventBus.on(ScoringEvents.REQUEST_REFRESH, () => {
      LogUtils.d('ScoringView: Received REQUEST_REFRESH event');
      this.requestRefreshUi();
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
    // 这里可以添加具体的移除逻辑，但由于EventBus是单例，
    // 我们可能需要保存回调函数的引用来正确移除
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
   * @param pitch 音调值
   * @param score 得分值
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
   * @param score 本行得分
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
