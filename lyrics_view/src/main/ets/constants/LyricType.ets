/**
 * 歌词类型枚举
 * 对应Android项目中的LyricType
 * Enumeration for different types of lyrics formats supported
 */
export enum LyricType {
  /**
   * LRC format - standard lyrics format with time stamps
   */
  LRC = 'LRC',

  /**
   * XML format - structured lyrics format
   */
  XML = 'XML',

  /**
   * KRC format - karaoke lyrics format with character-level timing
   */
  KRC = 'KRC'
}
