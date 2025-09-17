import { hilog } from '@kit.PerformanceAnalysisKit';
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import {
  KaraokeView, LyricModel, LyricsView, ScoringView, Utils
} from 'lyrics_view';

@Entry
@Component
struct Index {
  @State lyricsDescription: string = '';
  @State playingProgress: string = '0ms';
  @State callBackInfo: string = '';
  @State currentTime: number = 0;
  @State isPlaying: boolean = false;
  @State enableScoring: boolean = true;
  @State enableLyrics: boolean = true;
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
    this.initializeApp();
  }

  /**
   * 初始化KaraokeView，在组件实例创建后调用
   */
  private initKaraokeView() {
    if (!this.karaokeView) {
      // 创建KaraokeView实例，使用默认构造函数
      this.karaokeView = new KaraokeView();

      // 如果已经有歌词数据，延迟设置以确保事件监听器已准备好
      if (this.lyricModel) {
        setTimeout(() => {
          if (this.karaokeView && this.lyricModel) {
            this.logDebug('Setting lyric data after delay');
            this.karaokeView.setLyricData(this.lyricModel, false);
          }
        }, 50);
      }
    }
  }

  aboutToDisappear() {
    this.stopPlayback();
  }

  /**
   * 初始化应用，创建必要目录并复制文件
   */
  private async initializeApp() {
    try {
      await this.ensureLyricsDirectory();
      await this.copyRawFilesToPrivate();
      await this.loadCurrentSong();
    } catch (error) {
      this.logDebug(`Failed to initialize app: ${error}`);
      this.callBackInfo = `初始化失败: ${error}`;
    }
  }

  private logDebug(message: string) {
    hilog.debug(0x0000, "LyricsView-Main", message);
  }

  /**
   * 确保lyrics目录存在
   */
  private async ensureLyricsDirectory(): Promise<string> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const lyricsDir = `${context.filesDir}/lyrics`;

      this.logDebug(`App files directory: ${context.filesDir}`);
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
      const context = getContext(this) as common.UIAbilityContext;

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
          const content = await Utils.loadAsString(context, fileName);
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
   * 从私有目录读取文件内容
   */
  private async readPrivateFile(fileName: string): Promise<string> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const filePath = `${context.filesDir}/lyrics/${fileName}`;

      const fileBytes = Utils.getFileBytes(filePath);
      if (!fileBytes) {
        throw new Error(`File not found or failed to read: ${fileName}`);
      }

      return Utils.uint8ArrayToString(fileBytes);
    } catch (error) {
      this.logDebug(`Failed to read private file ${fileName}: ${error}`);
      throw new Error(`Failed to read private file ${fileName}: ${error}`);
    }
  }

  /**
   * 加载当前歌曲的KRC文件
   */
  private async loadCurrentSong() {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const lyricFilePath = `${context.filesDir}/lyrics/4875936889260991133.krc`;
      const pitchFilePath = `${context.filesDir}/lyrics/4875936889260991133.pitch`;

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
    this.lyricsDescription = `当前歌曲: ${this.songList[this.currentSongIndex]} | 评分: ${this.enableScoring ? '开启' :
      '关闭'} | 歌词: ${this.enableLyrics ? '开启' : '关闭'}`;
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
    this.currentTime = 15000;
    this.playingProgress = `${this.currentTime}ms`;
    this.callBackInfo = '跳过前奏';

    // 同步更新KaraokeView的进度（触发歌词显示更新）
    if (this.lyricModel && this.karaokeView) {
      this.karaokeView.setProgress(this.currentTime);
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
   * 组件就绪回调 - 简化版本
   */
  private onComponentReady() {
    this.logDebug('Components are ready');
    // 初始化KaraokeView（如果还没有初始化）
    this.initKaraokeView();
  }

  /**
   * 处理组件开关变化
   */
  private onComponentToggle(componentType:
  'lyrics' | 'scoring', enabled:
    boolean
  ) {
    if (componentType === 'lyrics') {
      this.enableLyrics = enabled;
    } else {
      this.enableScoring = enabled;
    }

    this.updateLyricsDescription();

    // 在HarmonyOS中，我们使用状态驱动的方式来控制UI显示
    // 不需要直接传递组件引用给KaraokeView.attachUi
    // 因为我们已经通过@State变量来控制歌词显示了

    this.callBackInfo = `${componentType === 'lyrics' ? '歌词' : '评分'}${enabled ? '开启' : '关闭'}`;

    // 在新架构中，组件状态通过@State变量自动管理
    // KaraokeView会通过事件系统与LyricsView通信
    if (componentType === 'lyrics' && this.karaokeView) {
      this.logDebug(`Lyrics component ${enabled ? 'enabled' : 'disabled'}`);
    }
  }

  @Builder
  LyricsViewBuilder() {
    if (this.enableLyrics && this.lyricModel) {
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
        .onAppear(() => {
          this.logDebug('LyricsView component appeared');
          // 延迟初始化，确保LyricsView的事件监听器已设置
          setTimeout(() => {
            this.onComponentReady();
          }, 100);
        })
    } else if (!this.enableLyrics) {
      Text('歌词已关闭')
        .fontSize(14)
        .fontColor('#999999')
    } else {
      Text('正在加载歌词...')
        .fontSize(14)
        .fontColor('#666666')
    }
  }

  @Builder
  ScoringViewBuilder() {
    if (this.enableScoring) {
      // 使用真实的ScoringView组件，所有逻辑由组件内部处理
      ScoringView({
        // ScoringView的配置参数
      })
        .width('100%')
        .height('100%')
        .onAppear(() => {
          this.logDebug('ScoringView component appeared');
          //this.onComponentReady();
        })
    } else {
      Text('评分已关闭')
        .fontSize(14)
        .fontColor('#999999')
    }
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
        .padding({ left: 8, right: 8, top: 4 })
        .alignItems(VerticalAlign.Top)
        .justifyContent(FlexAlign.Start)

        // 评分视图区域
        Row() {
          this.ScoringViewBuilder()
        }
        .width('100%')
        .height(300)
        .backgroundColor('#FFE0B2')
        .justifyContent(FlexAlign.Center)
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
        .padding({ left: 8, right: 8 })
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)

        // 主要控制按钮
        Row({ space: 8 }) {
          Button('播放')
            .fontSize(14)
            .backgroundColor('#4CAF50')
            .onClick(() => {
              this.startPlayback();
            })

          Button('暂停')
            .fontSize(14)
            .backgroundColor('#FF9800')
            .onClick(() => {
              this.pausePlayback();
            })

          Button('切换歌曲')
            .fontSize(14)
            .backgroundColor('#2196F3')
            .onClick(() => {
              this.switchToNext();
            })
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center)
        .padding({ bottom: 8 })

        // 次要控制按钮
        Row({ space: 8 }) {
          Button('跳过前奏')
            .fontSize(14)
            .backgroundColor('#9C27B0')
            .onClick(() => {
              this.skipIntro();
            })

          Button(this.isOriginalTrack ? '播放伴奏' : '播放原唱')
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

      // 评分开关
      Checkbox({ name: 'enableScoring', group: 'checkboxGroup' })
        .select(this.enableScoring)
        .selectedColor('#2196F3')
        .onChange((value: boolean) => {
          this.onComponentToggle('scoring', value);
        })
        .position({ x: '90%', y: 160 })

      // 歌词开关
      Checkbox({ name: 'enableLyrics', group: 'checkboxGroup' })
        .select(this.enableLyrics)
        .selectedColor('#2196F3')
        .onChange((value: boolean) => {
          this.onComponentToggle('lyrics', value);
        })
        .position({ x: '90%', y: 500 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
