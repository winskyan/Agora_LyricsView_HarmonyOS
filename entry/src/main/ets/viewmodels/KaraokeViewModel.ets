import {
  IKaraokeEvent, KaraokeView, LyricsLineModel
} from 'lyrics_view';
import { PlaybackState } from '../models/PlaybackState';
import { SongInfo } from '../models/SongInfo';
import { UIState } from '../models/UIState';
import { FileService } from '../services/FileService';
import { LyricsService } from '../services/LyricsService';
import { PlaybackCallback, PlaybackService } from '../services/PlaybackService';
import { BaseViewModel } from './BaseViewModel';

/**
 * 卡拉OK ViewModel
 * 负责状态管理和业务逻辑协调
 */
@ObservedV2
export class KaraokeViewModel extends BaseViewModel {
  protected readonly TAG: string = 'KaraokeViewModel';
  // 响应式状态模型
  @Trace playbackState: PlaybackState = new PlaybackState();
  @Trace songInfo: SongInfo = new SongInfo();
  @Trace uiState: UIState = new UIState();
  // 服务依赖
  private fileService: FileService;
  private playbackService: PlaybackService;
  private lyricsService: LyricsService;
  // KaraokeView 实例
  private karaokeView: KaraokeView | null = null;

  constructor() {
    super();
    this.fileService = new FileService();
    this.playbackService = new PlaybackService();
    this.lyricsService = new LyricsService();

    this.setupPlaybackCallbacks();
  }

  /**
   * 初始化 ViewModel
   */
  async initialize(): Promise<void> {
    await super.initialize();

    await this.safeExecute(
      () => this.initializeKaraoke(),
      () => {
        this.uiState.setSuccess('KaraokeView 初始化成功');
      },
      (error) => {
        this.uiState.setError(`初始化失败: ${error.message}`);
      }
    );
  }

  /**
   * 销毁 ViewModel
   */
  destroy(): void {
    if (this.checkDestroyed()) {
      return;
    }

    // 销毁服务
    this.playbackService.destroy();

    // 销毁 KaraokeView
    if (this.karaokeView && !this.karaokeView.getIsDestroyed()) {
      this.karaokeView.destroy();
      this.karaokeView = null;
    }

    super.destroy();
  }

  /**
   * 设置播放服务回调
   */
  private setupPlaybackCallbacks(): void {
    const callbacks: PlaybackCallback = {
      onProgressUpdate: (progress: number) => {
        this.playbackState.updateProgress(progress);

        if (this.karaokeView) {
          this.karaokeView.setProgress(progress);
        }
      },

      onStateChange: (isPlaying: boolean) => {
        this.playbackState.setPlayingState(isPlaying);
      },

      onPitchUpdate: (pitch: number) => {
        this.playbackState.updatePitch(pitch);

        if (this.karaokeView) {
          this.karaokeView.setPitch(pitch, 0);
        }
      }
    };

    this.playbackService.setCallbacks(callbacks);
  }

  /**
   * 初始化 KaraokeView
   */
  private async initializeKaraoke(): Promise<void> {
    this.karaokeView = new KaraokeView();
    this.karaokeView.setKaraokeEvent(new KaraokeEventImpl(this));
    this.lyricsService.setKaraokeView(this.karaokeView);

    this.logDebug('KaraokeView initialized successfully');
  }

  /**
   * 加载歌曲
   */
  async loadSong(): Promise<void> {
    if (this.checkDestroyed()) {
      return;
    }

    this.uiState.setLoading(true, '正在加载歌曲...');

    await this.safeExecute(
      async () => {
        // 加载歌词数据
        const lyricModel = await this.lyricsService.loadLyrics();

        if (!lyricModel) {
          throw new Error('Failed to load lyrics');
        }

        // 设置到 KaraokeView 和状态
        if (this.karaokeView) {
          this.karaokeView.setLyricData(lyricModel);
        }
        this.songInfo.setLyricModel(lyricModel);

        return lyricModel;
      },
      () => {
        this.uiState.setSuccess('歌曲加载完成');
      },
      (error) => {
        this.uiState.setError(`加载失败: ${error.message}`);
      }
    );
  }

  /**
   * 开始播放
   */
  startPlayback(): void {
    if (this.checkDestroyed()) {
      return;
    }

    if (!this.songInfo.hasLyrics()) {
       this.loadSong();
    }

    this.playbackService.start();
    this.uiState.setSuccess('开始播放');
  }

  /**
   * 暂停播放
   */
  pausePlayback(): void {
    if (this.checkDestroyed()) {
      return;
    }

    this.playbackService.pause();
    this.uiState.setSuccess('暂停播放');
  }

  /**
   * 停止播放
   */
  stopPlayback(): void {
    if (this.checkDestroyed()) {
      return;
    }

    this.playbackService.stop();
    this.playbackState.reset();
    this.uiState.setSuccess('停止播放');
  }

  /**
   * 切换到下一首歌
   */
  async switchToNext(): Promise<void> {
    if (this.checkDestroyed()) {
      return;
    }

    this.stopPlayback();
    this.songInfo.switchToNext();
    this.uiState.setLoading(true, `正在加载: ${this.songInfo.name}`);

    await this.loadSong();
  }

  /**
   * 跳过前奏
   */
  skipIntro(): void {
    if (this.checkDestroyed()) {
      return;
    }

    const lyricModel = this.songInfo.lyricModel;
    if (lyricModel && this.karaokeView) {
      const preludeEndPosition = lyricModel.preludeEndPosition - 1000;
      this.playbackService.seekTo(preludeEndPosition);
      this.uiState.setSuccess('跳过前奏');
    }
  }

  /**
   * 切换原唱/伴奏
   */
  toggleOriginalTrack(): void {
    if (this.checkDestroyed()) {
      return;
    }

    this.playbackState.toggleOriginalTrack();
    const message = this.playbackState.isOriginalTrack ? '切换到原唱' : '切换到伴奏';
    this.uiState.setSuccess(message);
  }

  /**
   * 处理拖拽事件
   */
  handleDragTo(finalProgress: number): void {
    if (this.checkDestroyed()) {
      return;
    }

    this.playbackService.seekTo(finalProgress);
    this.uiState.setSuccess(`拖拽到: ${finalProgress}ms`);
  }

  /**
   * 处理歌词行完成事件
   */
  handleLineFinished(line: LyricsLineModel, score: number, cumulativeScore: number,
    index: number, lineCount: number): void {
    if (this.checkDestroyed()) {
      return;
    }

    this.logDebug(`Line ${index} finished with score ${score}`);
    this.uiState.setSuccess(`第${index + 1}行完成，得分: ${score}`);
  }
}

/**
 * KaraokeEvent 实现类
 */
class KaraokeEventImpl implements IKaraokeEvent {
  private viewModel: KaraokeViewModel;

  constructor(viewModel: KaraokeViewModel) {
    this.viewModel = viewModel;
  }

  onDragTo(position: number): void {
    this.viewModel.handleDragTo(position);
  }

  onLineFinished(line: LyricsLineModel, score: number, cumulativeScore: number,
    index: number, lineCount: number): void {
    this.viewModel.handleLineFinished(line, score, cumulativeScore, index, lineCount);
  }
}
