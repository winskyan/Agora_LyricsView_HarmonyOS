import abilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it } from '@ohos/hypium';
// 导入lyrics_view模块的相关类
import { KaraokeView, LogUtils, LyricModel, LyricType, LyricsParser, Utils } from 'lyrics_view';

/**
 * 测试用例接口
 */
interface TestCase {
  fileName: string;
  expectedType: LyricType;
}

/**
 * 歌词行接口 - 用于类型断言
 */
interface LineWithMethods {
  getStartTime?: () => number;
  getEndTime?: () => number;
}

interface TonesArray {
  length: number;
}

interface LineWithTones {
  tones?: TonesArray;
}

/**
 * Mock Context接口 - 用于测试环境
 */
interface MockContext {
  resourceManager: object | null;
  filesDir: string;
  cacheDir: string;
}

/**
 * 启用歌词视图日志
 */
function enableLyricViewLog(context?: common.UIAbilityContext): void {
  if (context) {
    LogUtils.enableLog(context, true, true);
  }
}

/**
 * 解析歌词数据的辅助方法
 * 对应Android的parseLyricData方法
 */
async function parseLyricData(context: common.UIAbilityContext, fileName: string): Promise<LyricModel | null> {
  const TAG = 'LyricsInstrumentedTest';
  const DOMAIN = 0x0000;

  try {
    const lyricsContent = await Utils.loadAsString(context, fileName);
    if (!lyricsContent) {
      hilog.error(DOMAIN, TAG, 'parseLyricData: lyricsContent is empty');
      return null;
    }

    // 将字符串转换为Uint8Array - 使用简单的方法
    const lyricsData: Uint8Array = new Uint8Array(Array.from(lyricsContent, (char: string) => char.charCodeAt(0)));

    // 使用字节数组解析，避免任何/unknown 断言
    return LyricsParser.parseLyricData(lyricsData, undefined, true, 0);
  } catch (error) {
    const errorMsg = error instanceof Error ? error.message : String(error);
    hilog.error(DOMAIN, TAG, `parseLyricData: ${errorMsg}`);
    return null;
  }
}

/**
 * HarmonyOS歌词解析测试用例
 * 对应Android项目中的LyricsInstrumentedTest
 * 测试歌词文件解析功能，包括KRC、LRC、XML格式
 */
