import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import { Constants } from '../constants/Constants';
import { DownloadErrorDetail } from '../constants/DownloadError';
import { DownloadLyricModel } from '../model/DownloadLyricModel';
import { HttpUrlRequest, RequestCallback } from '../net/HttpUrlRequest';
import { LogUtils } from '../utils/LogUtils';
import { Utils } from '../utils/Utils';
import { ZipUtils } from '../utils/ZipUtils';
import { LyricsFileDownloaderCallback } from './LyricsFileDownloaderCallback';

/**
 * 文件信息接口
 */
interface FileInfo {
  name: string;
  path: string;
  mtime: number;
}

/**
 * 下载请求回调实现类
 */
class DownloadRequestCallback implements RequestCallback {
  private requestId: number;
  private url: string;
  private filePath: string;
  private downloaderMap: Map<string, DownloadLyricModel>;
  private callback: LyricsFileDownloaderCallback | null;
  private cancelDownloadFn: (id: number) => void;
  private handleDownloadedFileFn: (id: number, path: string) => void;
  private notifyCompletedFn: (id: number, data: Uint8Array | null, error: DownloadErrorDetail | null) => void;

  constructor(
    requestId: number,
    url: string,
    filePath: string,
    downloaderMap: Map<string, DownloadLyricModel>,
    callback: LyricsFileDownloaderCallback | null,
    cancelDownloadFn: (id: number) => void,
    handleDownloadedFileFn: (id: number, path: string) => void,
    notifyCompletedFn: (id: number, data: Uint8Array | null, error: DownloadErrorDetail | null) => void
  ) {
    this.requestId = requestId;
    this.url = url;
    this.filePath = filePath;
    this.downloaderMap = downloaderMap;
    this.callback = callback;
    this.cancelDownloadFn = cancelDownloadFn;
    this.handleDownloadedFileFn = handleDownloadedFileFn;
    this.notifyCompletedFn = notifyCompletedFn;
  }

  updateResponseData(bytes: Uint8Array, len: number, currentLen: number, total: number): void {
    if (!this.downloaderMap.has(this.url)) {
      return;
    }

    let progress = 0;
    if (total !== -1) {
      progress = Math.floor(currentLen * 100 / total) / 100.0;
    }

    LogUtils.d(`LyricsFileDownloader:download progress requestId: ${this.requestId}, currentLen: ${currentLen}, total: ${total}, progress: ${progress}`);

    if (bytes && len > 0) {
      try {
        const data = bytes.slice(0, len);
        const file = fs.openSync(this.filePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.APPEND);
        fs.writeSync(file.fd, data.buffer);
        fs.closeSync(file);
      } catch (error) {
        LogUtils.e(`LyricsFileDownloader:download requestId: ${this.requestId}, write file fail: ${error}`);
      }
    }

    if (this.callback) {
      this.callback.onLyricsFileDownloadProgress(this.requestId, progress);
    }
  }

  requestFail(errorCode: number, msg: string): void {
    if (!this.downloaderMap.has(this.url)) {
      return;
    }

    LogUtils.e(`LyricsFileDownloader:download fail requestId: ${this.requestId}, url: ${this.url}, error: ${errorCode} ${msg}`);
    this.cancelDownloadFn(this.requestId);

    if (this.callback) {
      const downloadError = errorCode < 0 ?
      DownloadErrorDetail.createHttpDownloadError(errorCode, msg) :
      DownloadErrorDetail.createHttpLogicError(errorCode, msg);
      this.notifyCompletedFn(this.requestId, null, downloadError);
    }
  }

  requestFinish(): void {
    if (!this.downloaderMap.has(this.url)) {
      return;
    }

    LogUtils.d(`LyricsFileDownloader:download finish requestId: ${this.requestId}, url: ${this.url} finish`);
    this.handleDownloadedFileFn(this.requestId, this.filePath);
    this.downloaderMap.delete(this.url);
  }
}

/**
 * 歌词文件下载器 - HarmonyOS版本 (简化版)
 * 管理歌词文件的下载和缓存，使用ZipUtils处理ZIP文件解压
 */
export class LyricsFileDownloader {
  /**
   * 单例实例
   */
  private static instance: LyricsFileDownloader | null = null;
  /**
   * 应用上下文
   */
  private readonly mContext: common.UIAbilityContext;
  /**
   * 下载事件回调
   */
  private mLyricsFileDownloaderCallback: LyricsFileDownloaderCallback | null = null;
  /**
   * 缓存中保持的最大文件数
   */
  private mMaxFileNum: number = 50;
  /**
   * 缓存文件的最大存活时间（秒）
   */
  private mMaxFileAge: number = 8 * 60 * 60; // 8小时

