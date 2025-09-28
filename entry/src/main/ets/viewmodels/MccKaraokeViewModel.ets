import { common } from '@kit.AbilityKit';
import { Constants, MusicContentCenterVendorId } from "@shengwang/rtc-full";
import { IMccCallback } from '../interfaces/IMccCallback';
import { MusicManager, PlaybackStatus } from '../managers/MusicManager';
import { PlaybackState } from '../models/PlaybackState';
import { SongInfo } from '../models/SongInfo';
import { UIState } from '../models/UIState';
import { LyricsService } from '../services/LyricsService';
import { ContextManager } from '../utils/ContextManager';
import { ExampleLogUtils } from '../utils/ExmapleLogUtils';
import { KeyCenter, TokenCallback, TokenResponse, YSDTokenCallback, YSDTokenResponse } from '../utils/KeyCenter';
import { BaseViewModel } from './BaseViewModel';

import {
  IKaraokeEvent, KaraokeView, LyricModel, LyricsLineModel
} from 'lyrics_view';

/**
 * MCC 卡拉OK ViewModel
 * 集成MCC音乐播放和歌词显示功能
 */
@ObservedV2
export class MccKaraokeViewModel extends BaseViewModel implements IMccCallback {
  protected readonly TAG: string = 'LyricsView-MccKaraokeViewModel';
  // 响应式状态模型
  @Trace playbackState: PlaybackState = new PlaybackState();
  @Trace songInfo: SongInfo = new SongInfo();
  @Trace uiState: UIState = new UIState();
  // 服务依赖
  private lyricsService: LyricsService;
  public musicManager: MusicManager;
  // KaraokeView 实例
  private karaokeView: KaraokeView | null = null;
  // 配置信息 - 从KeyCenter获取
  public appId: string = KeyCenter.APP_ID;
  public rtcToken: string = "";
  public rtmToken: string = "";
  public userId: string = "";
  public ysdAppId: string = KeyCenter.VENDOR_2_APP_ID;
  public ysdAppKey: string = KeyCenter.VENDOR_2_APP_KEY;
  public ysdUserId: string = "";
  public ysdToken: string = "";
  // 当前服务类型
  private currentVendorId: MusicContentCenterVendorId = MusicContentCenterVendorId.DEFAULT;

  constructor() {
    super();
    this.lyricsService = new LyricsService();
    this.musicManager = new MusicManager();
  }

  /**
   * 初始化 ViewModel
   */
  async initialize(): Promise<void> {
    await super.initialize();

    await this.safeExecute(
      () => this.initializeMccKaraoke(),
      () => {
        this.uiState.setSuccess('MCC KaraokeView 初始化成功');
        this.musicManager.joinChannel();
      },
      (error) => {
        this.uiState.setError(`初始化失败: ${error.message}`);
      }
    );
  }

  /**
   * 初始化MCC卡拉OK系统
   */
  private async initializeMccKaraoke(): Promise<void> {
    ExampleLogUtils.logDebug(this.TAG, 'Initializing MCC Karaoke');
    // 1. 创建KaraokeView
    this.karaokeView = new KaraokeView();

    // 2. 设置KaraokeView事件监听
    this.setupKaraokeViewEvents();

    // 3. 设置歌词服务
    this.lyricsService.setKaraokeView(this.karaokeView);

    // 4. 获取Token并初始化音乐管理器
    const context = ContextManager.getInstance().getContext();
    if (!context) {
      throw new Error('Application context not available');
    }

    await this.initializeWithTokens(context);

    // 5. 更新歌曲信息
    this.updateCurrentSongInfo();

    ExampleLogUtils.logDebug(this.TAG, 'MCC Karaoke initialized successfully');
  }

  /**
   * 设置KaraokeView事件监听
   */
  private setupKaraokeViewEvents(): void {
    if (!this.karaokeView) {
      return;
    }

    const eventHandler: IKaraokeEvent = new MccKaraokeEventImpl(this);
    this.karaokeView.setKaraokeEvent(eventHandler);
  }

