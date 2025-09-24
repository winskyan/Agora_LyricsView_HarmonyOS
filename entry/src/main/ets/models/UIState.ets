/**
 * UI 状态模型
 * 管理界面相关的状态信息
 */
@ObservedV2
export class UIState {
  /** 回调信息显示 */
  @Trace callBackInfo: string = '';
  /** 加载状态 */
  @Trace isLoading: boolean = false;
  /** 错误信息 */
  @Trace errorMessage: string = '';
  /** 是否显示错误 */
  @Trace hasError: boolean = false;

  /**
   * 设置加载状态
   */
  setLoading(loading: boolean, message?: string): void {
    this.isLoading = loading;
    if (message) {
      this.callBackInfo = message;
    }
  }

  /**
   * 设置成功信息
   */
  setSuccess(message: string): void {
    this.callBackInfo = message;
    this.hasError = false;
    this.errorMessage = '';
    this.isLoading = false;
  }

  /**
   * 设置错误信息
   */
  setError(error: string): void {
    this.errorMessage = error;
    this.hasError = true;
    this.callBackInfo = `错误: ${error}`;
    this.isLoading = false;
  }

  /**
   * 清除错误状态
   */
  clearError(): void {
    this.hasError = false;
    this.errorMessage = '';
  }

  /**
   * 重置所有状态
   */
  reset(): void {
    this.callBackInfo = '';
    this.isLoading = false;
    this.errorMessage = '';
    this.hasError = false;
  }
}
