import { hilog } from '@kit.PerformanceAnalysisKit';
import { FileService } from './FileService';
import { LyricsService } from './LyricsService';
import { PlaybackService } from './PlaybackService';

const TAG = 'ServiceManager';

/**
 * 服务管理器
 * 负责全局服务的初始化和管理
 */
export class ServiceManager {
  private static instance: ServiceManager;
  private fileService: FileService | null = null;
  private playbackService: PlaybackService | null = null;
  private lyricsService: LyricsService | null = null;
  private initialized: boolean = false;

  /**
   * 获取单例实例
   */
  static getInstance(): ServiceManager {
    if (!ServiceManager.instance) {
      ServiceManager.instance = new ServiceManager();
    }
    return ServiceManager.instance;
  }

  /**
   * 初始化所有服务
   */
  async initialize(): Promise<void> {
    if (this.initialized) {
      return;
    }

    try {
      this.logInfo('Initializing services...');

      // 初始化各个服务
      this.fileService = new FileService();
      this.playbackService = new PlaybackService();
      this.lyricsService = new LyricsService();

      // 可以在这里进行服务间的依赖注入或配置

      this.initialized = true;
      this.logInfo('All services initialized successfully');

    } catch (error) {
      this.logError(`Failed to initialize services: ${error}`);
      throw new Error(`Failed to initialize services: ${error}`);
    }
  }

  /**
   * 获取文件服务
   */
  getFileService(): FileService {
    if (!this.fileService) {
      throw new Error('FileService not initialized');
    }
    return this.fileService;
  }

  /**
   * 获取播放服务
   */
  getPlaybackService(): PlaybackService {
    if (!this.playbackService) {
      throw new Error('PlaybackService not initialized');
    }
    return this.playbackService;
  }

  /**
   * 获取歌词服务
   */
  getLyricsService(): LyricsService {
    if (!this.lyricsService) {
      throw new Error('LyricsService not initialized');
    }
    return this.lyricsService;
  }

  /**
   * 销毁所有服务
   */
  destroy(): void {
    if (!this.initialized) {
      return;
    }

    this.logInfo('Destroying services...');

    try {
      // 销毁各个服务
      this.playbackService?.destroy();

      // 清理引用
      this.fileService = null;
      this.playbackService = null;
      this.lyricsService = null;

      this.initialized = false;
      this.logInfo('All services destroyed');

    } catch (error) {
      this.logError(`Failed to destroy services: ${error}`);
    }
  }

  /**
   * 检查服务是否已初始化
   */
  isInitialized(): boolean {
    return this.initialized;
  }

  /**
   * 信息日志
   */
  private logInfo(message: string): void {
    hilog.info(0x0000, TAG, `%{public}s`, message);
  }

  /**
   * 错误日志
   */
  private logError(message: string): void {
    hilog.error(0x0000, TAG, `%{public}s`, message);
  }
}

/**
 * 全局服务管理器实例
 */
export const serviceManager = ServiceManager.getInstance();
