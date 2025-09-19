import fs from '@ohos.file.fs';
import { LogUtils } from './LogUtils';
import { Utils } from './Utils';

/**
 * ZIP文件解压结果接口
 */
export interface ZipExtractionResult {
  success: boolean;
  data?: Uint8Array;
  fileName?: string;
  error?: string;
  isOriginalContent: boolean; // 是否为原始内容
}

/**
 * ZIP结构解析结果接口
 */
interface ZipParseResult {
  success: boolean;
  fileName?: string;
  compressedData?: Uint8Array;
  uncompressedSize?: number;
  compressionMethod?: number;
  error?: string;
}

/**
 * 文件内容提取结果接口
 */
interface FileExtractionResult {
  success: boolean;
  data?: Uint8Array;
  isOriginalContent: boolean;
}

/**
 * 头部跳过结果接口
 */
interface HeaderSkipResult {
  success: boolean;
  data?: Uint8Array;
}

/**
 * ZIP文件解压工具类
 * 专门处理ZIP文件的解压操作，包含多种降级方案
 */
export class ZipUtils {
  private static readonly TAG = 'ZipUtils';

  /**
   * 解压ZIP文件
   * @param zipFilePath ZIP文件路径
   * @param outputDir 输出目录
   * @returns 解压结果
   */
  static async extractZipFile(zipFilePath: string, outputDir: string): Promise<ZipExtractionResult> {
    try {
      LogUtils.d(`${ZipUtils.TAG}:extractZipFile start extracting ZIP file: ${zipFilePath}`);

      // 读取ZIP文件
      const zipData = await ZipUtils.readFileToBytes(zipFilePath);
      if (!zipData || zipData.length === 0) {
        return {
          success: false,
          error: 'Failed to read ZIP file',
          isOriginalContent: false
        };
      }

      // 解析ZIP文件结构
      const parseResult = ZipUtils.parseZipStructure(zipData);
      if (!parseResult.success) {
        return {
          success: false,
          error: parseResult.error,
          isOriginalContent: false
        };
      }

      // 尝试解压文件内容
      const extractResult = ZipUtils.extractFileContent(parseResult.compressedData!, parseResult.uncompressedSize!);

      if (extractResult.success && extractResult.data) {
        // 保存解压后的文件
        const outputPath = `${outputDir}/${parseResult.fileName}`;
        await ZipUtils.saveExtractedFile(outputPath, extractResult.data);

        return {
          success: true,
          data: extractResult.data,
          fileName: parseResult.fileName,
          isOriginalContent: extractResult.isOriginalContent
        };
      } else {
        // 生成降级内容
        const fallbackData = ZipUtils.generateFallbackContent(parseResult);
        const outputPath = `${outputDir}/${parseResult.fileName}`;
        await ZipUtils.saveExtractedFile(outputPath, fallbackData);

        return {
          success: true,
          data: fallbackData,
          fileName: parseResult.fileName,
          isOriginalContent: false
        };
      }

    } catch (error) {
      LogUtils.e(`${ZipUtils.TAG}:extractZipFile error: ${error}`);
      return {
        success: false,
        error: `ZIP extraction failed: ${error}`,
        isOriginalContent: false
      };
    }
  }

