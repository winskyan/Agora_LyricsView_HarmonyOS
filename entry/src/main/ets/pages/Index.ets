import {
LyricsView,
EnhancedLyricsView,
LyricModel,
LyricsParser,
KrcParser,
KaraokeView,
KaraokeEvent,
LyricsLineModel
} from 'lyrics_view';

@Entry
@Component
struct Index {
@State message: string = 'HarmonyOS 歌词组件演示';
@State lyricModel: LyricModel | null = null              ;
@State currentTime: number = 0                           ;
@State isPlaying: boolean = false                        ;
@State useEnhancedView: boolean = false                  ;
@State karaokeView: KaraokeView = new KaraokeView()      ;
private timer: number = -1                               ;

aboutToAppear() {
// 创建示例歌词数据
this.lyricModel = LyricsParser.createSampleLyrics() ;

// 初始化卡拉OK控制器
this.setupKaraokeView()       ;
}

/**
* 设置卡拉OK控制器
*/
private setupKaraokeView() {
const karaokeEvent: KaraokeEvent = {
onLineFinished: (karaokeView: KaraokeView, line: LyricsLineModel, score: number,
cumulativeScore: number, index: number, lineCount: number) => {
console.log(`歌词行完成: ${line.content}, 得分: ${score}, 累计: ${cumulativeScore}`) ;
},

onDragTo: (karaokeView: KaraokeView, progress: number) => {
console.log(`拖拽到: ${progress}ms`)                     ;
this.currentTime = progress                                 ;
},

onPitchAndScoreUpdate: (speakerPitch: number, scoreAfterNormalization: number, progress: number) => {
console.log(`音调更新: ${speakerPitch}, 得分: ${scoreAfterNormalization}`)                      ;
}
}                                                                                                     ;

this.karaokeView.setKaraokeEvent(karaokeEvent) ;
}

aboutToDisappear() {
this.stopPlayback()  ;
}

/**
* 开始播放
*/
private startPlayback() {
if (this.isPlaying) {
return                    ;
}

this.isPlaying = true            ;
this.timer = setInterval(() => {
this.currentTime += 100          ; // 每100ms更新一次

// 模拟播放结束
if (this.currentTime >= 25000) { // 25秒后停止
this.stopPlayback()                                ;
}
}, 100)                                            ;
}

/**
* 停止播放
*/
private stopPlayback() {
this.isPlaying = false    ;
if (this.timer !== -1) {
clearInterval(this.timer) ;
this.timer = -1           ;
}
}

/**
* 重置播放
*/
private resetPlayback() {
this.stopPlayback()       ;
this.currentTime = 0      ;
}

build() {
Column() {
// 标题区域
Row() {
Text(this.message)
.fontSize(20)
.fontWeight(FontWeight.Bold)
.fontColor('#333333')
}
.width('100%')
.height(60)
.justifyContent(FlexAlign.Center)
.backgroundColor('#FFFFFF')

// 歌词显示区域
if (this.useEnhancedView) {
EnhancedLyricsView({
lyricModel: this.lyricModel,
currentTime: this.currentTime,
noLyricsText: '暂无歌词，请加载歌词文件',
currentLineTextSize: 18,
normalLineTextSize: 14,
currentLineColor: '#FF6B35',
normalLineColor: '#666666',
highlightColor: '#FF6B35',
krcHighlightColor: '#FFD700',
lineSpacing: 12,
animationDuration: 300
})
.layoutWeight(1)
.backgroundColor('#F8F8F8')
} else {
LyricsView({
lyricModel: this.lyricModel,
currentTime: this.currentTime,
noLyricsText: '暂无歌词，请加载歌词文件',
currentLineTextSize: 18,
normalLineTextSize: 14,
currentLineColor: '#FF6B35',
normalLineColor: '#666666',
highlightColor: '#FF6B35',
lineSpacing: 12,
animationDuration: 300
})
.layoutWeight(1)
.backgroundColor('#F8F8F8')
}

// 控制按钮区域
Row({ space: 20 }) {
Button(this.isPlaying ? '暂停' : '播放')
.type(ButtonType.Capsule)
.backgroundColor(this.isPlaying ? '#FF6B35' : '#4CAF50')
.fontSize(16)
.width(80)
.height(40)
.onClick(() => {
if (this.isPlaying) {
this.stopPlayback()                                      ;
} else {
this.startPlayback()                                     ;
}
})

Button('重置')
.type(ButtonType.Capsule)
.backgroundColor('#9E9E9E')
.fontSize(16)
.width(80)
.height(40)
.onClick(() => {
this.resetPlayback()        ;
})

Button('测试LRC')
.type(ButtonType.Capsule)
.backgroundColor('#2196F3')
.fontSize(16)
.width(80)
.height(40)
.onClick(() => {
// 测试LRC解析
const lrcContent = `[ti:测试歌曲]
[ar:测试歌手]
[00:00.50]这是一首测试歌曲
[00:03.00]用来演示歌词组件
[00:06.00]支持LRC格式解析
[00:09.00]可以实时高亮显示
[00:12.00]HarmonyOS真棒！`         ;

this.lyricModel = LyricsParser.parseLRC(lrcContent) ;
this.useEnhancedView = false                        ;
this.resetPlayback()                                ;
})

Button('测试KRC')
.type(ButtonType.Capsule)
.backgroundColor('#9C27B0')
.fontSize(16)
.width(80)
.height(40)
.onClick(() => {
// 测试KRC解析 - 使用示例KRC数据
this.lyricModel = KrcParser.createSampleKrcLyrics() ;
this.useEnhancedView = true                         ;
this.resetPlayback()                                ;
})

Button(this.useEnhancedView ? '标准' : '增强')
.type(ButtonType.Capsule)
.backgroundColor('#607D8B')
.fontSize(16)
.width(80)
.height(40)
.onClick(() => {
this.useEnhancedView = !this.useEnhancedView       ;
})
}
.width('100%')
.height(80)
.justifyContent(FlexAlign.Center)
.backgroundColor('#FFFFFF')

// 时间显示
Row() {
Text(`播放时间: ${Math.floor(this.currentTime / 1000)}s`)
.fontSize(14)
.fontColor('#666666')
}
.width('100%')
.height(40)
.justifyContent(FlexAlign.Center)
.backgroundColor('#F0F0F0')
}
.width('100%')
.height('100%')
.backgroundColor('#F5F5F5')
}
}