  /**
   * 获取Token并初始化音乐管理器
   */
  private async initializeWithTokens(context: common.UIAbilityContext): Promise<void> {
    ExampleLogUtils.logDebug(this.TAG, 'Starting token initialization');

    // 获取用户ID
    this.userId = KeyCenter.getUserUid().toString();
    const channelName = KeyCenter.CHANNEL_NAME;

    ExampleLogUtils.logDebug(this.TAG, `Using userId: ${this.userId}, channel: ${channelName}`);

    return new Promise((resolve, reject) => {
      let rtcTokenReceived = false;
      let rtmTokenReceived = false;
      let ysdTokenReceived = false;
      let hasError = false;

      const checkComplete = () => {
        if ((rtcTokenReceived && rtmTokenReceived && ysdTokenReceived) || hasError) {
          if (!hasError) {
            ExampleLogUtils.logDebug(this.TAG, 'All tokens received, initializing MusicManager');
            this.musicManager.init(context, this.appId, KeyCenter.CHANNEL_NAME, KeyCenter.RTC_TOKEN,
              KeyCenter.RTM_TOKEN,
              this.userId,
              this.ysdAppId, this.ysdAppKey, this.ysdUserId, this.ysdToken, this)
              .then(() => resolve())
              .catch((error: Error) => reject(error));
          }
        }
      };

      // 获取RTC Token
      const rtcTokenCallback = new RtcTokenCallbackImpl(this, () => {
        rtcTokenReceived = true;
      }, checkComplete);
      KeyCenter.getRtcToken(channelName, KeyCenter.getUserUid(), rtcTokenCallback);

      // 获取RTM Token
      const rtmTokenCallback = new RtmTokenCallbackImpl(this, () => {
        rtmTokenReceived = true;
      }, checkComplete);
      KeyCenter.getRtmToken(KeyCenter.getUserUid(), rtmTokenCallback);

      // 获取音速达Token
      const ysdTokenCallback = new YSDTokenCallbackImpl(this, () => {
        ysdTokenReceived = true;
      }, checkComplete);
      KeyCenter.getYSDToken(KeyCenter.getUserUid(), ysdTokenCallback);

      // 设置超时
      setTimeout(() => {
        if (!rtcTokenReceived || !rtmTokenReceived || !ysdTokenReceived) {
          hasError = true;
          ExampleLogUtils.logError(this.TAG, 'Token initialization timeout');
          reject(new Error('Token initialization timeout'));
        }
      }, 15000); // 15秒超时
    });
  }

  /**
   * 更新当前歌曲信息
   */
  private updateCurrentSongInfo(): void {
    const currentMusic = this.musicManager.getCurrentMusicInfo();
    if (currentMusic) {
      this.songInfo.name = currentMusic.songName;
    }
  }

  public getVendorName(): string {
    switch (this.currentVendorId) {
      case MusicContentCenterVendorId.DEFAULT:
        return "Default (音集协)";
      case MusicContentCenterVendorId.VENDOR_2:
        return "Vendor2 (音速达)";
      default:
        return "未知供应商";
    }
  }

  /**
   * 开始播放
   */
  startPlayback(): void {
    ExampleLogUtils.logDebug(this.TAG, 'startPlayback');
    if (this.musicManager.isPaused()) {
      this.uiState.setLoading(false, '正在播放音乐...');
      this.playbackState.isPlaying = true;
    } else {
      this.uiState.setLoading(true, '正在加载音乐...');
    }
    this.musicManager.playMusic();
  }

  /**
   * 暂停播放
   */
  pausePlayback(): void {
    this.musicManager.pauseOrResumeMusic();
  }

  /**
   * 停止播放
   */
  stopPlayback(): void {
    ExampleLogUtils.logDebug(this.TAG, 'stopPlayback');
    this.musicManager.stopMusic();
    this.playbackState.reset();
    this.karaokeView?.reset();
  }

