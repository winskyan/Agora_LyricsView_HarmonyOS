import { DownloadErrorDetail } from '../constants/DownloadError';

/**
 * 歌词文件下载回调接口 - HarmonyOS版本
 * 提供跟踪下载进度和完成状态的方法
 */
export interface LyricsFileDownloaderCallback {
  /**
   * 下载进度更新时调用
   * @param requestId 下载请求的ID
   * @param progress 当前下载进度（0.0 到 1.0）
   */
  onLyricsFileDownloadProgress(requestId: number, progress: number): void;

  /**
   * 下载完成或遇到错误时调用
   * @param requestId 下载请求的ID
   * @param fileData 下载的文件数据（字节数组），下载失败时为null
   * @param error 下载过程中发生的错误，下载成功时为null
   */
  onLyricsFileDownloadCompleted(requestId: number, fileData: Uint8Array | null,
    error: DownloadErrorDetail | null): void;
}
