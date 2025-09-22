import { IScoringAlgorithm } from '../../IScoringAlgorithm';
import { LyricsLineModel, Tone } from '../../model/LyricsLineModel';
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
   *
   * @param currentPitch    The current pitch detected from the user's voice
   * @param currentRefPitch The reference pitch from the song
   * @return A normalized score value (0-100)
   */
  getPitchScore(currentPitch: number, currentRefPitch: number): number {
    // 简化的评分算法，没有使用AI算法
    if (currentRefPitch === 0) {
      return 0;
    }

    const pitchDiff = Math.abs(currentPitch - currentRefPitch);

    // 根据音调差异计算得分
    if (pitchDiff === 0) {
      return 100;
    }
    if (pitchDiff <= 1) {
      return 90;
    }
    if (pitchDiff <= 2) {
      return 80;
    }
    if (pitchDiff <= 3) {
      return 70;
    }
    if (pitchDiff <= 4) {
      return 60;
    }
    if (pitchDiff <= 5) {
      return 50;
    }

    // 应用评分等级和补偿偏移
    let baseScore = Math.max(0, 50 - (pitchDiff - 5) * 5);
    baseScore = baseScore * (this.scoringLevel / 15.0); // 标准化到评分等级
    baseScore += this.scoringCompensationOffset;

    return Math.max(0, Math.min(100, baseScore));
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
