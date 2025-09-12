import { LyricModel } from '../model/LyricModel';

/**
 * 歌词拖拽监听器接口
 */
export interface OnLyricsSeekListener {
  /**
   * 进度改变回调
   * @param progress 当前进度（毫秒）
   */
  onProgressChanged(progress: number): void;

  /**
   * 开始拖拽回调
   */
  onStartTrackingTouch(): void;

  /**
   * 停止拖拽回调
   */
  onStopTrackingTouch(): void;
}

/**
 * 歌词显示组件 - HarmonyOS版本
 * 对应Android项目中的LyricsView
 * 支持KRC格式的逐字高亮显示
 */
@Component
export struct LyricsView {
  /** 歌词数据模型 */
  @Prop lyricModel: LyricModel | null = null;
  /** 当前播放时间（毫秒） */
  @Prop @Watch('onCurrentTimeChanged') currentTime: number = 0;
  /** 当前歌词行索引 */
  @State currentLineIndex: number = -1;
  /** 无歌词时显示的文本 */
  @Prop noLyricsText: string = '暂无歌词';
  /** 是否启用拖拽 */
  @Prop enableDragging: boolean = false;
  /** 拖拽监听器 */
  @Prop seekListener ?: OnLyricsSeekListener;
  // 样式配置
  @Prop currentLineTextSize: number = 20;
  @Prop normalLineTextSize: number = 16;
  @Prop currentLineColor: string = '#333333';
  @Prop normalLineColor: string = '#999999';
  @Prop highlightColor: string = '#FF6B35';
  @Prop lineSpacing: number = 12;
  @Prop animationDuration: number = 300;
  @Prop paddingTop: number = 50;
  @State private isDragging: boolean = false;
  @State private viewHeight: number = 0;

  /**
   * 监听当前时间变化
   */
  onCurrentTimeChanged() {
    this.updateCurrentLine();
  }

  /**
   * 更新当前歌词行
   */
  private updateCurrentLine() {

  }

  /**
   * 滚动到当前歌词行
   */
  private scrollToCurrentLine() {

  }

  /**
   * 渲染无歌词状态
   */
  @Builder
  NoLyricsBuilder() {
    Column() {
      Text(this.noLyricsText)
        .fontSize(18)
        .fontColor('#999999')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
  }

  build() {
  }

  requestRefreshUi() {
  }

  reset() {

  }

  setSeekListener(listener: OnLyricsSeekListener) {
  }
}
