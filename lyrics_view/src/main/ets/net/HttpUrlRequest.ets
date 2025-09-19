import http from '@ohos.net.http';
import { Constants } from '../constants/Constants';
import { LogUtils } from '../utils/LogUtils';

/**
 * HTTP请求回调接口
 */
export interface RequestCallback {
  /**
   * 响应数据更新回调
   * @param bytes 数据字节数组
   * @param len 当前数据长度
   * @param currentLen 已接收总长度
   * @param total 文件总长度
   */
  updateResponseData(bytes: Uint8Array, len: number, currentLen: number, total: number): void;

  /**
   * 请求失败回调
   * @param errorCode 错误码
   * @param msg 错误消息
   */
  requestFail(errorCode: number, msg: string): void;

  /**
   * 请求完成回调
   */
  requestFinish(): void;
}

/**
 * 网络错误对象接口
 */
interface NetworkError {
  code?: number;
  message?: string;
}

/**
 * HTTP URL请求类 - HarmonyOS版本
 * 处理HTTP GET请求，支持下载进度回调和取消操作
 */
export class HttpUrlRequest {
  private mCallback: RequestCallback | null = null;
  private mCancelled: boolean = false;
  private mHttpRequest: http.HttpRequest | null = null;
  private mRequestId: string = '';