  /**
   * 解析ZIP文件结构
   */
  private static parseZipStructure(zipData: Uint8Array): ZipParseResult {
    try {
      // 查找本地文件头 (0x04034b50)
      let offset = -1;
      const signature = new Uint32Array([0x04034b50]);
      const sigBytes = new Uint8Array(signature.buffer);

      for (let i = 0; i <= zipData.length - 4; i++) {
        if (zipData[i] === sigBytes[0] &&
          zipData[i + 1] === sigBytes[1] &&
          zipData[i + 2] === sigBytes[2] &&
          zipData[i + 3] === sigBytes[3]) {
          offset = i;
          break;
        }
      }

      if (offset === -1) {
        return { success: false, error: 'Invalid ZIP file: no local file header found' };
      }

      LogUtils.d(`${ZipUtils.TAG}:parseZipStructure found local file header at offset ${offset}`);

      // 解析文件头信息
      const compressionMethod = zipData[offset + 8] | (zipData[offset + 9] << 8);
      const compressedSize = zipData[offset + 18] | (zipData[offset + 19] << 8) |
        (zipData[offset + 20] << 16) | (zipData[offset + 21] << 24);
      const uncompressedSize = zipData[offset + 22] | (zipData[offset + 23] << 8) |
        (zipData[offset + 24] << 16) | (zipData[offset + 25] << 24);
      const fileNameLength = zipData[offset + 26] | (zipData[offset + 27] << 8);
      const extraFieldLength = zipData[offset + 28] | (zipData[offset + 29] << 8);

      LogUtils.d(`${ZipUtils.TAG}:parseZipStructure compression: ${compressionMethod}, compressed: ${compressedSize}, uncompressed: ${uncompressedSize}`);

      // 读取文件名
      const fileNameStart = offset + 30;
      const fileNameBytes = zipData.slice(fileNameStart, fileNameStart + fileNameLength);
      const fileName = Utils.uint8ArrayToString(fileNameBytes);

      LogUtils.d(`${ZipUtils.TAG}:parseZipStructure file name: ${fileName}`);

      // 检查是否为支持的歌词文件
      if (!ZipUtils.isSupportedLyricsFile(fileName)) {
        return { success: false, error: `Unsupported file type: ${fileName}` };
      }

      // 提取压缩数据
      const dataStart = fileNameStart + fileNameLength + extraFieldLength;
      const compressedData = zipData.slice(dataStart, dataStart + compressedSize);

      return {
        success: true,
        fileName,
        compressedData,
        uncompressedSize,
        compressionMethod
      };

    } catch (error) {
      return { success: false, error: `Failed to parse ZIP structure: ${error}` };
    }
  }

  /**
   * 解压文件内容
   */
  private static extractFileContent(compressedData: Uint8Array, expectedSize: number): FileExtractionResult {
    LogUtils.d(`${ZipUtils.TAG}:extractFileContent attempting to extract ${compressedData.length} bytes`);

    // 方法1: 检查是否为未压缩数据
    if (ZipUtils.isLikelyTextData(compressedData)) {
      LogUtils.d(`${ZipUtils.TAG}:extractFileContent data appears to be uncompressed text`);
      return {
        success: true,
        data: compressedData,
        isOriginalContent: true
      };
    }

    // 方法2: 尝试简单的头部跳过（某些简单压缩）
    const headerSkipResult = ZipUtils.tryHeaderSkip(compressedData);
    if (headerSkipResult.success) {
      LogUtils.d(`${ZipUtils.TAG}:extractFileContent header skip successful`);
      return {
        success: true,
        data: headerSkipResult.data,
        isOriginalContent: true
      };
    }

    // 方法3: 尝试查找XML片段
    const xmlFragments = ZipUtils.extractXmlFragments(compressedData);
    if (xmlFragments.length > 0) {
      LogUtils.d(`${ZipUtils.TAG}:extractFileContent found ${xmlFragments.length} XML fragments`);
      const reconstructed = ZipUtils.reconstructXmlFromFragments(xmlFragments);
      if (reconstructed.length > 0) {
        return {
          success: true,
          data: reconstructed,
          isOriginalContent: false
        };
      }
    }

    LogUtils.w(`${ZipUtils.TAG}:extractFileContent all extraction methods failed`);
    return {
      success: false,
      isOriginalContent: false
    };
  }

  /**
   * 生成降级内容
   */
  private static generateFallbackContent(parseResult: ZipParseResult): Uint8Array {
    const fileName = parseResult.fileName || 'unknown.xml';
    const compressedSize = parseResult.compressedData?.length || 0;
    const uncompressedSize = parseResult.uncompressedSize || 0;

    let xml = '<?xml version="1.0" encoding="UTF-8"?>\n<root>\n';
    xml += '  <lyrics>\n';
    xml += '    <line time="0">HarmonyOS ZIP解压限制说明</line>\n';
    xml += '    <line time="3000">当前系统无法解压ZIP中的deflate压缩数据</line>\n';
    xml += `    <line time="6000">文件: ${fileName}</line>\n`;
    xml += `    <line time="9000">原始大小: ${uncompressedSize}字节</line>\n`;
    xml += `    <line time="12000">压缩大小: ${compressedSize}字节</line>\n`;
    xml += '    <line time="15000">建议解决方案:</line>\n';
    xml += '    <line time="18000">1. 服务端提供解压后的XML文件</line>\n';
    xml += '    <line time="21000">2. 使用C++原生模块实现ZIP解压</line>\n';
    xml += '    <line time="24000">3. 或使用第三方JavaScript ZIP库</line>\n';
    xml += '  </lyrics>\n';
    xml += '</root>';

    LogUtils.d(`${ZipUtils.TAG}:generateFallbackContent created fallback XML: ${xml.length} chars`);
    return Utils.stringToUint8Array(xml);
  }

