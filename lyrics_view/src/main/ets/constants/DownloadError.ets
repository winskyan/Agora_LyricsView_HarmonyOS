/**
 * 下载错误枚举类 - HarmonyOS版本
 * 定义下载操作中可能出现的各种错误场景
 */
export enum DownloadError {
  /**
   * 通用下载错误
   */
  GENERAL = 0,

  /**
   * 重复下载错误（文件正在下载中）
   */
  REPEAT_DOWNLOADING = 1,

  /**
   * HTTP下载错误
   */
  HTTP_DOWNLOAD_ERROR = 2,

  /**
   * HTTP下载逻辑错误
   */
  HTTP_DOWNLOAD_ERROR_LOGIC = 3,

  /**
   * 文件解压失败
   */
  UNZIP_FAIL = 4
}

/**
 * 下载错误详情类
 * 包含错误类型、错误码和错误消息
 */
export class DownloadErrorDetail {
  private mType: DownloadError;
  private mErrorCode: number = 0;
  private mMessage: string = '';

  constructor(type: DownloadError) {
    this.mType = type;
  }

  /**
   * 获取错误类型
   * @returns 错误类型
   */
  getType(): DownloadError {
    return this.mType;
  }

  /**
   * 获取错误码
   * @returns 错误码
   */
  getErrorCode(): number {
    return this.mErrorCode;
  }

  /**
   * 设置错误码
   * @param errorCode 错误码
   */
  setErrorCode(errorCode: number): void {
    this.mErrorCode = errorCode;
  }

  /**
   * 获取错误消息
   * @returns 错误消息
   */
  getMessage(): string {
    return this.mMessage;
  }

  /**
   * 设置错误消息
   * @param message 错误消息
   */
  setMessage(message: string): void {
    this.mMessage = message;
  }

  /**
   * 转换为字符串表示
   * @returns 包含错误名称、类型、错误码和消息的字符串
   */
  toString(): string {
    return `DownloadError{type=${this.mType}, errorCode=${this.mErrorCode}, message='${this.mMessage}'}`;
  }

  /**
   * 创建通用错误
   * @param message 错误消息
   * @returns 错误详情对象
   */
  static createGeneralError(message: string = ''): DownloadErrorDetail {
    const error = new DownloadErrorDetail(DownloadError.GENERAL);
    error.setMessage(message);
    return error;
  }

  /**
   * 创建重复下载错误
   * @param message 错误消息
   * @returns 错误详情对象
   */
  static createRepeatDownloadingError(message: string = '文件正在下载中'): DownloadErrorDetail {
    const error = new DownloadErrorDetail(DownloadError.REPEAT_DOWNLOADING);
    error.setMessage(message);
    return error;
  }

  /**
   * 创建HTTP下载错误
   * @param errorCode 错误码
   * @param message 错误消息
   * @returns 错误详情对象
   */
  static createHttpDownloadError(errorCode: number, message: string = ''): DownloadErrorDetail {
    const error = new DownloadErrorDetail(DownloadError.HTTP_DOWNLOAD_ERROR);
    error.setErrorCode(errorCode);
    error.setMessage(message);
    return error;
  }

  /**
   * 创建HTTP逻辑错误
   * @param errorCode 错误码
   * @param message 错误消息
   * @returns 错误详情对象
   */
  static createHttpLogicError(errorCode: number, message: string = ''): DownloadErrorDetail {
    const error = new DownloadErrorDetail(DownloadError.HTTP_DOWNLOAD_ERROR_LOGIC);
    error.setErrorCode(errorCode);
    error.setMessage(message);
    return error;
  }

  /**
   * 创建解压失败错误
   * @param message 错误消息
   * @returns 错误详情对象
   */
  static createUnzipFailError(message: string = '文件解压失败'): DownloadErrorDetail {
    const error = new DownloadErrorDetail(DownloadError.UNZIP_FAIL);
    error.setMessage(message);
    return error;
  }
}
