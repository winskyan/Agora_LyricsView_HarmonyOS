//
//  Algorithm.h
//  AgoraLyricsScore - HarmonyOS版本
//
//  移植自Android版本的C++算法
//

#ifndef Algorithm_h
#define Algorithm_h

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 将pitch值转换为音调值
 * @param pitch 音调值
 * @return 转换后的音调值
 */
double pitchToToneC(double pitch);

/**
 * 计算评分
 * @param voicePitch 用户音调
 * @param stdPitch 标准音调
 * @param scoreLevel 评分等级 (0-100)
 * @param scoreCompensationOffset 补偿偏移 (0-100)
 * @return 计算得分 (0-100)
 */
float calculatedScoreC(double voicePitch, double stdPitch, int scoreLevel, int scoreCompensationOffset);

/**
 * 处理音调补偿 - 八度音调补偿算法 v0.2
 * @param stdPitch 标准音调
 * @param voicePitch 用户音调
 * @param stdMaxPitch 最大标准音调
 * @return 处理后的音调值
 */
double handlePitchC(double stdPitch, double voicePitch, double stdMaxPitch);

/**
 * 重置算法状态
 */
void resetC(void);

#ifdef __cplusplus
}
#endif

#endif /* Algorithm_h */
