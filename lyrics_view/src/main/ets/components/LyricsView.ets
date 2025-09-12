import { LyricModel } from '../model/LyricModel';
import { PitchData } from '../model/PitchData';
import { LyricsLineModel, Tone } from '../model/LyricsLineModel';
import { LyricType } from '../constants/LyricType';

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

    // 内部状态
    @State private scrollController: Scroller = new Scroller();
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
        if (!this.lyricModel || !this.lyricModel.hasValidLyrics()) {
            this.currentLineIndex = -1;
            return;
        }

        const newIndex = this.lyricModel.findLineByTime(this.currentTime);
        if (newIndex !== this.currentLineIndex) {
            this.currentLineIndex = newIndex;
            this.scrollToCurrentLine();
        }
    }

/**
* 滚动到当前歌词行
*/
private scrollToCurrentLine() {
        if (this.currentLineIndex >= 0 && !this.isDragging) {
            // 计算滚动位置，使当前行居中显示
            const itemHeight = this.currentLineTextSize + this.lineSpacing;
            const scrollOffset = this.currentLineIndex * itemHeight - this.viewHeight / 2;

            animateTo({
                duration: this.animationDuration,
                curve: Curve.EaseInOut
            }, () => {
                this.scrollController.scrollTo({
                    xOffset: 0,
                    yOffset: Math.max(0, scrollOffset),
                    animation: true
                });
            });
        }
    }

    /**
    * 渲染KRC格式的逐字高亮歌词
    */
    @Builder
    KrcLineBuilder(line: LyricsLineModel, index: number) {
        if (!line.krcChars || line.krcChars.length === 0) {
            // 没有字符级数据，显示普通文本
            this.NormalLineBuilder(line, index);
            return;
        }

        Row() {
            ForEach(line.krcChars, (krcChar: KrcCharModel, charIndex: number) => {
                Text(krcChar.char)
                    .fontSize(index === this.currentLineIndex ? this.currentLineTextSize : this.normalLineTextSize)
                    .fontColor(this.getCharColor(line, krcChar, index))
                    .fontWeight(index === this.currentLineIndex ? FontWeight.Bold : FontWeight.Normal)
                    .animation({
                        duration: 200,
                        curve: Curve.EaseInOut
                    })
            }, (krcChar: KrcCharModel, charIndex: number) => `${index}-${charIndex}-${krcChar.char}`)
        }
.width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    }

    /**
    * 渲染普通歌词行
    */
    @Builder
    NormalLineBuilder(line: LyricsLineModel, index: number) {
        Text(line.content)
            .fontSize(index === this.currentLineIndex ? this.currentLineTextSize : this.normalLineTextSize)
            .fontColor(index === this.currentLineIndex ? this.currentLineColor : this.normalLineColor)
            .fontWeight(index === this.currentLineIndex ? FontWeight.Bold : FontWeight.Normal)
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .animation({
                duration: this.animationDuration,
                curve: Curve.EaseInOut
            })
    }

    /**
    * 渲染单行歌词（根据格式选择渲染方式）
    */
    @Builder
    LyricLineBuilder(line: LyricsLineModel, index: number) {
        if (this.lyricModel?.type === LyricType.KRC && line.krcChars && line.krcChars.length > 0) {
            this.KrcLineBuilder(line, index);
        } else {
            this.NormalLineBuilder(line, index);
        }
    }

/**
* 获取字符颜色（用于KRC逐字高亮）
*/
private getCharColor(line: LyricsLineModel, krcChar: KrcCharModel, lineIndex: number): string {
        if (lineIndex !== this.currentLineIndex) {
            return this.normalLineColor;
        }

        // 当前行，检查字符是否应该高亮
        if (krcChar.isTimeInRange(this.currentTime, line.startTime)) {
            return this.highlightColor;
        } else if (this.currentTime >= krcChar.getAbsoluteStartTime(line.startTime)) {
            // 已经播放过的字符
            return this.currentLineColor;
        } else {
            // 还未播放的字符
            return this.currentLineColor;
        }
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

/**
* 处理拖拽事件
*/
private handleDragEvent(event: TouchEvent) {
        if (!this.enableDragging || !this.lyricModel || !this.lyricModel.hasValidLyrics()) {
            return;
        }

        switch (event.type) {
            case TouchType.Down:
                this.isDragging = true;
                this.seekListener?.onStartTrackingTouch();
                break;

            case TouchType.Move:
                // 根据触摸位置计算对应的歌词行和时间
                const touchY = event.touches[0].y;
                const lineIndex = Math.floor(touchY / (this.currentLineTextSize + this.lineSpacing));
                if (lineIndex >= 0 && lineIndex < this.lyricModel.lines.length) {
                    const targetLine = this.lyricModel.lines[lineIndex];
                    this.seekListener?.onProgressChanged(targetLine.startTime);
                }
                break;

            case TouchType.Up:
            case TouchType.Cancel:
                this.isDragging = false;
                this.seekListener?.onStopTrackingTouch();
                break;
        }
    }

    build() {
        Column() {
            if (!this.lyricModel || !this.lyricModel.hasValidLyrics()) {
                // 无歌词状态
                this.NoLyricsBuilder()
            } else {
                // 有歌词 - 使用Scroll组件实现滚动
                Scroll(this.scrollController) {
                    Column() {
                        // 添加顶部空白
                        Row().height(this.paddingTop)

                        // 渲染歌词行
                        ForEach(this.lyricModel.lines, (line: LyricsLineModel, index: number) => {
                            Column() {
                                this.LyricLineBuilder(line, index)
                            }
.width('100%')
                                .onClick(() => {
                                    if (this.enableDragging) {
                                        this.seekListener?.onProgressChanged(line.startTime);
                                    }
                                })
                        }, (line: LyricsLineModel, index: number) => `${index}-${line.content}`)

                        // 添加底部空白
                        Row().height(this.paddingTop)
                    }
.width('100%')
                }
.width('100%')
                    .height('100%')
                    .scrollBar(BarState.Off)
                    .scrollable(ScrollDirection.Vertical)
                    .onTouch((event: TouchEvent) => {
                        this.handleDragEvent(event);
                    })
            }
        }
.width('100%')
            .height('100%')
            .backgroundColor('#F8F8F8')
            .onAreaChange((oldValue: Area, newValue: Area) => {
                this.viewHeight = Number(newValue.height);
            })
    }

    /**
    * 重置组件状态
    */
    reset() {
        this.currentLineIndex = -1;
        this.isDragging = false;
        this.scrollController.scrollToEdge(Edge.Top);
    }

    /**
    * 请求刷新UI
    */
    requestRefreshUi() {
        this.updateCurrentLine();
    }

    /**
    * 设置歌词拖拽监听器
    */
    setSeekListener(listener: OnLyricsSeekListener) {
        this.seekListener = listener;
    }

    /**
    * 启用或禁用拖拽功能
    */
    enableDraggingFunction(enable: boolean) {
        this.enableDragging = enable;
    }
}