  /**
   * 当前请求ID计数器
   */
  private mRequestId: number = -1;
  /**
   * 活跃下载映射表
   */
  private readonly mLyricsDownloaderMap: Map<string, DownloadLyricModel> = new Map();
  /**
   * 最大并发下载数
   */
  private static readonly MAX_DOWNLOADER_NUM: number = 3;

  /**
   * 私有构造函数，用于单例模式
   * @param context 应用上下文
   */
  private constructor(context: common.UIAbilityContext) {
    this.mContext = context;
  }

  /**
   * 获取LyricsFileDownloader的单例实例
   * @param context 应用上下文
   * @returns LyricsFileDownloader实例
   */
  static getInstance(context: common.UIAbilityContext): LyricsFileDownloader {
    if (!LyricsFileDownloader.instance) {
      LyricsFileDownloader.instance = new LyricsFileDownloader(context);
    }
    return LyricsFileDownloader.instance;
  }

  /**
   * 设置下载事件回调
   * @param callback 回调实现
   */
  setLyricsFileDownloaderCallback(callback: LyricsFileDownloaderCallback): void {
    this.mLyricsFileDownloaderCallback = callback;
  }

  /**
   * 设置缓存中保持的最大文件数
   * @param maxFileNum 最大文件数
   */
  setMaxFileNum(maxFileNum: number): void {
    LogUtils.d(`LyricsFileDownloader:setMaxFileNum maxFileNum: ${maxFileNum}`);
    if (maxFileNum <= 0) {
      LogUtils.e('LyricsFileDownloader:setMaxFileNum maxFileNum is invalid');
      return;
    }
    this.mMaxFileNum = maxFileNum;
  }

  /**
   * 设置缓存文件的最大存活时间
   * @param maxFileAge 最大文件存活时间（秒）
   */
  setMaxFileAge(maxFileAge: number): void {
    LogUtils.d(`LyricsFileDownloader:setMaxFileAge maxFileAge: ${maxFileAge}`);
    if (maxFileAge <= 0) {
      LogUtils.e('LyricsFileDownloader:setMaxFileAge maxFileAge is invalid');
      return;
    }
    this.mMaxFileAge = maxFileAge;
  }

  /**
   * 开始下载歌词文件
   * @param url 要下载的歌词文件URL
   * @returns 下载任务的请求ID
   */
  download(url: string): number {
    if (!this.mContext) {
      LogUtils.e('LyricsFileDownloader:download context is null');
      return Constants.ERROR_GENERAL;
    }
    if (!url || url.trim().length === 0) {
      LogUtils.e('LyricsFileDownloader:download url is null or empty');
      return Constants.ERROR_GENERAL;
    }

    LogUtils.d(`LyricsFileDownloader:download url: ${url}`);

    // 检查是否已在下载
    if (this.mLyricsDownloaderMap.has(url)) {
      LogUtils.i('LyricsFileDownloader:download url is already downloading');
      const model = this.mLyricsDownloaderMap.get(url);
      if (model) {
        this.notifyLyricsFileDownloadCompleted(model.getRequestId(), null,
          DownloadErrorDetail.createRepeatDownloadingError());
        return model.getRequestId();
      } else {
        this.mLyricsDownloaderMap.delete(url);
        LogUtils.e(`LyricsFileDownloader:download exception and remove downloading url: ${url}`);
      }
    }

    // 创建下载目录
    const folder = `${this.mContext.cacheDir}/${Constants.LYRICS_FILE_DOWNLOAD_DIR}`;
    if (!fs.accessSync(folder)) {
      fs.mkdirSync(folder, true);
    }

    // 生成请求ID
    if (this.mRequestId + 1 === Number.MAX_SAFE_INTEGER) {
      this.mRequestId = -1;
    }
    this.mRequestId++;

    // 检查文件年龄
    this.checkFileAge(folder);

    // 生成文件名
    let urlFileName = url.substring(url.lastIndexOf('/') + 1);
    if (!urlFileName || urlFileName.trim().length === 0) {
      urlFileName = `${Date.now()}.${Constants.FILE_EXTENSION_ZIP}`;
    }
    const filePath = `${folder}/${urlFileName}`;

    // 检查文件是否已存在
    if (fs.accessSync(filePath)) {
      LogUtils.d(`LyricsFileDownloader:download ${filePath} exists`);
      this.handleDownloadedFile(this.mRequestId, filePath);
      return this.mRequestId;
    }

    // 创建下载模型
    const model = new DownloadLyricModel();
    model.setUrl(url);
    model.setFilePath(filePath);
    model.setRequestId(this.mRequestId);

    const request = new HttpUrlRequest();
    model.setHttpUrlRequest(request);
    this.mLyricsDownloaderMap.set(url, model);

    const downloadRequestId = this.mRequestId;

    // 开始下载
    this.startDownload(downloadRequestId, url, filePath, request);

    return this.mRequestId;
  }

