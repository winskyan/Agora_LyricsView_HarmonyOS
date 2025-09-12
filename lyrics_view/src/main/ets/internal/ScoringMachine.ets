import { LyricModel } from '../model/LyricModel';
import { LyricsLineModel } from '../model/LyricsLineModel';

/**
 * 评分机器监听器接口
 */
export interface OnScoringListener {
  /**
   * 歌词行完成回调
   * @param line 完成的歌词行
   * @param score 本行得分
   * @param cumulativeScore 累计得分
   * @param index 行索引
   * @param lineCount 总行数
   */
  onLineFinished(line: LyricsLineModel, score: number, cumulativeScore: number, index: number, lineCount: number): void;

  /**
   * 重置UI
   */
  resetUi(): void;

  /**
   * 请求刷新UI
   */
  requestRefreshUi(): void;
}

/**
 * 评分算法接口
 */
export interface IScoringAlgorithm {
  /**
   * 计算得分
   * @param referencePitch 参考音调
   * @param userPitch 用户音调
   * @param duration 持续时间
   * @returns 得分
   */
  calculateScore(referencePitch: number, userPitch: number, duration: number): number;
}

/**
 * 评分机器 - HarmonyOS版本
 * 对应Android项目中的ScoringMachine
 * 负责管理卡拉OK评分计算和状态
 */
export class ScoringMachine {
  private lyricModel: LyricModel | null = null;
  private currentProgress: number = 0;
  private isReady: boolean = false;
  private usingInternalScoring: boolean = true;
  private scoringLevel: number = 15;
  private scoringCompensationOffset: number = 0;
  private scoringAlgorithm?: IScoringAlgorithm;
  private listener?: OnScoringListener;

  constructor(listener?: OnScoringListener) {
    this.listener = listener;
  }

  /**
   * 准备评分数据
   * @param model 歌词模型
   * @param usingInternalScoring 是否使用内部评分算法
   */
  prepare(model: LyricModel, usingInternalScoring: boolean): void {
    this.lyricModel = model;
    this.usingInternalScoring = usingInternalScoring;
    this.isReady = true;
  }

  /**
   * 设置音调数据
   * @param speakerPitch 当前音调值
   * @param pitchScore 音调得分
   * @param progressInMs 当前进度（毫秒）
   */
  setPitch(speakerPitch: number, pitchScore: number, progressInMs: number): void {
    // TODO: 实现音调处理逻辑
  }

  /**
   * 设置歌词进度
   * @param progress 当前进度（毫秒）
   */
  setLyricProgress(progress: number): void {
    this.currentProgress = progress;
    // TODO: 实现进度更新和评分计算逻辑
  }

  /**
   * 设置评分算法
   * @param algorithm 评分算法
   */
  setScoringAlgorithm(algorithm: IScoringAlgorithm): void {
    this.scoringAlgorithm = algorithm;
  }

  /**
   * 设置评分难度
   * @param level 难度等级
   */
  setScoringLevel(level: number): void {
    this.scoringLevel = level;
  }

  /**
   * 获取评分难度
   * @returns 难度等级
   */
  getScoringLevel(): number {
    return this.scoringLevel;
  }

  /**
   * 设置评分补偿偏移（已废弃）
   * @param offset 偏移值
   * @deprecated 使用setScoringLevel替代
   */
  setScoringCompensationOffset(offset: number): void {
    this.scoringCompensationOffset = offset;
  }

  /**
   * 获取评分补偿偏移（已废弃）
   * @returns 偏移值
   * @deprecated 使用getScoringLevel替代
   */
  getScoringCompensationOffset(): number {
    return this.scoringCompensationOffset;
  }

  /**
   * 重置状态
   */
  reset(): void {
    this.lyricModel = null;
    this.currentProgress = 0;
    this.isReady = false;
    this.listener?.resetUi();
  }

  /**
   * 处理拖拽事件
   * @param progress 拖拽到的进度
   */
  whenDraggingHappen(progress: number): void {
    this.currentProgress = progress;
    // TODO: 实现拖拽处理逻辑
  }

  /**
   * 准备UI
   */
  prepareUi(): void {
    this.listener?.requestRefreshUi();
  }
}
