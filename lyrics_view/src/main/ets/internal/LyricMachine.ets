import { LyricModel } from '../model/LyricModel';

/**
* 歌词机器监听器接口
*/
export interface OnLyricListener {
    /**
    * 重置UI
    */
    resetUi(): void;

    /**
    * 请求刷新UI
    */
    requestRefreshUi(): void;
}

/**
* 歌词机器 - HarmonyOS版本
* 对应Android项目中的LyricMachine
* 负责管理歌词的播放状态和进度
*/
export class LyricMachine {
    private lyricModel: LyricModel | null = null;
    private currentProgress: number = 0;
    private isReady: boolean = false;
    private listener?: OnLyricListener;

    constructor(listener?: OnLyricListener) {
        this.listener = listener;
    }

    /**
    * 准备歌词数据
    * @param model 歌词模型
    */
    prepare(model: LyricModel): void {
        this.lyricModel = model;
        this.isReady = true;
        this.currentProgress = 0;
    }

    /**
    * 设置进度
    * @param progress 当前进度（毫秒）
    */
    setProgress(progress: number): void {
        this.currentProgress = progress;
        // TODO: 实现进度更新逻辑
    }

    /**
    * 获取当前歌词进度
    * @returns 当前进度（毫秒）
    */
    getCurrentLyricProgress(): number {
        return this.currentProgress;
    }

    /**
    * 获取歌词模型
    * @returns 歌词模型
    */
    getLyricsModel(): LyricModel | null {
        return this.lyricModel;
    }

    /**
    * 检查是否准备就绪
    * @returns 是否准备就绪
    */
    isReady(): boolean {
        return this.isReady;
    }

    /**
    * 重置状态
    */
    reset(): void {
        this.lyricModel = null;
        this.currentProgress = 0;
        this.isReady = false;
        this.listener?.resetUi();
    }

    /**
    * 处理拖拽事件
    * @param progress 拖拽到的进度
    */
    whenDraggingHappen(progress: number): void {
        this.currentProgress = progress;
        // TODO: 实现拖拽处理逻辑
    }

    /**
    * 准备UI
    */
    prepareUi(): void {
        this.listener?.requestRefreshUi();
    }
}