  /**
   * 开始下载任务
   */
  private startDownload(requestId: number, url: string, filePath: string, request: HttpUrlRequest): void {
    LogUtils.d(`LyricsFileDownloader:startDownload requestId: ${requestId}, url: ${url}, saveTo: ${filePath}`);

    const callback = new DownloadRequestCallback(
      requestId,
      url,
      filePath,
      this.mLyricsDownloaderMap,
      this.mLyricsFileDownloaderCallback,
      (id: number) => this.cancelDownload(id),
      (id: number, path: string) => this.handleDownloadedFile(id, path),
      (id: number, data: Uint8Array | null, error: DownloadErrorDetail | null) =>
      this.notifyLyricsFileDownloadCompleted(id, data, error)
    );

    request.setCallback(callback);

    request.requestGetUrl(url, undefined);
  }

  /**
   * 处理已下载的文件，包括必要时的解压
   */
  private async handleDownloadedFile(requestId: number, filePath: string): Promise<void> {
    LogUtils.d(`LyricsFileDownloader:handleDownloadedFile requestId: ${requestId}, file: ${filePath}`);

    const folder = `${this.mContext.cacheDir}/${Constants.LYRICS_FILE_DOWNLOAD_DIR}`;
    await this.checkFileAge(folder);

    if (!fs.accessSync(filePath)) {
      LogUtils.e('LyricsFileDownloader:handleDownloadedFile file does not exist');
      this.notifyLyricsFileDownloadCompleted(requestId, null,
        DownloadErrorDetail.createHttpDownloadError(Constants.ERROR_GENERAL, '文件不存在'));
      return;
    }

    const fileName = filePath.substring(filePath.lastIndexOf('/') + 1);

    if (fileName.toLowerCase().endsWith(Constants.FILE_EXTENSION_ZIP)) {
      LogUtils.d('LyricsFileDownloader:handleDownloadedFile file is zip file');
      await this.handleZipFile(requestId, filePath);
    } else if (this.isSupportLyricsFile(fileName)) {
      LogUtils.d(`LyricsFileDownloader:handleDownloadedFile file is ${this.getFileExtension(fileName)} file`);
      await this.handleLyricsFile(requestId, filePath, false);
    } else {
      LogUtils.e('LyricsFileDownloader:handleDownloadedFile unknown file format and return directly');
      const error = DownloadErrorDetail.createUnzipFailError('不支持的文件格式');
      error.setErrorCode(Constants.ERROR_UNZIP_ERROR);
      this.notifyLyricsFileDownloadCompleted(requestId, null, error);
    }
  }

  /**
   * 处理ZIP文件解压 (使用ZipUtils)
   */
  private async handleZipFile(requestId: number, zipFilePath: string): Promise<void> {
    try {
      LogUtils.d('LyricsFileDownloader:handleZipFile processing ZIP file with ZipUtils');

      // 创建临时目录
      const tempFolder = `${this.mContext.cacheDir}/${Constants.LYRICS_FILE_TEMP_DIR}`;
      if (!fs.accessSync(tempFolder)) {
        fs.mkdirSync(tempFolder, true);
      }

      // 使用ZipUtils解压文件
      const result = await ZipUtils.extractZipFile(zipFilePath, tempFolder);

      if (result.success && result.data && result.fileName) {
        LogUtils.d(`LyricsFileDownloader:handleZipFile extraction successful, original content: ${result.isOriginalContent}`);

        // 构建解压后的文件路径
        const extractedFilePath = `${tempFolder}/${result.fileName}`;

        // 处理解压后的歌词文件
        await this.handleLyricsFile(requestId, extractedFilePath, true);
      } else {
        throw new Error(result.error || 'ZIP解压失败');
      }

    } catch (error) {
      LogUtils.e(`LyricsFileDownloader:handleZipFile error: ${error}`);
      this.notifyLyricsFileDownloadCompleted(requestId, null,
        DownloadErrorDetail.createUnzipFailError(`ZIP解压失败: ${error}`));
    }
  }

