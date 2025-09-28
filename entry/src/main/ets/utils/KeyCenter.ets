import { BuildConfig } from './BuildConfig';
import { ExampleConstants } from './ExampleConstants';
import { ExampleLogUtils } from './ExmapleLogUtils';
import { TokenHttpClient, TokenHttpResponse } from './TokenHttpClient';

/**
 * Token生成响应接口
 */
export interface TokenResponse {
  success: boolean;
  token?: string;
  error?: string;
}

/**
 * Token生成回调接口
 */
export interface TokenCallback {
  onTokenGenerated(response: TokenResponse): void;
}

/**
 * Agora服务端Token生成响应
 */
interface AgoraTokenData {
  token: string;
  expire_time: number;
}

interface AgoraTokenResponse {
  code: number;
  message: string;
  data?: AgoraTokenData;
}

/**
 * 音速达API响应数据结构
 */
interface YSDApiData {
  yinsuda_uid: string;
  token: string;
}

/**
 * 音速达API响应结构
 */
interface YSDApiResponse {
  error: number;
  data: YSDApiData;
}

/**
 * 音速达Token响应接口
 */
export interface YSDTokenResponse {
  success: boolean;
  ysdUserId?: string;
  ysdToken?: string;
  error?: string;
}

/**
 * 音速达Token回调接口
 */
export interface YSDTokenCallback {
  onYSDTokenGenerated(response: YSDTokenResponse): void;
}

/**
 * KeyCenter - 密钥和Token管理中心
 * 参考Android KeyCenter.kt实现
 * 负责生成RTC Token和管理用户ID、频道名等
 */
export class KeyCenter {
  private static readonly TAG: string = ExampleConstants.APP_TAG + '-KeyCenter';
  private static readonly USER_MAX_UID: number = 10000;
  // 从 BuildConfig 读取配置（构建时从 local.properties 生成）
  public static readonly APP_ID: string = BuildConfig.APP_ID;
  private static readonly APP_CERTIFICATE: string = BuildConfig.APP_CERTIFICATE;
  public static readonly RTC_TOKEN: string = BuildConfig.RTC_TOKEN;
  public static readonly RTM_TOKEN: string = BuildConfig.RTM_TOKEN;
  // 音速达(Vendor2)配置
  public static readonly VENDOR_2_APP_ID: string = BuildConfig.VENDOR_2_APP_ID;
  public static readonly VENDOR_2_APP_KEY: string = BuildConfig.VENDOR_2_APP_KEY;
  public static readonly VENDOR_2_TOKEN_HOST: string = BuildConfig.VENDOR_2_TOKEN_HOST;
  // 频道名称
  public static readonly CHANNEL_NAME: string = BuildConfig.CHANNEL_NAME;
  // 用户UID缓存
  private static USER_RTC_UID: number = 123456;

  /**
   * 获取用户UID
   * 如果未设置则随机生成一个
   */
  public static getUserUid(): number {
    if (KeyCenter.USER_RTC_UID === -1) {
      KeyCenter.USER_RTC_UID = Math.floor(Math.random() * KeyCenter.USER_MAX_UID);
    }
    return KeyCenter.USER_RTC_UID;
  }

  /**
   * 设置用户UID
   */
  public static setUserUid(uid: number): void {
    KeyCenter.USER_RTC_UID = uid;
  }

