/**
 * HarmonyOS Native AI算法接口
 * 对应Android版本的AIAlgorithmScoreNative
 * 通过NAPI调用C++算法实现
 */

// 导入Native模块
import lyricsView from 'liblyricsview.so';

/**
 * Native AI算法接口类
 * 提供与Android版本完全一致的算法调用
 */
export class AIAlgorithmNative {
  /**
   * 将pitch值转换为音调值
   * 对应Android的pitchToTone方法
   *
   * @param pitch 音调值
   * @return 转换后的音调值
   */
  static pitchToTone(pitch: number): number {
    try {
      return lyricsView.pitchToTone(pitch);
    } catch (error) {
      console.error('AIAlgorithmNative.pitchToTone error:', error);
      return 0;
    }
  }

  /**
   * 计算评分
   * 对应Android的calculatedScore方法
   *
   * @param voicePitch 用户音调
   * @param stdPitch 标准音调
   * @param scoreLevel 评分等级 (0-100)
   * @param scoreCompensationOffset 补偿偏移 (0-100)
   * @return 计算得分 (0-100)
   */
  static calculatedScore(voicePitch: number, stdPitch: number, scoreLevel: number,
    scoreCompensationOffset: number): number {
    try {
      return lyricsView.calculatedScore(voicePitch, stdPitch, scoreLevel, scoreCompensationOffset);
    } catch (error) {
      console.error('AIAlgorithmNative.calculatedScore error:', error);
      return 0;
    }
  }

  /**
   * 处理音调补偿
   * 对应Android的handlePitch方法
   *
   * @param stdPitch 标准音调
   * @param voicePitch 用户音调
   * @param stdMaxPitch 最大标准音调
   * @return 处理后的音调值
   */
  static handlePitch(stdPitch: number, voicePitch: number, stdMaxPitch: number): number {
    try {
      return lyricsView.handlePitch(stdPitch, voicePitch, stdMaxPitch);
    } catch (error) {
      console.error('AIAlgorithmNative.handlePitch error:', error);
      return voicePitch; // 出错时返回原始值
    }
  }

  /**
   * 重置算法状态
   * 对应Android的reset方法
   */
  static reset(): void {
    try {
      lyricsView.reset();
    } catch (error) {
      console.error('AIAlgorithmNative.reset error:', error);
    }
  }

  /**
   * 测试Native模块连接
   * 用于验证NAPI是否正常工作
   */
  static testConnection(): number {
    try {
      return lyricsView.add(1, 2); // 应该返回3
    } catch (error) {
      console.error('AIAlgorithmNative.testConnection error:', error);
      return -1;
    }
  }
}
