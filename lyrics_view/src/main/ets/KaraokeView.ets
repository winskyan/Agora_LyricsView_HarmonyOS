import { Context } from '@ohos.app.ability.common';
import { IKaraokeEvent } from './IKaraokeEvent';
import { LyricsView, OnLyricsSeekListener } from './components/LyricsView';
import { ScoringView } from './components/ScoringView';
import { LyricMachine } from './internal/LyricMachine';
import { IScoringAlgorithm, ScoringMachine } from './internal/ScoringMachine';
import { LyricsParser } from './internal/parser/LyricsParser';
import { LyricModel } from './model/LyricModel';
import { LyricsLineModel } from './model/LyricsLineModel';
import { LogUtils } from './utils/LogUtils';


/**
* 卡拉OK主控制器 - HarmonyOS版本
* 对应Android项目中的KaraokeView
* 管理歌词显示、评分和不同组件之间的同步
*/
export class KaraokeView {
    /**
    * 卡拉OK事件监听器
    */
    private mKaraokeEvent?: IKaraokeEvent;

    /**
    * 歌词显示组件
    */
    private mLyricsView?: LyricsView;

    /**
    * 歌词控制器
    */
    private mLyricMachine: LyricMachine;

    /**
    * 评分显示组件
    */
    private mScoringView?: ScoringView;

    /**
    * 评分控制器
    */
    private mScoringMachine: ScoringMachine;

    /**
    * 应用上下文 - HarmonyOS版本
    * 对应Android项目中的Context
    */
    private mContext?: Context;

    /**
    * 默认构造函数
    */
    constructor();
    /**
    * 构造函数 - 带上下文
    * @param context 应用上下文
    */
    constructor(context: Context);
    /**
    * 构造函数 - 带歌词和评分视图
    * @param lyricsView 歌词显示视图
    * @param scoringView 评分显示视图
    */
    constructor(lyricsView: LyricsView, scoringView: ScoringView);
    constructor(param1?: Context | LyricsView, param2?: ScoringView) {
        if (!param1) {
            // 默认构造函数
            // 什么都不做，只初始化
        } else if (param2 !== undefined) {
            // 双参数构造函数: LyricsView + ScoringView
            this.mLyricsView = param1 as LyricsView;
            this.mScoringView = param2;
            // 尝试从视图获取context（如果有的话）
            // 注意：HarmonyOS组件可能没有直接的getContext方法
        } else {
            // 单参数构造函数: Context
            this.mContext = param1 as Context;
        }
        this.initialize();
    }

    /**
    * 初始化卡拉OK组件，包括歌词和评分机器
    */
    private initialize(): void {
        LogUtils.d('initialize');

        // 创建歌词机器
        this.mLyricMachine = new LyricMachine({
            resetUi: () => {
                if (this.mLyricsView) {
                    this.mLyricsView.requestRefreshUi();
                }
                if (this.mScoringView) {
                    this.mScoringView.resetPitchIndicatorAndAnimation();
                    this.mScoringView.requestRefreshUi();
                }
            },
            requestRefreshUi: () => {
                if (this.mLyricsView) {
                    this.mLyricsView.requestRefreshUi();
                }
                if (this.mScoringView) {
                    this.mScoringView.requestRefreshUi();
                }
            }
        });

        // 创建评分机器
        this.mScoringMachine = new ScoringMachine({
            onLineFinished: (line: LyricsLineModel, score: number, cumulativeScore: number, index: number, lineCount: number) => {
                LogUtils.d(`onLineFinished line startTime:${line.startTime}, line endTime:${line.endTime}, score:${score}, cumulativeScore:${cumulativeScore}, index:${index}, lineCount:${lineCount}`);

                if (this.mScoringView) {
                    this.mScoringView.resetPitchIndicatorAndAnimationWhenFullLineFinished(score);
                }

                if (this.mKaraokeEvent) {
                    this.mKaraokeEvent.onLineFinished(this, line, score, cumulativeScore, index, lineCount);
                }
            },
            resetUi: () => {
                if (this.mLyricsView) {
                    this.mLyricsView.requestRefreshUi();
                }
                if (this.mScoringView) {
                    this.mScoringView.resetPitchIndicatorAndAnimation();
                    this.mScoringView.requestRefreshUi();
                }
            },
            requestRefreshUi: () => {
                if (this.mLyricsView) {
                    this.mLyricsView.requestRefreshUi();
                }
                if (this.mScoringView) {
                    this.mScoringView.requestRefreshUi();
                }
            }
        });

        // 启用日志功能（如果有上下文）
        if (this.mContext) {
            // 自动使用应用私有目录，类似Android的getExternalFilesDir
            LogUtils.enableLog(this.mContext, true, true);
        }
    }

