import { IScoringAlgorithm } from '../../IScoringAlgorithm';
import { LyricsLineModel, Tone } from '../../model/LyricsLineModel';
import { AIAlgorithmNative } from '../../native/AIAlgorithmNative';
import { LogUtils } from '../../utils/LogUtils';

/**
 * Default implementation of the IScoringAlgorithm interface.
 * This class provides scoring functionality for karaoke performances by evaluating
 * the match between user's pitch and reference pitch data.
 */
export class DefaultScoringAlgorithm implements IScoringAlgorithm {
  /**
   * Maximum score for one line, 100 for maximum and 0 for minimum
   */
  private readonly maximumScoreForLine: number = 100;
  /**
   * Difficulty level for scoring (0-100, higher values are more lenient)
   * Can be changed by the application
   */
  private scoringLevel: number = 15;
  /**
   * Compensation offset for scoring (-100 to 100)
   * Used to adjust scores based on external factors
   */
  private scoringCompensationOffset: number = 0;

  /**
   * Constructs a new DefaultScoringAlgorithm with default settings
   */
  constructor() {
  }

  /**
   * Calculates a normalized score for the current pitch compared to the reference pitch
   * 调用HarmonyOS Native C++算法实现 - 与Android版本完全一致
   *
   * @param currentPitch    The current pitch detected from the user's voice
   * @param currentRefPitch The reference pitch from the song
   * @return A normalized score value (0-100)
   */
  getPitchScore(currentPitch: number, currentRefPitch: number): number {
    try {
      // 直接调用Native C++实现，与Android版本完全一致
      return AIAlgorithmNative.calculatedScore(currentPitch, currentRefPitch, this.scoringLevel,
        this.scoringCompensationOffset);
    } catch (error) {
      LogUtils.d(`DefaultScoringAlgorithm: Native call failed, using fallback: ${error}`);
      // 如果Native调用失败，使用TypeScript实现作为备用
      return this.calculatedScoreFallback(currentPitch, currentRefPitch, this.scoringLevel,
        this.scoringCompensationOffset);
    }
  }

  /**
   * 将pitch值转换为音调值 - Native调用
   *
   * @param pitch 音调值
   * @return 转换后的音调值
   */
  pitchToTone(pitch: number): number {
    try {
      return AIAlgorithmNative.pitchToTone(pitch);
    } catch (error) {
      LogUtils.d(`DefaultScoringAlgorithm: Native pitchToTone failed, using fallback: ${error}`);
      return this.pitchToToneFallback(pitch);
    }
  }

  /**
   * 将pitch值转换为音调值 - TypeScript备用实现
   *
   * @param pitch 音调值
   * @return 转换后的音调值
   */
  private pitchToToneFallback(pitch: number): number {
    const eps = 1e-6;
    return Math.max(0, Math.log(pitch / 55 + eps) / Math.log(2)) * 12;
  }

  /**
   * 计算评分 - TypeScript备用实现
   * 完全移植自C++算法
   *
   * @param voicePitch 用户音调
   * @param stdPitch 标准音调
   * @param scoreLevel 评分等级 (0-100)
   * @param scoreCompensationOffset 补偿偏移 (0-100)
   * @return 计算得分 (0-100)
   */
  private calculatedScoreFallback(voicePitch: number, stdPitch: number, scoreLevel: number,
    scoreCompensationOffset: number): number {
    // 输入验证 - 对应C++版本的验证逻辑
    if (voicePitch <= 0) {
      return 0;
    }
    if (stdPitch <= 0) {
      return 0;
    }

    // 参数范围限制 - 对应C++版本的参数检查
    if (scoreLevel <= 0) {
      scoreLevel = 1;
    } else if (scoreLevel > 100) {
      scoreLevel = 100;
    }

    if (scoreCompensationOffset < 0) {
      scoreCompensationOffset = 0;
    } else if (scoreCompensationOffset > 100) {
      scoreCompensationOffset = 100;
    }

    // 转换为音调值 - 对应C++的pitchToToneC调用
    const stdTone = this.pitchToToneFallback(stdPitch);
    const voiceTone = this.pitchToToneFallback(voicePitch);

    // 核心评分算法 - 完全对应C++版本的计算逻辑
    let match = 1 - (scoreLevel / 100) * Math.abs(voiceTone - stdTone) + (scoreCompensationOffset / 100);
    const rate = 1 + (scoreLevel / 50);

    match = match * 100 * rate;

    // 结果范围限制 - 对应C++的min/max宏
    match = Math.max(0, match);
    match = Math.min(100, match);

    return match;
  }

  /**
   * 处理音调补偿 - Native调用
   * 八度音调补偿算法 v0.2
   *
   * @param stdPitch 标准音调
   * @param voicePitch 用户音调
   * @param stdMaxPitch 最大标准音调
   * @return 处理后的音调值
   */
  handlePitch(stdPitch: number, voicePitch: number, stdMaxPitch: number): number {
    try {
      return AIAlgorithmNative.handlePitch(stdPitch, voicePitch, stdMaxPitch);
    } catch (error) {
      LogUtils.d(`DefaultScoringAlgorithm: Native handlePitch failed, using fallback: ${error}`);
      return this.handlePitchFallback(stdPitch, voicePitch, stdMaxPitch);
    }
  }

