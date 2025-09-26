/**
 * MCC (Music Content Center) 回调接口
 * 定义音乐播放和歌词相关的事件回调
 */
export interface IMccCallback {
  /**
   * 音乐歌词请求回调
   * @param songCode - 歌曲内部编码
   * @param lyricUrl - 歌词文件路径
   * @param pitchUrl - 音高文件路径
   * @param songOffsetBegin - 歌曲开始偏移时间(ms)
   * @param songOffsetEnd - 歌曲结束偏移时间(ms)
   * @param lyricOffset - 歌词偏移时间(ms)
   */
  onMusicLyricRequest?(
    songCode: bigint,
    lyricUrl: string,
    pitchUrl: string,
    songOffsetBegin: number,
    songOffsetEnd: number,
    lyricOffset: number
  ): void;

  /**
   * 音乐预加载结果回调
   * @param songCode - 歌曲内部编码
   * @param percent - 预加载进度百分比
   */
  onMusicPreloadResult?(songCode: bigint, percent: number): void;

  /**
   * 音乐播放位置变化回调
   * @param position - 当前播放位置(ms)
   */
  onMusicPositionChange?(position: number): void;

  /**
   * 音乐音高评分回调
   * @param internalSongCode - 歌曲内部编码
   * @param voicePitch - 声音音高
   * @param pitchScore - 音高评分
   * @param progressInMs - 播放进度(ms)
   */
  onMusicPitchScore?(
    internalSongCode: bigint,
    voicePitch: number,
    pitchScore: number,
    progressInMs: number
  ): void;

  /**
   * 音乐行评分回调
   * @param internalSongCode - 歌曲内部编码
   * @param linePitchScore - 行音高评分
   * @param cumulativeTotalLinePitchScores - 累计总行音高评分
   * @param performedLineIndex - 已演唱行索引
   * @param performedTotalLines - 总演唱行数
   */
  onMusicLineScore?(
    internalSongCode: bigint,
    linePitchScore: number,
    cumulativeTotalLinePitchScores: number,
    performedLineIndex: number,
    performedTotalLines: number
  ): void;

  /**
   * 音乐开始播放回调
   */
  onMusicPlaying?(): void;

  /**
   * 音乐停止播放回调
   */
  onMusicStop?(): void;

  /**
   * 音乐播放错误回调
   * @param error - 错误码
   */
  onMusicError?(error: number): void;
}