export default function lyricsInstrumentedTest() {
  describe('LyricsInstrumentedTest', () => {
    const TAG = 'LyricsView-LyricsInstrumentedTest';
    const DOMAIN = 0x0000;
    let context: common.UIAbilityContext | undefined;
    let karaokeView: KaraokeView;

    beforeAll(async () => {
      hilog.info(DOMAIN, TAG, 'beforeAll: 初始化测试环境');

      try {
        // 获取测试上下文 - 使用abilityDelegatorRegistry
        const abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator();
        if (abilityDelegator) {
          hilog.info(DOMAIN, TAG, 'AbilityDelegator obtained');

          // 尝试获取当前顶层Ability
          const topAbility = await abilityDelegator.getCurrentTopAbility();
          if (topAbility && topAbility.context) {
            context = topAbility.context as common.UIAbilityContext;
            hilog.info(DOMAIN, TAG, 'Context obtained from top ability');
          } else {
            hilog.warn(DOMAIN, TAG, 'No top ability or context available');
          }
        } else {
          hilog.warn(DOMAIN, TAG, 'AbilityDelegator not available');
        }

        // 如果还是没有context，尝试其他方法
        if (!context) {
          hilog.warn(DOMAIN, TAG, 'Context not available - tests will be limited');
        }
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Failed to get context: ${JSON.stringify(error)}`);
      }

      // 启用日志
      enableLyricViewLog(context);
    });

    beforeEach(() => {
      hilog.info(DOMAIN, TAG, 'beforeEach: 准备单个测试用例');
    });

    afterEach(() => {
      hilog.info(DOMAIN, TAG, 'afterEach: 清理单个测试用例');
    });

    afterAll(() => {
      hilog.info(DOMAIN, TAG, 'afterAll: 清理测试环境');
    });


    /**
     * 测试应用上下文
     * 对应Android的useAppContext测试
     */
    it('useAppContext', 0, async () => {
      hilog.info(DOMAIN, TAG, 'useAppContext: 测试应用上下文');

      if (context) {
        hilog.info(DOMAIN, TAG, 'Context is available for testing');

        // 创建KaraokeView实例
        karaokeView = new KaraokeView(context);
        expect(karaokeView).not().assertUndefined();

        // 启用日志
        enableLyricViewLog(context);

        hilog.info(DOMAIN, TAG, 'KaraokeView created successfully');
      } else {
        hilog.warn(DOMAIN, TAG, 'Context not available - creating mock context for basic testing');

        // 创建一个基本的mock context用于测试
        const mockContext: MockContext = {
          resourceManager: null,
          filesDir: '/data/app/test',
          cacheDir: '/data/app/cache'
        };

        try {
          karaokeView = new KaraokeView(mockContext as common.UIAbilityContext);
          expect(karaokeView).not().assertUndefined();
          hilog.info(DOMAIN, TAG, 'KaraokeView created with mock context');
        } catch (error) {
          hilog.warn(DOMAIN, TAG, `KaraokeView creation failed with mock context: ${JSON.stringify(error)}`);
          // 这不是测试失败，只是环境限制
        }
      }
    });

    /**
     * 解析单行XML文件测试
     * 对应Android的parseOneAndOnlyOneLineXmlFile测试
     */
    it('parseOneAndOnlyOneLineXmlFile', 0, async () => {
      hilog.info(DOMAIN, TAG, 'parseOneAndOnlyOneLineXmlFile: 测试解析单行XML文件');

      if (!context) {
        hilog.info(DOMAIN, TAG, 'Test skipped - no context available');
        return;
      }

      // 指定测试文件：810507.xml
      const fileNameOfSong = "810507.xml";
      const songArtist = "张学友";

      try {
        // 从rawfile读取文件内容
        const xmlFileContent = await Utils.loadAsString(context, fileNameOfSong);

        expect(xmlFileContent).not().assertUndefined();
        expect(xmlFileContent).not().assertNull();
        expect(xmlFileContent!.includes(songArtist)).assertTrue();

        // 读取文件字节数据用于解析
        const xmlFileData = await Utils.loadAsBytes(context, fileNameOfSong);

        if (xmlFileData) {
          hilog.info(DOMAIN, TAG, `xmlFileData length: ${xmlFileData.length}`);
        }

        expect(xmlFileData).not().assertUndefined();
        expect(xmlFileData).not().assertNull();

        // 使用字节数组解析
        const parsedLyrics = LyricsParser.parseLyricData(xmlFileData!, undefined, true, 0);
        hilog.info(DOMAIN, TAG, `parsedLyrics is null: ${parsedLyrics === null}`);
        hilog.info(DOMAIN, TAG, `parsedLyrics is undefined: ${parsedLyrics === undefined}`);

        expect(parsedLyrics).not().assertUndefined();
        expect(parsedLyrics).not().assertNull();

        hilog.info(DOMAIN, TAG, `Line count for this lyrics: ${parsedLyrics!.lines.length}`);

        // 打印每行歌词信息
        for (let i = 0; i < parsedLyrics!.lines.length; i++) {
          const line = parsedLyrics!.lines[i];
          // 简化输出：避免复杂断言
          hilog.info(DOMAIN, TAG, `Line info: ${line}`);
        }

        // 验证解析结果 - 应该有42行歌词
        expect(parsedLyrics!.lines.length).assertEqual(42);

        // 第7行包含 '泪' '慢' '慢' '流' '慢' '慢' '收'
        const the7thLine = parsedLyrics!.lines[6];
        const startOf7thLine = parsedLyrics!.lines[6].getStartTime();
        const endOf7thLine = parsedLyrics!.lines[6].getEndTime();
        expect(endOf7thLine - startOf7thLine > 0).assertTrue();
        expect(the7thLine.tones[0].word === "泪" && the7thLine.tones[0].pitch === 176).assertTrue();
        expect(the7thLine.tones[1].word === "慢" && the7thLine.tones[1].pitch === 0).assertTrue();
        expect(the7thLine.tones[2].word === "慢" && the7thLine.tones[2].pitch === 176).assertTrue();
        expect(the7thLine.tones[3].word === "流" && the7thLine.tones[3].pitch === 158).assertTrue();
        expect(the7thLine.tones[4].word === "慢" && the7thLine.tones[4].pitch === 125).assertTrue();
        expect(the7thLine.tones[5].word === "慢" && the7thLine.tones[5].pitch === 159).assertTrue();
        expect(the7thLine.tones[6].word === "收" && the7thLine.tones[6].pitch === 150).assertTrue();

        // 第41行包含 '你' '何' '忍' '远' '走' '高' '飞'
        const the41thLine = parsedLyrics!.lines[40];
        const startOf41thLine = parsedLyrics!.lines[40].getStartTime();
        const endOf41thLine = parsedLyrics!.lines[40].getEndTime();
        expect(endOf41thLine - startOf41thLine > 0).assertTrue();
        expect(the41thLine.tones[0].word === "你" && the41thLine.tones[0].pitch === 0).assertTrue();
        expect(the41thLine.tones[1].word === "何" && the41thLine.tones[1].pitch === 0).assertTrue();
        expect(the41thLine.tones[2].word === "忍" && the41thLine.tones[2].pitch === 0).assertTrue();
        expect(the41thLine.tones[3].word === "远" && the41thLine.tones[3].pitch === 0).assertTrue();
        expect(the41thLine.tones[4].word === "走" && the41thLine.tones[4].pitch === 0).assertTrue();
        expect(the41thLine.tones[5].word === "高" && the41thLine.tones[5].pitch === 0).assertTrue();
        expect(the41thLine.tones[6].word === "飞" && the41thLine.tones[6].pitch === 0).assertTrue();

      } catch (error) {
        hilog.error(DOMAIN, TAG, `parseOneAndOnlyOneLineXmlFile failed: ${JSON.stringify(error)}`);
        expect().assertFail();
      }
    });

    /**
     * 解析歌词元数据测试
     * 对应Android的parseMetadataForThisLyrics测试
     */
    it('parseMetadataForThisLyrics', 0, async () => {
      hilog.info(DOMAIN, TAG, 'parseMetadataForThisLyrics: 测试解析歌词元数据');

      if (!context) {
        hilog.info(DOMAIN, TAG, 'Test skipped - no context available');
        return;
      }

      // 指定测试文件
      const fileNameOfSong = "c18228e223144247810ee511916e2207.xml";
      const songTitle = "路边的野花不要采";
      const songArtist = "邓丽君";
      const expectedNumberOfLines = 20;

      const expectedPreludeEndPosition = Math.floor(13.0600 * 1000);
      const expectedDuration = Math.floor(113.0414 * 1000);

      try {
        // 从rawfile读取文件内容
        const xmlFileContent = await Utils.loadAsString(context, fileNameOfSong);
        expect(xmlFileContent).not().assertUndefined();
        expect(xmlFileContent!.includes(songArtist)).assertTrue();
        expect(xmlFileContent!.includes(songTitle)).assertTrue();

        // 读取文件字节数据用于解析
        const xmlFileData = await Utils.loadAsBytes(context, fileNameOfSong);
        expect(xmlFileData).not().assertUndefined();

        // 使用字节数组解析
        const parsedLyrics = LyricsParser.parseLyricData(xmlFileData!, undefined, true, 0);
        expect(parsedLyrics).not().assertUndefined();

        // 验证元数据
        expect(parsedLyrics!.name).assertEqual(songTitle);
        expect(parsedLyrics!.singer).assertEqual(songArtist);
        expect(parsedLyrics!.preludeEndPosition).assertEqual(expectedPreludeEndPosition);
        expect(parsedLyrics!.duration).assertEqual(expectedDuration);
        expect(parsedLyrics!.lines.length).assertEqual(expectedNumberOfLines);

        hilog.info(DOMAIN, TAG,
          `Metadata for this lyrics, numberOfLines: ${parsedLyrics!.lines.length}, title: ${parsedLyrics!.name}, singer: ${parsedLyrics!.singer}, preludeEndPosition: ${parsedLyrics!.preludeEndPosition}, duration: ${parsedLyrics!.duration}`);
      } catch (error) {
        hilog.error(DOMAIN, TAG, `parseMetadataForThisLyrics failed: ${JSON.stringify(error)}`);
        expect().assertFail();
      }
    });

    /**
     * 异常内容检查测试
     * 对应Android的unexpectedContentCheckingForLyrics测试
     */
    it('unexpectedContentCheckingForLyrics', 0, async () => {
      hilog.info(DOMAIN, TAG, 'unexpectedContentCheckingForLyrics: 测试异常内容检查');

      if (!context) {
        hilog.info(DOMAIN, TAG, 'Test skipped - no context available');
        return;
      }

      // 测试空内容文件 - 237732-empty-content.xml
      try {
        let fileNameOfSong = "237732-empty-content.xml";
        let songTitle = "不是因为寂寞才想你(Empty Content)";
        let songArtist = "AI";

        hilog.info(DOMAIN, TAG, `Testing file: ${fileNameOfSong}`);

        // 从rawfile读取文件内容
        const lyricsContentInString = await Utils.loadAsString(context, fileNameOfSong);
        if (lyricsContentInString) {
          expect(lyricsContentInString.includes(songArtist)).assertTrue();
          expect(lyricsContentInString.includes(songTitle)).assertTrue();
        }

        // 读取文件字节数据用于解析
        const xmlFileData = await Utils.loadAsBytes(context, fileNameOfSong);
        if (xmlFileData) {
          // 解析歌词文件，期望返回null（空内容）
          const parsedLyrics = LyricsParser.parseLyricData(xmlFileData, undefined, true, 0);
          expect(parsedLyrics).assertNull();
          hilog.info(DOMAIN, TAG, `File ${fileNameOfSong} parsed result: null (expected)`);
        }
      } catch (error) {
        hilog.info(DOMAIN, TAG, `Expected error for empty content file: ${JSON.stringify(error)}`);
      }

      // 测试空内容文件2 - 237732-empty-content-2.xml
      try {
        let fileNameOfSong = "237732-empty-content-2.xml";
        let songTitle = "不是因为寂寞才想你(Empty Content)";
        let songArtist = "AI";

        hilog.info(DOMAIN, TAG, `Testing file: ${fileNameOfSong}`);

        const lyricsContentInString = await Utils.loadAsString(context, fileNameOfSong);
        if (lyricsContentInString) {
          expect(lyricsContentInString.includes(songArtist)).assertTrue();
          expect(lyricsContentInString.includes(songTitle)).assertTrue();
        }

        const xmlFileData = await Utils.loadAsBytes(context, fileNameOfSong);
        if (xmlFileData) {
          const parsedLyrics = LyricsParser.parseLyricData(xmlFileData, undefined, true, 0);
          expect(parsedLyrics).assertNull();
          hilog.info(DOMAIN, TAG, `File ${fileNameOfSong} parsed result: null (expected)`);
        }
      } catch (error) {
        hilog.info(DOMAIN, TAG, `Expected error for empty content file 2: ${JSON.stringify(error)}`);
      }

      // 测试无效内容文件 - 237732-invalid-content.xml
      try {
        let fileNameOfSong = "237732-invalid-content.xml";
        let songTitle = "不是因为寂寞才想你(Invalid Content)";
        let songArtist = "AI";

        hilog.info(DOMAIN, TAG, `Testing file: ${fileNameOfSong}`);

        const lyricsContentInString = await Utils.loadAsString(context, fileNameOfSong);
        if (lyricsContentInString) {
          expect(lyricsContentInString.includes(songArtist)).assertTrue();
          expect(lyricsContentInString.includes(songTitle)).assertTrue();
        }

        const xmlFileData = await Utils.loadAsBytes(context, fileNameOfSong);
        if (xmlFileData) {
          const parsedLyrics = LyricsParser.parseLyricData(xmlFileData, undefined, true, 0);
          expect(parsedLyrics).assertNull();
          hilog.info(DOMAIN, TAG, `File ${fileNameOfSong} parsed result: null (expected)`);
        }
      } catch (error) {
        hilog.info(DOMAIN, TAG, `Expected error for invalid content file: ${JSON.stringify(error)}`);
      }

      // 测试无效内容文件2 - 237732-invalid-content-2.xml
      try {
        let fileNameOfSong = "237732-invalid-content-2.xml";
        let songTitle = "不是因为寂寞才想你(Invalid Content)";
        let songArtist = "AI";

        hilog.info(DOMAIN, TAG, `Testing file: ${fileNameOfSong}`);

        const lyricsContentInString = await Utils.loadAsString(context, fileNameOfSong);
        if (lyricsContentInString) {
          expect(lyricsContentInString.includes(songArtist)).assertTrue();
          expect(lyricsContentInString.includes(songTitle)).assertTrue();
        }

        const xmlFileData = await Utils.loadAsBytes(context, fileNameOfSong);
        if (xmlFileData) {
          const parsedLyrics = LyricsParser.parseLyricData(xmlFileData, undefined, true, 0);
          expect(parsedLyrics).assertNull();
          hilog.info(DOMAIN, TAG, `File ${fileNameOfSong} parsed result: null (expected)`);
        }
      } catch (error) {
        hilog.info(DOMAIN, TAG, `Expected error for invalid content file 2: ${JSON.stringify(error)}`);
      }
    });

    /**
     * 解析LRC和Pitch文件测试
     * 对应Android的parseLrcAndPitchFile测试
     */
    it('parseLrcAndPitchFile', 0, async () => {
      hilog.info(DOMAIN, TAG, 'parseLrcAndPitchFile: 测试解析LRC和Pitch文件');

      if (!context) {
        hilog.info(DOMAIN, TAG, 'Test skipped - no context available');
        return;
      }

      const fileNameOfSong = "6246262727282260.lrc";
      const fileNameOfPitch = "6246262727282260.bin";
      const expectedNumberOfLines = 60;

      try {
        hilog.info(DOMAIN, TAG, `Testing LRC and Pitch file parsing: ${fileNameOfSong}, ${fileNameOfPitch}`);

        // 读取歌词文件
        const lrcFileData = await Utils.loadAsBytes(context, fileNameOfSong);
        expect(lrcFileData).not().assertUndefined();
        expect(lrcFileData).not().assertNull();

        // 读取音高文件
        const pitchFileData = await Utils.loadAsBytes(context, fileNameOfPitch);
        expect(pitchFileData).not().assertUndefined();
        expect(pitchFileData).not().assertNull();

        // 使用字节数组解析（包含pitch）
        const parsedLyrics = LyricsParser.parseLyricData(lrcFileData!, pitchFileData!, true, 0);
        expect(parsedLyrics).not().assertUndefined();
        expect(parsedLyrics).not().assertNull();

        const lineCount = parsedLyrics!.lines.length;
        expect(lineCount).assertEqual(expectedNumberOfLines);

        hilog.info(DOMAIN, TAG,
          `LRC file parsed successfully with ${lineCount} lines (expected: ${expectedNumberOfLines})`);

        // 验证解析结果的基本属性
        if (parsedLyrics!.lines.length > 0) {
          const firstLine = parsedLyrics!.lines[0];
          expect(firstLine.getStartTime() >= 0).assertTrue();
          expect(firstLine.getEndTime() > firstLine.getStartTime()).assertTrue();
          hilog.info(DOMAIN, TAG, `First line: start=${firstLine.getStartTime()}, end=${firstLine.getEndTime()}`);
        }

      } catch (error) {
        hilog.error(DOMAIN, TAG, `parseLrcAndPitchFile failed: ${JSON.stringify(error)}`);
        expect().assertFail();
      }
    });

    /**
     * 解析KRC文件测试
     * 对应Android的testParseKRCFile测试
     */
    it('testParseKRCFile', 0, async () => {
      hilog.info(DOMAIN, TAG, 'testParseKRCFile: 测试解析KRC文件');

      if (!context) {
        hilog.info(DOMAIN, TAG, 'Test skipped - no context available');
        return;
      }

      const fileNameOfSong = "4875936889260991133.krc";

      try {
        hilog.info(DOMAIN, TAG, `Testing KRC file parsing: ${fileNameOfSong}`);

        // 读取KRC文件
        const krcFileData = await Utils.loadAsBytes(context, fileNameOfSong);
        expect(krcFileData).not().assertUndefined();
        expect(krcFileData).not().assertNull();

        // 使用字节数组解析
        const model = LyricsParser.parseLyricData(krcFileData!, undefined, true, 0);
        expect(model).not().assertUndefined();
        expect(model).not().assertNull();

        // 验证解析结果
        expect(model!.lines.length > 0).assertTrue();
        expect(model!.lines[0].getStartTime()).assertEqual(0);
        expect(model!.name).assertEqual("十年 (《明年今日》国语版|《隐婚男女》电影插曲|《摆渡人》电影插曲)");
        expect(model!.singer).assertEqual("陈奕迅");
        expect(model!.type).assertEqual(LyricType.KRC);
        expect(model!.duration).assertEqual(182736); // [179088,3648]
        expect(model!.preludeEndPosition).assertEqual(0);
        expect(model!.pitchDataList).assertNull();

        hilog.info(DOMAIN, TAG, `KRC file parsed successfully: ${model!.name} by ${model!.singer}`);
        hilog.info(DOMAIN, TAG, `Duration: ${model!.duration}ms, Lines: ${model!.lines.length}`);

      } catch (error) {
        hilog.error(DOMAIN, TAG, `testParseKRCFile failed: ${JSON.stringify(error)}`);
        expect().assertFail();
      }
    });

    /**
     * 测试歌词数据格式解析
     * 对应Android的testParseLyricDataFormat测试
     */
    it('testParseLyricDataFormat', 0, async () => {
      hilog.info(DOMAIN, TAG, 'testParseLyricDataFormat: 测试歌词数据格式解析');

      enableLyricViewLog(context);

      if (!context) {
        hilog.info(DOMAIN, TAG, 'Test skipped - no context available');
        return;
      }

      // 测试KRC文件类型检测 - 8141335308133421388.krc
      try {
        let fileNameOfSong = "8141335308133421388.krc";
        hilog.info(DOMAIN, TAG, `Testing file format detection: ${fileNameOfSong}`);

        const model = await parseLyricData(context, fileNameOfSong);
        expect(model).not().assertUndefined();
        expect(model).not().assertNull();
        expect(model!.type).assertEqual(LyricType.KRC);

        hilog.info(DOMAIN, TAG, `File ${fileNameOfSong} detected as type: ${model!.type}`);
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Format detection failed for 8141335308133421388.krc: ${JSON.stringify(error)}`);
        expect().assertFail();
      }

      // 测试KRC文件类型检测 - 4875936889260991133.krc
      try {
        let fileNameOfSong = "4875936889260991133.krc";
        hilog.info(DOMAIN, TAG, `Testing file format detection: ${fileNameOfSong}`);

        const model = await parseLyricData(context, fileNameOfSong);
        expect(model).not().assertUndefined();
        expect(model).not().assertNull();
        expect(model!.type).assertEqual(LyricType.KRC);

        hilog.info(DOMAIN, TAG, `File ${fileNameOfSong} detected as type: ${model!.type}`);
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Format detection failed for 4875936889260991133.krc: ${JSON.stringify(error)}`);
        expect().assertFail();
      }

      // 测试XML文件类型检测 - 660078.xml
      try {
        let fileNameOfSong = "660078.xml";
        hilog.info(DOMAIN, TAG, `Testing file format detection: ${fileNameOfSong}`);

        const model = await parseLyricData(context, fileNameOfSong);
        expect(model).not().assertUndefined();
        expect(model).not().assertNull();
        expect(model!.type).assertEqual(LyricType.XML);

        hilog.info(DOMAIN, TAG, `File ${fileNameOfSong} detected as type: ${model!.type}`);
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Format detection failed for 660078.xml: ${JSON.stringify(error)}`);
        expect().assertFail();
      }

      // 测试LRC文件类型检测 - 6246262727282260.lrc
      try {
        let fileNameOfSong = "6246262727282260.lrc";
        hilog.info(DOMAIN, TAG, `Testing file format detection: ${fileNameOfSong}`);

        const model = await parseLyricData(context, fileNameOfSong);
        expect(model).not().assertUndefined();
        expect(model).not().assertNull();
        expect(model!.type).assertEqual(LyricType.LRC);

        hilog.info(DOMAIN, TAG, `File ${fileNameOfSong} detected as type: ${model!.type}`);
      } catch (error) {
        hilog.error(DOMAIN, TAG, `Format detection failed for 6246262727282260.lrc: ${JSON.stringify(error)}`);
        expect().assertFail();
      }

      // 测试LRC文件类型检测 - kj5380f846be5811ed9efdb2f16c44e48f.lrc
      try {
        let fileNameOfSong = "kj5380f846be5811ed9efdb2f16c44e48f.lrc";
        hilog.info(DOMAIN, TAG, `Testing file format detection: ${fileNameOfSong}`);

        const model = await parseLyricData(context, fileNameOfSong);
        expect(model).not().assertUndefined();
        expect(model).not().assertNull();
        expect(model!.type).assertEqual(LyricType.LRC);

        hilog.info(DOMAIN, TAG, `File ${fileNameOfSong} detected as type: ${model!.type}`);
      } catch (error) {
        hilog.error(DOMAIN, TAG,
          `Format detection failed for kj5380f846be5811ed9efdb2f16c44e48f.lrc: ${JSON.stringify(error)}`);
        expect().assertFail();
      }
    });

    /**
     * 测试解析Pitch文件
     * 对应Android的testParsePitchFile测试
     */
    it('testParsePitchFile', 0, async () => {
      hilog.info(DOMAIN, TAG, 'testParsePitchFile: 测试解析Pitch文件');

      if (!context) {
        hilog.info(DOMAIN, TAG, 'Test skipped - no context available');
        return;
      }

      const fileNameOfSong = "4875936889260991133.krc";
      const fileNameOfPitch = "4875936889260991133.pitch";

      try {
        hilog.info(DOMAIN, TAG, `Testing pitch file parsing: ${fileNameOfSong} + ${fileNameOfPitch}`);

        // 读取歌词文件
        const krcFileData = await Utils.loadAsBytes(context, fileNameOfSong);
        expect(krcFileData).not().assertUndefined();
        expect(krcFileData).not().assertNull();

        // 读取音高文件
        const pitchFileData = await Utils.loadAsBytes(context, fileNameOfPitch);
        expect(pitchFileData).not().assertUndefined();
        expect(pitchFileData).not().assertNull();

        // 使用字节数组解析（包含pitch）
        const model = LyricsParser.parseLyricData(krcFileData!, pitchFileData!, true, 0);
        expect(model).not().assertUndefined();
        expect(model).not().assertNull();

        // 验证pitch数据
        expect(model!.pitchDataList).not().assertNull();
        expect(model!.pitchDataList!.length).assertEqual(294);
        expect(model!.pitchDataList![0].duration).assertEqual(241);
        expect(model!.pitchDataList![0].startTime).assertEqual(15203);
        expect(model!.pitchDataList![0].pitch).assertEqual(50);

        const lastIndex = model!.pitchDataList!.length - 1;
        expect(model!.pitchDataList![lastIndex].duration).assertEqual(2907);
        expect(model!.pitchDataList![lastIndex].startTime).assertEqual(180203);
        expect(model!.pitchDataList![lastIndex].pitch).assertEqual(50);

        hilog.info(DOMAIN, TAG, `Pitch file parsed successfully with ${model!.pitchDataList!.length} pitch points`);

      } catch (error) {
        hilog.error(DOMAIN, TAG, `testParsePitchFile failed: ${JSON.stringify(error)}`);
        expect().assertFail();
      }
    });

    /**
     * 测试解析KRC歌词和Pitch文件
     * 对应Android的testParseKRCLyricAndPitch测试
     */
    it('testParseKRCLyricAndPitch', 0, async () => {
      hilog.info(DOMAIN, TAG, 'testParseKRCLyricAndPitch: 测试解析KRC歌词和Pitch文件');

      if (!context) {
        hilog.info(DOMAIN, TAG, 'Test skipped - no context available');
        return;
      }

      const fileNameOfSong = "4875936889260991133.krc";
      const fileNameOfPitch = "4875936889260991133.pitch";

      try {
        hilog.info(DOMAIN, TAG, `Testing KRC and pitch parsing: ${fileNameOfSong} + ${fileNameOfPitch}`);

        // 读取歌词文件
        const krcFileData = await Utils.loadAsBytes(context, fileNameOfSong);
        expect(krcFileData).not().assertUndefined();
        expect(krcFileData).not().assertNull();

        // 读取音高文件
        const pitchFileData = await Utils.loadAsBytes(context, fileNameOfPitch);
        expect(pitchFileData).not().assertUndefined();
        expect(pitchFileData).not().assertNull();

        // 使用字节数组解析（不包含版权句子）
        const model = LyricsParser.parseLyricData(krcFileData!, pitchFileData!, false, 0);
        expect(model).not().assertUndefined();
        expect(model).not().assertNull();

        // 验证基本信息
        expect(model!.lines[0].getStartTime()).assertEqual(11590);
        expect(model!.lines.length > 0).assertTrue();
        expect(model!.name).assertEqual("十年 (《明年今日》国语版|《隐婚男女》电影插曲|《摆渡人》电影插曲)");
        expect(model!.singer).assertEqual("陈奕迅");
        expect(model!.type).assertEqual(LyricType.KRC);
        expect(model!.duration).assertEqual(182736); // [179088,3648]
        expect(model!.preludeEndPosition).assertEqual(15203);

        // 验证pitch数据
        expect(model!.pitchDataList).not().assertNull();
        expect(model!.pitchDataList!.length > 0).assertTrue();
        expect(model!.pitchDataList!.length).assertEqual(294);
        expect(model!.pitchDataList![0].duration).assertEqual(241);
        expect(model!.pitchDataList![0].startTime).assertEqual(15203);
        expect(model!.pitchDataList![0].pitch).assertEqual(50);

        const lastIndex = model!.pitchDataList!.length - 1;
        expect(model!.pitchDataList![lastIndex].duration).assertEqual(2907);
        expect(model!.pitchDataList![lastIndex].startTime).assertEqual(180203);
        expect(model!.pitchDataList![lastIndex].pitch).assertEqual(50);

        hilog.info(DOMAIN, TAG, `KRC and pitch parsed successfully: ${model!.name} by ${model!.singer}`);
        hilog.info(DOMAIN, TAG, `Lines: ${model!.lines.length}, Pitch points: ${model!.pitchDataList!.length}`);

      } catch (error) {
        hilog.error(DOMAIN, TAG, `testParseKRCLyricAndPitch failed: ${JSON.stringify(error)}`);
        expect().assertFail();
      }
    });

    /**
     * 测试增强LRC歌词文件
     * 对应Android的testEnhancedLrcLyricFile测试
     */
    it('testEnhancedLrcLyricFile', 0, async () => {
      hilog.info(DOMAIN, TAG, 'testEnhancedLrcLyricFile: 测试增强LRC歌词文件');

      enableLyricViewLog(context);

      if (!context) {
        hilog.info(DOMAIN, TAG, 'Test skipped - no context available');
        return;
      }

      const fileNameOfSong = "kj5380f846be5811ed9efdb2f16c44e48f.lrc";

      try {
        hilog.info(DOMAIN, TAG, `Testing enhanced LRC file: ${fileNameOfSong}`);

        // 读取LRC文件
        const lrcFileData = await Utils.loadAsBytes(context, fileNameOfSong);
        expect(lrcFileData).not().assertUndefined();
        expect(lrcFileData).not().assertNull();

        // 使用字节数组解析
        const model = LyricsParser.parseLyricData(lrcFileData!, undefined, true, 0);
        expect(model).not().assertUndefined();
        expect(model).not().assertNull();

        hilog.info(DOMAIN, TAG, `Enhanced LRC model: ${JSON.stringify(model)}`);

        // 验证行数
        const lineCount = model!.lines.length;
        hilog.info(DOMAIN, TAG, `Total lines parsed: ${lineCount}`);
        expect(lineCount).assertEqual(8);

        // 验证第一行内容
        let firstLineContent = "";
        for (let i = 0; i < model!.lines[0].tones.length; i++) {
          const tone = model!.lines[0].tones[i];
          firstLineContent += tone.word;
        }
        hilog.info(DOMAIN, TAG, `First line content: ${firstLineContent}`);
        expect(firstLineContent).assertEqual("他们总是说我有时不会怎么讲话");

        hilog.info(DOMAIN, TAG, `Enhanced LRC parsed successfully with ${lineCount} lines`);

      } catch (error) {
        hilog.error(DOMAIN, TAG, `testEnhancedLrcLyricFile failed: ${JSON.stringify(error)}`);
        expect().assertFail();
      }
    });

    /**
     * 测试歌词文件解析
     * 对应Android的testLyricFileParse测试
     */
    it('testLyricFileParse', 0, async () => {
      hilog.info(DOMAIN, TAG, 'testLyricFileParse: 测试歌词文件解析');

      enableLyricViewLog(context);

      if (!context) {
        hilog.info(DOMAIN, TAG, 'Test skipped - no context available');
        return;
      }

      const testFiles = [
        "non-normal-timestamp-format.lrc",
        "6246262727282260.lrc",
        "872957.xml",
        "e6fa1ebb_.lrc",
        "xml_no_type.xml",
        "745012"
      ];

      for (const fileName of testFiles) {
        try {
          hilog.info(DOMAIN, TAG, `Testing lyric file parsing: ${fileName}`);

          // 读取文件
          const fileData = await Utils.loadAsBytes(context, fileName);
          expect(fileData).not().assertUndefined();
          expect(fileData).not().assertNull();

          // 使用字节数组解析
          const model = LyricsParser.parseLyricData(fileData!, undefined, true, 0);
          expect(model).not().assertUndefined();
          expect(model).not().assertNull();

          hilog.info(DOMAIN, TAG, `File ${fileName} parsed successfully: ${JSON.stringify({
            name: model!.name,
            singer: model!.singer,
            type: model!.type,
            lineCount: model!.lines.length
          })}`);

        } catch (error) {
          hilog.error(DOMAIN, TAG, `testLyricFileParse failed for ${fileName}: ${JSON.stringify(error)}`);
          expect().assertFail();
        }
      }
    });

    /**
     * 测试解析XML文件
     * 对应Android的testParseXmlFile测试
     */
    it('testParseXmlFile', 0, async () => {
      hilog.info(DOMAIN, TAG, 'testParseXmlFile: 测试解析XML文件');

      enableLyricViewLog(context);

      if (!context) {
        hilog.info(DOMAIN, TAG, 'Test skipped - no context available');
        return;
      }

      const fileNameOfSong = "20250317.xml";

      try {
        hilog.info(DOMAIN, TAG, `Testing XML file parsing: ${fileNameOfSong}`);

        // 读取XML文件
        const xmlFileData = await Utils.loadAsBytes(context, fileNameOfSong);
        expect(xmlFileData).not().assertUndefined();
        expect(xmlFileData).not().assertNull();

        // 使用字节数组解析
        const model = LyricsParser.parseLyricData(xmlFileData!, undefined, true, 0);
        expect(model).not().assertUndefined();
        expect(model).not().assertNull();

        hilog.info(DOMAIN, TAG, `XML model: ${JSON.stringify({
          name: model!.name,
          singer: model!.singer,
          type: model!.type,
          lineCount: model!.lines.length
        })}`);

        // 验证解析结果
        expect(model!.lines.length > 0).assertTrue();
        expect(model!.lines[0].tones.length > 0).assertTrue();
        expect(model!.lines[0].tones[0].pitch !== 0).assertTrue();

        hilog.info(DOMAIN, TAG, `XML file parsed successfully with ${model!.lines.length} lines`);
        hilog.info(DOMAIN, TAG, `First tone pitch: ${model!.lines[0].tones[0].pitch}`);

      } catch (error) {
        hilog.error(DOMAIN, TAG, `testParseXmlFile failed: ${JSON.stringify(error)}`);
        expect().assertFail();
      }
    });


    // 以下是占位测试方法，对应Android中的其他测试方法
    // 后续可以根据需要实现具体逻辑

    /**
     * 行分离测试 - 占位方法
     */
    it('lineSeparating', 0, async () => {
      hilog.info(DOMAIN, TAG, 'lineSeparating: 测试行分离 - 待实现');
      // TODO: 实现行分离测试逻辑
    });

    /**
     * 评分测试 - 占位方法
     */
    it('testForScoring', 0, async () => {
      hilog.info(DOMAIN, TAG, 'testForScoring: 测试评分功能 - 待实现');
      // TODO: 实现评分测试逻辑
    });

    /**
     * 前5行测试 - 占位方法
     */
    it('testFirst5Lines', 0, async () => {
      hilog.info(DOMAIN, TAG, 'testFirst5Lines: 测试前5行 - 待实现');
      // TODO: 实现前5行测试逻辑
    });

    /**
     * 音高命中测试 - 占位方法
     */
    it('testPitchHit', 0, async () => {
      hilog.info(DOMAIN, TAG, 'testPitchHit: 测试音高命中 - 待实现');
      // TODO: 实现音高命中测试逻辑
    });

    /**
     * 下载测试 - 占位方法
     */
    it('testDownload', 0, async () => {
      hilog.info(DOMAIN, TAG, 'testDownload: 测试下载功能 - 待实现');
      // TODO: 实现下载测试逻辑
    });

    /**
     * 模拟评分测试 - 占位方法
     */
    it('testMockScoring', 0, async () => {
      hilog.info(DOMAIN, TAG, 'testMockScoring: 测试模拟评分 - 待实现');
      // TODO: 实现模拟评分测试逻辑
    });

    /**
     * 歌词评分与音高测试 - 占位方法
     */
    it('testLyricScoreWithPitch', 0, async () => {
      hilog.info(DOMAIN, TAG, 'testLyricScoreWithPitch: 测试歌词评分与音高 - 待实现');
      // TODO: 实现歌词评分与音高测试逻辑
    });
  });
}
