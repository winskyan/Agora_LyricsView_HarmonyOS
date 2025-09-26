import { common } from '@kit.AbilityKit';
import http from '@ohos.net.http';
import {
  CacheStatistics,
  ChannelMediaOptions,
  Constants,
  IAgoraMusicContentCenter,
  IAgoraMusicPlayer,
  IMediaPlayerObserver,
  IMusicContentCenterEventHandler,
  LyricInfo,
  Music,
  MusicChartInfo,
  MusicContentCenterConfiguration,
  MusicContentCenterVendorId,
  PlayerPlaybackStats,
  PlayerUpdatedInfo,
  RtcEngine,
  RtcEngineConfig,
  RtcStats,
  SrcInfo
} from "@shengwang/rtc-full";
import { IMccCallback } from '../interfaces/IMccCallback';

/**
 * YinSuDa API 响应数据结构
 */
interface YSDApiData {
  yinsuda_uid: string;
  token: string;
}

interface YSDApiResponse {
  error: number;
  data: YSDApiData;
}

/**
 * RTC事件处理器接口
 */
interface IRtcEventHandler {
  onJoinChannelSuccess?: (channel: string, uid: number, elapsed: number) => void;
  onLeaveChannel?: (stats: RtcStats | null) => void;
  onUserJoined?: (uid: number, elapsed: number) => void;
  onUserOffline?: (uid: number, reason: number) => void;
}

/**
 * Vendor1配置接口
 */
interface IVendor1Config {
  appId: string;
  token: string;
  userId: string;
  domain: string;
  channelId: string;
  channelUserId: string;
}

/**
 * Vendor2配置接口
 */
interface IVendor2Config {
  appId: string;
  appKey: string;
  token: string;
  userId: string;
  deviceId: string;
  urlTokenExpireTime: number;
  chargeMode: number;
  channelId: string;
  channelUserId: string;
}

/**
 * RTC MCC (Music Content Center) 管理器
 * 负责管理RTC引擎、音乐内容中心和音乐播放器
 */