  /**
   * 生成RTC Token
   * 优先级：预定义的RTC_TOKEN > 服务端API生成 > APP_ID作为fallback
   */
  public static async getRtcToken(channelId: string, uid: number, callback: TokenCallback): Promise<void> {
    ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtcToken: channelId=${channelId}, uid=${uid}`)

    // 如果定义了RTC_TOKEN常量，直接返回
    if (KeyCenter.RTC_TOKEN && KeyCenter.RTC_TOKEN.trim() !== '') {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtcToken: using predefined RTC_TOKEN`)
      callback.onTokenGenerated({
        success: true,
        token: KeyCenter.RTC_TOKEN
      });
      return;
    }

    // 如果没有证书，直接返回APP_ID
    if (!KeyCenter.APP_CERTIFICATE || KeyCenter.APP_CERTIFICATE.trim() === '') {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtcToken: using APP_ID as token`)
      callback.onTokenGenerated({
        success: true,
        token: KeyCenter.APP_ID
      });
      return;
    }

    try {
      // 调用服务端API生成token
      await KeyCenter.generateTokenFromServer(channelId, uid, 'rtc', callback);
    } catch (error) {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtcToken: failed to generate RTC token: ${JSON.stringify(error)}`)
      callback.onTokenGenerated({
        success: false,
        error: `Failed to generate RTC token: ${JSON.stringify(error)}`
      });
    }
  }

  /**
   * 生成RTM Token
   * 优先级：预定义的RTM_TOKEN > 服务端API生成 > APP_ID作为fallback
   */
  public static async getRtmToken(uid: number, callback: TokenCallback): Promise<void> {
    ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtmToken: uid=${uid}`)

    // 如果定义了RTM_TOKEN常量，直接返回
    if (KeyCenter.RTM_TOKEN && KeyCenter.RTM_TOKEN.trim() !== '') {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtmToken: using predefined RTM_TOKEN`)
      callback.onTokenGenerated({
        success: true,
        token: KeyCenter.RTM_TOKEN
      });
      return;
    }

    // 如果没有证书，直接返回APP_ID
    if (!KeyCenter.APP_CERTIFICATE || KeyCenter.APP_CERTIFICATE.trim() === '') {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtmToken: using APP_ID as token`)
      callback.onTokenGenerated({
        success: true,
        token: KeyCenter.APP_ID
      });
      return;
    }

    try {
      // 调用服务端API生成token
      await KeyCenter.generateTokenFromServer('', uid, 'rtm', callback);
    } catch (error) {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getRtmToken: failed to generate RTM token: ${JSON.stringify(error)}`)
      callback.onTokenGenerated({
        success: false,
        error: `Failed to generate RTM token: ${JSON.stringify(error)}`
      });
    }
  }

  /**
   * 获取音速达(Vendor2)用户ID和Token
   * @param uid 用户ID，用于构建请求URL
   * @param callback 回调接口
   */
  public static async getYSDToken(uid: number, callback: YSDTokenCallback): Promise<void> {
    ExampleLogUtils.logDebug(KeyCenter.TAG, `getYSDToken: uid=${uid}`)

    try {
      // 构建请求URL
      const requestUrl = `${KeyCenter.VENDOR_2_TOKEN_HOST}${uid}`;
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getYSDToken: requestUrl=${requestUrl}`)

      // 发送GET请求
      const requestHeaders: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      };
      const response: TokenHttpResponse = await TokenHttpClient.get(requestUrl, requestHeaders);

      if (response.success && response.data) {
        ExampleLogUtils.logDebug(KeyCenter.TAG, `getYSDToken: response=${response.data}`)

        try {
          const ysdResponse: YSDApiResponse = JSON.parse(response.data);

          if (ysdResponse.error === 0 && ysdResponse.data) {
            ExampleLogUtils.logDebug(KeyCenter.TAG, `getYSDToken: YSD API response: ${ysdResponse}`)

            callback.onYSDTokenGenerated({
              success: true,
              ysdUserId: ysdResponse.data.yinsuda_uid,
              ysdToken: ysdResponse.data.token
            });
          } else {
            ExampleLogUtils.logDebug(KeyCenter.TAG, `getYSDToken: YSD API error: ${ysdResponse.error}`)
            callback.onYSDTokenGenerated({
              success: false,
              error: `YSD API error: ${ysdResponse.error}`
            });
          }
        } catch (parseError) {
          ExampleLogUtils.logDebug(KeyCenter.TAG,
            `getYSDToken: Failed to parse YSD response: ${JSON.stringify(parseError)}`)
          callback.onYSDTokenGenerated({
            success: false,
            error: `Failed to parse YSD response: ${JSON.stringify(parseError)}`
          });
        }
      } else {
        ExampleLogUtils.logDebug(KeyCenter.TAG, `getYSDToken: HTTP error: ${JSON.stringify(response.error)}`)
        callback.onYSDTokenGenerated({
          success: false,
          error: response.error || 'Unknown HTTP error'
        });
      }

    } catch (error) {
      ExampleLogUtils.logDebug(KeyCenter.TAG, `getYSDToken: Network error: ${JSON.stringify(error)}`)
      callback.onYSDTokenGenerated({
        success: false,
        error: `Network error: ${JSON.stringify(error)}`
      });
    }
  }

  /**
   * 从服务端生成Token
   * 参考声网文档的HTTP基本认证方式
   */
  private static async generateTokenFromServer(
    channelId: string,
    uid: number,
    tokenType: 'rtc' | 'rtm',
    callback: TokenCallback
  ): Promise<void> {
    try {
      // 构建请求URL
      const baseUrl = 'https://api.agora.io/dev/v1/token';
      let requestUrl = '';
      let requestBody = '';

      if (tokenType === 'rtc') {
        // RTC Token请求
        requestUrl = `${baseUrl}`;
        requestBody = JSON.stringify({
          appId: KeyCenter.APP_ID,
          appCertificate: KeyCenter.APP_CERTIFICATE,
          channelName: channelId,
          uid: uid.toString(),
          role: 1, // Publisher role
          expireTime: 3600 // 1小时过期
        });
      } else {
        // RTM Token请求
        requestUrl = `${baseUrl}/rtm`;
        requestBody = JSON.stringify({
          appId: KeyCenter.APP_ID,
          appCertificate: KeyCenter.APP_CERTIFICATE,
          userId: uid.toString(),
          expireTime: 3600 // 1小时过期
        });
      }

      // 创建HTTP基本认证头
      const credentials = `${KeyCenter.APP_ID}:${KeyCenter.APP_CERTIFICATE}`;
      const base64Credentials = KeyCenter.base64Encode(credentials);
      const authHeader = `Basic ${base64Credentials}`;

      ExampleLogUtils.logDebug(KeyCenter.TAG, ` HTTP Basic Auth Header: ${authHeader}`);

      // 使用TokenHttpClient发送请求
      const headers: Record<string, string> = {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      };

      const response: TokenHttpResponse = await TokenHttpClient.postForToken(requestUrl, headers, requestBody);

      if (response.success && response.data) {
        ExampleLogUtils.logDebug(KeyCenter.TAG, ` Token request URL: ${requestUrl}`);

        try {
          const tokenResponse: AgoraTokenResponse = JSON.parse(response.data);

          if (tokenResponse.code === 200 && tokenResponse.data?.token) {
            callback.onTokenGenerated({
              success: true,
              token: tokenResponse.data.token
            });
          } else {
            callback.onTokenGenerated({
              success: false,
              error: `Server error: ${tokenResponse.message || 'Unknown error'}`
            });
          }
        } catch (parseError) {
          ExampleLogUtils.logError(KeyCenter.TAG, ` Failed to parse response:` + JSON.stringify(parseError));
          callback.onTokenGenerated({
            success: false,
            error: `Failed to parse server response: ${JSON.stringify(parseError)}`
          });
        }
      } else {
        ExampleLogUtils.logError(KeyCenter.TAG, ` HTTP request failed:` + JSON.stringify(response.error));
        callback.onTokenGenerated({
          success: false,
          error: response.error || 'Unknown HTTP error'
        });
      }

    } catch (error) {
      ExampleLogUtils.logError(KeyCenter.TAG, ` generateTokenFromServer error:` + JSON.stringify(error));
      callback.onTokenGenerated({
        success: false,
        error: `Network error: ${JSON.stringify(error)}`
      });
    }
  }

  /**
   * 简单的Base64编码实现
   * 用于HTTP基本认证
   */
  private static base64Encode(str: string): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result = '';
    let i = 0;

    while (i < str.length) {
      const a = str.charCodeAt(i++);
      const b = i < str.length ? str.charCodeAt(i++) : 0;
      const c = i < str.length ? str.charCodeAt(i++) : 0;

      const bitmap = (a << 16) | (b << 8) | c;

      result += chars.charAt((bitmap >> 18) & 63);
      result += chars.charAt((bitmap >> 12) & 63);
      result += i - 2 < str.length ? chars.charAt((bitmap >> 6) & 63) : '=';
      result += i - 1 < str.length ? chars.charAt(bitmap & 63) : '=';
    }

    return result;
  }

  /**
   * 生成随机频道名
   */
  public static generateChannelName(): string {
    const timestamp = Date.now();
    const random = Math.floor(Math.random() * 1000);
    return `${KeyCenter.CHANNEL_NAME}_${timestamp}_${random}`;
  }

  /**
   * 验证配置是否有效
   */
  public static isConfigValid(): boolean {
    return !!(KeyCenter.APP_ID && KeyCenter.APP_ID.trim() !== '');
  }

  /**
   * 获取配置信息（用于调试）
   */
  public static getConfigInfo(): Record<string, Object> {
    return BuildConfig.getConfigInfo();
  }
}
