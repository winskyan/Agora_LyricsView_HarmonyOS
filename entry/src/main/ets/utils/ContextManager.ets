import common from '@ohos.app.ability.common';
import resmgr from '@ohos.resourceManager';

/**
 * Context管理器
 * 提供全局的Context访问，避免使用已废弃的getContext()方法
 */
export class ContextManager {
  private static instance: ContextManager;
  private context: common.UIAbilityContext | null = null;

  /**
   * 获取单例实例
   */
  static getInstance(): ContextManager {
    if (!ContextManager.instance) {
      ContextManager.instance = new ContextManager();
    }
    return ContextManager.instance;
  }

  /**
   * 设置Context（通常在Ability的onCreate中调用）
   */
  setContext(context: common.UIAbilityContext): void {
    this.context = context;
  }

  /**
   * 获取Context
   */
  getContext(): common.UIAbilityContext {
    if (!this.context) {
      throw new Error('Context not initialized. Please call setContext() first.');
    }
    return this.context;
  }

  /**
   * 获取缓存目录路径
   */
  getCacheDir(): string {
    return this.getContext().cacheDir;
  }

  /**
   * 获取文件目录路径
   */
  getFilesDir(): string {
    return this.getContext().filesDir;
  }

  /**
   * 获取临时目录路径
   */
  getTempDir(): string {
    return this.getContext().tempDir;
  }

  /**
   * 获取数据库目录路径
   */
  getDatabaseDir(): string {
    return this.getContext().databaseDir;
  }

  /**
   * 获取资源管理器
   */
  getResourceManager(): resmgr.ResourceManager {
    return this.getContext().resourceManager;
  }

  /**
   * 检查Context是否已初始化
   */
  isInitialized(): boolean {
    return this.context !== null;
  }

  /**
   * 清理Context（通常在应用退出时调用）
   */
  clear(): void {
    this.context = null;
  }
}

/**
 * 全局Context管理器实例
 */
export const contextManager = ContextManager.getInstance();