  constructor() {
    this.mRequestId = `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * 设置请求回调
   * @param callback 回调接口
   */
  setCallback(callback: RequestCallback): void {
    this.mCallback = callback;
  }

  /**
   * 设置取消状态
   * @param cancelled 是否取消
   */
  setCancelled(cancelled: boolean): void {
    this.mCancelled = cancelled;
    if (cancelled && this.mHttpRequest) {
      this.mHttpRequest.destroy();
      this.mHttpRequest = null;
    }
  }

  /**
   * 获取取消状态
   * @returns 是否已取消
   */
  isCancelled(): boolean {
    return this.mCancelled;
  }

  /**
   * 取消请求
   */
  cancel(): void {
    this.setCancelled(true);
  }

  /**
   * 发起GET请求
   * @param url 请求URL
   * @param headers 请求头（可选）
   */
  async requestGetUrl(url: string, headers?: Record<string, string>): Promise<void> {
    if (this.mCancelled) {
      LogUtils.w(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Request cancelled before start`);
      return;
    }

    if (!url || url.trim().length === 0) {
      this.notifyRequestFail(Constants.ERROR_GENERAL, 'HttpUrlRequest:URL is empty');
      return;
    }

    LogUtils.d(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Starting GET request to ${url}`);

    try {
      // 创建HTTP请求
      this.mHttpRequest = http.createHttp();

      // 设置请求选项 - 使用基本配置避免兼容性问题
      // 合并自定义headers（避免使用展开运算符和for...in）
      const finalHeaders: Record<string, string> = {
        'User-Agent': 'HarmonyOS-LyricsView',
        'Accept': '*/*'
      };

      if (headers) {
        // 使用Object.keys遍历并复制属性
        const headerKeys = Object.keys(headers);
        for (let i = 0; i < headerKeys.length; i++) {
          const key = headerKeys[i];
          finalHeaders[key] = headers[key];
        }
      }

      const requestOptions: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        connectTimeout: Constants.HTTP_TIMEOUT * 1000, // 15秒连接超时
        readTimeout: Constants.HTTP_TIMEOUT * 1000, // 30秒读取超时
        header: finalHeaders,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      };

      // 监听响应头事件
      this.mHttpRequest.on('headersReceive', (header) => {
        if (this.mCancelled) {
          return;
        }
        LogUtils.d(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Headers received: ${JSON.stringify(header)}`);
      });

      // 监听数据接收事件
      this.mHttpRequest.on('dataReceive', (data: ArrayBuffer) => {
        if (this.mCancelled) {
          return;
        }

        const uint8Array = new Uint8Array(data);
        const currentLen = uint8Array.length;

        LogUtils.d(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Data received: ${currentLen} bytes`);

        if (this.mCallback) {
          // 注意：HarmonyOS的dataReceive事件不提供总长度信息，这里传-1表示未知
          this.mCallback.updateResponseData(uint8Array, currentLen, currentLen, -1);
        }
      });

      // 监听数据接收进度事件（HarmonyOS可能不支持此事件，注释掉）
      // this.mHttpRequest.on('dataProgress', (data: DataProgress) => {
      //   if (this.mCancelled) return;
      //   LogUtils.d(`HttpUrlRequest[${this.mRequestId}]: Progress: ${data.receiveSize}/${data.totalSize}`);
      // });

      // 发起请求
      const response = await this.mHttpRequest.request(url, requestOptions);

      if (this.mCancelled) {
        LogUtils.w(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Request cancelled after completion`);
        return;
      }

      // 检查响应状态
      if (response.responseCode === 200) {
        LogUtils.d(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Request completed successfully`);

        // 如果响应数据是ArrayBuffer，处理完整数据
        if (response.result instanceof ArrayBuffer) {
          const uint8Array = new Uint8Array(response.result);
          if (this.mCallback) {
            this.mCallback.updateResponseData(uint8Array, uint8Array.length, uint8Array.length, uint8Array.length);
          }
        }

        this.notifyRequestFinish();
      } else {
        const errorMsg = `HTTP ${response.responseCode}: ${response.header}`;
        LogUtils.e(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Request failed: ${errorMsg}`);
        this.notifyRequestFail(response.responseCode, errorMsg);
      }

    } catch (error) {
      if (this.mCancelled) {
        LogUtils.w(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Request cancelled during execution`);
        return;
      }

      // 改进错误信息处理
      let errorMsg = 'Network error: Unknown error';
      let errorCode = Constants.ERROR_GENERAL;

      if (error && typeof error === 'object') {
        const errorObj = error as NetworkError;

        // 尝试获取错误信息
        if (errorObj.message) {
          errorMsg = `Network error: ${errorObj.message}`;
        } else if (errorObj.code) {
          errorMsg = `Network error: Code ${errorObj.code}`;
        } else {
          errorMsg = `Network error: ${JSON.stringify(error)}`;
        }

        // 根据错误码设置具体的错误类型
        if (errorObj.code === 2300003) {
          errorCode = Constants.ERROR_HTTP_NOT_CONNECT;
          errorMsg = 'Network error: Connection failed';
        } else if (errorObj.code === 2300006) {
          errorCode = Constants.ERROR_HTTP_UNKNOWN_HOST;
          errorMsg = 'Network error: Unknown host';
        } else if (errorObj.code === 2300007) {
          errorCode = Constants.ERROR_HTTP_TIMEOUT;
          errorMsg = 'Network error: Request timeout';
        } else if (errorObj.code) {
          errorCode = Constants.ERROR_GENERAL;
          errorMsg = `Network error: HTTP error ${errorObj.code}`;
        }
      } else if (typeof error === 'string') {
        errorMsg = `Network error: ${error}`;
      }

      LogUtils.e(`HttpUrlRequest:HttpUrlRequest[${this.mRequestId}]: Request error: ${errorMsg}`);
      this.notifyRequestFail(errorCode, errorMsg);
    } finally {
      // 清理资源
      if (this.mHttpRequest) {
        this.mHttpRequest.destroy();
        this.mHttpRequest = null;
      }
    }
  }

  /**
   * 通知请求失败
   * @param errorCode 错误码
   * @param msg 错误消息
   */
  private notifyRequestFail(errorCode: number, msg: string): void {
    if (this.mCallback && !this.mCancelled) {
      this.mCallback.requestFail(errorCode, msg);
    }
  }

  /**
   * 通知请求完成
   */
  private notifyRequestFinish(): void {
    if (this.mCallback && !this.mCancelled) {
      this.mCallback.requestFinish();
    }
  }

  /**
   * 获取请求ID
   * @returns 请求ID
   */
  getRequestId(): string {
    return this.mRequestId;
  }

  /**
   * 返回请求对象的字符串表示
   * @returns 字符串表示
   */
  toString(): string {
    return `HttpUrlRequest:HttpUrlRequest{id='${this.mRequestId}', cancelled=${this.mCancelled}}`;
  }
}
