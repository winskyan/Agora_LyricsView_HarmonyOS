import { IScoringAlgorithm } from '../IScoringAlgorithm';
import { LyricModel } from '../model/LyricModel';
import { LyricsLineModel } from '../model/LyricsLineModel';
import { Pitch, PitchLineModel } from '../model/PitchLineModel';
import { LogUtils } from '../utils/LogUtils';
import { DefaultScoringAlgorithm } from './scoring/DefaultScoringAlgorithm';


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

  /**
   * 音调和得分更新回调
   * @param speakerPitch 处理后的用户音调
   * @param scoreAfterNormalization 标准化后的得分(0-100)
   * @param progress 当前进度(毫秒)
   */
  onPitchAndScoreUpdate(speakerPitch: number, scoreAfterNormalization: number, progress: number): void;
}


/**
 * 评分机器 - HarmonyOS版本
 * 对应Android项目中的ScoringMachine
 * 负责管理卡拉OK评分计算和状态
 */
export class ScoringMachine {
  private lyricsModel: LyricModel | null = null;
  private listener?: OnScoringListener;
  private currentLyricProgress: number = 0;
  private maximumRefPitch: number = 0;
  private minimumRefPitch: number = 100;
  private pitchLines: PitchLineModel[] = [];
  private scoringAlgorithm: IScoringAlgorithm;
  private usingInternalScoring: boolean = false;
  private deltaOfUpdate: number = 20; // 默认更新间隔20ms
  private pitchesForLine: Map<number, number> = new Map();
  private scoreForEachLine: Map<number, number> = new Map();
  private timestampOfFirstRefPitch: number = -1;
  private endTimeOfThisLyrics: number = 0;
  private indexOfCurrentLine: number = 0;
  private initialScore: number = 0;
  private cumulativeScore: number = 0;
  private continuousZeroCount: number = 0;
  private readonly ZERO_PITCH_COUNT_THRESHOLD: number = 10;

  constructor(listener?: OnScoringListener) {
    this.listener = listener;
    this.scoringAlgorithm = new DefaultScoringAlgorithm();
    this.reset();
  }

  /**
   * 准备评分数据
   * @param model 歌词模型
   * @param usingInternalScoring 是否使用内部评分算法
   */
  prepare(model: LyricModel, usingInternalScoring: boolean): void {
    this.reset();

    if (!model || !model.lines || model.lines.length === 0) {
      LogUtils.e('ScoringMachine: Invalid lyrics model');
      return;
    }

    this.lyricsModel = this.mayBeFixLyricModel(model);
    this.usingInternalScoring = usingInternalScoring;
    this.endTimeOfThisLyrics = model.lines[model.lines.length - 1].getEndTime();
    this.timestampOfFirstRefPitch = model.preludeEndPosition;

    // 处理音调数据
    if (model.hasPitch) {
      this.processPitchData(model);
    } else {
      LogUtils.d('ScoringMachine: Model has no pitch data');
    }

    LogUtils.d(`ScoringMachine: Prepared with ${model.lines.length} lines, pitch range: ${this.minimumRefPitch} - ${this.maximumRefPitch}`);
  }

