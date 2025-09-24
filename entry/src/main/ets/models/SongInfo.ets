import { LyricModel } from 'lyrics_view';

/**
 * 歌曲信息模型
 * 使用 @ObservedV2 实现响应式状态管理
 */
@ObservedV2
export class SongInfo {
  /** 歌曲列表 */
  @Trace songList: string[] = ['十年', '月亮代表我的心', '童话'];
  /** 当前歌曲索引 */
  @Trace currentIndex: number = 0;
  /** 当前歌曲名称 */
  @Trace name: string = '';
  /** 歌词模型 */
  @Trace lyricModel: LyricModel | null = null;

  constructor() {
    this.updateCurrentSongName();
  }

  /**
   * 切换到下一首歌
   */
  switchToNext(): void {
    this.currentIndex = (this.currentIndex + 1) % this.songList.length;
    this.updateCurrentSongName();
    this.lyricModel = null; // 清空当前歌词数据
  }

  /**
   * 切换到上一首歌
   */
  switchToPrevious(): void {
    this.currentIndex = (this.currentIndex - 1 + this.songList.length) % this.songList.length;
    this.updateCurrentSongName();
    this.lyricModel = null; // 清空当前歌词数据
  }

  /**
   * 切换到指定歌曲
   */
  switchToSong(index: number): void {
    if (index >= 0 && index < this.songList.length) {
      this.currentIndex = index;
      this.updateCurrentSongName();
      this.lyricModel = null; // 清空当前歌词数据
    }
  }

  /**
   * 设置歌词模型
   */
  setLyricModel(model: LyricModel | null): void {
    this.lyricModel = model;
  }

  /**
   * 获取歌曲描述信息
   */
  getDescription(): string {
    return `当前歌曲: ${this.name} (${this.currentIndex + 1}/${this.songList.length})`;
  }

  /**
   * 检查是否有歌词数据
   */
  hasLyrics(): boolean {
    return this.lyricModel !== null;
  }

  /**
   * 更新当前歌曲名称
   */
  private updateCurrentSongName(): void {
    this.name = this.songList[this.currentIndex];
  }
}
