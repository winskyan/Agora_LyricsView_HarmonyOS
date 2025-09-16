import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import { LogUtils } from './LogUtils';

/**
 * 工具类 - HarmonyOS版本
 * 提供通用的工具方法，包括文件操作、字符串处理、编码转换等
 */
export class Utils {

  // ========== 字符串处理工具 ==========

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

  // ========== 编码转换工具 ==========

  /**
   * 将 Uint8Array 转换为字符串（UTF-8解码）
   * @param uint8Array 字节数组
   * @param encoding 编码格式（默认 utf-8）
   * @returns 转换后的字符串
   */
  static uint8ArrayToString(uint8Array: Uint8Array, encoding: string = 'utf-8'): string {
    try {
      return Utils.decodeUTF8(uint8Array);
    } catch (error) {
      LogUtils.e(`uint8ArrayToString error: ${error}`);
      // 降级方案：逐字节转换（可能有乱码）
      let result = '';
      for (let i = 0; i < uint8Array.length; i++) {
        result += String.fromCharCode(uint8Array[i]);
      }
      return result;
    }
  }

  /**
   * 将字符串转换为 Uint8Array（UTF-8编码）
   * @param str 输入字符串
   * @param encoding 编码格式（默认 utf-8）
   * @returns 转换后的字节数组
   */
  static stringToUint8Array(str: string, encoding: string = 'utf-8'): Uint8Array {
    try {
      return Utils.encodeUTF8(str);
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
   * UTF-8解码方法
   * 正确处理多字节UTF-8字符
   */
  private static decodeUTF8(uint8Array: Uint8Array): string {
    let result = '';
    let i = 0;

    while (i < uint8Array.length) {
      let byte1 = uint8Array[i++];

      if (byte1 < 0x80) {
        // 单字节字符 (ASCII)
        result += String.fromCharCode(byte1);
      } else if ((byte1 & 0xE0) === 0xC0) {
        // 双字节字符
        if (i >= uint8Array.length) break;
        let byte2 = uint8Array[i++];
        let codePoint = ((byte1 & 0x1F) << 6) | (byte2 & 0x3F);
        result += String.fromCharCode(codePoint);
      } else if ((byte1 & 0xF0) === 0xE0) {
        // 三字节字符
        if (i + 1 >= uint8Array.length) break;
        let byte2 = uint8Array[i++];
        let byte3 = uint8Array[i++];
        let codePoint = ((byte1 & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F);
        result += String.fromCharCode(codePoint);
      } else if ((byte1 & 0xF8) === 0xF0) {
        // 四字节字符
        if (i + 2 >= uint8Array.length) break;
        let byte2 = uint8Array[i++];
        let byte3 = uint8Array[i++];
        let byte4 = uint8Array[i++];
        let codePoint = ((byte1 & 0x07) << 18) | ((byte2 & 0x3F) << 12) | ((byte3 & 0x3F) << 6) | (byte4 & 0x3F);

        // 处理超出基本多文种平面的字符
        if (codePoint > 0xFFFF) {
          codePoint -= 0x10000;
          result += String.fromCharCode(0xD800 + (codePoint >> 10));
          result += String.fromCharCode(0xDC00 + (codePoint & 0x3FF));
        } else {
          result += String.fromCharCode(codePoint);
        }
      } else {
        // 无效的UTF-8字节，跳过
        continue;
      }
    }

    return result;
  }

  /**
   * UTF-8编码方法
   * 将字符串编码为UTF-8字节数组
   */
  private static encodeUTF8(str: string): Uint8Array {
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
  }

  // ========== 本地文件操作工具 ==========

  /**
   * 读取本地文件字节数据（同步）
   * @param filePath 文件路径
   * @returns 文件字节数组，如果读取失败返回null
   */
  static getFileBytes(filePath: string): Uint8Array | null {
    try {
      return Utils.readFileSync(filePath);
    } catch (error) {
      LogUtils.e(`getFileBytes error for path ${filePath}: ${error}`);
      return null;
    }
  }

  /**
   * 读取本地文件字节数据（异步）
   * @param filePath 文件路径
   * @returns Promise<Uint8Array | null> 文件字节数组，如果读取失败返回null
   */
  static async getFileBytesAsync(filePath: string): Promise<Uint8Array | null> {
    try {
      return await Utils.readFileAsync(filePath);
    } catch (error) {
      LogUtils.e(`getFileBytesAsync error for path ${filePath}: ${error}`);
      return null;
    }
  }

  /**
   * 读取本地文件内容为字符串（异步）
   * @param filePath 文件路径
   * @returns Promise<string | null> 文件内容字符串，失败返回null
   */
  static async readFileAsString(filePath: string): Promise<string | null> {
    try {
      const bytes = await Utils.readFileAsync(filePath);
      if (!bytes) return null;
      return Utils.uint8ArrayToString(bytes);
    } catch (error) {
      LogUtils.e(`readFileAsString error for path ${filePath}: ${error}`);
      return null;
    }
  }

  /**
   * 同步读取文件的核心实现
   */
  private static readFileSync(filePath: string): Uint8Array | null {
    // 检查文件路径是否有效
    if (!filePath || filePath.trim().length === 0) {
      LogUtils.e('readFileSync: filePath is empty');
      return null;
    }

    // 检查文件是否存在
    if (!fs.accessSync(filePath)) {
      LogUtils.e(`readFileSync: file does not exist: ${filePath}`);
      return null;
    }

    // 获取文件状态信息
    const stat = fs.statSync(filePath);
    if (!stat.isFile()) {
      LogUtils.e(`readFileSync: path is not a file: ${filePath}`);
      return null;
    }

    // 检查文件大小
    const fileSize = stat.size;
    if (fileSize <= 0) {
      LogUtils.w(`readFileSync: file is empty: ${filePath}`);
      return new Uint8Array(0);
    }

    // 打开文件
    const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);

    try {
      // 创建缓冲区并读取文件内容
      const buffer = new ArrayBuffer(fileSize);
      const readSize = fs.readSync(file.fd, buffer);

      if (readSize !== fileSize) {
        LogUtils.w(`readFileSync: read size (${readSize}) != file size (${fileSize})`);
      }

      const uint8Array = new Uint8Array(buffer, 0, readSize);
      LogUtils.d(`readFileSync: successfully read ${readSize} bytes from ${filePath}`);
      return uint8Array;

    } finally {
      // 确保文件被关闭
      fs.closeSync(file.fd);
    }
  }

  /**
   * 异步读取文件的核心实现
   */
  private static async readFileAsync(filePath: string): Promise<Uint8Array | null> {
    // 检查文件路径是否有效
    if (!filePath || filePath.trim().length === 0) {
      LogUtils.e('readFileAsync: filePath is empty');
      return null;
    }

    // 检查文件是否存在
    const exists = await fs.access(filePath).then(() => true).catch(() => false);
    if (!exists) {
      LogUtils.e(`readFileAsync: file does not exist: ${filePath}`);
      return null;
    }

    // 获取文件状态信息
    const stat = await fs.stat(filePath);
    if (!stat.isFile()) {
      LogUtils.e(`readFileAsync: path is not a file: ${filePath}`);
      return null;
    }

    // 检查文件大小
    const fileSize = stat.size;
    if (fileSize <= 0) {
      LogUtils.w(`readFileAsync: file is empty: ${filePath}`);
      return new Uint8Array(0);
    }

    // 打开文件
    const file = await fs.open(filePath, fs.OpenMode.READ_ONLY);

    try {
      // 创建缓冲区并读取文件内容
      const buffer = new ArrayBuffer(fileSize);
      const readSize = await fs.read(file.fd, buffer);

      if (readSize !== fileSize) {
        LogUtils.w(`readFileAsync: read size (${readSize}) != file size (${fileSize})`);
      }

      const uint8Array = new Uint8Array(buffer, 0, readSize);
      LogUtils.d(`readFileAsync: successfully read ${readSize} bytes from ${filePath}`);
      return uint8Array;

    } finally {
      // 确保文件被关闭
      await fs.close(file.fd);
    }
  }

  // ========== rawfile资源文件操作工具 ==========

  /**
   * 从rawfile目录加载文件内容为字符串
   * @param context 应用上下文
   * @param fileName 文件名
   * @returns 文件内容字符串，失败返回null
   */
  static async loadAsString(context: common.UIAbilityContext, fileName: string): Promise<string | null> {
    try {
      const fileData = await Utils.loadAsBytes(context, fileName);
      if (!fileData) return null;

      const content = Utils.uint8ArrayToString(fileData);
      LogUtils.d(`loadAsString success: ${fileName}, length: ${content.length}`);
      return content;
    } catch (error) {
      LogUtils.e(`loadAsString failed: ${fileName}, error: ${error}`);
      return null;
    }
  }

  /**
   * 从rawfile目录加载文件内容为Uint8Array
   * @param context 应用上下文
   * @param fileName 文件名
   * @returns 文件内容字节数组，失败返回null
   */
  static async loadAsBytes(context: common.UIAbilityContext, fileName: string): Promise<Uint8Array | null> {
    try {
      const resourceMgr = context.resourceManager;
      const fileData = await resourceMgr.getRawFileContent(fileName);

      LogUtils.d(`loadAsBytes success: ${fileName}, length: ${fileData.length}`);
      return fileData;
    } catch (error) {
      LogUtils.e(`loadAsBytes failed: ${fileName}, error: ${error}`);
      return null;
    }
  }

  /**
   * 检查rawfile文件是否存在
   * @param context 应用上下文
   * @param fileName 文件名
   * @returns 文件是否存在
   */
  static async fileExists(context: common.UIAbilityContext, fileName: string): Promise<boolean> {
    try {
      const resourceMgr = context.resourceManager;
      await resourceMgr.getRawFileContent(fileName);
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * 获取rawfile文件列表
   * @param context 应用上下文
   * @param dirPath 目录路径，空字符串表示根目录
   * @returns 文件列表
   */
  static async listRawFiles(context: common.UIAbilityContext, dirPath: string = ''): Promise<string[]> {
    try {
      const resourceMgr = context.resourceManager;
      const fileList = await resourceMgr.getRawFileList(dirPath);

      LogUtils.d(`listRawFiles success: ${dirPath}, count: ${fileList.length}`);
      return fileList;
    } catch (error) {
      LogUtils.e(`listRawFiles failed: ${dirPath}, error: ${error}`);
      return [];
    }
  }

  /**
   * 将rawfile文件复制到临时目录
   * @param context 应用上下文
   * @param fileName rawfile中的文件名
   * @returns 临时文件路径，失败返回null
   */
  static async copyRawFileToTemp(context: common.UIAbilityContext, fileName: string): Promise<string | null> {
    try {
      const fileData = await Utils.loadAsBytes(context, fileName);
      if (!fileData) {
        return null;
      }

      // 在应用缓存目录创建临时文件
      const tempFilePath = `${context.cacheDir}/${fileName}`;

      try {
        // 写入文件
        const file = fs.openSync(tempFilePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE);
        fs.writeSync(file.fd, fileData.buffer as ArrayBuffer);
        fs.closeSync(file);

        LogUtils.d(`copyRawFileToTemp success: ${fileName} -> ${tempFilePath}`);
        return tempFilePath;
      } catch (writeError) {
        LogUtils.e(`copyRawFileToTemp write failed: ${fileName}, error: ${writeError}`);
        return null;
      }
    } catch (error) {
      LogUtils.e(`copyRawFileToTemp failed: ${fileName}, error: ${error}`);
      return null;
    }
  }

  // ========== 特殊格式文件处理工具 ==========

  /**
   * 读取文件内容为数字数组
   * 适用于包含数字列表的文本文件
   * @param filePath 文件路径
   * @returns 数字数组，失败返回null
   */
  static async readFileToDoubleArray(filePath: string): Promise<number[] | null> {
    try {
      const content = await Utils.readFileAsString(filePath);
      if (!content) return null;

      const lines = content.split('\n');
      const numbers: number[] = [];

      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed && !isNaN(Number(trimmed))) {
          numbers.push(Number(trimmed));
        }
      }

      LogUtils.d(`readFileToDoubleArray success: ${filePath}, count: ${numbers.length}`);
      return numbers;
    } catch (error) {
      LogUtils.e(`readFileToDoubleArray failed: ${filePath}, error: ${error}`);
      return null;
    }
  }
}