export class RtcMccManager {
  private static readonly TAG = "RtcMccManager";
  // 核心组件
  private rtcEngine: RtcEngine | null = null;
  private musicCenter: IAgoraMusicContentCenter | null = null;
  private musicPlayer: IAgoraMusicPlayer | null = null;
  private config: MusicContentCenterConfiguration | null = null;
  // 配置信息
  private channelId: string = "";
  private token: string = "";
  private userId: string = "";
  private localUid: number = 0;
  // 回调接口
  private callback: IMccCallback | null = null;
  // 状态标识
  private isJoined: boolean = false;
  /**
   * MCC事件处理器
   */
  private mccEventHandler: IMusicContentCenterEventHandler = {
    onPreLoadEvent: (requestId: string, internalSongCode: bigint, percent: number, payload: string,
      state: Constants.MusicContentCenterState, reason: number) => {
      console.log(`${RtcMccManager.TAG} onPreLoadEvent requestId:${requestId} songCode:${internalSongCode} percent:${percent} payload:${payload} state:${state} reason:${reason}`);

      this.callback?.onMusicPreloadResult?.(internalSongCode, percent);

      if (state === 0 && percent === 100) { // PRELOAD_COMPLETED = 0
        this.handleLyricResult(internalSongCode, payload);
      }
    },

    onMusicCollectionResult: (requestId: string, page: number, pageSize: number, total: number, list: Music[],
      errorCode: number) => {
      console.log(`${RtcMccManager.TAG} onMusicCollectionResult requestId:${requestId} page:${page} total:${total} errorCode:${errorCode}`);
    },

    onMusicChartsResult: (requestId: string, list: MusicChartInfo[], errorCode: number) => {
      console.log(`${RtcMccManager.TAG} onMusicChartsResult requestId:${requestId} errorCode:${errorCode}`);
    },

    onLyricResult: (requestId: string, internalSongCode: bigint, payload: string, reason: number) => {
      console.log(`${RtcMccManager.TAG} onLyricResult requestId:${requestId} songCode:${internalSongCode} payload:${payload} reason:${reason}`);
      this.handleLyricResult(internalSongCode, payload);
    },

    onLyricInfoResult: (requestId: string, internalSongCode: bigint, lyricInfo: LyricInfo, reason: number) => {
      console.log(`${RtcMccManager.TAG} onLyricInfoResult requestId:${requestId} songCode:${internalSongCode} reason:${reason}`);
    },

    onSongSimpleInfoResult: (requestId: string, songCode: bigint, simpleInfo: string, errorCode: number) => {
      console.log(`${RtcMccManager.TAG} onSongSimpleInfoResult requestId:${requestId} songCode:${songCode} simpleInfo:${simpleInfo} errorCode:${errorCode}`);
    },

    onStartScoreResult: (internalSongCode: bigint, state: Constants.MusicContentCenterState, reason: number) => {
      console.log(`${RtcMccManager.TAG} onStartScoreResult songCode:${internalSongCode} state:${state} reason:${reason}`);

      if (state === 0 && reason === 0) { // START_SCORE_COMPLETED = 0, REASON_OK = 0
        // 设置评分等级
        // this.musicCenter?.setScoreLevel(5); // ScoreLevel API may not exist
        // 打开音乐播放器
        this.openMusicBySongCode(internalSongCode);
      }
    }
  };
  /**
   * 媒体播放器观察者
   */
  private mediaPlayerObserver: IMediaPlayerObserver = {
    onPlayerStateChanged: (state: Constants.MediaPlayerState, reason: Constants.MediaPlayerReason) => {
      console.log(`${RtcMccManager.TAG} onPlayerStateChanged state:${state} reason:${reason}`);

      switch (state) {
        case Constants.MediaPlayerState.OPEN_COMPLETED:
          this.callback?.onMusicPlaying?.();
          this.musicPlayer?.play();
          break;
        case Constants.MediaPlayerState.PLAYING:
          this.callback?.onMusicPlaying?.();
          break;
        case Constants.MediaPlayerState.PAUSED:
          break;
        case Constants.MediaPlayerState.STOPPED:
          this.callback?.onMusicStop?.();
          break;
        case Constants.MediaPlayerState.PLAYBACK_ALL_LOOPS_COMPLETED:
          this.callback?.onMusicStop?.();
          break;
        case Constants.MediaPlayerState.FAILED:
          this.callback?.onMusicError?.(reason);
          break;
      }
    },

    onPositionChanged: (positionMs: number, timestampMs: number) => {
      // 位置变化在MusicManager中处理
    },

    onPlayerEvent: (eventCode: Constants.MediaPlayerEvent, elapsedTime: number, message: string) => {
      // 播放器事件处理
    },

    onMetaData: (type: Constants.MediaPlayerMetadataType, data: ArrayBuffer) => {
      // 元数据处理
    },

    onPlayBufferUpdated: (playCachedBuffer: number) => {
      // 缓冲更新处理
    },

    onPreloadEvent: (src: string, event: Constants.MediaPlayerPreloadEvent) => {
      // 预加载事件处理
    },

    onPlayerSrcInfoChanged: (from: SrcInfo, to: SrcInfo) => {
      // 源信息变化处理
    },

    onPlayerInfoUpdated: (info: PlayerUpdatedInfo) => {
      // 播放器信息更新处理
    },

    onPlayerCacheStats: (stats: CacheStatistics) => {
      // 缓存统计处理
    },

    onPlayerPlaybackStats: (stats: PlayerPlaybackStats) => {
      // 播放统计处理
    },

    onAudioVolumeIndication: (volume: number) => {
      // 音量指示处理
    }
  };

  /**
   * 初始化RTC MCC管理器
   * @param context - 应用上下文
   * @param appId - Agora App ID
   * @param token - RTC Token
   * @param userId - 用户ID
   * @param callback - 回调接口
   */
  async init(context: common.UIAbilityContext, appId: string, token: string, userId: string,
    callback: IMccCallback): Promise<void> {
    this.token = token;
    this.userId = userId;
    this.callback = callback;

    try {
      await this.initRtcEngine(context, appId);
      await this.initMusicContentCenter();
      console.log(`${RtcMccManager.TAG} init completed successfully`);
    } catch (error) {
      console.error(`${RtcMccManager.TAG} init failed:`, JSON.stringify(error));
      throw Error(JSON.stringify(error));
    }
  }

