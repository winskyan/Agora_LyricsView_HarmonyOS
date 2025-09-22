import { ConsoleLogger } from './ConsoleLogger';
import { LogLevel } from './LogLevel';
import { ILogger } from './ILogger';

/**
 * 日志管理器
 * 基于 Agora-LoggingService 的 LogManager 实现
 * 使用单例模式进行异步日志处理
 */
export class LogManager {
  private static instance: LogManager | null = null;
  private readonly loggers: Map<ILogger, number> = new Map();

  private constructor() {
    // 私有构造函数，确保单例模式
  }

  /**
   * 获取单例实例
   */
  static getInstance(): LogManager {
    if (LogManager.instance !== null) {
      return LogManager.instance;
    }

    // 双重检查锁定
    if (LogManager.instance === null) {
      LogManager.instance = new LogManager();
    }

    return LogManager.instance;
  }

  /**
   * 输出警告级别日志
   */
  warn(tag: string, message: string): void {
    this.log(LogLevel.WARN, tag, message);
  }

  /**
   * 输出信息级别日志
   */
  info(tag: string, message: string): void {
    this.log(LogLevel.INFO, tag, message);
  }

  /**
   * 输出调试级别日志
   */
  debug(tag: string, message: string): void {
    this.log(LogLevel.DEBUG, tag, message);
  }

  /**
   * 输出错误级别日志
   */
  error(tag: string, message: string): void {
    this.log(LogLevel.ERROR, tag, message);
  }

  /**
   * 输出详细级别日志
   */
  verbose(tag: string, message: string): void {
    this.log(LogLevel.VERBOSE, tag, message);
  }

  /**
   * 输出指定级别的日志
   */
  private log(level: number, tag: string, message: string): void {
    // 使用 setTimeout 实现异步日志处理，避免阻塞主线程
    setTimeout(() => {
      this.executeLogSync(level, tag, message);
    }, 0);
  }

  /**
   * 同步执行日志输出
   */
  private executeLogSync(level: number, tag: string, message: string): void {
    for (const logger of this.loggers.keys()) {
      try {
        logger.onLog(level, tag, message);
      } catch (error) {
        console.error('LogManager', `Logger execution failed: ${error}`);
      }
    }
  }

  /**
   * 添加日志记录器
   */
  addLogger(logger: ILogger): void {
    if (!logger) {
      throw new Error('Logger must not be null');
    }

    if (this.loggers.has(logger)) {
      return;
    }

    // 如果是 ConsoleLogger，检查是否已经存在
    if (logger instanceof ConsoleLogger) {
      for (const existingLogger of this.loggers.keys()) {
        if (existingLogger instanceof ConsoleLogger) {
          return; // 已经存在 ConsoleLogger，不再添加
        }
      }
    }

    const hash = this.getLoggerHash(logger);
    this.loggers.set(logger, hash);
  }

  /**
   * 获取所有日志记录器
   */
  getLoggers(): ILogger[] {
    return Array.from(this.loggers.keys());
  }

  /**
   * 移除日志记录器
   */
  removeLogger(logger: ILogger): void {
    this.loggers.delete(logger);
  }

  /**
   * 移除所有日志记录器
   */
  removeAllLogger(): void {
    this.loggers.clear();
  }

  /**
   * 获取 Logger 的哈希值
   */
  private getLoggerHash(logger: ILogger): number {
    // 简单的哈希实现，基于对象的字符串表示
    const str = logger.constructor.name + JSON.stringify(logger);
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // 转换为32位整数
    }
    return Math.abs(hash);
  }

  /**
   * 销毁日志管理器
   */
  destroy(): void {
    this.removeAllLogger();
    // 日志管理器销毁完成
  }
}
