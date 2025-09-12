import { LyricsView, OnLyricsSeekListener } from '../../../../../../lyrics_view/src/main/ets/components/LyricsView';
import { KaraokeView } from '../../../../../../lyrics_view/src/main/ets/KaraokeView';
import { IKaraokeEvent } from '../../../../../../lyrics_view/src/main/ets/IKaraokeEvent';
import { LyricModel } from '../../../../../../lyrics_view/src/main/ets/model/LyricModel';

/**
* 简单的歌词显示示例
* 展示如何在实际项目中使用LyricsView组件
*/
@Entry
@Component
struct SimpleExample {
@State private lyricModel: LyricModel | null = null    ;
@State private currentTime: number = 0                 ;
@State private isPlaying: boolean = false              ;

// 模拟播放器定时器
private playTimer: number = -1 ;

aboutToAppear() {
this.loadLyrics() ;
}

aboutToDisappear() {
this.stopPlayback()  ;
}

/**
* 加载歌词数据
*/
private loadLyrics() {
// 示例KRC歌词内容
const krcContent = `[ti:热烈的少年]
[ar:Big Cole]
[al:热烈的少年]
[offset:0]
[8124,1957]<0,199,0>可<200,198,0>我<398,288,0>生<687,277,0>来<964,298,0>就<1263,293,0>倔<1556,401,0>强
[10566,2045]<0,339,0>是<339,249,0>热<588,338,0>烈<927,293,0>的<1220,344,0>骄<1565,481,0>阳
[12923,2564]<0,196,0>偏<196,241,0>要<438,207,0>向<645,325,0>着<970,291,0>逆<1261,345,0>风<1607,297,0>的<1905,282,0>方<2188,376,0>向
[15579,1767]<0,234,0>拼<234,462,0>命<697,284,0>翱<982,785,0>翔
[17840,1947]<0,168,0>若<168,228,0>是<397,236,0>黑<633,339,0>暗<973,271,0>敢<1245,368,0>抵<1614,334,0>挡
[20117,2146]<0,200,0>便<200,311,0>做<512,207,0>撕<720,408,0>破<1128,284,0>夜<1413,309,0>的<1722,423,0>光`                             ;

try {
// 使用KaraokeView解析歌词
this.lyricModel = KaraokeView.parseLyricContent(krcContent)                             ;
console.info(`歌词加载成功: ${this.lyricModel.name} - ${this.lyricModel.singer}`) ;
} catch (error) {
console.error('歌词加载失败:', error)                                             ;
}
}

/**
* 开始播放
*/
private startPlayback() {
if (this.isPlaying) return ;

this.isPlaying = true                ;
this.playTimer = setInterval(() => {
this.currentTime += 100              ; // 每100ms更新一次

// 模拟歌曲结束
if (this.currentTime >= 25000) { // 25秒后结束
this.stopPlayback()                                ;
}
}, 100)                                            ;
}

/**
* 停止播放
*/
private stopPlayback() {
this.isPlaying = false        ;
if (this.playTimer !== -1) {
clearInterval(this.playTimer) ;
this.playTimer = -1           ;
}
}

/**
* 重置播放
*/
private resetPlayback() {
this.stopPlayback()       ;
this.currentTime = 0      ;
}

/**
* 歌词拖拽监听器
*/
private readonly seekListener: OnLyricsSeekListener = {
onProgressChanged: (progress: number) => {
this.currentTime = progress                             ;
console.info(`拖拽到: ${progress}ms`)                ;
},

onStartTrackingTouch: () => {
console.info('开始拖拽');
// 拖拽时暂停播放
if (this.isPlaying) {
this.stopPlayback()           ;
}
},

onStopTrackingTouch: () => {
console.info('结束拖拽');
// 可以选择是否自动恢复播放
}
}                                       ;

build() {
Column() {
// 标题栏
Row() {
Text('歌词显示示例')
.fontSize(18)
.fontWeight(FontWeight.Bold)
.fontColor('#333333')
}
.width('100%')
.height(50)
.justifyContent(FlexAlign.Center)
.backgroundColor('#FFFFFF')

// 歌词显示区域
LyricsView({
lyricModel: this.lyricModel,
currentTime: this.currentTime,
enableDragging: true,
seekListener: this.seekListener,
currentLineTextSize: 20,
normalLineTextSize: 16,
currentLineColor: '#333333',
normalLineColor: '#999999',
highlightColor: '#FF6B35',
lineSpacing: 16,
noLyricsText: '歌词加载中...'
})
.layoutWeight(1)
.backgroundColor('#F8F8F8')

// 简单的控制栏
Row({ space: 20 }) {
Button('重置')
.fontSize(14)
.backgroundColor('#E0E0E0')
.fontColor('#333333')
.onClick(() => this.resetPlayback())

Button(this.isPlaying ? '暂停' : '播放')
.fontSize(16)
.backgroundColor('#FF6B35')
.fontColor('#FFFFFF')
.onClick(() => {
if (this.isPlaying) {
this.stopPlayback()                          ;
} else {
this.startPlayback()                         ;
}
})

Text(`${Math.floor(this.currentTime / 1000)}s`)
.fontSize(14)
.fontColor('#666666')
}
.width('100%')
.height(60)
.justifyContent(FlexAlign.Center)
.backgroundColor('#FFFFFF')
}
.width('100%')
.height('100%')
.backgroundColor('#F0F0F0')
}
}
