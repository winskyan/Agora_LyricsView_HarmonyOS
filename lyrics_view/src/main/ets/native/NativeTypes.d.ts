/**
 * Native模块类型声明
 * 用于TypeScript编译器识别Native函数
 */

declare module 'liblyrics_view.so' {
  /**
   * 将pitch值转换为音调值
   */
  export function pitchToTone(pitch: number): number;

  /**
   * 计算评分
   */
  export function calculatedScore(
    voicePitch: number,
    stdPitch: number,
    scoreLevel: number,
    scoreCompensationOffset: number
  ): number;

  /**
   * 处理音调补偿
   */
  export function handlePitch(
    stdPitch: number,
    voicePitch: number,
    stdMaxPitch: number
  ): number;

  /**
   * 重置算法状态
   */
  export function reset(): void;

  /**
   * 测试函数
   */
  export function add(a: number, b: number): number;
}
