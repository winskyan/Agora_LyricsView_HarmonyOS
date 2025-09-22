import fs from '@ohos.file.fs';
import { ILogger } from './ILogger';
import { LogLevelUtils } from './LogLevel';

/**
 * 文件日志记录器
 * 基于 Agora-LoggingService 的 FileLogger 实现
 * 支持文件大小限制和循环保存
 */
export class FileLogger implements ILogger {
  private readonly logFilePath: string;
  private readonly filePrefixName: string;
  private readonly maxFileSizeOfBytes: number;
  private readonly maxFileCount: number;
  private readonly supportTags: string[];
  // 1MB in bytes
  private static readonly ONE_MB = 1024 * 1024;

  constructor(
    logFilePath: string,
    filePrefixName: string,
    maxFileSizeOfBytes: number,
    maxFileCount: number,
    supportTags?: string[]
  ) {
    if (!logFilePath || logFilePath.trim().length === 0) {
      throw new Error('FileLogger init failed, logFilePath is empty');
    }
    if (!filePrefixName || filePrefixName.trim().length === 0) {
      throw new Error('FileLogger init failed, filePrefixName is empty');
    }
    if (maxFileSizeOfBytes === 0) {
      throw new Error('FileLogger init failed, maxFileSizeOfBytes is 0');
    }
    if (maxFileCount === 0) {
      throw new Error('FileLogger init failed, maxFileCount is 0');
    }

    this.logFilePath = logFilePath;
    this.filePrefixName = filePrefixName;
    this.maxFileSizeOfBytes = maxFileSizeOfBytes;
    this.maxFileCount = maxFileCount;
    this.supportTags = supportTags || [];
  }

  /**
   * 添加支持的标签
   */
  addSupportTag(tag: string): void {
    if (!this.supportTags.includes(tag)) {
      this.supportTags.push(tag);
    }
  }

  /**
   * 移除支持的标签
   */
  removeSupportTag(tag: string): void {
    const index = this.supportTags.indexOf(tag);
    if (index > -1) {
      this.supportTags.splice(index, 1);
    }
  }

  onLog(level: number, tag: string, message: string): void {
    try {
      if (!this.isStorageSpaceEnough(this.logFilePath)) {
        console.info('FileLogger', 'onLog: storage space is less than 1MB');
        return;
      }

      if (this.supportTags.length > 0 && !this.supportTags.includes(tag)) {
        return;
      }

      // 构建日志消息
      const lineMessage = this.buildLogMessage(level, tag, message);

      // 确保日志目录存在
      this.ensureLogDirectoryExists();

      // 获取排序后的日志文件列表
      let logFiles = this.getSortedLogFiles();

      // 如果没有日志文件，创建新文件
      if (logFiles.length === 0) {
        this.createNewLogFile();
        logFiles = this.getSortedLogFiles();
      }

      // 检查第一个日志文件
      if (this.checkFirstLogFile(logFiles)) {
        logFiles = this.getSortedLogFiles();
      }

      const firstLogFile = logFiles[0];
      const currentFileSize = this.getFileSize(firstLogFile);

      // 如果当前文件加上新消息超出大小限制，需要轮转
      if (currentFileSize + lineMessage.length > this.maxFileSizeOfBytes) {
        this.renameLogFile(logFiles);
        this.createNewLogFile();
        logFiles = this.getSortedLogFiles();
      }

      // 写入日志到第一个文件
      this.appendToFile(logFiles[0], lineMessage);

      // 删除多余的日志文件
      this.deleteExtraLogFiles();

    } catch (error) {
      console.error('FileLogger', `Error writing log: ${error}`);
    }
  }

  /**
   * 构建日志消息
   */
  private buildLogMessage(level: number, tag: string, message: string): string {
    const now = new Date();
    const timestamp = this.formatTimestamp(now);
    const levelName = LogLevelUtils.getLevelName(level);

    return `[${timestamp}][${tag}][${levelName}]${message}\n`;
  }