  /**
   * 切换到下一首
   */
  switchToNext(): void {
    ExampleLogUtils.logDebug(this.TAG, 'switchToNext');
    this.stopPlayback();
    this.musicManager.switchMusic();
    this.updateCurrentSongInfo();
    this.uiState.setSuccess('已切换到下一首歌曲');
  }

  /**
   * 跳过前奏
   */
  skipIntro(): void {
    ExampleLogUtils.logDebug(this.TAG, 'skipIntro');
    // 跳转到歌词开始位置
    if (this.karaokeView) {
      const preludeEnd = this.lyricsService.getPreludeEndPosition();
      if (preludeEnd > 0) {
        this.musicManager.seekMusic(preludeEnd);
        this.uiState.setSuccess(`已跳过前奏，跳转到 ${preludeEnd}ms`);
      } else {
        this.uiState.callBackInfo = '当前歌曲没有前奏';
      }
    }
  }

  /**
   * 切换原唱/伴唱
   */
  toggleOriginalTrack(): void {
    ExampleLogUtils.logDebug(this.TAG, 'toggleOriginalTrack');
    this.musicManager.switchPlayOriginal();
    this.playbackState.isOriginalTrack = this.musicManager.isOriginalMode();

    const mode = this.musicManager.isOriginalMode() ? '原唱' : '伴唱';
    this.uiState.setSuccess(`已切换到${mode}模式`);
  }

  /**
   * 切换服务类型
   */
  switchServiceType(): void {
    ExampleLogUtils.logDebug(this.TAG, 'switchServiceType');

    // 先停止当前播放
    this.stopPlayback();

    // 切换服务类型
    this.currentVendorId =
      this.currentVendorId === MusicContentCenterVendorId.DEFAULT ? MusicContentCenterVendorId.VENDOR_2 :
      MusicContentCenterVendorId.DEFAULT;
    this.musicManager.updateMusicVendor(this.currentVendorId);

    // 更新歌曲信息
    this.updateCurrentSongInfo();

    const typeName = this.getVendorName();
    this.uiState.setSuccess(`已切换到 ${typeName}`); // API may not exist
  }

  // ==================== IMccCallback 实现 ====================

  /**
   * 音乐歌词请求回调
   */
  onMusicLyricRequest(
    songCode: bigint,
    lyricUrl: string,
    pitchUrl: string,
    songOffsetBegin: number,
    songOffsetEnd: number,
    lyricOffset: number
  ): void {
    // 异步加载歌词
    this.loadLyricsFromMcc(lyricUrl, pitchUrl, songOffsetBegin, songOffsetEnd, lyricOffset);
  }

  /**
   * 从MCC加载歌词
   */
  private async loadLyricsFromMcc(
    lyricUrl: string,
    pitchUrl: string,
    songOffsetBegin: number,
    songOffsetEnd: number,
    lyricOffset: number
  ): Promise<void> {
    try {
      this.uiState.setLoading(true, '正在加载歌词...');

      const lyricModel: LyricModel | null = await this.lyricsService.loadLyricsFromMcc(
        lyricUrl,
        pitchUrl,
        songOffsetBegin,
        songOffsetEnd,
        lyricOffset
      );

      if (lyricModel && this.karaokeView) {

        this.songInfo.setLyricModel(lyricModel)

        // 设置歌词数据
        this.karaokeView.setLyricData(lyricModel);

        // 更新歌曲信息
        // this.songInfo(lyricModel.duration); // API may not exist

        this.uiState.setSuccess('歌词加载成功');
        ExampleLogUtils.logDebug(this.TAG, `Lyrics loaded successfully, duration: ${lyricModel.duration}ms`);
      } else {
        throw new Error('Failed to load lyrics from MCC');
      }
    } catch (error) {
      console.error('Failed to load lyrics from MCC', JSON.stringify(error));
      this.uiState.setError(`歌词加载失败: ${error.message}`);
    }
  }

