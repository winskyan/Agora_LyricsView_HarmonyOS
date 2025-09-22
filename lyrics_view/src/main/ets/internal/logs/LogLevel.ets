/**
 * 日志级别定义
 * 对应 Android Log 类的级别定义
 */
export enum LogLevel {
  VERBOSE = 2,
  DEBUG = 3,
  INFO = 4,
  WARN = 5,
  ERROR = 6
}

/**
 * 日志级别工具类
 */
export class LogLevelUtils {
  /**
   * 获取日志级别名称
   * @param logLevel 日志级别
   * @returns 级别名称字符串
   */
  static getLevelName(logLevel: number): string {
    switch (logLevel) {
      case LogLevel.VERBOSE:
        return "V";
      case LogLevel.DEBUG:
        return "D";
      case LogLevel.INFO:
        return "I";
      case LogLevel.WARN:
        return "W";
      case LogLevel.ERROR:
        return "E";
      default:
        if (logLevel < LogLevel.VERBOSE) {
          return `V-${LogLevel.VERBOSE - logLevel}`;
        } else {
          return `E+${logLevel - LogLevel.ERROR}`;
        }
    }
  }
}
