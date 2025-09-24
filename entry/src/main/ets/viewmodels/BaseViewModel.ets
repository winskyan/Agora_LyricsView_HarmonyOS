import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * ViewModel 基类
 * 提供通用的 ViewModel 功能
 */
@ObservedV2
export abstract class BaseViewModel {
  /** 是否已销毁 */
  @Trace protected isDestroyed: boolean = false;
  /** ViewModel 标签，用于日志 */
  protected abstract readonly TAG: string;

  /**
   * 初始化 ViewModel
   * 子类可以重写此方法进行自定义初始化
   */
  async initialize(): Promise<void> {
    this.logDebug('ViewModel initialized');
  }

  /**
   * 销毁 ViewModel
   * 子类应该重写此方法进行资源清理
   */
  destroy(): void {
    if (this.isDestroyed) {
      return;
    }

    this.isDestroyed = true;
    this.logDebug('ViewModel destroyed');
  }

  /**
   * 检查是否已销毁
   */
  protected checkDestroyed(): boolean {
    if (this.isDestroyed) {
      this.logDebug('ViewModel operation called after destruction');
      return true;
    }
    return false;
  }

  /**
   * 安全执行异步操作
   * 确保在 ViewModel 销毁后不执行回调
   */
  protected async safeExecute<T>(
    operation: () => Promise<T>,
    onSuccess?: (result: T) => void,
    onError?: (error: Error) => void
  ): Promise<void> {
    if (this.checkDestroyed()) {
      return;
    }

    try {
      const result = await operation();

      if (!this.checkDestroyed() && onSuccess) {
        onSuccess(result);
      }
    } catch (error) {
      if (!this.checkDestroyed() && onError) {
        onError(error as Error);
      } else {
        this.logError(`Operation failed: ${error}`);
      }
    }
  }

  /**
   * 调试日志
   */
  protected logDebug(message: string): void {
    hilog.debug(0x0000, this.TAG, `%{public}s`, message);
  }

  /**
   * 错误日志
   */
  protected logError(message: string): void {
    hilog.error(0x0000, this.TAG, `%{public}s`, message);
  }

  /**
   * 信息日志
   */
  protected logInfo(message: string): void {
    hilog.info(0x0000, this.TAG, `%{public}s`, message);
  }
}
