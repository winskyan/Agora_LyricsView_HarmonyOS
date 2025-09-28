import { hilog } from '@kit.PerformanceAnalysisKit';
import fs from '@ohos.file.fs';

import { KaraokeView, LyricModel, LyricsCutter } from 'lyrics_view';

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
 * 负责歌词数据的加载和处理，支持从rawfile和MCC两种方式加载
 */
export class LyricsService {
  protected readonly TAG: string = 'LyricsView-LyricsService';
  private karaokeView: KaraokeView | null = null;
  private lyricModel: LyricModel | null = null;

  constructor() {
  }

  /**
   * 设置 KaraokeView 实例
   */
  setKaraokeView(karaokeView: KaraokeView): void {
    this.karaokeView = karaokeView;
  }


  /**
   * 从MCC加载歌词数据（新增方式）
   * @param lyricUrl - 歌词文件路径
   * @param pitchUrl - 音高文件路径
   * @param songOffsetBegin - 歌曲开始偏移时间(ms)
   * @param songOffsetEnd - 歌曲结束偏移时间(ms)
   * @param lyricOffset - 歌词偏移时间(ms)
   */
  async loadLyricsFromMcc(
    lyricUrl: string,
    pitchUrl: string,
    songOffsetBegin: number,
    songOffsetEnd: number,
    lyricOffset: number
  ): Promise<LyricModel | null> {
    try {
      this.logDebug(`Loading loadLyricsFromMcc lyricUrl: ${lyricUrl} pitchUrl: ${pitchUrl} begin=${songOffsetBegin}, end=${songOffsetEnd}, lyricOffset=${lyricOffset}`);

      // 检查文件是否存在
      if (!await this.checkFileExists(lyricUrl)) {
        throw new Error(`Lyric file not found: ${lyricUrl}`);
      }

      // 使用 KaraokeView 解析歌词
      if (!this.karaokeView) {
        throw new Error('KaraokeView not initialized');
      }

      // 解析歌词，应用偏移量
      const lyricModel: LyricModel | null = this.karaokeView.parseLyrics(lyricUrl, pitchUrl, true, lyricOffset);

      if (!lyricModel) {
        throw new Error('Failed to parse lyrics from MCC');
      }

      this.logDebug(`Successfully parsed MCC lyrics with ${lyricModel.lines?.length || 0} lines`);

      // 如果有歌曲偏移，需要裁剪歌词
      if (songOffsetBegin > 0 || songOffsetEnd > 0) {
        const startTime = songOffsetBegin;
        const endTime: number = songOffsetEnd > 0 ? songOffsetEnd : (lyricModel.duration || 0);

        const cutResult: LyricModel | null = LyricsCutter.cut(lyricModel, startTime, endTime);
        if (cutResult !== null) {
          this.logDebug(`Successfully cut MCC lyrics, duration: ${cutResult.duration}ms`);
          return cutResult;
        }
      }

      this.lyricModel = lyricModel;
      return lyricModel;

    } catch (error) {
      this.logDebug(`Failed to load lyrics from MCC: ${error}`);
      return null;
    }
  }

  /**
   * 检查文件是否存在
   * @param filePath - 文件路径
   */
  private async checkFileExists(filePath: string): Promise<boolean> {
    try {
      const stat = await fs.stat(filePath);
      return stat.isFile();
    } catch (error) {
      this.logDebug(`File check failed: ${filePath}, error: ${error}`);
      return false;
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

  getPreludeEndPosition(): number {
    if (this.lyricModel) {
      return this.lyricModel.preludeEndPosition;
    }
    return 0;
  }

  /**
   * 调试日志
   */
  private logDebug(message: string): void {
    hilog.debug(0x0000, this.TAG, `%{public}s`, message);
  }
}