    /**
    * 重置所有组件到初始状态
    */
    reset(): void {
        LogUtils.d('KaraokeView reset');
        if (this.mLyricsView) {
            this.mLyricsView.reset();
        }
        if (this.mScoringView) {
            this.mScoringView.reset();
        }
        this.mLyricMachine.reset();
        this.mScoringMachine.reset();
    }

    /**
     * Parse lyrics data from file path or byte array
     *
     * @param lyricSource              Lyrics file path (string) or byte data (Uint8Array)
     * @param pitchSource              Pitch file path (string) or byte data (Uint8Array), optional
     * @param includeCopyrightSentence Whether to include copyright information
     * @param lyricOffset              Timing offset for lyrics
     * @return Parsed lyrics model
     */
    static parseLyrics(
        lyricSource: string | Uint8Array,
        pitchSource?: string | Uint8Array,
        includeCopyrightSentence: boolean = true,
        lyricOffset: number = 0
    ): LyricModel | null {
        LogUtils.d(`parseLyrics lyricSource type:${typeof lyricSource}, pitchSource type:${typeof pitchSource}, includeCopyrightSentence:${includeCopyrightSentence}, lyricOffset:${lyricOffset}`);

        try {
            // 根据输入类型分发处理逻辑
            if (typeof lyricSource === 'string') {
                // 处理文件路径
                const pitchPath = typeof pitchSource === 'string' ? pitchSource : undefined;
                return LyricsParser.parseFile(lyricSource, pitchPath, includeCopyrightSentence, lyricOffset);
            } else if (lyricSource instanceof Uint8Array) {
                // 处理字节数组
                const pitchData = pitchSource instanceof Uint8Array ? pitchSource : undefined;
                return LyricsParser.parseLyricData(lyricSource, pitchData, includeCopyrightSentence, lyricOffset);
            } else {
                LogUtils.e('Invalid lyric source type. Expected string or Uint8Array.');
                return null;
            }
        } catch (error) {
            LogUtils.e(`parseLyrics error: ${error}`);
            return null;
        }
    }
    /**
     * Attach UI components to the karaoke view
     *
     * @param lyrics  Lyrics view component
     * @param scoring Scoring view component
     * @throws IllegalStateException if called before initialization
     */
    attachUi(lyrics?: LyricsView, scoring?: ScoringView): void {
        LogUtils.d(`attachUi lyrics:${lyrics}, scoring:${scoring}`);

        if (!this.mLyricMachine) {
            throw new Error('Call this after KaraokeView initialized, this is a convenient method for attach/detach on-the-fly');
        }

        if (!this.mScoringMachine) {
            throw new Error('Call this after KaraokeView initialized, this is a convenient method for attach/detach on-the-fly');
        }

        // 处理评分视图
        if (scoring && this.mScoringView !== scoring) {
            if (this.mScoringView) {
                this.mScoringView.reset();
            }
            this.mScoringView = scoring;
        } else if (!scoring) {
            if (this.mScoringView) {
                this.mScoringView.reset();
            }
            this.mScoringView = undefined;
        }

        // 处理歌词视图
        if (lyrics && this.mLyricsView !== lyrics) {
            if (this.mLyricsView) {
                this.mLyricsView.reset();
            }
            this.mLyricsView = lyrics;
        } else if (!lyrics) {
            if (this.mLyricsView) {
                this.mLyricsView.reset();
            }
            this.mLyricsView = undefined;
        }

        // 附加到机器
        if (this.mLyricsView) {
            // TODO: 实现附加到歌词机器的逻辑
        }

        if (this.mScoringView) {
            this.mScoringView.attachToScoreMachine(this.mScoringMachine);
        }
    }

    /**
     * Set lyrics data and initialize scoring system
     *
     * @param model                Lyrics model containing timing and text data
     * @param usingInternalScoring Whether to use internal scoring algorithm
     */
    setLyricData(model: LyricModel, usingInternalScoring: boolean = true): void {
        LogUtils.d(`setLyricData model:${model}`);
        this.mLyricMachine.prepare(model);
        this.mScoringMachine.prepare(model, usingInternalScoring);

        if (this.mLyricsView) {
            // TODO: 实现附加到歌词机器的逻辑
        }

        if (this.mScoringView) {
            this.mScoringView.attachToScoreMachine(this.mScoringMachine);
        }

        this.mLyricMachine.prepareUi();
        this.mScoringMachine.prepareUi();
    }

