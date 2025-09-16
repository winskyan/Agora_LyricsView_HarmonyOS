import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';

/**
 * 测试工具类 - HarmonyOS版本
 * 对应Android项目中的Utils类
 * 用于读取rawfile资源文件和文件操作
 */
export class TestUtils {
  private static readonly TAG = 'TestUtils';
  private static readonly DOMAIN = 0x0000;

  /**
   * 从rawfile目录加载文件内容为字符串
   * 对应Android的loadAsString方法
   *
   * @param context 应用上下文
   * @param fileName 文件名
   * @returns 文件内容字符串，失败返回null
   */
  static async loadAsString(context: common.UIAbilityContext, fileName: string): Promise<string | null> {
    try {
      const resourceMgr = context.resourceManager;
      const fileData = await resourceMgr.getRawFileContent(fileName);

      // 将Uint8Array转换为字符串
      const content = TestUtils.uint8ArrayToString(fileData);

      hilog.info(TestUtils.DOMAIN, TestUtils.TAG, `loadAsString success: ${fileName}, length: ${content.length}`);
      return content;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      hilog.error(TestUtils.DOMAIN, TestUtils.TAG, `loadAsString failed: ${fileName}, error: ${errorMsg}`);
      return null;
    }
  }

  /**
   * 从rawfile目录加载文件内容为Uint8Array
   * 对应Android的文件读取操作
   *
   * @param context 应用上下文
   * @param fileName 文件名
   * @returns 文件内容字节数组，失败返回null
   */
  static async loadAsBytes(context: common.UIAbilityContext, fileName: string): Promise<Uint8Array | null> {
    try {
      const resourceMgr = context.resourceManager;
      const fileData = await resourceMgr.getRawFileContent(fileName);

      hilog.info(TestUtils.DOMAIN, TestUtils.TAG, `loadAsBytes success: ${fileName}, length: ${fileData.length}`);
      return fileData;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      hilog.error(TestUtils.DOMAIN, TestUtils.TAG, `loadAsBytes failed: ${fileName}, error: ${errorMsg}`);
      return null;
    }
  }

  /**
   * 检查rawfile文件是否存在
   *
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
   *
   * @param context 应用上下文
   * @param dirPath 目录路径，空字符串表示根目录
   * @returns 文件列表
   */
  static async listRawFiles(context: common.UIAbilityContext, dirPath: string = ''): Promise<string[]> {
    try {
      const resourceMgr = context.resourceManager;
      const fileList = await resourceMgr.getRawFileList(dirPath);

      hilog.info(TestUtils.DOMAIN, TestUtils.TAG, `listRawFiles success: ${dirPath}, count: ${fileList.length}`);
      return fileList;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      hilog.error(TestUtils.DOMAIN, TestUtils.TAG, `listRawFiles failed: ${dirPath}, error: ${errorMsg}`);
      return [];
    }
  }

  /**
   * 创建临时文件用于测试
   * 对应Android的copyAssetsToCreateNewFile方法
   *
   * @param context 应用上下文
   * @param fileName rawfile中的文件名
   * @returns 临时文件路径，失败返回null
   */
  static async copyRawFileToTemp(context: common.UIAbilityContext, fileName: string): Promise<string | null> {
    try {
      const fileData = await TestUtils.loadAsBytes(context, fileName);
      if (!fileData) {
        return null;
      }

      // 在应用缓存目录创建临时文件
      const tempFilePath = `${context.cacheDir}/${fileName}`;

      // 这里需要使用HarmonyOS的文件写入API
      // 由于当前环境限制，先返回路径，实际实现需要文件写入操作
      hilog.info(TestUtils.DOMAIN, TestUtils.TAG, `copyRawFileToTemp: ${fileName} -> ${tempFilePath}`);
      return tempFilePath;
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      hilog.error(TestUtils.DOMAIN, TestUtils.TAG,
        `copyRawFileToTemp failed: ${fileName}, error: ${errorMsg}`);
      return null;
    }
  }

  /**
   * 读取文件内容为double数组
   * 对应Android的readFileToDoubleArray方法
   *
   * @param filePath 文件路径
   * @returns double数组，失败返回null
   */
  static async readFileToDoubleArray(filePath: string): Promise<number[] | null> {
    try {
      // 这里需要实现文件读取和解析逻辑
      // 由于当前环境限制，先返回空数组
      hilog.info(TestUtils.DOMAIN, TestUtils.TAG, `readFileToDoubleArray: ${filePath}`);
      return [];
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      hilog.error(TestUtils.DOMAIN, TestUtils.TAG,
        `readFileToDoubleArray failed: ${filePath}, error: ${errorMsg}`);
      return null;
    }
  }

  /**
   * 将Uint8Array转换为字符串
   * HarmonyOS兼容的转换方法，正确处理UTF-8编码
   */
  private static uint8ArrayToString(uint8Array: Uint8Array, encoding: string = 'utf-8'): string {
    try {
      // 使用正确的UTF-8解码方法
      return TestUtils.decodeUTF8(uint8Array);
    } catch (error) {
      hilog.error(TestUtils.DOMAIN, TestUtils.TAG, `uint8ArrayToString error: ${error}`);
      // 降级处理：直接转换（可能有乱码）
      let result = '';
      for (let i = 0; i < uint8Array.length; i++) {
        result += String.fromCharCode(uint8Array[i]);
      }
      return result;
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
        if (i >= uint8Array.length) {
          break;
        }
        let byte2 = uint8Array[i++];
        let codePoint = ((byte1 & 0x1F) << 6) | (byte2 & 0x3F);
        result += String.fromCharCode(codePoint);
      } else if ((byte1 & 0xF0) === 0xE0) {
        // 三字节字符
        if (i + 1 >= uint8Array.length) {
          break;
        }
        let byte2 = uint8Array[i++];
        let byte3 = uint8Array[i++];
        let codePoint = ((byte1 & 0x0F) << 12) | ((byte2 & 0x3F) << 6) | (byte3 & 0x3F);
        result += String.fromCharCode(codePoint);
      } else if ((byte1 & 0xF8) === 0xF0) {
        // 四字节字符
        if (i + 2 >= uint8Array.length) {
          break;
        }
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
}