  /**
   * 格式化时间戳
   */
  private formatTimestamp(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');
    const milliseconds = String(date.getMilliseconds()).padStart(3, '0');

    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}.${milliseconds}`;
  }

  /**
   * 确保日志目录存在
   */
  private ensureLogDirectoryExists(): void {
    try {
      if (!fs.accessSync(this.logFilePath)) {
        fs.mkdirSync(this.logFilePath, true);
      }
    } catch (error) {
      console.error('FileLogger', `Failed to create log directory: ${error}`);
    }
  }

  /**
   * 获取排序后的日志文件列表
   */
  private getSortedLogFiles(): string[] {
    try {
      const files = fs.listFileSync(this.logFilePath);
      const logFiles = files
        .filter(file => file.startsWith(this.filePrefixName))
        .map(file => `${this.logFilePath}/${file}`);

      // 按文件名排序（prefix.log, prefix.1.log, prefix.2.log...）
      logFiles.sort((file1, file2) => {
        const name1 = this.extractFileName(file1);
        const name2 = this.extractFileName(file2);

        const num1 = this.extractFileNumber(name1);
        const num2 = this.extractFileNumber(name2);

        return num1 - num2;
      });

      return logFiles;
    } catch (error) {
      console.error('FileLogger', `Failed to list log files: ${error}`);
      return [];
    }
  }

  /**
   * 从路径中提取文件名
   */
  private extractFileName(filePath: string): string {
    const parts = filePath.split('/');
    return parts[parts.length - 1];
  }

  /**
   * 从文件名中提取编号
   */
  private extractFileNumber(fileName: string): number {
    try {
      // 去掉 .log 后缀
      const nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));

      if (nameWithoutExt.length > this.filePrefixName.length) {
        const numberPart = nameWithoutExt.substring(this.filePrefixName.length + 1);
        return parseInt(numberPart);
      } else {
        return 0; // prefix.log 文件的编号为 0
      }
    } catch (error) {
      return 0;
    }
  }

  /**
   * 检查第一个日志文件
   */
  private checkFirstLogFile(files: string[]): boolean {
    if (files.length === 0) {
      return false;
    }

    const firstLogFile = files[0];
    const fileName = this.extractFileName(firstLogFile);
    const currentLogFileName = `${this.filePrefixName}.log`;

    if (fileName !== currentLogFileName) {
      // 重新命名文件
      for (let i = files.length - 1; i >= 0; i--) {
        const oldFile = files[i];
        let newFileName: string;
        if (i === 0) {
          newFileName = currentLogFileName;
        } else {
          newFileName = `${this.filePrefixName}.${i}.log`;
        }
        const newFile = `${this.logFilePath}/${newFileName}`;
        try {
          fs.renameSync(oldFile, newFile);
        } catch (error) {
          console.error('FileLogger', `Failed to rename file: ${error}`);
        }
      }
      return true;
    }
    return false;
  }

  /**
   * 创建新的日志文件
   */
  private createNewLogFile(): void {
    const newFileName = `${this.logFilePath}/${this.filePrefixName}.log`;
    try {
      // 创建空文件
      const file = fs.openSync(newFileName, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY);
      fs.closeSync(file);
    } catch (error) {
      console.error('FileLogger', `Failed to create new log file: ${error}`);
    }
  }

  /**
   * 重命名日志文件
   */
  private renameLogFile(files: string[]): void {
    for (let i = files.length - 1; i >= 0; i--) {
      const oldFile = files[i];
      const newFileName = `${this.filePrefixName}.${i + 1}.log`;
      const newFile = `${this.logFilePath}/${newFileName}`;
      try {
        fs.renameSync(oldFile, newFile);
      } catch (error) {
        console.error('FileLogger', `Failed to rename file: ${error}`);
      }
    }
  }

  /**
   * 删除多余的日志文件
   */
  private deleteExtraLogFiles(): void {
    const logFiles = this.getSortedLogFiles();
    if (logFiles.length > this.maxFileCount) {
      for (let i = this.maxFileCount; i < logFiles.length; i++) {
        try {
          fs.unlinkSync(logFiles[i]);
        } catch (error) {
          console.error('FileLogger', `Failed to delete extra log file: ${error}`);
        }
      }
    }
  }

  /**
   * 获取文件大小
   */
  private getFileSize(filePath: string): number {
    try {
      const stat = fs.statSync(filePath);
      return stat.size;
    } catch (error) {
      return 0;
    }
  }

  /**
   * 追加内容到文件
   */
  private appendToFile(filePath: string, content: string): void {
    try {
      const file = fs.openSync(filePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.APPEND);
      fs.writeSync(file.fd, content, { encoding: 'utf-8' });
      fs.closeSync(file);
    } catch (error) {
      console.error('FileLogger', `Failed to append to file: ${error}`);
    }
  }

  /**
   * 检查存储空间是否足够
   */
  private isStorageSpaceEnough(logFilePath: string): boolean {
    try {
      // 在 HarmonyOS 中，我们简化存储空间检查
      // 这里假设有足够的空间，实际项目中可以根据需要实现更复杂的检查
      return fs.accessSync(logFilePath) || true;
    } catch (error) {
      return false;
    }
  }
}
