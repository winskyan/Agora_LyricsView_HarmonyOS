//
//  Algorithm.c
//  AgoraLyricsScore - HarmonyOS版本
//
//  移植自Android版本的C++算法
//

#include "Algorithm.h"
#include <math.h>

// 版本标识
#define PTS_version "20231021001_HarmonyOS"

// 工具宏定义
#define min(a, b) ((a) < (b) ? (a) : (b))
#define max(a, b) ((a) > (b) ? (a) : (b))

// 静态变量 - 用于算法状态管理
static double n = 0.0;
static double offset = 0.0;

/**
 * 将pitch值转换为音调值
 * 完全对应Android版本的pitchToToneC函数
 */
double pitchToToneC(double pitch) {
    double eps = 1e-6;
    return (fmax(0, log(pitch / 55 + eps) / log(2))) * 12;
}

/**
 * 计算评分 - 核心评分算法
 * 完全对应Android版本的calculatedScoreC函数
 */
float calculatedScoreC(double voicePitch, double stdPitch, int scoreLevel, int scoreCompensationOffset) {
    // 输入验证
    if (voicePitch <= 0) {
        return 0;
    }
    if (stdPitch <= 0) {
        return 0;
    }

    // 参数范围限制
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

    // 转换为音调值
    double stdTone = pitchToToneC(stdPitch);
    double voiceTone = pitchToToneC(voicePitch);

    // 核心评分算法
    float match = 1 - (float)scoreLevel / 100 * fabs(voiceTone - stdTone) + (float)scoreCompensationOffset / 100;
    float rate = 1 + ((float)scoreLevel / (float)50);

    match = match * 100 * rate;

    // 结果范围限制
    match = max(0, match);
    match = min(100, match);
    return match;
}

/**
 * 处理音调补偿 - 八度音调补偿算法 v0.2
 * 完全对应Android版本的handlePitchC函数
 */
double handlePitchC(double stdPitch, double voicePitch, double stdMaxPitch) {
    int cnt = 0;
    double stdTone = pitchToToneC(stdPitch);
    double voiceTone = pitchToToneC(voicePitch);

    // 输入验证
    if (voicePitch <= 0) {
        return 0;
    }
    if (stdPitch <= 0) {
        return 0;
    }

    // 如果音调差异在6个半音以内，直接返回
    if (fabs(voiceTone - stdTone) <= 6) {
        return voicePitch;
    } else if (voicePitch < stdPitch) {
        // 用户音调过低，尝试倍频补偿
        for (cnt = 0; cnt < 11; cnt++) {
            voicePitch = 2 * voicePitch;
            voiceTone = pitchToToneC(voicePitch);
            if (fabs(voiceTone - stdTone) <= 6) {
                return voicePitch;
            }
        }
    } else if (voicePitch > stdPitch) {
        // 用户音调过高，尝试降频补偿
        for (cnt = 0; cnt < 11; cnt++) {
            voicePitch = voicePitch / 2;
            voiceTone = pitchToToneC(voicePitch);
            if (fabs(voiceTone - stdTone) <= 6) {
                return voicePitch;
            }
        }
    }
    return voicePitch;
}

/**
 * 重置算法状态
 * 完全对应Android版本的resetC函数
 */
void resetC(void) {
    offset = 0.0;
    n = 0.0;
}