  /**
   * 修复歌词模型中的潜在问题，比如重叠的歌词行
   *
   * @param model 原始歌词模型
   * @returns 修复后的歌词模型
   */
  private mayBeFixLyricModel(model: LyricModel): LyricModel {
    if (!model || !model.lines || model.lines.length === 0) {
      LogUtils.e('ScoringMachine: Invalid lyrics model in mayBeFixLyricModel');
      return model;
    }

    // 创建模型的副本进行修复
    const newModel = model.copy();

    if (!newModel.lines || newModel.lines.length === 0) {
      return model;
    }

    let preLineModel = newModel.lines[0];
    for (let i = 1; i < newModel.lines.length; i++) {
      const lineModel = newModel.lines[i];

      // 检查当前行的开始时间是否早于前一行的结束时间（重叠情况）
      if (lineModel.getStartTime() < preLineModel.getEndTime()) {
        const tones = lineModel.tones;

        if (tones && tones.length > 0) {
          // 修复重叠的音调段
          for (const tone of tones) {
            if (tone.begin < preLineModel.getEndTime()) {
              // 将音调段的开始时间调整为前一行的结束时间
              tone.begin = preLineModel.getEndTime();

              // 确保结束时间不早于开始时间
              if (tone.end < tone.begin) {
                tone.end = tone.begin;
              }
            } else {
              // 如果当前音调段不重叠，后续的也不会重叠，可以跳出
              break;
            }
          }
        }
      }

      preLineModel = lineModel;
    }

    LogUtils.d('ScoringMachine: mayBeFixLyricModel completed, fixed potential overlapping issues');
    return newModel;
  }

  /**
   * 处理音调数据
   * @param model 歌词模型
   */
  private processPitchData(model: LyricModel): void {
    if (model.pitchDataList && model.pitchDataList.length > 0) {
      // 使用独立的音调数据
      for (const data of model.pitchDataList) {
        this.minimumRefPitch = Math.min(this.minimumRefPitch, data.pitch);
        this.maximumRefPitch = Math.max(this.maximumRefPitch, data.pitch);
      }

      this.pitchLines = [];
      const firstStartTime = model.lines[0].getStartTime();
      const lastEndTime = model.lines[model.lines.length - 1].getEndTime();

      for (const line of model.lines) {
        const lineModel = new PitchLineModel();
        const startTime = line.getStartTime();
        const endTime = line.getEndTime();

        for (const data of model.pitchDataList) {
          if (data.startTime >= startTime && data.startTime < endTime) {
            const pitch = new Pitch();
            pitch.begin = Math.max(data.startTime, firstStartTime);
            pitch.end = Math.min(data.startTime + data.duration, lastEndTime);
            pitch.pitch = data.pitch;
            lineModel.pitches.push(pitch);
          }
        }
        this.pitchLines.push(lineModel);
      }
    } else {
      // 使用歌词行中的音调数据
      this.pitchLines = [];
      for (const line of model.lines) {
        const lineModel = new PitchLineModel();
        if (line.tones && line.tones.length > 0) {
          for (const tone of line.tones) {
            const pitch = new Pitch();
            pitch.begin = tone.begin;
            pitch.end = tone.end;
            pitch.pitch = tone.pitch;

            this.minimumRefPitch = Math.min(this.minimumRefPitch, pitch.pitch);
            this.maximumRefPitch = Math.max(this.maximumRefPitch, pitch.pitch);

            lineModel.pitches.push(pitch);
          }
        }
        this.pitchLines.push(lineModel);
      }
    }
  }

  /**
   * 设置音调数据
   * @param speakerPitch 当前音调值
   * @param pitchScore 音调得分
   */
  setPitch(speakerPitch: number, pitchScore: number): void {
    if (!this.lyricsModel) {
      this.listener?.resetUi();
      return;
    }

    // 处理音调评分
    this.processPitchScoring(speakerPitch, pitchScore, this.currentLyricProgress);
    this.listener?.requestRefreshUi();
  }

