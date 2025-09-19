import { HttpUrlRequest } from '../net/HttpUrlRequest';

/**
 * 歌词下载请求模型类 - HarmonyOS版本
 * 包含下载请求的相关信息，包括URL、文件路径和HTTP请求对象
 */
export class DownloadLyricModel {
  private mRequestId: number = 0;
  private mUrl: string = '';
  private mFilePath: string = '';
  private mHttpUrlRequest: HttpUrlRequest | null = null;

  /**
   * 获取请求标识符
   * @returns 请求ID
   */
  getRequestId(): number {
    return this.mRequestId;
  }

  /**
   * 设置请求标识符
   * @param requestId 请求ID
   */
  setRequestId(requestId: number): void {
    this.mRequestId = requestId;
  }

  /**
   * 获取歌词文件的URL
   * @returns URL字符串
   */
  getUrl(): string {
    return this.mUrl;
  }

  /**
   * 设置歌词文件的URL
   * @param url URL字符串
   */
  setUrl(url: string): void {
    this.mUrl = url;
  }

  /**
   * 获取保存歌词的本地文件路径
   * @returns 文件路径字符串
   */
  getFilePath(): string {
    return this.mFilePath;
  }

  /**
   * 设置保存歌词的本地文件路径
   * @param filePath 文件路径字符串
   */
  setFilePath(filePath: string): void {
    this.mFilePath = filePath;
  }

  /**
   * 获取HTTP请求对象
   * @returns HTTP请求对象
   */
  getHttpUrlRequest(): HttpUrlRequest | null {
    return this.mHttpUrlRequest;
  }

  /**
   * 设置HTTP请求对象
   * @param httpUrlRequest HTTP请求对象
   */
  setHttpUrlRequest(httpUrlRequest: HttpUrlRequest): void {
    this.mHttpUrlRequest = httpUrlRequest;
  }

  /**
   * 返回下载模型的字符串表示
   * @returns 包含所有模型属性的字符串
   */
  toString(): string {
    return `DownloadLyricModel{requestId=${this.mRequestId}, url='${this.mUrl}', filePath='${this.mFilePath}', httpUrlRequest=${this.mHttpUrlRequest}}`;
  }

  /**
   * 检查模型是否有效
   * @returns 模型是否包含必要的信息
   */
  isValid(): boolean {
    return this.mRequestId > 0 &&
      this.mUrl.length > 0 &&
      this.mFilePath.length > 0 &&
      this.mHttpUrlRequest !== null;
  }

  /**
   * 清理资源
   */
  cleanup(): void {
    if (this.mHttpUrlRequest) {
      this.mHttpUrlRequest.cancel();
      this.mHttpUrlRequest = null;
    }
    this.mUrl = '';
    this.mFilePath = '';
    this.mRequestId = 0;
  }
}