  /**
   * 处理歌词文件并通知完成
   */
  private async handleLyricsFile(requestId: number, lyricFilePath: string, deleteLyricsFile: boolean): Promise<void> {
    try {
      const fileData = await Utils.getFileBytes(lyricFilePath);
      this.notifyLyricsFileDownloadCompleted(requestId, fileData, null);

      if (deleteLyricsFile && fs.accessSync(lyricFilePath)) {
        LogUtils.d(`LyricsFileDownloader:handleLyricsFile delete file: ${lyricFilePath}`);
        fs.unlinkSync(lyricFilePath);
      }

      LogUtils.d('LyricsFileDownloader:handleLyricsFile success');
    } catch (error) {
      LogUtils.e(`LyricsFileDownloader:handleLyricsFile error: ${error}`);
      this.notifyLyricsFileDownloadCompleted(requestId, null,
        DownloadErrorDetail.createUnzipFailError(`处理歌词文件失败: ${error}`));
    }
  }

  /**
   * 检查文件是否为支持的歌词格式
   */
  private isSupportLyricsFile(fileName: string): boolean {
    const lowerName = fileName.toLowerCase();
    return lowerName.endsWith(`.${Constants.FILE_EXTENSION_XML}`) ||
    lowerName.endsWith(`.${Constants.FILE_EXTENSION_LRC}`) ||
    lowerName.endsWith(`.${Constants.FILE_EXTENSION_KRC}`);
  }

  /**
   * 获取文件扩展名
   */
  private getFileExtension(fileName: string): string {
    const lastDot = fileName.lastIndexOf('.');
    return lastDot > 0 ? fileName.substring(lastDot + 1).toLowerCase() : '';
  }

  /**
   * 检查并删除过期文件
   */
  private async checkFileAge(folder: string): Promise<void> {
    try {
      if (!fs.accessSync(folder)) {
        return;
      }

      const files = fs.listFileSync(folder);
      LogUtils.d(`LyricsFileDownloader:checkFileAge files: ${files.join(', ')}`);

      const now = Date.now();

      for (const fileName of files) {
        const filePath = `${folder}/${fileName}`;
        try {
          const stat = fs.statSync(filePath);
          if (stat.isFile() && (now - stat.mtime * 1000 > this.mMaxFileAge * 1000)) {
            LogUtils.d(`LyricsFileDownloader:checkFileAge delete expired file: ${filePath}`);
            fs.unlinkSync(filePath);
          }
        } catch (error) {
          LogUtils.e(`LyricsFileDownloader:checkFileAge error processing ${filePath}: ${error}`);
        }
      }
    } catch (error) {
      LogUtils.e(`LyricsFileDownloader:checkFileAge error: ${error}`);
    }
  }

  /**
   * 通知回调下载完成
   */
  private notifyLyricsFileDownloadCompleted(requestId: number, lyricFileData: Uint8Array | null,
    error: DownloadErrorDetail | null): void {
    this.checkMaxFileNum();

    if (this.mLyricsFileDownloaderCallback) {
      if (lyricFileData) {
        LogUtils.d(`LyricsFileDownloader:notifyLyricsFileDownloadCompleted requestId: ${requestId}, data size: ${lyricFileData.length}, error: ${error}`);
        this.mLyricsFileDownloaderCallback.onLyricsFileDownloadCompleted(requestId, lyricFileData, null);
      } else {
        LogUtils.d(`LyricsFileDownloader:notifyLyricsFileDownloadCompleted requestId: ${requestId}, data is null, error: ${error}`);
        this.mLyricsFileDownloaderCallback.onLyricsFileDownloadCompleted(requestId, null, error);
      }
    } else {
      LogUtils.d('LyricsFileDownloader:notifyLyricsFileDownloadCompleted callback is null');
    }
  }