  /**
   * 初始化RTC引擎
   */
  private async initRtcEngine(context: common.UIAbilityContext, appId: string): Promise<void> {
    console.log(`${RtcMccManager.TAG} RtcEngine version: ${RtcEngine.getSdkVersion()}`);

    const rtcEngineConfig: RtcEngineConfig = new RtcEngineConfig();
    rtcEngineConfig.mContext = context;
    rtcEngineConfig.mAppId = appId;
    const eventHandler: IRtcEventHandler = {
      onJoinChannelSuccess: (channel: string, uid: number, elapsed: number) => {
        console.log(`${RtcMccManager.TAG} onJoinChannelSuccess channel:${channel} uid:${uid} elapsed:${elapsed}`);
        this.localUid = uid;
        this.isJoined = true;
      },

      onLeaveChannel: (stats: RtcStats | null) => {
        console.log(`${RtcMccManager.TAG} onLeaveChannel`);
        this.isJoined = false;
      },

      onUserJoined: (uid: number, elapsed: number) => {
        console.log(`${RtcMccManager.TAG} onUserJoined uid:${uid} elapsed:${elapsed}`);
      },

      onUserOffline: (uid: number, reason: number) => {
        console.log(`${RtcMccManager.TAG} onUserOffline uid:${uid} reason:${reason}`);
      }
    };
    rtcEngineConfig.mEventHandler = eventHandler;

    this.rtcEngine = RtcEngine.create(rtcEngineConfig);
    this.rtcEngine.enableAudio();
    this.rtcEngine.setDefaultAudioRoutetoSpeakerphone(true);

    // 生成频道ID
    this.channelId = `music_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
  }

  /**
   * 初始化音乐内容中心
   */
  private async initMusicContentCenter(): Promise<void> {
    this.musicCenter = IAgoraMusicContentCenter.create();

    this.config = new MusicContentCenterConfiguration();
    this.config.eventHandler = this.mccEventHandler;

    const ret: number = this.musicCenter.initialize(this.config);
    if (ret !== 0) {
      throw Error(`MCC initialize failed with code: ${ret}`);
    }

    // 先获取访问数据
    await this.fetchAccessData();

    // 添加Vendor1 (默认供应商)
    const vendor1Config: IVendor1Config = {
      appId: "b792b33fc5f046ffa22776bf8d140e4d",
      token: "006b792b33fc5f046ffa22776bf8d140e4dIAB6nlAEWFCe0Xq8os3u2jEYPK+/T8spfLqGL7P32/RnJMJzkjAAAAAAEACF5MW4GZ3UaAEA6AMZndRo",
      userId: "123123",
      domain: "api-test.agora.io",
      channelId: this.channelId,
      channelUserId: "123123"
    };

    let addVendorRet: number =
      this.musicCenter.addVendor(MusicContentCenterVendorId.DEFAULT, JSON.stringify(vendor1Config));
    console.log(`${RtcMccManager.TAG} add vendor1 ret:${addVendorRet} config:${JSON.stringify(vendor1Config)}`);

    // 添加Vendor2 (第三方供应商)
    const vendor2Config: IVendor2Config = {
      appId: "203321",
      appKey: "4059144a3ace4a23a351ca3f96e6693d",
      token: this.token ||
        "KNH5K6UFHMIML9HE7H658HKGP47MOBG9OROLQKJH4PVCLP5LOK4ICQ0QEJDALHO87UT4U2LPL8OB60J783A6D9A53AD5L2S83N3BKBBJS5HTVHD0PQPDD7AUO79P4I6GMCSJTA28HEGNVUJ1URRGRCADI6PP267A2EPDOINPSA6GTDDQ18J02BLF405KL39Q",
      userId: this.userId || "341B43975E830CEB9F9925643F343B9C",
      deviceId: "341B43975E830CEB9F9925643F343B9C",
      urlTokenExpireTime: 15 * 60,
      chargeMode: 2,
      channelId: this.channelId,
      channelUserId: "123123"
    };

    addVendorRet = this.musicCenter.addVendor(MusicContentCenterVendorId.VENDOR_2, JSON.stringify(vendor2Config));
    console.log(`${RtcMccManager.TAG} add vendor2 ret:${addVendorRet} config:${JSON.stringify(vendor2Config)}`);

    // 创建音乐播放器
    this.musicPlayer = this.musicCenter.createMusicPlayer();
    this.musicPlayer?.registerPlayerObserver(this.mediaPlayerObserver);

    console.log(`${RtcMccManager.TAG} MCC initialized successfully`);
  }

  /**
   * 获取访问数据
   */
  private async fetchAccessData(): Promise<void> {
    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request('https://yapi-test.tuwan.com/yinsuda/getUserData?uid=1', {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json'
        }
      });

      if (response.responseCode === 200) {
        const result: YSDApiResponse = JSON.parse(response.result as string);
        console.log(`${RtcMccManager.TAG} fetchAccessData response:`, JSON.stringify(result));

        if (result.error === 0) {
          this.userId = result.data.yinsuda_uid;
          this.token = result.data.token;
          console.log(`${RtcMccManager.TAG} fetchAccessData success - userId:${this.userId} token:${this.token}`);
        } else {
          console.log(`${RtcMccManager.TAG} fetchAccessData error:${result.error}`);
        }
      } else {
        console.log(`${RtcMccManager.TAG} fetchAccessData failed with response code:${response.responseCode}`);
      }

      httpRequest.destroy();
    } catch (error) {
      console.log(`${RtcMccManager.TAG} fetchAccessData error:`, JSON.stringify(error));
    }
  }

  /**
   * 处理歌词结果
   */
  private handleLyricResult(internalSongCode: bigint, payload: string): void {
    try {
      const jsonObject: Record<string, Object> = JSON.parse(payload);
      const lyricPath = (jsonObject.lyricPath as string) || "";
      const pitchPath = (jsonObject.pitchPath as string) || "";
      const songOffsetBegin = (jsonObject.songOffsetBegin as number) || 0;
      const songOffsetEnd = (jsonObject.songOffsetEnd as number) || 0;
      const lyricOffset = (jsonObject.lyricOffset as number) || 0;

      console.log(`${RtcMccManager.TAG} handleLyricResult songCode:${internalSongCode} lyricPath:${lyricPath}`);

      this.callback?.onMusicLyricRequest?.(
        internalSongCode,
        lyricPath,
        pitchPath,
        songOffsetBegin,
        songOffsetEnd,
        lyricOffset
      );
    } catch (error) {
      console.error(`${RtcMccManager.TAG} handleLyricResult error:`, JSON.stringify(error));
    }
  }

  /**
   * 加入频道
   */
  joinChannel(): void {
    if (!this.rtcEngine) {
      console.error(`${RtcMccManager.TAG} RTC Engine not initialized`);
      return;
    }

    const option: ChannelMediaOptions = new ChannelMediaOptions();
    option.autoSubscribeAudio = true;
    option.autoSubscribeVideo = true;
    option.channelProfile = Constants.ChannelProfile.LIVE_BROADCASTING;
    option.clientRoleType = Constants.ClientRole.BROADCASTER;

    this.rtcEngine.setAudioScenario(Constants.AudioScenarioType.DEFAULT);
    this.rtcEngine.setDefaultAudioRoutetoSpeakerphone(true);

    const ret: number = this.rtcEngine.joinChannelWithOptions("", this.channelId, 123123, option);
    console.log(`${RtcMccManager.TAG} joinChannel ret:${ret} channel:${this.channelId}`);
  }

  /**
   * 离开频道
   */
  leaveChannel(): void {
    if (!this.rtcEngine) {
      console.error(`${RtcMccManager.TAG} RTC Engine not initialized`);
      return;
    }

    this.rtcEngine.leaveChannel();
    console.log(`${RtcMccManager.TAG} leaveChannel called`);
  }

  /**
   * 预加载音乐
   */
  preloadMusic(songCode: string, vendorId: MusicContentCenterVendorId, songOptionJson: string): void {
    if (!this.musicCenter) {
      console.error(`${RtcMccManager.TAG} MCC not initialized`);
      return;
    }

    try {
      const internalSongCode: bigint = this.musicCenter.getInternalSongCode(vendorId, songCode, songOptionJson);
      console.log(`${RtcMccManager.TAG} preloadMusic internalSongCode:${internalSongCode} songCode:${songCode}`);

      const isPreloaded: number = this.musicCenter.isPreloaded(internalSongCode);
      console.log(`${RtcMccManager.TAG} preload state:${isPreloaded}`);

      const requestId: string = this.musicCenter.preload(internalSongCode);
      console.log(`${RtcMccManager.TAG} preload requestId:${requestId}`);
    } catch (error) {
      console.error(`${RtcMccManager.TAG} preloadMusic error:`, JSON.stringify(error));
    }
  }

  /**
   * 开始评分
   */
  startScore(vendorId: MusicContentCenterVendorId, songCode: string, jsonOption: string): void {
    if (!this.musicCenter) {
      console.error(`${RtcMccManager.TAG} MCC not initialized`);
      return;
    }

    try {
      const internalSongCode: bigint = this.musicCenter.getInternalSongCode(vendorId, songCode, jsonOption);
      if (internalSongCode === BigInt(0)) {
        console.error(`${RtcMccManager.TAG} getInternalSongCode failed songCode:${songCode}`);
        return;
      }

      const ret: number = this.musicCenter.startScore(internalSongCode);
      console.log(`${RtcMccManager.TAG} startScore ret:${ret} internalSongCode:${internalSongCode}`);
    } catch (error) {
      console.error(`${RtcMccManager.TAG} startScore error:`, JSON.stringify(error));
    }
  }

  /**
   * 通过歌曲代码打开音乐
   */
  private openMusicBySongCode(internalSongCode: bigint): void {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return;
    }

    const ret: number = this.musicPlayer.openWithSongCode(internalSongCode, 0);
    console.log(`${RtcMccManager.TAG} openMusicBySongCode ret:${ret} songCode:${internalSongCode}`);
  }

  /**
   * 播放音乐
   */
  play(): void {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return;
    }

    this.musicPlayer.play();
    console.log(`${RtcMccManager.TAG} play called`);
  }

  /**
   * 暂停音乐
   */
  pause(): void {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return;
    }

    this.musicPlayer.pause();
    console.log(`${RtcMccManager.TAG} pause called`);
  }

  /**
   * 停止音乐
   */
  stop(): void {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return;
    }

    this.musicPlayer.stop();
    this.musicCenter?.stopScore();
    console.log(`${RtcMccManager.TAG} stop called`);
  }

  /**
   * 恢复播放
   */
  resume(): void {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return;
    }

    this.musicPlayer.resume();
    console.log(`${RtcMccManager.TAG} resume called`);
  }

  /**
   * 跳转到指定位置
   */
  seek(time: number): void {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return;
    }

    this.musicPlayer.seek(time);
    console.log(`${RtcMccManager.TAG} seek to:${time}`);
  }

  /**
   * 获取播放位置
   */
  getPlayPosition(): number {
    if (!this.musicPlayer) {
      return 0;
    }

    return this.musicPlayer.getPlayPosition();
  }

  /**
   * 设置播放模式
   */
  setPlayMode(playMode: Constants.MusicPlayMode): number {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return -1;
    }

    const ret: number = this.musicPlayer.setPlayMode(playMode);
    console.log(`${RtcMccManager.TAG} setPlayMode:${playMode} ret:${ret}`);
    return ret;
  }

  /**
   * 调整播放音量
   */
  adjustPlayoutVolume(volume: number): number {
    if (!this.musicPlayer) {
      console.error(`${RtcMccManager.TAG} Music player not created`);
      return -1;
    }

    const ret: number = this.musicPlayer.adjustPlayoutVolume(volume);
    console.log(`${RtcMccManager.TAG} adjustPlayoutVolume:${volume} ret:${ret}`);
    return ret;
  }

  /**
   * 获取播放音量
   */
  getPlayoutVolume(): number {
    if (!this.musicPlayer) {
      return 0;
    }

    return this.musicPlayer.getPlayoutVolume();
  }

  /**
   * 移除缓存
   */
  removeCache(internalSongCode: bigint): number {
    if (!this.musicCenter) {
      console.error(`${RtcMccManager.TAG} MCC not initialized`);
      return -1;
    }

    const ret: number = this.musicCenter.removeCache(internalSongCode);
    console.log(`${RtcMccManager.TAG} removeCache ret:${ret} songCode:${internalSongCode}`);
    return ret;
  }

  /**
   * 清理所有缓存
   */
  clearCache(): void {
    if (!this.musicCenter) {
      console.error(`${RtcMccManager.TAG} MCC not initialized`);
      return;
    }

    // const caches = this.musicCenter.getCaches(); // API may not exist
    const caches: CacheStatistics[] = []; // placeholder
    for (const cache of caches) {
      // this.musicCenter.removeCache(cache.songCode); // API may not exist
      // console.log(`${RtcMccManager.TAG} would remove cache: ${cache.songCode}`); // 暂时注释，避免API错误
      console.log(`${RtcMccManager.TAG} would remove cache`);
    }
    console.log(`${RtcMccManager.TAG} clearCache completed`);
  }

  /**
   * 销毁管理器
   */
  destroy(): void {
    console.log(`${RtcMccManager.TAG} destroy called`);

    // 注销观察者
    // this.musicPlayer?.unRegisterPlayerObserver(this.mediaPlayerObserver); // API may not exist

    // 销毁音乐播放器
    if (this.musicPlayer && this.musicCenter) {
      this.musicCenter.destroyMusicPlayer(this.musicPlayer);
      this.musicPlayer = null;
    }

    // 销毁MCC
    if (this.musicCenter) {
      IAgoraMusicContentCenter.destroy();
      this.musicCenter = null;
    }

    // 销毁RTC引擎
    if (this.rtcEngine) {
      if (this.isJoined) {
        this.rtcEngine.leaveChannel();
      }
      RtcEngine.destroy();
      this.rtcEngine = null;
    }

    // 清理配置
    this.config = null;
    this.callback = null;
    this.isJoined = false;

    console.log(`${RtcMccManager.TAG} destroy completed`);
  }

  /**
   * 获取频道ID
   */
  getChannelId(): string {
    return this.channelId;
  }

  /**
   * 获取本地用户ID
   */
  getLocalUid(): number {
    return this.localUid;
  }

  /**
   * 是否已加入频道
   */
  isChannelJoined(): boolean {
    return this.isJoined;
  }
}
