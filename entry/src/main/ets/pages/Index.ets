import { hilog } from '@kit.PerformanceAnalysisKit';
import fs from '@ohos.file.fs';
import {
  IKaraokeEvent,
  KaraokeView,
  LyricModel,
  LyricsLineModel,
  LyricsView,
  ScoringView,
  Utils
} from 'lyrics_view';
import { contextManager } from '../utils/ContextManager';

const TAG = 'Index';

class IndexKaraokeEventImpl implements IKaraokeEvent {
  private indexComponent: Index;

  constructor(indexComponent: Index) {
    this.indexComponent = indexComponent;
  }

  onKaraokeReady(): void {
    this.indexComponent.handleKaraokeReady();
  }

  onDragTo(position: number): void {
    this.indexComponent.handleDragTo(position);
  }

  onLineFinished(line: LyricsLineModel, score: number, cumulativeScore: number, index: number,
    lineCount: number): void {
    this.indexComponent.handleLineFinished(line, score, cumulativeScore, index, lineCount);
  }
}

@Entry
@Component
struct Index {
  @State lyricsDescription: string = '';
  @State playingProgress: string = '0ms';
  @State callBackInfo: string = '';
  @State currentTime: number = 0;
  @State isPlaying: boolean = false;
  @State currentSongIndex: number = 0;
  @State isOriginalTrack: boolean = false;
  // 卡拉OK相关
  private karaokeView: KaraokeView | null = null;
  @State lyricModel: LyricModel | null = null;
  // 移除组件引用，采用事件驱动的方式
  private timer: number = -1;
  private songList: string[] = ['十年', '月亮代表我的心', '童话'];

  aboutToAppear() {
    this.updateLyricsDescription();
    this.initKaraokeView();
  }

  /**
   * 初始化KaraokeView，在组件实例创建后调用
   */
  private initKaraokeView() {
    try {
      this.karaokeView = new KaraokeView();
      this.karaokeView.setKaraokeEvent(new IndexKaraokeEventImpl(this));
      this.logDebug('KaraokeView initialized successfully');
    } catch (error) {
      this.logDebug(`Failed to initialize KaraokeView: ${error}`);
    }
  }

