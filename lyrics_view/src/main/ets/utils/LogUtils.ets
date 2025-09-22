import Context from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import { Constants } from '../constants/Constants';
import { ConsoleLogger, FileLogger, LogManager } from '../internal/logs';

/**
 * 日志工具类 - HarmonyOS版本
 * 对应Android项目中的LogUtils
 * 集成了新的日志管理系统，支持控制台和文件双重输出
 */
export class LogUtils {
  /**
   * 新的日志管理器实例
   * New log manager instance
   */
  private static logManager: LogManager = LogManager.getInstance();
  /**
   * 日志系统是否已初始化
   * Whether the logging system has been initialized
   */
  private static initialized: boolean = false;

  /**
   * 输出调试级别日志
   * Output debug level log
   * @param msg 日志消息
   * @param args 格式化参数
   */
  static d(msg: string, ...args: (string | number | boolean)[]): void {
    // 使用新的日志管理器
    LogUtils.logManager.debug(Constants.TAG, msg);

  }

  /**
   * 输出信息级别日志
   * Output info level log
   * @param msg 日志消息
   * @param args 格式化参数
   */
  static i(msg: string, ...args: (string | number | boolean)[]): void {
    // 使用新的日志管理器
    LogUtils.logManager.info(Constants.TAG, msg);
  }

  /**
   * 输出警告级别日志
   * Output warning level log
   * @param msg 日志消息
   * @param args 格式化参数
   */
  static w(msg: string, ...args: (string | number | boolean)[]): void {
    // 使用新的日志管理器
    LogUtils.logManager.warn(Constants.TAG, msg);
  }

  /**
   * 输出错误级别日志
   * Output error level log
   * @param msg 日志消息
   * @param args 格式化参数
   */
  static e(msg: string, ...args: (string | number | boolean)[]): void {
    // 使用新的日志管理器
    LogUtils.logManager.error(Constants.TAG, msg);
  }

  /**
   * 获取日志文件路径
   * Get log file path
   * @param customPath 自定义路径（可选）
   * @returns 日志文件路径
   */
  private static getLogFilePath(customPath?: string): string {
    // 如果指定了自定义路径，直接使用
    if (customPath) {
      return customPath;
    }

    // 如果没有context，使用默认路径
    // 优先使用应用私有文件目录的标准路径
    const defaultLogPath: string = '/data/storage/el2/base/haps/entry/files/logs';

    console.info('LogUtils', `Using default log path: ${defaultLogPath}`);
    console.warn('LogUtils',
      'No context provided, using default path. Consider passing context for better path resolution.');
    return defaultLogPath;
  }

  /**
   * 初始化日志系统
   * Initialize logging system
   * @param enableConsoleLog 是否启用控制台日志
   * @param enableFileLog 是否启用文件日志
   * @param logFilePath 日志文件路径（可选）
   */
  static initializeLogger(
    enableConsoleLog: boolean = true,
    enableFileLog: boolean = true,
    logFilePath?: string
  ): void {
    if (LogUtils.initialized) {
      LogUtils.i('Logger system already initialized');
      return;
    }

    try {
      // 清空现有的日志记录器
      LogUtils.logManager.removeAllLogger();

      // 添加控制台日志记录器
      if (enableConsoleLog) {
        const consoleLogger = new ConsoleLogger(Constants.DOMAIN);
        LogUtils.logManager.addLogger(consoleLogger);
      }

      // 添加文件日志记录器
      if (enableFileLog) {
        const finalLogPath = LogUtils.getLogFilePath(logFilePath);

        const fileLogger = new FileLogger(
          finalLogPath, // 日志文件路径
          Constants.LOG_FILE_NAME, // 文件名前缀
          1024 * 1024 * 2, // 最大文件大小 2MB
          5, // 最大文件数量
          []// 支持所有标签
        );

        // 添加项目相关标签
        fileLogger.addSupportTag('LyricsView');
        fileLogger.addSupportTag('KaraokeView');
        fileLogger.addSupportTag('ScoreView');
        fileLogger.addSupportTag('AIAlgorithm');

        LogUtils.logManager.addLogger(fileLogger);
        LogUtils.i(`File logger initialized with path: ${finalLogPath}`);
      }

      LogUtils.initialized = true;
      LogUtils.i(`Logger system initialized with ${LogUtils.logManager.getLoggers().length} loggers`);
    } catch (error) {
      hilog.error(Constants.DOMAIN, Constants.TAG, `Failed to initialize logger: ${error}`);
    }
  }

  /**
   * 启用日志功能（兼容Android版本接口）
   * Enable logging functionality (compatible with Android version interface)
   * @param enableLog 是否启用日志
   * @param saveLogFile 是否保存日志文件
   * @param logFilePath 日志文件路径（可选，为空时自动生成）
   */
  static enableLog(enableLog: boolean, saveLogFile: boolean, logFilePath?: string): void {
    // 调用新的初始化方法
    LogUtils.initializeLogger(enableLog, saveLogFile, logFilePath);
  }

  /**
   * 检查日志系统是否已初始化
   * Check if logging system is initialized
   */
  static isInitialized(): boolean {
    return LogUtils.initialized;
  }

  /**
   * 销毁日志系统（兼容Android版本接口）
   * Destroy logging system (compatible with Android version interface)
   */
  static destroy(): void {
    LogUtils.logManager.destroy();
    LogUtils.initialized = false;
    LogUtils.i('LogUtils destroyed');
  }
}
