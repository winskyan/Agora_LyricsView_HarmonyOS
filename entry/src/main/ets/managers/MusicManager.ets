import { common } from '@kit.AbilityKit';
import { Constants, MusicContentCenterVendorId } from "@shengwang/rtc-full";
import { IMccCallback } from '../interfaces/IMccCallback';
import { MusicResource, MusicResourcePool } from '../utils/MusicResourcePool';
import { RtcMccManager } from './RtcMccManager';
import { ExampleConstants } from '../utils/ExampleConstants'
import { ExampleLogUtils } from '../utils/ExmapleLogUtils';

/**
 * 播放状态枚举
 */
export enum PlaybackStatus {
  IDLE = 0,
  LOADING = 1,
  OPENED = 2,
  PLAYING = 3,
  PAUSED = 4,
  STOPPED = 5,
  COMPLETED = 6,
  ERROR = 7
}

/**
 * 音乐播放管理器
 * 负责协调音乐播放状态、歌词同步和UI更新
 */
export class MusicManager implements IMccCallback {
  private static readonly TAG = ExampleConstants.APP_TAG + "-MusicManager";
  private static readonly MUSIC_POSITION_UPDATE_INTERVAL = 20; // 20ms更新间隔

  // 核心组件
  private rtcMccManager: RtcMccManager | null = null;
  // 播放状态
  private status: PlaybackStatus = PlaybackStatus.IDLE;
  private playPosition: number = 0;
  private lyricsCurrentProgress: number = 0;
  private songOffsetBegin: number = 0;
  // 音乐配置
  private lyricType: Constants.LyricSourceType = 0; // LYRIC_SOURCE_XML = 0
  private musicPlayMode: Constants.MusicPlayMode = Constants.MusicPlayMode.ORIGINAL;
  private isOriginal: boolean = true;
  // 音乐资源
  private musicResources: MusicResource[] = [];
  private currentSongIndex: number = 0;
  // 定时器
  private positionUpdateTimer: number | null = null;
  // 回调接口
  private callback: IMccCallback | null = null;

  /**
   * 初始化音乐管理器
   * @param context - 应用上下文
   * @param appId - Agora App ID
   * @param token - RTC Token
   * @param userId - 用户ID
   * @param callback - 回调接口
   */
  async init(context: common.UIAbilityContext, appId: string, token: string, userId: string,
    callback: IMccCallback): Promise<void> {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MusicManager init`);
    this.callback = callback;
    this.initData();

    this.rtcMccManager = new RtcMccManager();
    await this.rtcMccManager.init(context, appId, token, userId, this);

    ExampleLogUtils.logDebug(MusicManager.TAG, `MusicManager init completed`);
  }

  /**
   * 初始化数据
   */
  private initData(): void {
    this.musicResources = MusicResourcePool.getVendor1MusicList();
    this.currentSongIndex = 0;
    this.status = PlaybackStatus.IDLE;
  }

  /**
   * 更新音乐服务类型
   * @param serviceType - 服务类型
   */
  updateMusicVendor(vendorId: MusicContentCenterVendorId): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `updateMusicVendor:${vendorId}`);

    this.currentSongIndex = 0;

    switch (vendorId) {
      case MusicContentCenterVendorId.DEFAULT:
        this.lyricType = Constants.LyricSourceType.XML;
        this.musicPlayMode = Constants.MusicPlayMode.ORIGINAL;
        this.musicResources = MusicResourcePool.getVendor1MusicList();
        break;
      case MusicContentCenterVendorId.VENDOR_2:
        this.lyricType = Constants.LyricSourceType.KRC;
        this.musicPlayMode = Constants.MusicPlayMode.ORIGINAL;
        this.musicResources = MusicResourcePool.getVendor2MusicList();
        break;
    }
  }

  /**
   * 加入频道
   */
  joinChannel(): void {
    this.rtcMccManager?.joinChannel();
  }

  /**
   * 离开频道
   */
  leaveChannel(): void {
    this.rtcMccManager?.leaveChannel();
  }

  /**
   * 播放音乐
   */
  playMusic(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager playMusic`);

    if (this.musicResources.length === 0) {
      console.error(`${MusicManager.TAG} no music resources available`);
      return;
    }

    this.isOriginal = true;
    this.lyricsCurrentProgress = 0;
    this.setPlayMode(Constants.MusicPlayMode.ORIGINAL);

    const currentMusic = this.musicResources[this.currentSongIndex];

    // 根据供应商设置歌词类型
    if (currentMusic.vendorId === MusicContentCenterVendorId.VENDOR_2) {
      //TODO LyricType 0: xml 1: lrc 2: lrc with pitches 3: krc
      this.lyricType = Constants.LyricSourceType.KRC; // LYRIC_SOURCE_KRC = 1
    }

