import { LyricsView, OnLyricsSeekListener } from '../../../../../../lyrics_view/src/main/ets/components/LyricsView';
import { KaraokeView } from '../../../../../../lyrics_view/src/main/ets/KaraokeView';
import { IKaraokeEvent } from '../../../../../../lyrics_view/src/main/ets/IKaraokeEvent';
import { KrcParser } from '../../../../../../lyrics_view/src/main/ets/parser/KrcParser';
import { LyricModel } from '../../../../../../lyrics_view/src/main/ets/model/LyricModel';
import { LyricsLineModel } from '../../../../../../lyrics_view/src/main/ets/model/LyricsLineModel';
import { LyricType } from '../../../../../../lyrics_view/src/main/ets/constants/LyricType';

/**
* 歌词显示测试页面
* 用于测试KRC歌词解析和UI显示功能
*/
@Entry
@Component
struct LyricsTestPage {
@State private lyricModel: LyricModel | null = null ;
@State private currentTime: number = 0              ;
@State private isPlaying: boolean = false           ;
@State private duration: number = 180000            ; // 3分钟
@State private playbackSpeed: number = 1.0          ;

// 定时器ID
private timerId: number = -1 ;

// 测试用的KRC歌词内容
private readonly testKrcContent = `[ti:热烈的少年 (是热烈)]
[ar:Big Cole]
[al:热烈的少年 (是热烈)]
[by:v_pxjwang]
[offset:0]
[0,737]<0,67,0>热<67,67,0>烈<134,67,0>的<201,67,0>少<268,67,0>年 <335,67,0>(是<402,67,0>热<469,67,0>烈)<536,67,0> - <603,67,0>Big <670,67,0>Cole
[737,536]<0,67,0>词：<67,67,0>翟<134,67,0>思<201,67,0>伟<268,67,0>/<335,67,0>胡<402,67,0>静<469,67,0>宜
[1273,536]<0,67,0>曲：<67,67,0>胡<134,67,0>静<201,67,0>宜<268,67,0>/<335,67,0>翟<402,67,0>思<469,67,0>伟
[8124,1957]<0,199,0>可<200,198,0>我<398,288,0>生<687,277,0>来<964,298,0>就<1263,293,0>倔<1556,401,0>强
[10566,2045]<0,339,0>是<339,249,0>热<588,338,0>烈<927,293,0>的<1220,344,0>骄<1565,481,0>阳
[12923,2564]<0,196,0>偏<196,241,0>要<438,207,0>向<645,325,0>着<970,291,0>逆<1261,345,0>风<1607,297,0>的<1905,282,0>方<2188,376,0>向
[15579,1767]<0,234,0>拼<234,462,0>命<697,284,0>翱<982,785,0>翔
[17840,1947]<0,168,0>若<168,228,0>是<397,236,0>黑<633,339,0>暗<973,271,0>敢<1245,368,0>抵<1614,334,0>挡
[20117,2146]<0,200,0>便<200,311,0>做<512,207,0>撕<720,408,0>破<1128,284,0>夜<1413,309,0>的<1722,423,0>光
[22607,3241]<0,284,0>我<285,415,0>在<700,234,0>属<935,342,0>于<1278,260,0>我<1539,394,0>的<1933,256,0>舞<2189,314,0>台<2504,215,0>之<2720,522,0>上
[25978,3352]<0,277,0>无<278,2107,0>畏 <2386,245,0>绽<2631,721,0>放`                                                                                      ;

aboutToAppear() {
this.loadTestLyrics() ;
}

aboutToDisappear() {
this.stopPlayback()  ;
}

/**
* 加载测试歌词
*/
private loadTestLyrics() {
try {
// 使用KrcParser解析测试歌词
this.lyricModel = KrcParser.parseKRC(this.testKrcContent)                           ;
console.info(`Loaded lyrics: ${this.lyricModel.name} by ${this.lyricModel.singer}`) ;
console.info(`Total lines: ${this.lyricModel.lines.length}`)                        ;

if (this.lyricModel.lines.length > 0) {
this.duration = this.lyricModel.duration || 180000  ;
}
} catch (error) {
console.error('Failed to load test lyrics:', error) ;
// 如果解析失败，使用示例歌词
this.lyricModel = KrcParser.createSampleKrcLyrics() ;
}
}

/**
* 开始播放
*/
private startPlayback() {
if (this.isPlaying) return ;

this.isPlaying = true                       ;
this.timerId = setInterval(() => {
this.currentTime += 50 * this.playbackSpeed ; // 每50ms更新一次

if (this.currentTime >= this.duration) {
this.stopPlayback()                      ;
this.currentTime = this.duration         ;
}
}, 50)                                   ;
}

/**
* 停止播放
*/
private stopPlayback() {
this.isPlaying = false      ;
if (this.timerId !== -1) {
clearInterval(this.timerId) ;
this.timerId = -1           ;
}
}

/**
* 暂停播放
*/
private pausePlayback() {
this.stopPlayback()       ;
}

/**
* 重置播放
*/
private resetPlayback() {
this.stopPlayback()       ;
this.currentTime = 0      ;
}

/**
* 跳转到指定时间
*/
private seekTo(time: number) {
this.currentTime = Math.max(0, Math.min(time, this.duration)) ;
}

/**
* 格式化时间显示
*/
private formatTime(timeMs: number): string {
const totalSeconds = Math.floor(timeMs / 1000)                                          ;
const minutes = Math.floor(totalSeconds / 60)                                           ;
const seconds = totalSeconds % 60                                                       ;
return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
}

/**
* 歌词拖拽监听器
*/
private readonly seekListener: OnLyricsSeekListener = {
onProgressChanged: (progress: number) => {
console.info(`Seek to: ${progress}ms`)                  ;
this.seekTo(progress)                                   ;
},

onStartTrackingTouch: () => {
console.info('Start tracking touch');
this.pausePlayback()                  ;
},

onStopTrackingTouch: () => {
console.info('Stop tracking touch');
// 可以选择是否自动恢复播放
}
}                                       ;

/**
* 控制面板
*/
@Builder
ControlPanel() {
Column({ space: 16 }) {
// 歌曲信息
Column({ space: 8 }) {
Text(this.lyricModel?.name || '未知歌曲')
.fontSize(18)
.fontWeight(FontWeight.Bold)
.fontColor('#333333')

Text(this.lyricModel?.singer || '未知歌手')
.fontSize(14)
.fontColor('#666666')
}
.alignItems(HorizontalAlign.Center)

// 进度条
Column({ space: 8 }) {
Slider({
value: this.currentTime,
min: 0,
max: this.duration,
step: 1000
})
.width('100%')
.trackColor('#E0E0E0')
.selectedColor('#FF6B35')
.onChange((value: number) => {
this.seekTo(value)             ;
})

Row() {
Text(this.formatTime(this.currentTime))
.fontSize(12)
.fontColor('#666666')

Spacer()

Text(this.formatTime(this.duration))
.fontSize(12)
.fontColor('#666666')
}
.width('100%')
}

// 播放控制按钮
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
this.pausePlayback()                         ;
} else {
this.startPlayback()                         ;
}
})

