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
   * 当前的控制台日志记录器实例
   * Current console logger instance
   */
  private static currentConsoleLogger: ConsoleLogger | null = null;
  /**
   * 当前的文件日志记录器实例
   * Current file logger instance
   */
  private static currentFileLogger: FileLogger | null = null;
  /**
   * 当前文件日志路径
   * Current file log path
   */
  private static currentLogFilePath: string | null = null;

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
  private static initializeLogger(
    enableConsoleLog: boolean = true,
    enableFileLog: boolean = true,
    logFilePath?: string
  ): void {
    if (LogUtils.initialized) {
      LogUtils.i('Logger system already initialized');
      return;
    }

    try {
      // 清空现有的日志记录器和状态
      LogUtils.logManager.removeAllLogger();
      LogUtils.currentConsoleLogger = null;
      LogUtils.currentFileLogger = null;
      LogUtils.currentLogFilePath = null;

      // 添加控制台日志记录器
      if (enableConsoleLog) {
        LogUtils.currentConsoleLogger = new ConsoleLogger(Constants.DOMAIN);
        LogUtils.logManager.addLogger(LogUtils.currentConsoleLogger);
      }

      // 添加文件日志记录器
      if (enableFileLog) {
        const finalLogPath = LogUtils.getLogFilePath(logFilePath);

        LogUtils.currentFileLogger = new FileLogger(
          finalLogPath, // 日志文件路径
          Constants.LOG_FILE_NAME, // 文件名前缀
          1024 * 1024 * 2, // 最大文件大小 2MB
          5, // 最大文件数量
          []// 支持所有标签
        );

        // 添加项目相关标签
        LogUtils.currentFileLogger.addSupportTag('LyricsView');
        LogUtils.currentFileLogger.addSupportTag('KaraokeView');
        LogUtils.currentFileLogger.addSupportTag('ScoreView');
        LogUtils.currentFileLogger.addSupportTag('AIAlgorithm');

        LogUtils.logManager.addLogger(LogUtils.currentFileLogger);
        LogUtils.currentLogFilePath = finalLogPath;
        LogUtils.i(`File logger initialized with path: ${finalLogPath}`);
      }

      LogUtils.initialized = true;
      LogUtils.i(`Logger system initialized with ${LogUtils.logManager.getLoggers().length} loggers`);
    } catch (error) {
      hilog.error(Constants.DOMAIN, Constants.TAG, `Failed to initialize logger: ${error}`);
    }
  }

  /**
   * 启用日志功能（支持动态更新配置）
   * Enable logging functionality (supports dynamic configuration updates)
   * @param enableConsoleLog 是否启用控制台日志
   * @param enableFileLog 是否启用文件日志
   * @param logFilePath 日志文件路径（可选，为空时使用默认路径）
   */
  static enableLog(enableConsoleLog: boolean, enableFileLog: boolean, logFilePath?: string): void {
    try {
      // 如果是第一次调用，进行初始化
      if (!LogUtils.initialized) {
        LogUtils.initializeLogger(enableConsoleLog, enableFileLog, logFilePath);
        return;
      }

      // 动态更新控制台日志记录器
      LogUtils.updateConsoleLogger(enableConsoleLog);

      // 动态更新文件日志记录器
      LogUtils.updateFileLogger(enableFileLog, logFilePath);

      LogUtils.i(`Logger configuration updated: console=${enableConsoleLog}, file=${enableFileLog}, path=${logFilePath ||
        'default'}`);
    } catch (error) {
      console.error('LogUtils', `Failed to enable log: ${error}`);
      hilog.error(Constants.DOMAIN, Constants.TAG, `Failed to enable log: ${error}`);
    }
  }

  /**
   * 更新控制台日志记录器
   * Update console logger
   * @param enable 是否启用控制台日志
   */
  private static updateConsoleLogger(enable: boolean): void {
    if (enable) {
      // 如果需要启用且当前没有控制台日志记录器
      if (!LogUtils.currentConsoleLogger) {
        LogUtils.currentConsoleLogger = new ConsoleLogger(Constants.DOMAIN);
        LogUtils.logManager.addLogger(LogUtils.currentConsoleLogger);
        LogUtils.d('Console logger enabled');
      }
    } else {
      // 如果需要禁用且当前有控制台日志记录器
      if (LogUtils.currentConsoleLogger) {
        LogUtils.logManager.removeLogger(LogUtils.currentConsoleLogger);
        LogUtils.currentConsoleLogger = null;
        console.log('LogUtils: Console logger disabled');
      }
    }
  }

  /**
   * 更新文件日志记录器
   * Update file logger
   * @param enable 是否启用文件日志
   * @param logFilePath 日志文件路径
   */
  private static updateFileLogger(enable: boolean, logFilePath?: string): void {
    if (enable) {
      const finalLogPath = LogUtils.getLogFilePath(logFilePath);

      // 如果路径发生变化或者当前没有文件日志记录器，需要重新创建
      if (!LogUtils.currentFileLogger || LogUtils.currentLogFilePath !== finalLogPath) {
        // 移除旧的文件日志记录器
        if (LogUtils.currentFileLogger) {
          LogUtils.logManager.removeLogger(LogUtils.currentFileLogger);
        }

        // 创建新的文件日志记录器
        LogUtils.currentFileLogger = new FileLogger(
          finalLogPath,
          Constants.LOG_FILE_NAME,
          1024 * 1024 * 2, // 2MB
          5, // 最大文件数量
          []// 支持所有标签
        );

        // 添加项目相关标签
        LogUtils.currentFileLogger.addSupportTag('LyricsView');
        LogUtils.currentFileLogger.addSupportTag('KaraokeView');
        LogUtils.currentFileLogger.addSupportTag('ScoreView');
        LogUtils.currentFileLogger.addSupportTag('AIAlgorithm');

        LogUtils.logManager.addLogger(LogUtils.currentFileLogger);
        LogUtils.currentLogFilePath = finalLogPath;
        LogUtils.i(`File logger updated with path: ${finalLogPath}`);
      }
    } else {
      // 如果需要禁用且当前有文件日志记录器
      if (LogUtils.currentFileLogger) {
        LogUtils.logManager.removeLogger(LogUtils.currentFileLogger);
        LogUtils.currentFileLogger = null;
        LogUtils.currentLogFilePath = null;
        console.log('LogUtils: File logger disabled');
      }
    }
  }

  /**
   * 销毁日志系统（兼容Android版本接口）
   * Destroy logging system (compatible with Android version interface)
   */
  static destroy(): void {
    try {
      // 记录销毁日志（在销毁前）
      if (LogUtils.initialized) {
        LogUtils.i('Destroying LogUtils system');
      }

      // 清理日志记录器状态
      LogUtils.currentConsoleLogger = null;
      LogUtils.currentFileLogger = null;
      LogUtils.currentLogFilePath = null;

      // 销毁日志管理器
      LogUtils.logManager.destroy();

      // 重置初始化状态
      LogUtils.initialized = false;

      console.log('LogUtils: System destroyed successfully');
    } catch (error) {
      console.error('LogUtils', `Error during destroy: ${error}`);
    }
  }

  /**
   * 重置日志系统（完全重新初始化）
   * Reset logging system (complete reinitialization)
   * @param enableConsoleLog 是否启用控制台日志
   * @param enableFileLog 是否启用文件日志
   * @param logFilePath 日志文件路径
   */
  static reset(enableConsoleLog: boolean = true, enableFileLog: boolean = true, logFilePath?: string): void {
    LogUtils.destroy();
    LogUtils.enableLog(enableConsoleLog, enableFileLog, logFilePath);
  }
}
