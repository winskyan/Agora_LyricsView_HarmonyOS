/**
 * 应用常量定义
 */
export class Constants {
  /** 日志域 */
  static readonly LOG_DOMAIN = 0x0000;

  /** 应用标签 */
  static readonly APP_TAG = 'LyricsViewApp';

  /** 播放相关常量 */
  static readonly PLAYBACK = {
    /** 定时器间隔 (ms) */
    TIMER_INTERVAL: 20,
    /** 最大播放时长 (ms) - 3分钟 */
    MAX_DURATION: 180000,
    /** 最大 Pitch 变化幅度 */
    MAX_PITCH_CHANGE: 10,
    /** 默认 Pitch 值 */
    DEFAULT_PITCH: 50
  };

  /** UI 相关常量 */
  static readonly UI = {
    /** 默认字体大小 */
    DEFAULT_FONT_SIZE: 16,
    /** 当前行字体大小 */
    CURRENT_LINE_FONT_SIZE: 20,
    /** 行间距 */
    LINE_SPACING: 15,
    /** 内边距 */
    PADDING_TOP: 15
  };

  /** 颜色常量 */
  static readonly COLORS = {
    /** 当前行文字颜色 */
    CURRENT_LINE_TEXT: '#FFFF00',
    /** 当前行高亮颜色 */
    CURRENT_LINE_HIGHLIGHTED: '#FFF44336',
    /** 已唱行颜色 */
    PREVIOUS_LINE_TEXT: '#FFFFFF',
    /** 未唱行颜色 */
    UPCOMING_LINE_TEXT: '#FFFFFF',
    /** 前奏指示器颜色 */
    PRELUDE_INDICATOR: '#FF6B35',
    /** 背景颜色 */
    BACKGROUND: '#F5F5F5',
    /** 播放按钮颜色 */
    PLAY_BUTTON: '#4CAF50',
    /** 暂停按钮颜色 */
    PAUSE_BUTTON: '#FF9800',
    /** 错误文字颜色 */
    ERROR_TEXT: '#FF5722'
  };

  /** 文件相关常量 */
  static readonly FILES = {
    /** 歌词目录名 */
    LYRICS_DIR: 'lyrics',
    /** 默认歌词文件 */
    DEFAULT_LYRIC_FILE: '6091274963611321451.krc',
    /** 默认音调文件 */
    DEFAULT_PITCH_FILE: '6091274963611321451.pitch'
  };

  /** 歌曲列表 */
  static readonly SONG_LIST = ['十年', '月亮代表我的心', '童话'];
}
