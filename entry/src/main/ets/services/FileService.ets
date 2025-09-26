import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import fs from '@ohos.file.fs';
import { contextManager } from '../utils/ContextManager';
// import { Utils } from 'lyrics_view';

// 临时定义Utils类
class Utils {
  static loadRawFileAsString(context: common.UIAbilityContext, fileName: string): Promise<string> {
    // 临时实现
    return Promise.resolve('');
  }

  static stringToUint8Array(str: string): Uint8Array {
    // 临时实现
    return new Uint8Array();
  }
}

const TAG = 'FileService';

/**
 * 文件服务
 * 负责文件操作相关的业务逻辑
 */
export class FileService {
  private lyricsDir: string = '';

  /**
   * 准备所需的文件
   */
  async prepareFiles(): Promise<void> {
    try {
      this.lyricsDir = await this.ensureLyricsDirectory();
      await this.copyRawFilesToPrivate();

      this.logDebug('Files prepared successfully');
    } catch (error) {
      this.logDebug(`Failed to prepare files: ${error}`);
      throw new Error(`Failed to prepare files: ${error}`);
    }
  }

  /**
   * 获取歌词文件路径
   */
  getLyricFilePath(): string {
    return `${this.lyricsDir}/6091274963611321451.krc`;
  }

  /**
   * 获取音调文件路径
   */
  getPitchFilePath(): string {
    return `${this.lyricsDir}/6091274963611321451.pitch`;
  }

  /**
   * 检查文件是否存在
   */
  checkFilesExist(): boolean {
    try {
      return fs.accessSync(this.getLyricFilePath()) && fs.accessSync(this.getPitchFilePath());
    } catch (error) {
      this.logDebug(`Failed to check files: ${error}`);
      return false;
    }
  }

  /**
   * 确保歌词目录存在
   */
  private async ensureLyricsDirectory(): Promise<string> {
    try {
      const lyricsDir = `${contextManager.getFilesDir()}/lyrics`;

      this.logDebug(`Checking lyrics directory: ${lyricsDir}`);

      if (!fs.accessSync(lyricsDir)) {
        this.logDebug(`Creating lyrics directory: ${lyricsDir}`);
        fs.mkdirSync(lyricsDir);
        this.logDebug(`Successfully created lyrics directory`);
      } else {
        this.logDebug(`Lyrics directory already exists`);
      }

      return lyricsDir;
    } catch (error) {
      this.logDebug(`Failed to ensure lyrics directory: ${error}`);
      throw new Error(`Failed to ensure lyrics directory: ${error}`);
    }
  }

  /**
   * 从 rawfile 复制文件到私有目录
   */
  private async copyRawFilesToPrivate(): Promise<void> {
    try {
      const filesToCopy = [
        '6091274963611321451.krc',
        '6091274963611321451.pitch'
      ];

      for (const fileName of filesToCopy) {
        const targetPath = `${this.lyricsDir}/${fileName}`;

        // 检查文件是否已存在
        if (fs.accessSync(targetPath)) {
          this.logDebug(`File already exists, skipping: ${targetPath}`);
          continue;
        }

        try {
          // 从 rawfile 读取内容
          const content: string = await Utils.loadRawFileAsString(contextManager.getContext(), fileName);
          if (!content) {
            throw new Error(`Failed to load rawfile: ${fileName}`);
          }

          // 写入文件
          await this.writePrivateFile(targetPath, content);
          this.logDebug(`Successfully copied ${fileName} to ${targetPath}`);

        } catch (error) {
          this.logDebug(`Failed to copy ${fileName}: ${error}`);
          // 继续处理其他文件
        }
      }

      // 验证目录内容
      await this.listDirectoryContents();

    } catch (error) {
      this.logDebug(`Failed to copy raw files: ${error}`);
      throw new Error(`Failed to copy raw files: ${error}`);
    }
  }

  /**
   * 写入私有文件
   */
  private async writePrivateFile(filePath: string, content: string): Promise<void> {
    try {
      const file = fs.openSync(filePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE);
      const buffer: Uint8Array = Utils.stringToUint8Array(content);
      fs.writeSync(file.fd, buffer.buffer as ArrayBuffer);
      fs.closeSync(file);

      this.logDebug(`Successfully wrote file: ${filePath}`);
    } catch (error) {
      this.logDebug(`Failed to write file ${filePath}: ${error}`);
      throw new Error(`Failed to write file ${filePath}: ${error}`);
    }
  }

  /**
   * 列出目录内容
   */
  private async listDirectoryContents(): Promise<void> {
    try {
      if (fs.accessSync(this.lyricsDir)) {
        const files = fs.listFileSync(this.lyricsDir);
        this.logDebug(`Directory ${this.lyricsDir} contains: ${JSON.stringify(files)}`);
      } else {
        this.logDebug(`Directory ${this.lyricsDir} does not exist`);
      }
    } catch (error) {
      this.logDebug(`Failed to list directory ${this.lyricsDir}: ${error}`);
    }
  }

  /**
   * 调试日志
   */
  private logDebug(message: string): void {
    hilog.debug(0x0000, TAG, `%{public}s`, message);
  }
}