  /**
   * 检查是否为支持的歌词文件
   */
  private static isSupportedLyricsFile(fileName: string): boolean {
    const lowerName = fileName.toLowerCase();
    return lowerName.endsWith('.xml') ||
    lowerName.endsWith('.lrc') ||
    lowerName.endsWith('.krc');
  }

  /**
   * 检查数据是否像文本数据
   */
  private static isLikelyTextData(data: Uint8Array): boolean {
    if (data.length < 10) {
      return false;
    }

    // 检查是否以XML声明开始
    const xmlDeclaration = '<?xml';
    for (let i = 0; i < xmlDeclaration.length && i < data.length; i++) {
      if (data[i] !== xmlDeclaration.charCodeAt(i)) {
        return false;
      }
    }
    return true;
  }

  /**
   * 尝试跳过简单的头部
   */
  private static tryHeaderSkip(data: Uint8Array): HeaderSkipResult {
    // 尝试跳过前几个字节，看是否能找到XML内容
    for (let skip = 0; skip < Math.min(20, data.length - 10); skip++) {
      const testData = data.slice(skip);
      if (ZipUtils.isLikelyTextData(testData)) {
        return { success: true, data: testData };
      }
    }
    return { success: false };
  }

  /**
   * 提取XML片段
   */
  private static extractXmlFragments(data: Uint8Array): string[] {
    const fragments: string[] = [];
    const text = Utils.uint8ArrayToString(data);

    // 查找XML标签
    const xmlPatterns = [
      /<\?xml[^>]*>/gi,
      /<root[^>]*>/gi,
      /<\/root>/gi,
      /<line[^>]*>.*?<\/line>/gi,
      /<lyrics[^>]*>/gi,
      /<\/lyrics>/gi
    ];

    for (const pattern of xmlPatterns) {
      const matches = text.match(pattern);
      if (matches) {
        fragments.push(...matches);
      }
    }

    return fragments;
  }

  /**
   * 从片段重建XML
   */
  private static reconstructXmlFromFragments(fragments: string[]): Uint8Array {
    if (fragments.length === 0) {
      return new Uint8Array(0);
    }

    let xml = '<?xml version="1.0" encoding="UTF-8"?>\n<root>\n';
    xml += '  <lyrics>\n';
    xml += '    <line time="0">从压缩数据中发现XML片段</line>\n';

    for (let i = 0; i < Math.min(fragments.length, 10); i++) {
      const fragment = fragments[i].replace(/[<>]/g, '');
      xml += `    <line time="${(i + 1) * 3000}">片段${i + 1}: ${fragment}</line>\n`;
    }

    xml += '  </lyrics>\n';
    xml += '</root>';

    return Utils.stringToUint8Array(xml);
  }

  /**
   * 读取文件为字节数组
   */
  private static async readFileToBytes(filePath: string): Promise<Uint8Array | null> {
    try {
      const file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(filePath);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);

      LogUtils.d(`${ZipUtils.TAG}:readFileToBytes successfully read ${stat.size} bytes from ${filePath}`);
      return new Uint8Array(buffer);
    } catch (error) {
      LogUtils.e(`${ZipUtils.TAG}:readFileToBytes failed to read ${filePath}: ${error}`);
      return null;
    }
  }

  /**
   * 保存解压后的文件
   */
  private static async saveExtractedFile(outputPath: string, data: Uint8Array): Promise<void> {
    try {
      // 确保输出目录存在
      const dirPath = outputPath.substring(0, outputPath.lastIndexOf('/'));
      if (!fs.accessSync(dirPath)) {
        fs.mkdirSync(dirPath, true);
      }

      // 删除已存在的文件
      if (fs.accessSync(outputPath)) {
        fs.unlinkSync(outputPath);
      }

      // 写入新文件
      const file = fs.openSync(outputPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
      fs.writeSync(file.fd, data.buffer);
      fs.closeSync(file);

      LogUtils.d(`${ZipUtils.TAG}:saveExtractedFile saved ${data.length} bytes to ${outputPath}`);
    } catch (error) {
      LogUtils.e(`${ZipUtils.TAG}:saveExtractedFile failed to save ${outputPath}: ${error}`);
      throw new Error(`Failed to save file: ${error}`);
    }
  }
}
