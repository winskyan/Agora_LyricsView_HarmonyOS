import hilog from '@ohos.hilog';
import { ILogger } from './ILogger';
import { LogLevel } from './LogLevel';

/**
 * 控制台日志记录器
 * 基于 Agora-LoggingService 的 ConsoleLogger 实现
 * 使用 HarmonyOS hilog 输出到控制台
 */
export class ConsoleLogger implements ILogger {
  /**
   * 日志域标识
   */
  private readonly domain: number;

  constructor(domain: number = 0x1001) {
    this.domain = domain;
  }

  onLog(level: number, tag: string, message: string): void {
    switch (level) {
      case LogLevel.DEBUG:
        hilog.debug(this.domain, tag, message);
        break;
      case LogLevel.ERROR:
        hilog.error(this.domain, tag, message);
        break;
      case LogLevel.INFO:
        hilog.info(this.domain, tag, message);
        break;
      case LogLevel.WARN:
        hilog.warn(this.domain, tag, message);
        break;
      case LogLevel.VERBOSE:
        hilog.debug(this.domain, tag, message); // HarmonyOS 没有 verbose，使用 debug
        break;
      default:
        hilog.info(this.domain, tag, message);
        break;
    }
  }
}