  /**
   * 处理音调评分
   * @param speakerPitch 用户音调
   * @param pitchScore 音调得分
   * @param progressInMs 当前进度
   */
  private processPitchScoring(speakerPitch: number, pitchScore: number, progressInMs: number): void {
    const newLine: boolean[] = [false];
    const indexOfMostRecentLine: number[] = [-1];
    let currentRefPitch = -1;

    if (this.usingInternalScoring) {
      currentRefPitch = this.findRefPitchByTime(progressInMs, newLine, indexOfMostRecentLine);
    }

    // 处理连续零音调
    if (speakerPitch === 0) {
      if (++this.continuousZeroCount < this.ZERO_PITCH_COUNT_THRESHOLD) {
        if (this.usingInternalScoring) {
          this.updateScoreForMostRecentLine(progressInMs, newLine[0], indexOfMostRecentLine[0]);
        }
        return;
      }
    } else {
      this.continuousZeroCount = 0;
    }

    if (this.usingInternalScoring) {
      if (currentRefPitch <= 0 || this.continuousZeroCount >= this.ZERO_PITCH_COUNT_THRESHOLD) {
        this.continuousZeroCount = 0;
        this.updateScoreForMostRecentLine(progressInMs, newLine[0], indexOfMostRecentLine[0]);
        this.listener?.resetUi();
        return;
      }

      this.updateScoreForMostRecentLine(progressInMs, newLine[0], indexOfMostRecentLine[0]);

      // 简化的音调处理
      const pitchAfterProcess = speakerPitch;
      const scoreAfterNormalization = this.scoringAlgorithm.getPitchScore(pitchAfterProcess, currentRefPitch);
      this.pitchesForLine.set(progressInMs, scoreAfterNormalization);

      this.listener?.onPitchAndScoreUpdate(pitchAfterProcess, scoreAfterNormalization, progressInMs);
    } else {
      const calculateScore = pitchScore > 0 ? pitchScore : this.calculateScoreWithPitch(speakerPitch, progressInMs);
      this.listener?.onPitchAndScoreUpdate(speakerPitch, calculateScore, progressInMs);
    }
  }

  /**
   * 设置歌词进度
   * @param progress 当前进度（毫秒）
   */
  setLyricProgress(progress: number): void {
    this.currentLyricProgress = progress;
  }


  /**
   * 根据时间查找参考音调
   * @param timestamp 时间戳
   * @param returnNewLine 是否为新行
   * @param returnIndexOfMostRecentLine 最近行索引
   * @returns 参考音调值
   */
  private findRefPitchByTime(timestamp: number, returnNewLine: boolean[],
    returnIndexOfMostRecentLine: number[]): number {
    if (!this.lyricsModel || !this.lyricsModel.lines) {
      return -1;
    }

    let referencePitch = -1;
    const numberOfLines = this.lyricsModel.lines.length;
    let timestampLineIndex = -1;

    for (let i = 0; i < numberOfLines; i++) {
      const line = this.lyricsModel.lines[i];
      if (timestamp >= line.getStartTime() && timestamp <= line.getEndTime()) {
        if (line.tones && line.tones.length > 0) {
          for (let j = 0; j < line.tones.length; j++) {
            const tone = line.tones[j];
            if (timestamp >= tone.begin && timestamp <= tone.end) {
              referencePitch = tone.pitch;
              if (j === line.tones.length - 1) {
                timestampLineIndex = i;
              }
              break;
            }
          }
        }
        break;
      }
    }

    if (referencePitch !== -1) {
      this.pitchesForLine.set(timestamp, -1);
    }

    if (this.isNewLine(timestamp, numberOfLines, timestampLineIndex)) {
      returnIndexOfMostRecentLine[0] = this.indexOfCurrentLine;
      returnNewLine[0] = true;
    }

    if (timestampLineIndex !== -1 && timestampLineIndex !== this.indexOfCurrentLine) {
      this.indexOfCurrentLine = timestampLineIndex;
    }

    return referencePitch;
  }