    this.status = PlaybackStatus.LOADING;

    this.rtcMccManager?.preloadMusic(
      currentMusic.songCode,
      currentMusic.vendorId,
      currentMusic.songOptionJson
    );
  }

  /**
   * 开始播放（通过评分系统）
   */
  private openMusic(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager openMusic`);

    if (this.musicResources.length === 0) {
      console.error(`${MusicManager.TAG} no music resources available`);
      return;
    }

    const currentMusic = this.musicResources[this.currentSongIndex];

    this.rtcMccManager?.startScore(
      currentMusic.vendorId,
      currentMusic.songCode,
      currentMusic.songOptionJson
    );
  }

  /**
   * 通过歌曲代码打开音乐
   */
  private openMusicBySongCode(internalSongCode: bigint): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager openMusicBySongCode:${internalSongCode}`);
    this.setPlayMode(this.musicPlayMode);
    // 音乐播放器会在RtcMccManager中自动打开和播放
  }

  /**
   * 停止音乐
   */
  stopMusic(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager stopMusic`);

    if (this.status === PlaybackStatus.IDLE) {
      return;
    }

    this.lyricsCurrentProgress = 0;
    this.status = PlaybackStatus.IDLE;
    this.stopDisplayLrc();

    this.rtcMccManager?.stop();
  }

  /**
   * 暂停音乐
   */
  private pauseMusic(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager pauseMusic`);

    if (this.status !== PlaybackStatus.PLAYING) {
      return;
    }

    this.status = PlaybackStatus.PAUSED;
    this.rtcMccManager?.pause();
  }

  /**
   * 恢复音乐
   */
  private resumeMusic(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager resumeMusic`);

    if (this.status !== PlaybackStatus.PAUSED) {
      return;
    }

    this.status = PlaybackStatus.PLAYING;
    this.rtcMccManager?.resume();
  }

  /**
   * 暂停或恢复音乐
   */
  pauseOrResumeMusic(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager pauseOrResumeMusic status:${this.status}`);

    if (this.status === PlaybackStatus.PLAYING) {
      this.pauseMusic();
    } else if (this.status === PlaybackStatus.PAUSED) {
      this.resumeMusic();
    }
  }

  /**
   * 跳转音乐位置
   * @param position - 目标位置(ms)
   */
  seekMusic(position: number): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager seekMusic:${position}`);
    this.lyricsCurrentProgress = position;
    this.rtcMccManager?.seek(position);
    this.updateMusicPosition(position);
  }

  /**
   * 切换原唱/伴唱
   */
  switchPlayOriginal(): void {
    if (this.isOriginal) {
      this.isOriginal = false;
      this.setPlayMode(Constants.MusicPlayMode.ACCOMPANY);
    } else {
      this.isOriginal = true;
      this.setPlayMode(Constants.MusicPlayMode.ORIGINAL);
    }
  }

  /**
   * 切换到下一首歌
   */
  switchMusic(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MuiscManager switchMusic`);

    this.lyricsCurrentProgress = 0;
    this.rtcMccManager?.stop();

    this.currentSongIndex++;
    if (this.currentSongIndex >= this.musicResources.length) {
      this.currentSongIndex = 0;
    }
  }

  /**
   * 设置播放模式
   */
  private setPlayMode(playMode: Constants.MusicPlayMode): void {
    const ret = this.rtcMccManager?.setPlayMode(playMode);
    if (ret === 0) {
      this.musicPlayMode = playMode;
    }
  }

  /**
   * 开始显示歌词（启动位置更新定时器）
   */
  private startDisplayLrc(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MusicManager startDisplayLrc`);

    this.playPosition = -1;

    this.positionUpdateTimer = setInterval(() => {
      if (this.status === PlaybackStatus.PLAYING) {
        if (this.playPosition === -1 || this.playPosition % 1000 < MusicManager.MUSIC_POSITION_UPDATE_INTERVAL) {
          this.playPosition = this.rtcMccManager?.getPlayPosition() || 0;
          this.playPosition += this.songOffsetBegin;
        } else {
          this.playPosition += MusicManager.MUSIC_POSITION_UPDATE_INTERVAL;
        }

        this.callback?.onMusicPositionChange?.(this.playPosition);
      }
    }, MusicManager.MUSIC_POSITION_UPDATE_INTERVAL);
  }

  /**
   * 停止显示歌词（清除位置更新定时器）
   */
  private stopDisplayLrc(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MusicManager stopDisplayLrc`);

    if (this.positionUpdateTimer !== null) {
      clearInterval(this.positionUpdateTimer);
      this.positionUpdateTimer = null;
    }
  }

  /**
   * 更新音乐位置
   */
  private updateMusicPosition(position: number): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MusicManager updateMusicPosition:${position}`);
    if (this.status === PlaybackStatus.PLAYING) {
      this.playPosition = position;
    }
  }

  /**
   * 重置状态
   */
  private reset(): void {
    this.status = PlaybackStatus.IDLE;
    this.stopDisplayLrc();
  }

  /**
   * 清理缓存
   */
  clearCache(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MusicManager clearCache`);
    this.rtcMccManager?.clearCache();
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
    ExampleLogUtils.logDebug(MusicManager.TAG, `onMusicLyricRequest songCode:${songCode} lyricUrl:${lyricUrl}`);

    this.songOffsetBegin = songOffsetBegin;

    // 转发给外部回调
    this.callback?.onMusicLyricRequest?.(songCode, lyricUrl, pitchUrl, songOffsetBegin, songOffsetEnd, lyricOffset);
  }

  /**
   * 音乐预加载结果回调
   */
  onMusicPreloadResult(songCode: bigint, percent: number): void {
    this.callback?.onMusicPreloadResult?.(songCode, percent);

    // 预加载完成后开始播放
    if (percent === 100) {
      this.openMusic();
    }
  }

  /**
   * 音乐位置变化回调
   */
  onMusicPositionChange(position: number): void {
    // 由定时器处理，这里不需要实现
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
    this.callback?.onMusicPitchScore?.(internalSongCode, voicePitch, pitchScore, progressInMs);
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
    this.callback?.onMusicLineScore?.(
      internalSongCode,
      linePitchScore,
      cumulativeTotalLinePitchScores,
      performedLineIndex,
      performedTotalLines
    );
  }

  /**
   * 音乐开始播放回调
   */
  onMusicPlaying(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `onMusicPlaying`);

    this.status = PlaybackStatus.PLAYING;
    this.startDisplayLrc();

    this.callback?.onMusicPlaying?.();
  }

  /**
   * 音乐停止播放回调
   */
  onMusicStop(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `onMusicStop`);

    if (this.status !== PlaybackStatus.IDLE) {
      this.status = PlaybackStatus.STOPPED;
    }

    this.stopDisplayLrc();
    this.callback?.onMusicStop?.();
  }

  /**
   * 音乐播放错误回调
   */
  onMusicError(error: number): void {
    console.error(`${MusicManager.TAG} MusicManager onMusicError:${error}`);

    this.status = PlaybackStatus.ERROR;
    this.stopDisplayLrc();

    this.callback?.onMusicError?.(error);
  }

  /**
   * 是否正在播放
   */
  isPlaying(): boolean {
    return this.status === PlaybackStatus.PLAYING;
  }

  /**
   * 是否暂停
   */
  isPaused(): boolean {
    return this.status === PlaybackStatus.PAUSED;
  }

  /**
   * 是否原唱模式
   */
  isOriginalMode(): boolean {
    return this.isOriginal;
  }

  isChannelJoined(): boolean {
    return this.rtcMccManager?.isChannelJoined() || false;
  }

  /**
   * 获取当前歌曲信息
   */
  getCurrentMusicInfo(): MusicResource | null {
    if (this.currentSongIndex >= 0 && this.currentSongIndex < this.musicResources.length) {
      return this.musicResources[this.currentSongIndex];
    }
    return null;
  }

  /**
   * 获取播放状态
   */
  getPlaybackStatus(): PlaybackStatus {
    return this.status;
  }

  /**
   * 获取歌词当前进度
   */
  getLyricsCurrentProgress(): number {
    return this.lyricsCurrentProgress;
  }

  /**
   * 设置歌词当前进度
   */
  setLyricsCurrentProgress(progress: number): void {
    this.lyricsCurrentProgress = progress;
  }

  /**
   * 获取歌词类型
   */
  getLyricType(): Constants.LyricSourceType {
    return this.lyricType;
  }

  /**
   * 设置歌词类型
   */
  setLyricType(lyricType: Constants.LyricSourceType): void {
    this.lyricType = lyricType;
  }

  /**
   * 获取频道ID
   */
  getChannelId(): string {
    return this.rtcMccManager?.getChannelId() || "";
  }

  /**
   * 销毁管理器
   */
  destroy(): void {
    ExampleLogUtils.logDebug(MusicManager.TAG, `MusicManager destroy`);

    this.stopDisplayLrc();
    this.rtcMccManager?.destroy();
    this.rtcMccManager = null;
    this.callback = null;
    this.reset();
  }
}
