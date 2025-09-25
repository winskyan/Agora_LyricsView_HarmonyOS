#!/usr/bin/env node

/**
 * 配置生成器
 * 从 project-config.json 生成 TypeScript 配置常量文件
 */

const fs = require('fs');
const path = require('path');

class ConfigGenerator {
  constructor() {
    this.projectRoot = path.join(__dirname, '..');
    this.configPath = path.join(this.projectRoot, 'project-config.json');
    this.outputPath = path.join(this.projectRoot, 'lyrics_view/src/main/ets/config/ProjectConfig.ets');
  }

  /**
   * 读取工程配置
   */
  readConfig() {
    try {
      const configContent = fs.readFileSync(this.configPath, 'utf8');
      return JSON.parse(configContent);
    } catch (error) {
      console.error('❌ 读取配置文件失败:', error.message);
      process.exit(1);
    }
  }

  /**
   * 生成配置常量文件
   */
  generateConfigFile(config) {
    const timestamp = new Date().toISOString();
    
    const content = `/**
 * 项目配置常量
 * 此文件由 scripts/generate-config.js 自动生成，请勿手动修改
 * 生成时间: ${timestamp}
 * 源文件: project-config.json
 * 
 * 此文件会被导出到 lyrics_view 模块，供其他模块使用
 */

// ========== 项目信息 ==========
/** 项目名称 */
export const PROJECT_NAME = '${config.project.name}';

/** 版本号 */
export const VERSION = '${config.project.version}';

/** 项目描述 */
export const DESCRIPTION = '${config.project.description}';

/** 作者 */
export const AUTHOR = '${config.project.author}';

/** 许可证 */
export const LICENSE = '${config.project.license}';

/** 仓库地址 */
export const REPOSITORY = '${config.project.repository}';

// ========== SDK 配置 ==========
/** SDK 模式开关 */
export const SDK_MODE = ${config.sdk.mode};

/** 是否为 SDK 模式 */
export const IS_SDK_MODE = ${config.sdk.mode};

/** 是否为源码模式 */
export const IS_SOURCE_MODE = ${!config.sdk.mode};

// ========== 构建配置 ==========
/** HAR 包名称 */
export const HAR_NAME = '${config.build.harName}';

/** 输出目录 */
export const OUTPUT_DIR = '${config.build.outputDir}';

/** 是否启用签名 */
export const SIGNING_ENABLED = ${config.build.signing.enabled};

// ========== 计算属性 ==========
/** 完整版本名称 */
export const VERSION_NAME = \`\${PROJECT_NAME}-\${VERSION}\`;

/** 完整HAR包名称 */
export const FULL_HAR_NAME = \`\${HAR_NAME}-\${VERSION}\`;

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
  return \`\${PROJECT_NAME} v\${VERSION} (\${getModeDescription()})\`;
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
`;

    return content;
  }

  /**
   * 写入配置文件
   */
  writeConfigFile(content) {
    try {
      // 确保目录存在
      const outputDir = path.dirname(this.outputPath);
      if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
      }
      
      fs.writeFileSync(this.outputPath, content, 'utf8');
      console.log('✅ 配置常量文件生成成功:', this.outputPath);
    } catch (error) {
      console.error('❌ 写入配置文件失败:', error.message);
      process.exit(1);
    }
  }

  /**
   * 生成配置
   */
  generate() {
    console.log('🚀 开始生成配置常量文件...');
    
    // 读取配置
    const config = this.readConfig();
    console.log('📋 读取工程配置:', config.project.name, 'v' + config.project.version);
    
    // 生成文件内容
    const content = this.generateConfigFile(config);
    
    // 写入文件
    this.writeConfigFile(content);
    
    console.log('✅ 配置生成完成!');
  }
}

// 命令行执行
if (require.main === module) {
  const generator = new ConfigGenerator();
  generator.generate();
}

module.exports = ConfigGenerator;
