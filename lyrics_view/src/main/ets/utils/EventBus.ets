/**
 * 全局事件总线，用于组件间通信
 * 避免直接的组件引用依赖
 */
export class EventBus {
  private static instance: EventBus | null = null;
  private listeners: Map<string, Array<Function>> = new Map();

  private constructor() {
  }

  static getInstance(): EventBus {
    if (!EventBus.instance) {
      EventBus.instance = new EventBus();
    }
    return EventBus.instance;
  }

  /**
   * 订阅事件
   * @param event 事件名称
   * @param callback 回调函数
   */
  on(event: string, callback: Function): void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }
    this.listeners.get(event)?.push(callback);
  }

  /**
   * 取消订阅事件
   * @param event 事件名称
   * @param callback 回调函数
   */
  off(event: string, callback: Function): void {
    const callbacks = this.listeners.get(event);
    if (callbacks) {
      const index = callbacks.indexOf(callback);
      if (index > -1) {
        callbacks.splice(index, 1);
      }
    }
  }

  /**
   * 发布事件
   * @param event 事件名称
   * @param data 事件数据
   */
  emit(event: string, ...data: Object[]): void {
    const callbacks = this.listeners.get(event);
    if (callbacks) {
      callbacks.forEach(callback => {
        try {
          (callback as (...args: Object[]) => void)(...data);
        } catch (error) {
          console.error(`EventBus error in ${event}:`, error);
        }
      });
    }
  }

  /**
   * 清除所有监听器
   */
  clear(): void {
    this.listeners.clear();
  }
}

/**
 * 歌词相关事件常量
 */
export class LyricsEvents {
  /** 设置歌词数据 */
  static readonly SET_LYRIC_DATA = 'lyrics:setData';
  /** 设置播放进度 */
  static readonly SET_PROGRESS = 'lyrics:setProgress';
  /** 重置歌词状态 */
  static readonly RESET = 'lyrics:reset';
  /** 请求刷新UI */
  static readonly REQUEST_REFRESH = 'lyrics:requestRefresh';
  /** 歌词拖拽开始 */
  static readonly DRAG_START = 'lyrics:dragStart';
  /** 歌词拖拽结束 */
  static readonly DRAG_END = 'lyrics:dragEnd';
  /** 歌词拖拽事件（兼容旧版本） */
  static readonly SEEK_PROGRESS = 'lyrics:seekProgress';
  /** 歌词组件准备就绪 */
  static readonly COMPONENT_READY = 'lyrics:componentReady';
  /** 销毁歌词组件 */
  static readonly DESTROY = 'lyrics:destroy';
}

/**
 * 评分相关事件常量
 */
export class ScoringEvents {
  /** 设置歌词数据 */
  static readonly SET_LYRIC_DATA = 'scoring:setData';
  /** 设置音高数据 */
  static readonly SET_PITCH = 'scoring:setPitch';
  /** 设置播放进度 */
  static readonly SET_PROGRESS = 'scoring:setProgress';
  /** 重置评分状态 */
  static readonly RESET = 'scoring:reset';
  /** 请求刷新UI */
  static readonly REQUEST_REFRESH = 'scoring:requestRefresh';
  /** 评分组件准备就绪 */
  static readonly COMPONENT_READY = 'scoring:componentReady';
  /** 设置评分算法 */
  static readonly SET_SCORING_ALGORITHM = 'scoring:setScoringAlgorithm';
  /** 设置评分难度 */
  static readonly SET_SCORING_LEVEL = 'scoring:setScoringLevel';
  /** 销毁评分组件 */
  static readonly DESTROY = 'scoring:destroy';
}

/**
 * 卡拉OK系统事件常量
 */
export class KaraokeEvents {
  /** 组件检测 - 用于自动发现集成的组件 */
  static readonly COMPONENT_DETECTION = 'karaoke:componentDetection';
  static readonly COMPONENT_DETECTION_REQUEST = 'DetectionRequest';
  static readonly COMPONENT_LYRICS_VIEW = 'LyricsView';
  static readonly COMPONENT_SCORING_VIEW = 'ScoringView';
  /** 销毁卡拉OK组件 */
  static readonly DESTROY = 'karaoke:destroy';
}
