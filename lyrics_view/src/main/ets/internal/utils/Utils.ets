import fs from '@ohos.file.fs';
import { LogUtils } from '../utils/LogUtils';

/**
 * 工具类 - HarmonyOS版本
 * 提供通用的工具方法
 */
export class Utils {
    /**
     * 移除字符串开头的BOM标记
     * @param str 输入字符串
     * @returns 移除BOM后的字符串
     */
    static removeStringBom(str: string): string {
        if (str.charCodeAt(0) === 0xFEFF) {
            return str.slice(1);
        }
        return str;
    }

    /**
     * 移除字符串两端的引号
     * @param str 输入字符串
     * @returns 移除引号后的字符串
     */
    static removeQuotes(str: string): string {
        if (!str) return str;
        if ((str.startsWith('"') && str.endsWith('"')) ||
            (str.startsWith("'") && str.endsWith("'"))) {
            return str.slice(1, -1);
        }
        return str;
    }

    /**
     * 读取文件字节数据
     * @param filePath 文件路径
     * @returns 文件字节数组，如果读取失败返回null
     */
    static getFileBytes(filePath: string): Uint8Array | null {
        try {
            // 检查文件路径是否有效
            if (!filePath || filePath.trim().length === 0) {
                LogUtils.e('getFileBytes: filePath is empty');
                return null;
            }

            // 检查文件是否存在
            if (!fs.accessSync(filePath)) {
                LogUtils.e(`getFileBytes: file does not exist: ${filePath}`);
                return null;
            }

            // 获取文件状态信息
            const stat = fs.statSync(filePath);
            if (!stat.isFile()) {
                LogUtils.e(`getFileBytes: path is not a file: ${filePath}`);
                return null;
            }

            // 检查文件大小
            const fileSize = stat.size;
            if (fileSize <= 0) {
                LogUtils.w(`getFileBytes: file is empty: ${filePath}`);
                return new Uint8Array(0);
            }

            // 打开文件
            const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);

            try {
                // 创建缓冲区
                const buffer = new ArrayBuffer(fileSize);

                // 读取文件内容
                const readSize = fs.readSync(file.fd, buffer);

                if (readSize !== fileSize) {
                    LogUtils.w(`getFileBytes: read size (${readSize}) != file size (${fileSize})`);
                }

                // 转换为Uint8Array
                const uint8Array = new Uint8Array(buffer, 0, readSize);

                LogUtils.d(`getFileBytes: successfully read ${readSize} bytes from ${filePath}`);
                return uint8Array;

            } finally {
                // 确保文件被关闭
                fs.closeSync(file);
            }

        } catch (error) {
            LogUtils.e(`getFileBytes error for path ${filePath}: ${error}`);
            return null;
        }
    }

    /**
     * 异步读取文件字节数据
     * @param filePath 文件路径
     * @returns Promise<Uint8Array | null> 文件字节数组，如果读取失败返回null
     */
    static async getFileBytesAsync(filePath: string): Promise<Uint8Array | null> {
        try {
            // 检查文件路径是否有效
            if (!filePath || filePath.trim().length === 0) {
                LogUtils.e('getFileBytesAsync: filePath is empty');
                return null;
            }

            // 检查文件是否存在
            const exists = await fs.access(filePath).then(() => true).catch(() => false);
            if (!exists) {
                LogUtils.e(`getFileBytesAsync: file does not exist: ${filePath}`);
                return null;
            }

            // 获取文件状态信息
            const stat = await fs.stat(filePath);
            if (!stat.isFile()) {
                LogUtils.e(`getFileBytesAsync: path is not a file: ${filePath}`);
                return null;
            }

            // 检查文件大小
            const fileSize = stat.size;
            if (fileSize <= 0) {
                LogUtils.w(`getFileBytesAsync: file is empty: ${filePath}`);
                return new Uint8Array(0);
            }

            // 打开文件
            const file = await fs.open(filePath, fs.OpenMode.READ_ONLY);

            try {
                // 创建缓冲区
                const buffer = new ArrayBuffer(fileSize);

                // 读取文件内容
                const readResult = await fs.read(file.fd, buffer);
                const readSize = readResult.bytesRead;

                if (readSize !== fileSize) {
                    LogUtils.w(`getFileBytesAsync: read size (${readSize}) != file size (${fileSize})`);
                }

                // 转换为Uint8Array
                const uint8Array = new Uint8Array(buffer, 0, readSize);

                LogUtils.d(`getFileBytesAsync: successfully read ${readSize} bytes from ${filePath}`);
                return uint8Array;

            } finally {
                // 确保文件被关闭
                await fs.close(file);
            }

        } catch (error) {
            LogUtils.e(`getFileBytesAsync error for path ${filePath}: ${error}`);
            return null;
        }
    }
}
