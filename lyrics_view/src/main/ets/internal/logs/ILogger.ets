/**
 * 日志记录器接口
 * 基于 Agora-LoggingService 的 Logger 接口
 */
export interface ILogger {
  /**
   * 分发日志消息到目标处理器
   * 此方法不应该阻塞
   *
   * @param level 日志级别
   * @param tag 日志标签
   * @param message 日志消息
   */
  onLog(level: number, tag: string, message: string): void;
}
