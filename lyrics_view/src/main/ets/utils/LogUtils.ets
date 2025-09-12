import { Context } from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';

/**
 * 日志工具类 - HarmonyOS版本
 * 对应Android项目中的LogUtils
 * Provides logging functionality using HarmonyOS hilog system
 */
export class LogUtils {
    /**
     * 日志域标识 - 歌词视图模块
     * Log domain identifier for LyricsView module
     * 0x1001 = 4097 (decimal) - Custom domain for lyrics functionality
     */
    private static readonly DOMAIN = 0x1001;

    /**
     * 日志标签
     * Log tag for identifying the module
     */
    private static readonly TAG = 'LyricsView';

    /**
     * 输出调试级别日志
     * Output debug level log
     * @param msg 日志消息
     * @param args 格式化参数
     */
    static d(msg: string, ...args: any[]): void {
        hilog.debug(LogUtils.DOMAIN, LogUtils.TAG, msg, ...args);
    }

    /**
     * 输出信息级别日志
     * Output info level log
     * @param msg 日志消息
     * @param args 格式化参数
     */
    static i(msg: string, ...args: any[]): void {
        hilog.info(LogUtils.DOMAIN, LogUtils.TAG, msg, ...args);
    }

    /**
     * 输出警告级别日志
     * Output warning level log
     * @param msg 日志消息
     * @param args 格式化参数
     */
    static w(msg: string, ...args: any[]): void {
        hilog.warn(LogUtils.DOMAIN, LogUtils.TAG, msg, ...args);
    }

    /**
     * 输出错误级别日志
     * Output error level log
     * @param msg 日志消息
     * @param args 格式化参数
     */
    static e(msg: string, ...args: any[]): void {
        hilog.error(LogUtils.DOMAIN, LogUtils.TAG, msg, ...args);
    }

    /**
     * 启用日志功能（兼容Android版本接口）
     * Enable logging functionality (compatible with Android version interface)
     * @param context 应用上下文
     * @param enableLog 是否启用日志
     * @param saveLogFile 是否保存日志文件
     * @param logFilePath 日志文件路径（可选，为空时自动生成）
     */
    static enableLog(context: Context | null, enableLog: boolean, saveLogFile: boolean, logFilePath?: string): void {
        let finalLogPath = logFilePath;

        // 如果没有提供路径且需要保存文件，则自动生成路径
        if (saveLogFile && !logFilePath && context) {
            try {
                // HarmonyOS获取应用私有文件目录（类似Android的getExternalFilesDir）
                finalLogPath = `${context.filesDir}/lyrics.log`;
            } catch (error) {
                LogUtils.w(`Failed to get files directory: ${error}`);
                finalLogPath = 'lyrics.log'; // 降级到相对路径
            }
        }

        // HarmonyOS中hilog默认启用，此方法保持接口兼容性
        LogUtils.i(`enableLog called with enableLog:${enableLog}, saveLogFile:${saveLogFile}, logFilePath:${finalLogPath}`);
    }

    /**
     * 添加自定义日志记录器（兼容Android版本接口）
     * Add custom logger (compatible with Android version interface)
     * @param logger 日志记录器
     */
    static addLogger(logger: any): void {
        LogUtils.i('addLogger not implemented in HarmonyOS version');
    }

    /**
     * 移除自定义日志记录器（兼容Android版本接口）
     * Remove custom logger (compatible with Android version interface)
     * @param logger 日志记录器
     */
    static removeLogger(logger: any): void {
        LogUtils.i('removeLogger not implemented in HarmonyOS version');
    }

    /**
     * 销毁日志系统（兼容Android版本接口）
     * Destroy logging system (compatible with Android version interface)
     */
    static destroy(): void {
        LogUtils.i('destroy not implemented in HarmonyOS version');
    }
}
