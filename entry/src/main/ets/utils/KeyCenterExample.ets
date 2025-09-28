import { KeyCenter, TokenResponse } from './KeyCenter';

/**
 * KeyCenter使用示例
 * 展示如何在实际项目中使用KeyCenter生成Token
 */
export class KeyCenterExample {
  private static readonly TAG: string = 'KeyCenterExample';

  /**
   * 示例：生成RTC Token并初始化RTC引擎
   */
  public static async initializeRtcWithToken(): Promise<void> {
    console.log(`${KeyCenterExample.TAG} Starting RTC initialization with token`);

    // 获取用户ID和频道名
    const uid = KeyCenter.getUserUid();
    const channelName = KeyCenter.generateChannelName();

    console.log(`${KeyCenterExample.TAG} User UID: ${uid}, Channel: ${channelName}`);

    // 生成RTC Token
    KeyCenter.getRtcToken(channelName, uid, {
      onTokenGenerated: (response: TokenResponse) => {
        if (response.success && response.token) {
          console.log(`${KeyCenterExample.TAG} RTC Token generated successfully`);
          console.log(`${KeyCenterExample.TAG} Token: ${response.token.substring(0, 20)}...`);

          // 这里可以使用token初始化RTC引擎
          // 例如：rtcEngine.joinChannel(response.token, channelName, uid, options);

        } else {
          console.error(`${KeyCenterExample.TAG} Failed to generate RTC token: ${response.error}`);

          // 如果token生成失败，可以使用APP_ID作为fallback
          console.log(`${KeyCenterExample.TAG} Using APP_ID as fallback token`);
          // rtcEngine.joinChannel(KeyCenter.APP_ID, channelName, uid, options);
        }
      }
    });
  }

  /**
   * 示例：生成RTM Token
   */
  public static async initializeRtmWithToken(): Promise<void> {
    console.log(`${KeyCenterExample.TAG} Starting RTM initialization with token`);

    const uid = KeyCenter.getUserUid();

    KeyCenter.getRtmToken(uid, {
      onTokenGenerated: (response: TokenResponse) => {
        if (response.success && response.token) {
          console.log(`${KeyCenterExample.TAG} RTM Token generated successfully`);
          console.log(`${KeyCenterExample.TAG} Token: ${response.token.substring(0, 20)}...`);

          // 这里可以使用token初始化RTM
          // 例如：rtmClient.login(response.token, uid.toString());

        } else {
          console.error(`${KeyCenterExample.TAG} Failed to generate RTM token: ${response.error}`);
        }
      }
    });
  }

  /**
   * 示例：检查配置并显示信息
   */
  public static checkConfiguration(): void {
    console.log(`${KeyCenterExample.TAG} Checking KeyCenter configuration`);

    if (KeyCenter.isConfigValid()) {
      const configInfo = KeyCenter.getConfigInfo();
      console.log(`${KeyCenterExample.TAG} Configuration:`, JSON.stringify(configInfo));
    } else {
      console.error(`${KeyCenterExample.TAG} Invalid configuration - please check APP_ID in local.properties`);
    }
  }

  /**
   * 示例：Promise方式的Token生成（封装回调为Promise）
   */
  public static generateRtcTokenAsync(channelName: string, uid: number): Promise<string> {
    return new Promise((resolve, reject) => {
      KeyCenter.getRtcToken(channelName, uid, {
        onTokenGenerated: (response: TokenResponse) => {
          if (response.success && response.token) {
            resolve(response.token);
          } else {
            reject(new Error(response.error || 'Failed to generate token'));
          }
        }
      });
    });
  }

  /**
   * 示例：在RtcMccManager中使用
   */
  public static async initRtcMccManagerWithToken(): Promise<void> {
    try {
      // 检查配置
      if (!KeyCenter.isConfigValid()) {
        throw new Error('Invalid KeyCenter configuration');
      }

      // 生成用户ID和频道名
      const uid = KeyCenter.getUserUid();
      const channelName = KeyCenter.CHANNEL_NAME;

      console.log(`${KeyCenterExample.TAG} Initializing RtcMccManager with UID: ${uid}, Channel: ${channelName}`);

      // 生成Token
      const token = await KeyCenterExample.generateRtcTokenAsync(channelName, uid);

      console.log(`${KeyCenterExample.TAG} Token generated, initializing RtcMccManager...`);

      // 这里可以初始化RtcMccManager
      // const rtcMccManager = new RtcMccManager();
      // await rtcMccManager.init(context, KeyCenter.APP_ID, token, uid.toString(), callback);

    } catch (error) {
      console.error(`${KeyCenterExample.TAG} Failed to initialize RtcMccManager:`, JSON.stringify(error));

      // Fallback: 使用APP_ID作为token
      console.log(`${KeyCenterExample.TAG} Using APP_ID as fallback token`);
      // const rtcMccManager = new RtcMccManager();
      // await rtcMccManager.init(context, KeyCenter.APP_ID, KeyCenter.APP_ID, KeyCenter.getUserUid().toString(), callback);
    }
  }
}