  /**
   * 判断是否为新行
   * @param timestamp 时间戳
   * @param numberOfLines 总行数
   * @param timestampLineIndex 当前行索引
   * @returns 是否为新行
   */
  private isNewLine(timestamp: number, numberOfLines: number, timestampLineIndex: number): boolean {
    let newLine = false;

    if (this.indexOfCurrentLine >= 0 && this.indexOfCurrentLine + 1 <= numberOfLines) {
      if (timestamp > this.lyricsModel!.lines[this.indexOfCurrentLine].getEndTime()) {
        if (timestampLineIndex === -1) {
          if (!this.scoreForEachLine.has(this.indexOfCurrentLine)) {
            newLine = true;
          }
        } else if (this.indexOfCurrentLine !== timestampLineIndex) {
          if (!this.scoreForEachLine.has(this.indexOfCurrentLine)) {
            newLine = true;
          }
        }
      }
    } else if (this.indexOfCurrentLine + 2 === numberOfLines) {
      if (timestamp >= this.lyricsModel!.lines[this.indexOfCurrentLine].getEndTime()) {
        if (!this.scoreForEachLine.has(this.indexOfCurrentLine)) {
          newLine = true;
        }
      }
    }

    return newLine;
  }

  /**
   * 更新最近行的得分
   * @param timestamp 时间戳
   * @param newLine 是否为新行
   * @param indexOfMostRecentLine 最近行索引
   */
  private updateScoreForMostRecentLine(timestamp: number, newLine: boolean, indexOfMostRecentLine: number): void {
    if ((timestamp < this.timestampOfFirstRefPitch) || this.timestampOfFirstRefPitch === -1) {
      return;
    }

    if (timestamp > this.endTimeOfThisLyrics + (2 * this.deltaOfUpdate)) {
      return;
    }

    if (newLine && this.lyricsModel) {
      const lineJustFinished = this.lyricsModel.lines[indexOfMostRecentLine];
      const scoreThisTime =
        this.scoringAlgorithm.getLineScore(this.pitchesForLine, indexOfMostRecentLine, lineJustFinished);

      this.cumulativeScore += scoreThisTime;

      LogUtils.d(`ScoringMachine: Line ${indexOfMostRecentLine} finished, score: ${scoreThisTime}, cumulative: ${this.cumulativeScore}`);

      this.listener?.onLineFinished(lineJustFinished, scoreThisTime, this.cumulativeScore, indexOfMostRecentLine,
        this.lyricsModel.lines.length);
      this.scoreForEachLine.set(indexOfMostRecentLine, scoreThisTime);
    }
  }

  /**
   * 根据音调计算得分
   * @param speakerPitch 用户音调
   * @param progressInMs 当前进度
   * @returns 计算得分
   */
  calculateScoreWithPitch(speakerPitch: number, progressInMs: number): number {
    const refPitch = this.getRefPitch(progressInMs);

    if (refPitch === 0) {
      return 0;
    }

    let scoreAfterNormalization = 0;

    if (speakerPitch == refPitch) {
      scoreAfterNormalization = 100;
    } else if (Math.abs(speakerPitch - refPitch) <= 1) {
      scoreAfterNormalization = 90;
    } else if (Math.abs(speakerPitch - refPitch) <= 2) {
      scoreAfterNormalization = 80;
    } else if (Math.abs(speakerPitch - refPitch) <= 3) {
      scoreAfterNormalization = 70;
    } else if (Math.abs(speakerPitch - refPitch) <= 4) {
      scoreAfterNormalization = 60;
    } else if (Math.abs(speakerPitch - refPitch) <= 5) {
      scoreAfterNormalization = 50;
    }

    return scoreAfterNormalization;
  }

  /**
   * 获取指定时间的参考音调
   * @param progressInMs 进度时间
   * @returns 参考音调
   */
  getRefPitch(progressInMs: number): number {
    if (!this.lyricsModel) {
      return 0;
    }

    if (this.lyricsModel.hasPitch) {
      if (this.lyricsModel.pitchDataList) {
        for (const data of this.lyricsModel.pitchDataList) {
          if (data.startTime <= progressInMs && data.startTime + data.duration >= progressInMs) {
            return data.pitch;
          }
        }
      } else if (this.lyricsModel.lines) {
        for (const line of this.lyricsModel.lines) {
          if (line.tones) {
            for (const tone of line.tones) {
              if (tone.begin <= progressInMs && tone.end >= progressInMs) {
                return tone.pitch;
              }
            }
          }
        }
      }
    }

    return 0;
  }