  /**
   * 音乐预加载结果回调
   */
  onMusicPreloadResult(songCode: bigint, percent: number): void {
    ExampleLogUtils.logDebug(this.TAG, `onMusicPreloadResult: songCode=${songCode}, percent=${percent}`);
    this.uiState.setLoading(true, `音乐加载中... ${percent}%`);
  }

  /**
   * 音乐播放位置变化回调
   */
  onMusicPositionChange(position: number): void {
    this.playbackState.updateProgress(position);

    // 更新歌词进度
    if (this.karaokeView) {
      this.karaokeView.setProgress(position);
    }
  }

  /**
   * 音乐音高评分回调
   */
  onMusicPitchScore(
    internalSongCode: bigint,
    voicePitch: number,
    pitchScore: number,
    progressInMs: number
  ): void {
    // 更新音高数据
    this.playbackState.updatePitch(voicePitch);

    // 更新KaraokeView音高
    if (this.karaokeView) {
      this.karaokeView.setPitch(voicePitch, pitchScore);
    }
  }

  /**
   * 音乐行评分回调
   */
  onMusicLineScore(
    internalSongCode: bigint,
    linePitchScore: number,
    cumulativeTotalLinePitchScores: number,
    performedLineIndex: number,
    performedTotalLines: number
  ): void {
    ExampleLogUtils.logDebug(this.TAG,
      `onMusicLineScore: line=${performedLineIndex}, score=${linePitchScore}, total=${cumulativeTotalLinePitchScores}`);
    // 可以在这里处理行评分
  }

  /**
   * 音乐开始播放回调
   */
  onMusicPlaying(): void {
    this.playbackState.setPlayingState(true);
    this.uiState.setSuccess('音乐播放中...');
  }

  onMusicPause(): void {
    this.playbackState.setPlayingState(false);
    this.uiState.callBackInfo = '音乐已暂停';
  }

  /**
   * 音乐停止播放回调
   */
  onMusicStop(): void {
    ExampleLogUtils.logDebug(this.TAG, 'onMusicStop');
    this.playbackState.setPlayingState(false);
    this.uiState.callBackInfo = '音乐已停止';
  }

  /**
   * 音乐播放错误回调
   */
  onMusicError(error: number): void {
    ExampleLogUtils.logError(this.TAG, `onMusicError: error=${error}`);
    this.playbackState.setPlayingState(false);
    this.uiState.setError(`播放错误: ${error}`);
  }

  // ==================== 状态查询方法 ====================

  /**
   * 获取当前播放状态
   */
  getPlaybackStatus(): PlaybackStatus {
    return this.musicManager.getPlaybackStatus();
  }

  /**
   * 是否已加入频道
   */
  isChannelJoined(): boolean {
    return this.musicManager.isChannelJoined();
  }

  /**
   * 获取频道ID
   */
  getChannelId(): string {
    return this.musicManager.getChannelId();
  }


  // ==================== 销毁方法 ====================

  /**
   * 销毁 ViewModel
   */
  destroy(): void {
    if (this.checkDestroyed()) {
      return;
    }

    // 停止播放
    this.stopPlayback();

    // 销毁音乐管理器
    this.musicManager.destroy();

    // 销毁 KaraokeView
    if (this.karaokeView && !this.karaokeView.getIsDestroyed()) {
      this.karaokeView.destroy();
      this.karaokeView = null;
    }

    super.destroy();
    ExampleLogUtils.logDebug(this.TAG, 'MccKaraokeViewModel destroyed');
  }
}

/**
 * MCC KaraokeEvent 实现类
 */
class MccKaraokeEventImpl implements IKaraokeEvent {
  private viewModel: MccKaraokeViewModel;

  constructor(viewModel: MccKaraokeViewModel) {
    this.viewModel = viewModel;
  }

