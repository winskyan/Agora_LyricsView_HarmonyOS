import fs from '@ohos.file.fs';
import { LogUtils } from '../../utils/LogUtils';

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
    if (!str) {
      return str;
    }
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
        fs.closeSync(file.fd);
      }

    } catch (error) {
      LogUtils.e(`getFileBytes error for path ${filePath}: ${error}`);
      return null;
    }
  }

  /**
   * 将 Uint8Array 转换为字符串（HarmonyOS 兼容方式）
   * @param uint8Array 字节数组
   * @param encoding 编码格式（默认 utf-8）
   * @returns 转换后的字符串
   */
  static uint8ArrayToString(uint8Array: Uint8Array, encoding: string = 'utf-8'): string {
    try {
      // 方法1：使用 String.fromCharCode（适用于较小的数据）
      if (uint8Array.length < 65536) {
        return String.fromCharCode(...Array.from(uint8Array));
      }

      // 方法2：分块处理大数据
      let result = '';
      const chunkSize = 8192; // 8KB 块大小
      for (let i = 0; i < uint8Array.length; i += chunkSize) {
        const chunk = uint8Array.slice(i, i + chunkSize);
        result += String.fromCharCode(...Array.from(chunk));
      }
      return result;
    } catch (error) {
      LogUtils.e(`uint8ArrayToString error: ${error}`);
      // 降级方案：逐字节转换
      let result = '';
      for (let i = 0; i < uint8Array.length; i++) {
        result += String.fromCharCode(uint8Array[i]);
      }
      return result;
    }
  }

  /**
   * 将字符串转换为 Uint8Array（HarmonyOS 兼容方式）
   * @param str 输入字符串
   * @param encoding 编码格式（默认 utf-8）
   * @returns 转换后的字节数组
   */
  static stringToUint8Array(str: string, encoding: string = 'utf-8'): Uint8Array {
    try {
      // 使用 UTF-8 编码将字符串转换为字节数组
      const bytes: number[] = [];
      for (let i = 0; i < str.length; i++) {
        const charCode = str.charCodeAt(i);

        if (charCode < 0x80) {
          // ASCII 字符 (0-127)
          bytes.push(charCode);
        } else if (charCode < 0x800) {
          // 2 字节 UTF-8
          bytes.push(0xC0 | (charCode >> 6));
          bytes.push(0x80 | (charCode & 0x3F));
        } else if (charCode < 0xD800 || charCode >= 0xE000) {
          // 3 字节 UTF-8 (非代理对)
          bytes.push(0xE0 | (charCode >> 12));
          bytes.push(0x80 | ((charCode >> 6) & 0x3F));
          bytes.push(0x80 | (charCode & 0x3F));
        } else {
          // 4 字节 UTF-8 (代理对)
          if (i + 1 < str.length) {
            const nextCharCode = str.charCodeAt(i + 1);
            if (charCode >= 0xD800 && charCode <= 0xDBFF && nextCharCode >= 0xDC00 && nextCharCode <= 0xDFFF) {
              const codePoint = 0x10000 + ((charCode & 0x3FF) << 10) + (nextCharCode & 0x3FF);
              bytes.push(0xF0 | (codePoint >> 18));
              bytes.push(0x80 | ((codePoint >> 12) & 0x3F));
              bytes.push(0x80 | ((codePoint >> 6) & 0x3F));
              bytes.push(0x80 | (codePoint & 0x3F));
              i++; // 跳过下一个字符（代理对的低位）
            } else {
              // 无效的代理对，使用替换字符
              bytes.push(0xEF, 0xBF, 0xBD);
            }
          } else {
            // 字符串结尾的无效代理字符
            bytes.push(0xEF, 0xBF, 0xBD);
          }
        }
      }

      return new Uint8Array(bytes);
    } catch (error) {
      LogUtils.e(`stringToUint8Array error: ${error}`);
      // 降级方案：简单的字符码转换
      const bytes = new Uint8Array(str.length);
      for (let i = 0; i < str.length; i++) {
        bytes[i] = str.charCodeAt(i) & 0xFF;
      }
      return bytes;
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
        const readSize = await fs.read(file.fd, buffer);

        if (readSize !== fileSize) {
          LogUtils.w(`getFileBytesAsync: read size (${readSize}) != file size (${fileSize})`);
        }

        // 转换为Uint8Array
        const uint8Array = new Uint8Array(buffer, 0, readSize);

        LogUtils.d(`getFileBytesAsync: successfully read ${readSize} bytes from ${filePath}`);
        return uint8Array;

      } finally {
        // 确保文件被关闭
        await fs.close(file.fd);
      }

    } catch (error) {
      LogUtils.e(`getFileBytesAsync error for path ${filePath}: ${error}`);
      return null;
    }
  }
}