  /**
   * 重置状态
   */
  reset(): void {
    this.resetProperties();
    this.resetStats();
  }

  /**
   * 重置属性
   */
  private resetProperties(): void {
    this.lyricsModel = null;
    this.minimumRefPitch = 100;
    this.maximumRefPitch = 0;
    this.timestampOfFirstRefPitch = -1;
    this.endTimeOfThisLyrics = 0;
  }

  /**
   * 重置统计数据
   */
  private resetStats(): void {
    this.minorReset();
    this.cumulativeScore = this.initialScore;
    this.scoreForEachLine.clear();
  }

  /**
   * 轻微重置
   */
  private minorReset(): void {
    this.currentLyricProgress = 0;
    this.indexOfCurrentLine = 0;
    this.pitchesForLine.clear();
  }

  /**
   * 处理拖拽事件
   * @param progress 拖拽到的进度
   */
  whenDraggingHappen(progress: number): void {
    this.minorReset();

    if (this.lyricsModel) {
      for (let index = 0; index < this.lyricsModel.lines.length; index++) {
        const line = this.lyricsModel.lines[index];
        if (progress <= line.getStartTime()) {
          this.scoreForEachLine.delete(index);
        }
      }

      this.cumulativeScore = this.initialScore;
      for (const score of this.scoreForEachLine.values()) {
        this.cumulativeScore += score;
      }
    }
  }

  /**
   * 准备UI
   */
  prepareUi(): void {
    this.listener?.resetUi();
  }

  // Getter方法
  isReady(): boolean {
    return this.lyricsModel !== null;
  }

  getCurrentPitchProgress(): number {
    return this.currentLyricProgress;
  }

  getMinimumRefPitch(): number {
    return this.minimumRefPitch;
  }

  getMaximumRefPitch(): number {
    return this.maximumRefPitch;
  }

  getPitchLines(): PitchLineModel[] {
    return this.pitchLines;
  }

  hasPitchData(): boolean {
    return this.lyricsModel?.hasPitch || false;
  }

  getLineStartTime(lineIndex: number): number {
    if (!this.lyricsModel || lineIndex < 0 || lineIndex >= this.lyricsModel.lines.length) {
      return 0;
    }
    return this.lyricsModel.lines[lineIndex].getStartTime();
  }

  setInitialScore(initialScore: number): void {
    this.cumulativeScore += initialScore;
    this.initialScore = initialScore;
  }

  /**
   * 设置评分算法
   * @param algorithm 评分算法
   */
  setScoringAlgorithm(algorithm: IScoringAlgorithm): void {
    if (!algorithm) {
      throw new Error('IScoringAlgorithm should not be null');
    }
    this.scoringAlgorithm = algorithm;
  }

  /**
   * 设置评分难度
   * @param level 难度等级
   */
  setScoringLevel(level: number): void {
    if (this.scoringAlgorithm) {
      this.scoringAlgorithm.setScoringLevel(level);
    }
  }

  /**
   * 获取评分难度
   * @returns 难度等级
   */
  getScoringLevel(): number {
    if (this.scoringAlgorithm) {
      return this.scoringAlgorithm.getScoringLevel();
    }
    return 0;
  }

  /**
   * 设置评分补偿偏移
   * @param offset 偏移值
   */
  setScoringCompensationOffset(offset: number): void {
    if (this.scoringAlgorithm) {
      this.scoringAlgorithm.setScoringCompensationOffset(offset);
    }
  }

  /**
   * 获取评分补偿偏移
   * @returns 偏移值
   */
  getScoringCompensationOffset(): number {
    if (this.scoringAlgorithm) {
      return this.scoringAlgorithm.getScoringCompensationOffset();
    }
    return 0;
  }

  /**
   * 检查是否使用内部评分
   * @returns 是否使用内部评分
   */
  isUsingInternalScoring(): boolean {
    return this.usingInternalScoring;
  }
}