Button('快进')
.fontSize(14)
.backgroundColor('#E0E0E0')
.fontColor('#333333')
.onClick(() => this.seekTo(this.currentTime + 10000))
}
.justifyContent(FlexAlign.Center)

// 播放速度控制
Row({ space: 10 }) {
Text('播放速度:')
.fontSize(14)
.fontColor('#666666')

Button('0.5x')
.fontSize(12)
.backgroundColor(this.playbackSpeed === 0.5 ? '#FF6B35' : '#E0E0E0')
.fontColor(this.playbackSpeed === 0.5 ? '#FFFFFF' : '#333333')
.onClick(() => this.playbackSpeed = 0.5)

Button('1.0x')
.fontSize(12)
.backgroundColor(this.playbackSpeed === 1.0 ? '#FF6B35' : '#E0E0E0')
.fontColor(this.playbackSpeed === 1.0 ? '#FFFFFF' : '#333333')
.onClick(() => this.playbackSpeed = 1.0)

Button('2.0x')
.fontSize(12)
.backgroundColor(this.playbackSpeed === 2.0 ? '#FF6B35' : '#E0E0E0')
.fontColor(this.playbackSpeed === 2.0 ? '#FFFFFF' : '#333333')
.onClick(() => this.playbackSpeed = 2.0)
}
.justifyContent(FlexAlign.Center)

// 测试信息
Column({ space: 4 }) {
Text(`当前时间: ${this.currentTime}ms`)
.fontSize(12)
.fontColor('#999999')

Text(`歌词行数: ${this.lyricModel?.lines.length || 0}`)
.fontSize(12)
.fontColor('#999999')

Text(`歌词类型: ${this.lyricModel?.type || 'Unknown'}`)
.fontSize(12)
.fontColor('#999999')
}
.alignItems(HorizontalAlign.Center)
}
.width('100%')
.padding(16)
.backgroundColor('#FFFFFF')
.borderRadius(8)
}

build() {
Column() {
// 标题栏
Row() {
Text('歌词显示测试')
.fontSize(20)
.fontWeight(FontWeight.Bold)
.fontColor('#333333')
}
.width('100%')
.height(56)
.justifyContent(FlexAlign.Center)
.backgroundColor('#FFFFFF')
.border({ width: { bottom: 1 }, color: '#E0E0E0' })

// 歌词显示区域
LyricsView({
lyricModel: this.lyricModel,
currentTime: this.currentTime,
enableDragging: true,
seekListener: this.seekListener,
currentLineTextSize: 22,
normalLineTextSize: 18,
currentLineColor: '#333333',
normalLineColor: '#999999',
highlightColor: '#FF6B35',
lineSpacing: 16,
animationDuration: 300,
paddingTop: 60,
noLyricsText: '正在加载歌词...'
})
.layoutWeight(1)
.backgroundColor('#F8F8F8')

// 控制面板
this.ControlPanel()
}
.width('100%')
.height('100%')
.backgroundColor('#F0F0F0')
}
}