  aboutToDisappear() {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  /**
   * 处理卡拉OK准备就绪事件
   */
  public handleKaraokeReady() {
    this.logDebug('Karaoke components are ready');
    this.callBackInfo = '卡拉OK组件已准备就绪';
    // 自动加载歌曲
    this.loadSong();
  }

  /**
   * 加载歌曲数据
   */
  private async loadSong() {
    try {
      await this.copyRawFilesToPrivate();
      await this.loadCurrentSong();
      this.callBackInfo = '歌曲加载完成';
    } catch (error) {
      this.logDebug(`Failed to load song: ${error}`);
      this.callBackInfo = `加载失败: ${error}`;
    }
  }

  /**
   * 调试日志输出
   */
  private logDebug(message: string): void {
    hilog.debug(0x0000, TAG, `%{public}s`, message);
  }

  /**
   * 确保lyrics目录存在
   */
  private async ensureLyricsDirectory(): Promise<string> {
    try {
      const lyricsDir = `${contextManager.getFilesDir()}/lyrics`;

      this.logDebug(`App files directory: ${contextManager.getFilesDir()}`);
      this.logDebug(`Checking lyrics directory: ${lyricsDir}`);

      // 检查目录是否存在
      if (!fs.accessSync(lyricsDir)) {
        this.logDebug(`Creating lyrics directory: ${lyricsDir}`);
        fs.mkdirSync(lyricsDir);
        this.logDebug(`Successfully created lyrics directory`);
        this.callBackInfo = `已创建歌词目录`;
      } else {
        this.logDebug(`Lyrics directory already exists`);
        this.callBackInfo = `歌词目录已存在`;
      }

      return lyricsDir;
    } catch (error) {
      this.logDebug(`Failed to ensure lyrics directory: ${error}`);
      throw new Error(`Failed to ensure lyrics directory: ${error}`);
    }
  }

  /**
   * 将内容写入私有目录文件
   */
  private async writePrivateFile(filePath: string, content: string): Promise<void> {
    try {
      const file = fs.openSync(filePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE);
      const buffer = Utils.stringToUint8Array(content);
      fs.writeSync(file.fd, buffer.buffer as ArrayBuffer);
      fs.closeSync(file);

      this.logDebug(`Successfully wrote file: ${filePath}`);
    } catch (error) {
      this.logDebug(`Failed to write file ${filePath}: ${error}`);
      throw new Error(`Failed to write file ${filePath}: ${error}`);
    }
  }

  /**
   * 从rawfile复制文件到私有目录
   */
  private async copyRawFilesToPrivate(): Promise<void> {
    try {
      const lyricsDir = await this.ensureLyricsDirectory();

      // 定义要复制的文件列表
      const filesToCopy = [
        '4875936889260991133.krc',
        '4875936889260991133.pitch'
      ];

      for (const fileName of filesToCopy) {
        const targetPath = `${lyricsDir}/${fileName}`;

        // 检查文件是否已存在，避免重复复制
        if (fs.accessSync(targetPath)) {
          this.logDebug(`File already exists, skipping: ${targetPath}`);
          continue;
        }

        try {
          // 使用Utils直接从rawfile读取内容
          const content = await Utils.loadAsString(contextManager.getContext(), fileName);
          if (!content) {
            throw new Error(`Failed to load rawfile: ${fileName}`);
          }

          // 使用Utils写入文件
          await this.writePrivateFile(targetPath, content);

          this.logDebug(`Successfully copied ${fileName} to ${targetPath}`);

        } catch (error) {
          this.logDebug(`Failed to copy ${fileName}: ${error}`);
          // 继续处理其他文件，不中断整个流程
        }
      }

      this.callBackInfo = `文件复制完成`;

      // 列出目录内容进行验证
      await this.listDirectoryContents(lyricsDir);

    } catch (error) {
      this.logDebug(`Failed to copy raw files: ${error}`);
      this.callBackInfo = `文件复制失败: ${error}`;
      throw new Error(`Failed to copy raw files: ${error}`);
    }
  }

  /**
   * 列出目录内容（调试用）
   */
  private async listDirectoryContents(dirPath: string): Promise<void> {
    try {
      if (fs.accessSync(dirPath)) {
        const files = fs.listFileSync(dirPath);
        this.logDebug(`Directory ${dirPath} contains: ${JSON.stringify(files)}`);
        this.callBackInfo = `目录包含 ${files.length} 个文件`;
      } else {
        this.logDebug(`Directory ${dirPath} does not exist`);
      }
    } catch (error) {
      this.logDebug(`Failed to list directory ${dirPath}: ${error}`);
    }
  }

  /**
   * 加载当前歌曲的KRC文件
   */
  private async loadCurrentSong() {
    try {
      const lyricFilePath = `${contextManager.getFilesDir()}/lyrics/4875936889260991133.krc`;
      const pitchFilePath = `${contextManager.getFilesDir()}/lyrics/4875936889260991133.pitch`;

      this.logDebug(`lyricFilePath: ${lyricFilePath} pitchFilePath: ${pitchFilePath}`);

      // 验证文件是否存在
      if (!fs.accessSync(lyricFilePath)) {
        throw new Error(`KRC file not found: ${lyricFilePath}`);
      }

      if (!fs.accessSync(pitchFilePath)) {
        throw new Error(`Pitch file not found: ${pitchFilePath}`);
      }

      // 1. 使用parseLyrics解析歌词（传入文件路径）
      this.lyricModel = KaraokeView.parseLyrics(lyricFilePath, pitchFilePath, true, 0);

      if (!this.lyricModel) {
        throw new Error('Failed to parse lyrics');
      }

      // 2. 如果KaraokeView已初始化，设置歌词数据
      if (this.karaokeView) {
        this.karaokeView.setLyricData(this.lyricModel, false);
      }

      this.logDebug(`Successfully loaded lyrics with ${this.lyricModel.lines?.length || 0} lines`);

    } catch (error) {
      console.error('Failed to load song:', error);
      this.callBackInfo = `加载失败: ${error}`;
      this.logDebug(`Failed to load song: ${error}`);
    }
  }

  private updateLyricsDescription() {
    this.lyricsDescription = `当前歌曲: ${this.songList[this.currentSongIndex]} `;
  }

  private startPlayback() {
    if (this.isPlaying) {
      return;
    }

    if (!this.lyricModel) {
      this.callBackInfo = '请先加载歌词文件';
      return;
    }

    this.isPlaying = true;
    // 使用20ms间隔的定时器，更精确地模拟播放
    this.timer = setInterval(() => {
      this.currentTime += 20; // 每20ms增加20ms
      this.playingProgress = `${this.currentTime}ms`;

      // 调用KaraokeView的setProgress方法（这会触发LyricMachine.setProgress → LyricsView.requestRefreshUi → updateByProgress）
      if (this.karaokeView) {
        this.karaokeView.setProgress(this.currentTime);
      }

      // 模拟播放结束（3分钟）
      if (this.currentTime >= 180000) {
        this.stopPlayback();
      }
    }, 20); // 20ms间隔

    this.callBackInfo = '开始播放';
  }

  private pausePlayback() {
    this.isPlaying = false;
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.callBackInfo = '暂停播放';
  }

  private stopPlayback() {
    this.pausePlayback();
    this.currentTime = 0;
    this.playingProgress = '0ms';
    this.callBackInfo = '停止播放';
  }

  private async switchToNext() {
    this.stopPlayback();
    this.currentSongIndex = (this.currentSongIndex + 1) % this.songList.length;
    this.updateLyricsDescription();
    this.callBackInfo = `正在加载: ${this.songList[this.currentSongIndex]}`;

    // 重新加载新歌曲的KRC文件
    await this.loadCurrentSong();
  }

  private skipIntro() {
    // 同步更新KaraokeView的进度（触发歌词显示更新）
    if (this.lyricModel && this.karaokeView) {
      const preludeEndPosition = this.lyricModel.preludeEndPosition - 1000;
      this.currentTime = preludeEndPosition;
      this.playingProgress = `${preludeEndPosition}ms`;
      this.callBackInfo = '跳过前奏';

      this.karaokeView.setProgress(preludeEndPosition);
    }
  }

  private toggleOriginalTrack() {
    this.isOriginalTrack = !this.isOriginalTrack;
    this.callBackInfo = this.isOriginalTrack ? '切换到原唱' : '切换到伴奏';
  }

  private openSettings() {
    this.callBackInfo = '设置功能待实现';
  }

  /**
   * 处理拖拽到指定位置的事件
   * 这个方法会被IKaraokeEvent.onDragTo调用
   */
  public handleDragTo(finalProgress: number) {
    // 更新当前时间到拖拽的最终位置
    this.currentTime = finalProgress;
    this.playingProgress = `${this.currentTime}ms`;
    this.callBackInfo = `拖拽到: ${this.currentTime}ms`;

    // 同步更新KaraokeView的进度
    if (this.karaokeView) {
      this.karaokeView.setProgress(this.currentTime);
    }
  }

  /**
   * 处理歌词行完成事件
   * 这个方法会被IKaraokeEvent.onLineFinished调用
   */
  public handleLineFinished(line: LyricsLineModel, score: number, cumulativeScore: number, index: number,
    lineCount: number) {
    this.logDebug(`Line ${index} finished with score ${score}`);
    this.callBackInfo = `第${index + 1}行完成，得分: ${score}`;
  }

  @Builder
  LyricsViewBuilder() {
    // 直接使用LyricsView组件，所有逻辑由组件内部处理
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
  ScoringViewBuilder() {
    // 使用真实的ScoringView组件，所有逻辑由组件内部处理
    ScoringView({
      // ScoringView的配置参数
    })
      .width('100%')
      .height('100%')
  }

  build() {
    Stack() {
      Column() {
        // 歌词描述信息
        Row() {
          Text(this.lyricsDescription)
            .fontSize(12)
            .fontColor('#333333')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height(40)
        .padding({ left: 16, right: 16 })
        .justifyContent(FlexAlign.Start)

        // 评分视图区域
        Row() {
          this.ScoringViewBuilder()
        }
        .width('100%')
        .height(300)
        .backgroundColor('#E1BEE7')
        .margin({ bottom: 20 })

        // 歌词视图区域
        Stack() {
          this.LyricsViewBuilder()

          // 播放进度显示
          Text(this.playingProgress)
            .fontSize(12)
            .fontColor('#333333')
            .backgroundColor('#FFFFFF80')
            .padding(4)
            .borderRadius(4)
            .position({ x: 8, y: 0 })
        }
        .width('100%')
        .height(300)
        .backgroundColor('#CE93D8')
        .layoutWeight(1)

        // 回调信息显示
        Row() {
          Text(this.callBackInfo)
            .fontSize(12)
            .fontColor('#333333')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .height(30)
        .padding({ left: 16, right: 16 })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)

        // 主要控制按钮
        Row({ space: 8 }) {
          Button(this.isPlaying ? '暂停' : '播放')
            .fontSize(14)
            .backgroundColor(this.isPlaying ? '#FF9800' : '#4CAF50')
            .onClick(() => {
              if (this.isPlaying) {
                this.pausePlayback();
              } else {
                this.startPlayback();
              }
            })

          Button('切歌')
            .fontSize(14)
            .backgroundColor('#2196F3')
            .onClick(() => {
              this.switchToNext();
            })

          Button('跳过前奏')
            .fontSize(14)
            .backgroundColor('#9C27B0')
            .onClick(() => {
              this.skipIntro();
            })
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center)
        .padding({ bottom: 8 })

        // 次要控制按钮
        Row({ space: 8 }) {
          Button(this.isOriginalTrack ? '伴唱' : '原唱')
            .fontSize(14)
            .backgroundColor('#607D8B')
            .onClick(() => {
              this.toggleOriginalTrack();
            })

          Button('设置')
            .fontSize(14)
            .backgroundColor('#795548')
            .onClick(() => {
              this.openSettings();
            })
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center)
        .padding({ bottom: 8 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
