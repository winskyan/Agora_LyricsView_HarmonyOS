/**
 * 项目配置常量
 * 此文件由 scripts/generate-config.js 自动生成，请勿手动修改
 * 生成时间: 2025-09-26T09:31:27.272Z
 * 源文件: project-config.json
 * 
 * 此文件会被导出到 lyrics_view 模块，供其他模块使用
 */

// ========== 项目信息 ==========
/** 项目名称 */
export const PROJECT_NAME = 'Agora LyricsView HarmonyOS';

/** 版本号 */
export const VERSION = '1.0.0';

/** 项目描述 */
export const DESCRIPTION = 'HarmonyOS LyricsView component with karaoke functionality';

/** 作者 */
export const AUTHOR = 'Agora';

/** 许可证 */
export const LICENSE = 'Apache-2.0';

/** 仓库地址 */
export const REPOSITORY = 'https://github.com/AgoraIO-Community/Agora-LyricsView-HarmonyOS';

// ========== SDK 配置 ==========
/** SDK 模式开关 */
export const SDK_MODE = false;

/** 是否为 SDK 模式 */
export const IS_SDK_MODE = false;

/** 是否为源码模式 */
export const IS_SOURCE_MODE = true;

// ========== 构建配置 ==========
/** HAR 包名称 */
export const HAR_NAME = 'Agora-LyricsView-HarmonyOS';

/** 输出目录 */
export const OUTPUT_DIR = 'lyrics_view/build/default/outputs/default';

/** 是否启用签名 */
export const SIGNING_ENABLED = false;

// ========== 计算属性 ==========
/** 完整版本名称 */
export const VERSION_NAME = `${PROJECT_NAME}-${VERSION}`;

/** 完整HAR包名称 */
export const FULL_HAR_NAME = `${HAR_NAME}-${VERSION}`;

// ========== 工具方法 ==========
/**
 * 获取模式描述
 */
export function getModeDescription(): string {
  return IS_SDK_MODE ? 'HAR 包模式' : '源码模式';
}

/**
 * 检查是否为 SDK 模式
 */
export function isUsingSdk(): boolean {
  return IS_SDK_MODE;
}

/**
 * 获取配置摘要
 */
export function getConfigSummary(): string {
  return `${PROJECT_NAME} v${VERSION} (${getModeDescription()})`;
}

/**
 * 获取版本信息
 */
export function getVersionInfo(): string {
  return JSON.stringify({
    name: PROJECT_NAME,
    version: VERSION,
    versionName: VERSION_NAME,
    description: DESCRIPTION,
    author: AUTHOR,
    license: LICENSE,
    repository: REPOSITORY
  });
}

/**
 * 获取SDK配置信息
 */
export function getSdkInfo(): string {
  return JSON.stringify({
    mode: SDK_MODE,
    isSdkMode: IS_SDK_MODE,
    isSourceMode: IS_SOURCE_MODE,
    description: getModeDescription()
  });
}

/**
 * 获取构建配置信息
 */
export function getBuildInfo(): string {
  return JSON.stringify({
    harName: HAR_NAME,
    fullHarName: FULL_HAR_NAME,
    outputDir: OUTPUT_DIR,
    signingEnabled: SIGNING_ENABLED
  });
}

/**
 * 项目配置类
 * 提供统一的配置访问接口
 */
export class ProjectConfig {
  // 项目信息
  static readonly PROJECT_NAME = PROJECT_NAME;
  static readonly VERSION = VERSION;
  static readonly DESCRIPTION = DESCRIPTION;
  static readonly AUTHOR = AUTHOR;
  static readonly LICENSE = LICENSE;
  static readonly REPOSITORY = REPOSITORY;
  
  // SDK 配置
  static readonly SDK_MODE = SDK_MODE;
  static readonly IS_SDK_MODE = IS_SDK_MODE;
  static readonly IS_SOURCE_MODE = IS_SOURCE_MODE;
  
  // 构建配置
  static readonly HAR_NAME = HAR_NAME;
  static readonly OUTPUT_DIR = OUTPUT_DIR;
  static readonly SIGNING_ENABLED = SIGNING_ENABLED;
  
  // 计算属性
  static readonly VERSION_NAME = VERSION_NAME;
  static readonly FULL_HAR_NAME = FULL_HAR_NAME;
  
  // 工具方法
  static getModeDescription(): string {
    return getModeDescription();
  }
  
  static isUsingSdk(): boolean {
    return isUsingSdk();
  }
  
  static getConfigSummary(): string {
    return getConfigSummary();
  }
  
  static getVersionInfo(): string {
    return getVersionInfo();
  }
  
  static getSdkInfo(): string {
    return getSdkInfo();
  }
  
  static getBuildInfo(): string {
    return getBuildInfo();
  }
}

/**
 * 默认导出
 */
export default ProjectConfig;