  /**
   * 检查并强制执行最大文件数限制
   */
  private checkMaxFileNum(): void {
    try {
      const folder = `${this.mContext.cacheDir}/${Constants.LYRICS_FILE_DOWNLOAD_DIR}`;
      if (!fs.accessSync(folder)) {
        LogUtils.i('LyricsFileDownloader:checkMaxFileNum folder does not exist');
        return;
      }

      const files = fs.listFileSync(folder);
      const fileInfos: Array<FileInfo> = [];

      for (const fileName of files) {
        const filePath = `${folder}/${fileName}`;
        try {
          const stat = fs.statSync(filePath);
          if (stat.isFile()) {
            fileInfos.push({
              name: fileName,
              path: filePath,
              mtime: stat.mtime
            });
          }
        } catch (error) {
          LogUtils.e(`LyricsFileDownloader:checkMaxFileNum error getting stat for ${filePath}: ${error}`);
        }
      }

      if (fileInfos.length <= this.mMaxFileNum) {
        LogUtils.d(`LyricsFileDownloader:checkMaxFileNum file count ${fileInfos.length} is within limit ${this.mMaxFileNum}`);
        return;
      }

      // 按修改时间排序，删除最旧的文件
      fileInfos.sort((a, b) => a.mtime - b.mtime);

      const filesToDelete = fileInfos.length - this.mMaxFileNum;
      for (let i = 0; i < filesToDelete; i++) {
        if (this.maybeDeleteFile(fileInfos[i].path)) {
          LogUtils.d(`LyricsFileDownloader:checkMaxFileNum deleted old file: ${fileInfos[i].path}`);
        }
      }
    } catch (error) {
      LogUtils.e(`LyricsFileDownloader:checkMaxFileNum error: ${error}`);
    }
  }

  /**
   * 尝试删除文件（如果没有正在下载）
   */
  private maybeDeleteFile(filePath: string): boolean {
    if (!fs.accessSync(filePath)) {
      return true;
    }

    // 检查是否有正在下载到此文件的任务
    for (const model of this.mLyricsDownloaderMap.values()) {
      if (model && model.getFilePath() === filePath) {
        return false; // 文件正在被下载，不能删除
      }
    }

    try {
      fs.unlinkSync(filePath);
      return true;
    } catch (error) {
      LogUtils.e(`LyricsFileDownloader:maybeDeleteFile error deleting ${filePath}: ${error}`);
      return false;
    }
  }

  /**
   * 取消正在进行的下载
   */
  cancelDownload(requestId: number): void {
    if (!this.mContext) {
      LogUtils.e('LyricsFileDownloader:cancelDownload context is null');
      return;
    }

    LogUtils.d(`LyricsFileDownloader:cancelDownload requestId: ${requestId}`);

    let urlToRemove = '';
    for (const entry of this.mLyricsDownloaderMap.entries()) {
      const url = entry[0];
      const model = entry[1];
      if (model && model.getRequestId() === requestId) {
        const httpRequest = model.getHttpUrlRequest();
        if (httpRequest) {
          httpRequest.setCancelled(true);
        }
        urlToRemove = url;

        // 删除临时文件
        const tempFilePath = model.getFilePath();
        if (fs.accessSync(tempFilePath)) {
          try {
            fs.unlinkSync(tempFilePath);
          } catch (error) {
            LogUtils.e(`LyricsFileDownloader:cancelDownload error deleting temp file: ${error}`);
          }
        }
        break;
      }
    }

    if (urlToRemove) {
      this.mLyricsDownloaderMap.delete(urlToRemove);
    }
  }

  /**
   * 清理缓存中的所有下载文件
   */
  cleanAll(): void {
    if (!this.mContext) {
      LogUtils.e('LyricsFileDownloader:cleanAll context is null');
      return;
    }

    const folder = `${this.mContext.cacheDir}/${Constants.LYRICS_FILE_DOWNLOAD_DIR}`;
    let isCleanAllSuccess = true;

    try {
      if (fs.accessSync(folder)) {
        const files = fs.listFileSync(folder);
        for (const fileName of files) {
          const filePath = `${folder}/${fileName}`;
          try {
            const stat = fs.statSync(filePath);
            if (stat.isFile()) {
              fs.unlinkSync(filePath);
            }
          } catch (error) {
            LogUtils.e(`LyricsFileDownloader:cleanAll delete file ${filePath} error: ${error}`);
            isCleanAllSuccess = false;
          }
        }
      }
    } catch (error) {
      LogUtils.e(`LyricsFileDownloader:cleanAll error: ${error}`);
      isCleanAllSuccess = false;
    }

    LogUtils.d(`LyricsFileDownloader:cleanAll isCleanAllSuccess: ${isCleanAllSuccess}`);
  }
}