  /**
   * 处理音调补偿 - TypeScript备用实现
   * 八度音调补偿算法 v0.2
   *
   * @param stdPitch 标准音调
   * @param voicePitch 用户音调
   * @param stdMaxPitch 最大标准音调
   * @return 处理后的音调值
   */
  private handlePitchFallback(stdPitch: number, voicePitch: number, stdMaxPitch: number): number {
    let cnt = 0;
    const stdTone = this.pitchToToneFallback(stdPitch);
    let voiceTone = this.pitchToToneFallback(voicePitch);
    let adjustedVoicePitch = voicePitch;

    // 输入验证
    if (voicePitch <= 0) {
      return 0;
    }
    if (stdPitch <= 0) {
      return 0;
    }

    // 如果音调差异在6个半音以内，直接返回
    if (Math.abs(voiceTone - stdTone) <= 6) {
      return adjustedVoicePitch;
    } else if (adjustedVoicePitch < stdPitch) {
      // 用户音调过低，尝试倍频补偿
      for (cnt = 0; cnt < 11; cnt++) {
        adjustedVoicePitch = 2 * adjustedVoicePitch;
        voiceTone = this.pitchToToneFallback(adjustedVoicePitch);
        if (Math.abs(voiceTone - stdTone) <= 6) {
          return adjustedVoicePitch;
        }
      }
    } else if (adjustedVoicePitch > stdPitch) {
      // 用户音调过高，尝试降频补偿
      for (cnt = 0; cnt < 11; cnt++) {
        adjustedVoicePitch = adjustedVoicePitch / 2;
        voiceTone = this.pitchToToneFallback(adjustedVoicePitch);
        if (Math.abs(voiceTone - stdTone) <= 6) {
          return adjustedVoicePitch;
        }
      }
    }

    return adjustedVoicePitch;
  }

  /**
   * 重置算法状态 - Native调用
   */
  reset(): void {
    try {
      AIAlgorithmNative.reset();
      LogUtils.d('DefaultScoringAlgorithm: Native algorithm state reset');
    } catch (error) {
      LogUtils.d(`DefaultScoringAlgorithm: Native reset failed: ${error}`);
    }
  }

  /**
   * 测试Native连接
   * 用于验证C++模块是否正常工作
   */
  testNativeConnection(): boolean {
    try {
      const result = AIAlgorithmNative.testConnection();
      LogUtils.d(`DefaultScoringAlgorithm: Native test result: ${result}`);
      return result === 3; // add(1, 2) 应该返回 3
    } catch (error) {
      LogUtils.d(`DefaultScoringAlgorithm: Native test failed: ${error}`);
      return false;
    }
  }

  /**
   * Calculates the overall score for a completed lyrics line
   *
   * @param pitchesForLine          Map of timestamps to pitch scores for the line
   * @param indexOfLineJustFinished Index of the line that was just finished
   * @param lineJustFinished        The lyrics line model that was just finished
   * @return The calculated score for the line (0-100)
   */
  getLineScore(pitchesForLine: Map<number, number>, indexOfLineJustFinished: number,
    lineJustFinished: LyricsLineModel): number {
    const tones = lineJustFinished.tones;
    if (!tones || tones.length === 0) {
      return 0;
    }

    const toneScoresMap = new Map<Tone, number>();

    let toneIndex = 0;
    let totalScoreForTone = 0;
    let scoreCountForTone = 0;

    // 遍历所有音调数据点
    for (const entry of pitchesForLine.entries()) {
      const timestamp = entry[0];
      const score = entry[1];
      // 找到对应的音调段
      while (toneIndex < tones.length) {
        const currentTone = tones[toneIndex];

        if (timestamp >= currentTone.begin && timestamp <= currentTone.end) {
          // 当前时间戳属于这个音调段
          if (score >= 0) {
            totalScoreForTone += score;
            scoreCountForTone++;
          }
          break;
        } else if (timestamp > currentTone.end) {
          // 当前音调段结束，保存得分并移动到下一个音调段
          if (scoreCountForTone > 0) {
            toneScoresMap.set(currentTone, totalScoreForTone / scoreCountForTone);
          } else {
            toneScoresMap.set(currentTone, 0);
          }

          toneIndex++;
          totalScoreForTone = 0;
          scoreCountForTone = 0;
        } else {
          // 时间戳还没到当前音调段
          break;
        }
      }
    }

    // 处理最后一个音调段
    if (toneIndex < tones.length) {
      const currentTone = tones[toneIndex];
      if (scoreCountForTone > 0) {
        toneScoresMap.set(currentTone, totalScoreForTone / scoreCountForTone);
      } else {
        toneScoresMap.set(currentTone, 0);
      }
    }

    // 计算整行的平均得分
    if (toneScoresMap.size > 0) {
      let totalScoreForThisLine = 0;
      for (const score of toneScoresMap.values()) {
        totalScoreForThisLine += score;
      }

      const lineScore = Math.round(totalScoreForThisLine / toneScoresMap.size);

      LogUtils.d(`DefaultScoringAlgorithm: Line ${indexOfLineJustFinished} score calculation - tones: ${tones.length}, scores: ${toneScoresMap.size}, final score: ${lineScore}`);

      return lineScore;
    }

    return 0;
  }

  /**
   * Gets the maximum possible score for a line
   *
   * @return The maximum score value (100)
   */
  getMaximumScoreForLine(): number {
    return this.maximumScoreForLine;
  }

  /**
   * Sets the scoring difficulty level
   *
   * @param level The difficulty level (0-100, higher values are more lenient)
   */
  setScoringLevel(level: number): void {
    this.scoringLevel = level;
  }

  /**
   * Sets the scoring compensation offset
   *
   * @param offset The compensation offset (-100 to 100)
   */
  setScoringCompensationOffset(offset: number): void {
    this.scoringCompensationOffset = offset;
  }

  /**
   * Gets the current scoring difficulty level
   *
   * @return The current difficulty level
   */
  getScoringLevel(): number {
    return this.scoringLevel;
  }

  /**
   * Gets the current scoring compensation offset
   *
   * @return The current compensation offset
   */
  getScoringCompensationOffset(): number {
    return this.scoringCompensationOffset;
  }
}