  onDragTo(position: number): void {
    ExampleLogUtils.logDebug('LyricsView-MccKaraokeEventImpl', `onDragTo: ${position}`);
    this.viewModel.musicManager.seekMusic(position);
  }

  onLineFinished(line: LyricsLineModel, score: number, cumulativeScore: number, index: number, total: number): void {
    ExampleLogUtils.logDebug('LyricsView-MccKaraokeEventImpl',
      `onLineFinished: line=${line}, score=${score}, total=${cumulativeScore}`);
    // 可以在这里处理行完成事件
  }
}

class RtcTokenCallbackImpl implements TokenCallback {
  private viewModel: MccKaraokeViewModel;
  private rtcTokenReceived: () => void;
  private checkComplete: () => void;

  constructor(viewModel: MccKaraokeViewModel, rtcTokenReceived: () => void, checkComplete: () => void) {
    this.viewModel = viewModel;
    this.rtcTokenReceived = rtcTokenReceived;
    this.checkComplete = checkComplete;
  }

  onTokenGenerated(response: TokenResponse): void {
    if (response.success && response.token) {
      this.viewModel.rtcToken = response.token;
      ExampleLogUtils.logDebug('LyricsView-RtcTokenCallbackImpl',
        `RTC Token received: ${response.token.substring(0, 20)}...`);
    } else {
      ExampleLogUtils.logError('LyricsView-RtcTokenCallbackImpl', `RTC Token failed: ${response.error}`);
      this.viewModel.rtcToken = this.viewModel.appId; // Fallback to APP_ID
    }
    this.rtcTokenReceived();
    this.checkComplete();
  }
}

class RtmTokenCallbackImpl implements TokenCallback {
  private viewModel: MccKaraokeViewModel;
  private rtmTokenReceived: () => void;
  private checkComplete: () => void;

  constructor(viewModel: MccKaraokeViewModel, rtmTokenReceived: () => void, checkComplete: () => void) {
    this.viewModel = viewModel;
    this.rtmTokenReceived = rtmTokenReceived;
    this.checkComplete = checkComplete;
  }

  onTokenGenerated(response: TokenResponse): void {
    if (response.success && response.token) {
      this.viewModel.rtmToken = response.token;
      ExampleLogUtils.logDebug('LyricsView-RtmTokenCallbackImpl',
        `RTM Token received: ${response.token.substring(0, 20)}...`);
    } else {
      ExampleLogUtils.logError('LyricsView-RtmTokenCallbackImpl', `RTM Token failed: ${response.error}`);
      this.viewModel.rtmToken = this.viewModel.appId; // Fallback to APP_ID
    }
    this.rtmTokenReceived();
    this.checkComplete();
  }
}

class YSDTokenCallbackImpl implements YSDTokenCallback {
  private viewModel: MccKaraokeViewModel;
  private ysdTokenReceived: () => void;
  private checkComplete: () => void;

  constructor(viewModel: MccKaraokeViewModel, ysdTokenReceived: () => void, checkComplete: () => void) {
    this.viewModel = viewModel;
    this.ysdTokenReceived = ysdTokenReceived;
    this.checkComplete = checkComplete;
  }

  onYSDTokenGenerated(response: YSDTokenResponse): void {
    if (response.success && response.ysdUserId && response.ysdToken) {
      this.viewModel.ysdUserId = response.ysdUserId;
      this.viewModel.ysdToken = response.ysdToken;
      ExampleLogUtils.logDebug('LyricsView-YSDTokenCallbackImpl',
        `YSD Token received - userId: ${response.ysdUserId}, token: ${response.ysdToken.substring(0, 20)}...`);
    } else {
      ExampleLogUtils.logError('LyricsView-YSDTokenCallbackImpl', `YSD Token failed: ${response.error}`);
      // 使用默认值
      this.viewModel.ysdUserId = "";
      this.viewModel.ysdToken = "";
    }
    this.ysdTokenReceived();
    this.checkComplete();
  }
}
