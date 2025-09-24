import { hilog } from '@kit.PerformanceAnalysisKit';
import { KaraokeView, LyricModel, LyricsCutter } from 'lyrics_view';
import { FileService } from './FileService';

const TAG = 'LyricsService';

/**
 * 歌词统计信息接口
 */
export interface LyricsStats {
  lineCount: number;
  duration: number;
  preludeEnd: number;
}

/**
 * 歌词服务
 * 负责歌词数据的加载和处理
 */
export class LyricsService {
  private fileService: FileService;
  private karaokeView: KaraokeView | null = null;

  constructor() {
    this.fileService = new FileService();
  }

  /**
   * 设置 KaraokeView 实例
   */
  setKaraokeView(karaokeView: KaraokeView): void {
    this.karaokeView = karaokeView;
  }

  /**
   * 加载歌词数据
   */
  async loadLyrics(): Promise<LyricModel | null> {
    try {
      // 确保文件已准备好
      if (!this.fileService.checkFilesExist()) {
        await this.fileService.prepareFiles();
      }

      const lyricFilePath = this.fileService.getLyricFilePath();
      const pitchFilePath = this.fileService.getPitchFilePath();

      this.logDebug(`Loading lyrics from: ${lyricFilePath}`);
      this.logDebug(`Loading pitch from: ${pitchFilePath}`);

      // 使用 KaraokeView 解析歌词
      if (!this.karaokeView) {
        throw new Error('KaraokeView not initialized');
      }

      const lyricModel = this.karaokeView.parseLyrics(lyricFilePath, pitchFilePath, true, 0);

      if (!lyricModel) {
        throw new Error('Failed to parse lyrics');
      }

      this.logDebug(`Successfully parsed lyrics with ${lyricModel.lines?.length || 0} lines`);

      // 裁剪歌词（如果需要）
      const cutResult = LyricsCutter.cut(lyricModel, 0, lyricModel.duration);
      if (cutResult !== null) {
        this.logDebug(`Successfully cut lyrics, duration: ${cutResult.duration}ms`);
        return cutResult;
      }

      return lyricModel;

    } catch (error) {
      this.logDebug(`Failed to load lyrics: ${error}`);
      return null;
    }
  }

  /**
   * 验证歌词数据
   */
  validateLyrics(lyricModel: LyricModel): boolean {
    if (!lyricModel) {
      return false;
    }

    if (!lyricModel.lines || lyricModel.lines.length === 0) {
      this.logDebug('Lyrics validation failed: no lines found');
      return false;
    }

    this.logDebug(`Lyrics validation passed: ${lyricModel.lines.length} lines`);
    return true;
  }

  /**
   * 获取歌词统计信息
   */
  getLyricsStats(lyricModel: LyricModel): LyricsStats {
    const stats: LyricsStats = {
      lineCount: lyricModel.lines?.length || 0,
      duration: lyricModel.duration || 0,
      preludeEnd: lyricModel.preludeEndPosition || 0
    };
    return stats;
  }

  /**
   * 调试日志
   */
  private logDebug(message: string): void {
    hilog.debug(0x0000, TAG, `%{public}s`, message);
  }
}
