// 根据配置导入
import { KaraokeViewModel } from '../viewmodels/KaraokeViewModel';

// 条件导入：根据 isSdkMode 决定导入方式
// 注意：HarmonyOS 中需要在编译时确定导入，所以这里使用静态导入
import {
  BuildProfile, IS_SDK_MODE, LyricsView, ScoringView, getModeDescription
} from 'lyrics_view';

/**
 * 标准化 MVVM 架构的 Index 页面 (ArkUI V2)
 * 职责：纯 UI 层，只负责数据绑定和渲染
 * 使用 @ComponentV2 + @ObservedV2 响应式系统
 *
 * 布局结构：
 * ┌─────────────────────────┐
 * │ 头部信息 (40px)          │
 * ├─────────────────────────┤
 * │ 评分视图 (200px)         │
 * ├─────────────────────────┤
 * │ 歌词视图 (280px)         │
 * ├─────────────────────────┤
 * │ 状态信息 (60px)          │
 * ├─────────────────────────┤
 * │ 控制按钮 (116px)         │
 * └─────────────────────────┘
 */
@Entry
@ComponentV2
struct Index {
  // ViewModel 实例 - 使用 @ObservedV2 响应式状态管理
  @Local private viewModel: KaraokeViewModel = new KaraokeViewModel();

  aboutToAppear() {
    // 初始化 ViewModel
    this.viewModel.initialize();
  }

  aboutToDisappear() {
    // 销毁 ViewModel，释放资源
    this.viewModel.destroy();
  }

  @Builder
  HeaderBuilder() {
    Row() {
      Column() {
        Text(this.viewModel.songInfo.getDescription())
          .fontSize(12)
          .fontColor('#333333')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`当前模式: ${getModeDescription()}`)
          .fontSize(10)
          .fontColor(IS_SDK_MODE ? '#FF6B35' : '#4CAF50')
          .margin({ top: 2 })

        Text(`版本: ${BuildProfile.HAR_VERSION}`)
          .fontSize(9)
          .fontColor('#666666')
          .margin({ top: 1 })

        Text(`构建: ${BuildProfile.BUILD_MODE_NAME}`)
          .fontSize(8)
          .fontColor('#999999')
          .margin({ top: 1 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(40)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  ScoringViewBuilder() {
    ScoringView({
      enableParticleEffect: true
    })
      .width('100%')
      .height('100%')
  }

  @Builder
  LyricsViewBuilder() {
    LyricsView({
      textSize: 16,
      currentLineTextSize: 20,
      currentLineTextColor: '#FFFF00',
      currentLineHighlightedTextColor: '#FFF44336',
      previousLineTextColor: '#FFFFFF',
      upcomingLineTextColor: '#FFFFFF',
      lineSpacing: 15,
      paddingTop: 15,
      labelWhenNoLyrics: '暂无歌词',
      enableLineWrap: false,
      enableDragging: true,
      enablePreviousLines: true,
      enableUpcomingLines: true,
      enablePreludeEndPositionIndicator: true,
      preludeEndPositionIndicatorPaddingTop: 5,
      preludeEndPositionIndicatorRadius: 4,
      preludeEndPositionIndicatorColor: '#FF6B35',
      textGravity: 0
    })
      .width('100%')
      .height('100%')
  }

  @Builder
  StatusBarBuilder() {
    Column({ space: 8 }) {
      // 播放进度显示
      Row() {
        Text('播放进度: ')
          .fontSize(12)
          .fontColor('#666666')

        Text(this.viewModel.playbackState.playingProgress)
          .fontSize(12)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)

      // 状态信息显示
      Row() {
        // 加载指示器
        if (this.viewModel.uiState.isLoading) {
          LoadingProgress()
            .width(16)
            .height(16)
            .margin({ right: 8 })
        }

        // 状态标签
        Text('状态: ')
          .fontSize(12)
          .fontColor('#666666')

        // 状态文本
        Text(this.viewModel.uiState.callBackInfo || '就绪')
          .fontSize(12)
          .fontColor(this.viewModel.uiState.hasError ? '#FF5722' : '#4CAF50')
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height(60)
    .padding({
      left: 16,
      right: 16,
      top: 8,
      bottom: 8
    })
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ left: 16, right: 16, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  MainControlButtonsBuilder() {
    Row({ space: 8 }) {
      Button(this.viewModel.playbackState.isPlaying ? '暂停' : '播放')
        .fontSize(14)
        .backgroundColor(this.viewModel.playbackState.isPlaying ? '#FF9800' : '#4CAF50')
        .enabled(!this.viewModel.uiState.isLoading)
        .onClick(() => {
          if (this.viewModel.playbackState.isPlaying) {
            this.viewModel.pausePlayback();
          } else {
            this.viewModel.startPlayback();
          }
        })

      Button('切歌')
        .fontSize(14)
        .backgroundColor('#2196F3')
        .enabled(!this.viewModel.uiState.isLoading)
        .onClick(() => {
          this.viewModel.switchToNext();
        })

      Button('跳过前奏')
        .fontSize(14)
        .backgroundColor('#9C27B0')
        .enabled(!this.viewModel.uiState.isLoading && this.viewModel.songInfo.hasLyrics())
        .onClick(() => {
          this.viewModel.skipIntro();
        })
    }
    .width('100%')
    .height(50)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  SecondaryControlButtonsBuilder() {
    Row({ space: 8 }) {
      Button(this.viewModel.playbackState.isOriginalTrack ? '伴唱' : '原唱')
        .fontSize(14)
        .backgroundColor('#607D8B')
        .enabled(!this.viewModel.uiState.isLoading)
        .onClick(() => {
          this.viewModel.toggleOriginalTrack();
        })

      Button('设置')
        .fontSize(14)
        .backgroundColor('#795548')
        .onClick(() => {
          // 设置功能 - 可以扩展
          this.viewModel.uiState.setSuccess('设置功能待实现');
        })
    }
    .width('100%')
    .height(50)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ControlButtonsBuilder() {
    Column({ space: 8 }) {
      // 主要控制按钮
      this.MainControlButtonsBuilder()

      // 次要控制按钮
      this.SecondaryControlButtonsBuilder()
    }
    .padding({ bottom: 8 })
  }

  build() {
    Stack() {
      Column() {
        // 头部信息
        this.HeaderBuilder()

        // 评分视图区域
        Row() {
          this.ScoringViewBuilder()
        }
        .width('100%')
        .height(200)
        .margin({ bottom: 20 })

        // 歌词视图区域（纯净，无覆盖层）
        Row() {
          this.LyricsViewBuilder()
        }
        .width('100%')
        .height(280)
        .margin({ bottom: 10 })

        // 状态信息区域（独立区域）
        this.StatusBarBuilder()

        // 控制按钮区域
        this.ControlButtonsBuilder()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