    /**
     * Get current lyrics data model
     *
     * @return Current lyrics model
     */
    getLyricData(): LyricModel | null {
        return this.mLyricMachine.getLyricsModel();
    }

    /**
     * Set real-time pitch data from microphone input
     * Note: Can be obtained from AgoraRTC DRM callback method 'onPitch' (50ms interval)
     *
     * @param speakerPitch Current pitch value from singer (Hz, typically 80-2000)
     * @param pitchScore   Current pitch score (0.0 to 100.0, float precision)
     * @param progressInMs Current progress timestamp in milliseconds (integer)
     */
    setPitch(speakerPitch: number, pitchScore: number, progressInMs: number): void {
        if (speakerPitch < 0 || speakerPitch > 5000) {
            LogUtils.w(`Invalid speaker pitch: ${speakerPitch}, expected 0-5000 Hz`);
        }
        if (pitchScore < 0 || pitchScore > 100) {
            LogUtils.w(`Invalid pitch score: ${pitchScore}, expected 0.0-100.0`);
        }
        if (progressInMs < 0) {
            LogUtils.w(`Invalid progress: ${progressInMs}, expected >= 0`);
        }

        LogUtils.d(`setPitch speakerPitch:${speakerPitch.toFixed(2)}Hz, pitchScore:${pitchScore.toFixed(1)}%, progressInMs:${Math.floor(progressInMs)}ms`);
        if (this.mScoringMachine) {
            this.mScoringMachine.setPitch(speakerPitch, pitchScore, progressInMs);
        }
    }

    /**
     * Set current song progress (should be called every 20ms)
     * Note: Can be obtained from the player's current progress
     *
     * @param progress Current song progress in milliseconds
     */
    setProgress(progress: number): void {
        LogUtils.d(`setProgress progress:${progress}`);
        this.mLyricMachine.setProgress(progress);
        this.mScoringMachine.setLyricProgress(progress);
    }

    /**
     * Set event listener for karaoke callbacks
     *
     * @param event Karaoke event listener
     */
    setKaraokeEvent(event: IKaraokeEvent): void {
        LogUtils.d(`setKaraokeEvent event:${event}`);
        this.mKaraokeEvent = event;

        if (this.mLyricsView) {
            const seekListener: OnLyricsSeekListener = {
                onProgressChanged: (progress: number) => {
                    if (this.mKaraokeEvent) {
                        this.mKaraokeEvent.onDragTo(this, progress);
                    }
                    this.mLyricMachine.whenDraggingHappen(progress);
                    this.mScoringMachine.whenDraggingHappen(progress);
                },
                onStartTrackingTouch: () => {
                    // 开始拖拽
                },
                onStopTrackingTouch: () => {
                    // 停止拖拽
                }
            };
            this.mLyricsView.setSeekListener(seekListener);
        }
    }

    /**
     * Set custom scoring algorithm
     *
     * @param algorithm Custom scoring algorithm implementation
     */
    setScoringAlgorithm(algorithm: IScoringAlgorithm): void {
        LogUtils.d(`setScoringAlgorithm algorithm:${algorithm}`);
        if (this.mScoringMachine) {
            this.mScoringMachine.setScoringAlgorithm(algorithm);
        }
    }

    /**
     * Set scoring difficulty level
     *
     * @param level Scoring difficulty level
     */
    setScoringLevel(level: number): void {
        LogUtils.d(`setScoringLevel level:${level}`);
        if (this.mScoringMachine) {
            this.mScoringMachine.setScoringLevel(level);
        }
    }

    /**
     * Get current scoring difficulty level
     *
     * @return Current scoring level, defaults to 15
     */
    getScoringLevel(): number {
        LogUtils.d(`getScoringLevel`);
        if (this.mScoringMachine) {
            return this.mScoringMachine.getScoringLevel();
        }
        return 15;
    }

    /**
     * Add custom logger
     *
     * @param logger Logger implementation to add
     */
    addLogger(logger: any): void {
        // TODO: 实现日志记录器添加逻辑
        LogUtils.i('addLogger not implemented yet');
    }

    /**
     * Remove custom logger
     *
     * @param logger Logger implementation to remove
     */
    removeLogger(logger: any): void {
        // TODO: 实现日志记录器移除逻辑
        LogUtils.i('removeLogger not implemented yet');
    }

    /**
     * Remove all custom loggers
     */
    removeAllLogger(): void {
        // TODO: 实现移除所有日志记录器逻辑
        LogUtils.i('removeAllLogger not implemented yet');
    }
}
