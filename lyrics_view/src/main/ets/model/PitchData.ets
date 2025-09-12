/**
 * 音调数据模型
 * 对应Android项目中的PitchData
 * Interface representing pitch data for karaoke scoring
 */
export interface PitchData {
  /** 开始时间 */
  startTime: number;

  /** 持续时间 */
  duration: number;

  /** 音调值 */
  pitch: number;
}

/**
 * 创建PitchData对象的工厂函数
 * @param startTime 开始时间，默认为0
 * @param duration 持续时间，默认为0
 * @param pitch 音调值，默认为0
 * @returns PitchData对象
 */
export function createPitchData(
  startTime: number = 0,
  duration: number = 0,
  pitch: number = 0
): PitchData {
  return { startTime, duration, pitch };
}
