import { LyricType } from '../../constants/LyricType';
import { LyricModel } from '../../model/LyricModel';
import { Lang, LyricsLineModel, Tone } from '../../model/LyricsLineModel';
import { LogUtils } from '../../utils/LogUtils';
import { Utils } from '../../utils/Utils';

/**
 * LRC格式歌词解析器 - HarmonyOS版本
 * 对应Java项目中的LyricParser.doParseLrc方法
 * 专门处理LRC格式歌词解析
 */
export class LrcParser {
  /**
   * 正则表达式：匹配时间标签
   */
  private static readonly LRC_PATTERN_TIME = /\[(\d{2}):(\d{2})\.(\d{2,3})]/g;
  /**
   * 正则表达式：匹配歌词内容行
   */
  private static readonly LRC_PATTERN_LINE = /^((\[\d{2}:\d{2}\.\d{2,3}])+)(.+)$/;
  /**
   * 正则表达式：匹配带时间标签的歌词内容
   */
  private static readonly LRC_LYRIC_CONTENT_PATTERN = /<(\d{2}):(\d{2})\.(\d{3})>(.*?)(?=<|$)/g;

  /**
   * 解析LRC格式歌词和音调数据（对外接口）
   * @param lyricData LRC歌词数据字节数组
   * @param pitchData 音调数据字节数组（可选）
   * @param includeCopyrightSentence 是否包含版权信息
   * @param lyricOffset 歌词时间偏移（毫秒）
   * @returns 解析后的歌词模型
   */
  static parseLrcLyricData(
    lyricData: Uint8Array,
    pitchData?: Uint8Array,
    includeCopyrightSentence: boolean = true,
    lyricOffset: number = 0
  ): LyricModel | null {
    try {
      // 使用核心解析方法
      const model = LrcParser.doParseLrc(lyricData);
      if (!model) {
        LogUtils.e('Failed to parse LRC data');
        return null;
      }

      model.hasPitch = false;

      // 替换音调并设置音调值
      // 每个音调持续100ms
      for (let i = 0; i < model.lines.length; i++) {
        const line = model.lines[i];
        const tones = line.tones;

        if (tones && tones.length > 0) {
          // 计算需要添加的音调数量并执行
          for (let j = 0; j < tones.length; j++) {
            const tone = tones[j];
            if (j < tones.length - 1) {
              tone.end = tones[j + 1].begin;
            } else {
              if (i < model.lines.length - 1) {
                tone.end = model.lines[i + 1].tones[0].begin;
              } else {
                // 最后一个音调
                tone.end = tone.begin + 99; // 100ms - 1
              }
            }
          }
        }
      }

      return model;
    } catch (error) {
      LogUtils.e(`parseLrcLyricData error: ${error}`);
      return null;
    }
  }

  /**
   * 核心LRC解析方法（对应Java的doParseLrc）
   * @param fileData LRC文件数据字节数组
   * @returns 解析后的歌词模型
   */
  static doParseLrc(fileData: Uint8Array): LyricModel | null {
    if (!fileData || fileData.length === 0) {
      return null;
    }

    const lines: LyricsLineModel[] = [];
    try {
      const fileContent = Utils.uint8ArrayToString(fileData);
      const lineArray = fileContent.split(/\n|\r\n/);

      let isFirstLine = true;
      for (let line of lineArray) {
        if (isFirstLine) {
          line = Utils.removeStringBom(line);
          isFirstLine = false;
        }

        const list = LrcParser.parseLrcLine(line);
        if (list && list.length > 0) {
          lines.push(...list);
        }
      }
    } catch (error) {
      LogUtils.e(`doParseLrc error: ${error}`);
    }

    return LrcParser.parseLrcLines(lines);
  }

  /**
   * 处理解析后的LRC行列表，组装成完整的歌词模型（对应Java的parseLrcLines）
   * @param lines 解析后的歌词行列表
   * @returns 完整的歌词模型
   */
  private static parseLrcLines(lines: LyricsLineModel[]): LyricModel | null {
    const lyrics = new LyricModel(LyricType.LRC);
    if (!lines || lines.length === 0) {
      return lyrics;
    }

    lyrics.lines = lines;

    // 设置每行的结束时间
    for (let i = 0; i < lines.length - 1; i++) {
      const cur = lines[i];
      const next = lines[i + 1];

      if (!cur.tones || cur.tones.length <= 0) {
        continue;
      }

      const first = cur.tones[0];
      first.end = next.getStartTime();
    }

    if (lines.length > 0) {
      const lastLine = lines[lines.length - 1];
      const faked = lastLine.getStartTime() + 8765;
      if (lastLine.tones && lastLine.tones.length > 0) {
        lastLine.tones[0].end = faked;
      }
      // 我们不知道歌曲的最后结束时间戳
      lyrics.duration = faked;
    }

    // 总是第一行歌词
    if (lines.length > 0) {
      lyrics.preludeEndPosition = lines[0].getStartTime();
    }

    if (lyrics.duration <= 0 || lyrics.preludeEndPosition < 0) {
      LogUtils.e(`no sentence or unexpected timestamp of sentence: ${lyrics.preludeEndPosition} ${lyrics.duration}`);
      // 无效歌词
      return null;
    }

    return lyrics;
  }

  /**
   * 解析LRC格式歌词（对外接口，保持兼容性）
   * @param lrcContent LRC歌词内容字符串
   * @returns 解析后的歌词模型
   */
  static parseLRC(lrcContent: string): LyricModel {
    const lrcData = Utils.stringToUint8Array(lrcContent);
    const result = LrcParser.doParseLrc(lrcData);
    return result || new LyricModel(LyricType.LRC);
  }

  /**
   * 解析单行LRC歌词（对应Java的parseLrcLine）
   * @param line 要解析的行
   * @returns 解析后的歌词行数组，如果解析失败则返回null
   */
  private static parseLrcLine(line: string): LyricsLineModel[] | null {
    if (!line || line.trim().length === 0) {
      return null;
    }

    const lines: LyricsLineModel[] = [];

    try {
      const trimmedLine = line.trim();
      // [00:17.65]让我掉下眼泪的
      const lineMatcher = LrcParser.LRC_PATTERN_LINE.exec(trimmedLine);
      if (!lineMatcher) {
        return null;
      }

      const times = lineMatcher[1];
      if (!times) {
        return null;
      }

      const text = lineMatcher[3];

      if (!text || text.trim().length === 0) {
        return lines; // 返回空数组
      }

      // 重置正则表达式的lastIndex，避免test()方法影响matchAll()
      LrcParser.LRC_LYRIC_CONTENT_PATTERN.lastIndex = 0;
      if (LrcParser.LRC_LYRIC_CONTENT_PATTERN.test(text)) {
        const lineModel = new LyricsLineModel();
        // 重置正则表达式的lastIndex，确保matchAll()从头开始匹配
        LrcParser.LRC_LYRIC_CONTENT_PATTERN.lastIndex = 0;
        const matches = text.matchAll(LrcParser.LRC_LYRIC_CONTENT_PATTERN);

        for (const match of matches) {
          const content = Utils.removeQuotes(match[4] || '');

          const min = parseInt(match[1] || '0');
          const sec = parseInt(match[2] || '0');
          const mil = parseInt(match[3] || '0');

          const beginTime = min * 60 * 1000 + sec * 1000 + mil;

          const tone = new Tone();
          tone.begin = beginTime;
          tone.word = content;
          tone.lang = Lang.Chinese;
          lineModel.tones.push(tone);
        }
        lines.push(lineModel);
        return lines;
      } else {
        // [00:17.65]
        LrcParser.LRC_PATTERN_TIME.lastIndex = 0; // 重置正则表达式
        const timeMatches = times.matchAll(LrcParser.LRC_PATTERN_TIME);

        for (const timeMatch of timeMatches) {
          const min = parseInt(timeMatch[1] || '0');
          const sec = parseInt(timeMatch[2] || '0');
          const milInString = timeMatch[3];
          let mil = 0;
          if (milInString) {
            mil = parseInt(milInString);
          }
          // 如果毫秒是两位数，乘以10
          if (milInString && milInString.length === 2) {
            mil = mil * 10;
          }
          const beginTime = min * 60 * 1000 + sec * 1000 + mil;

          const tone = new Tone();
          tone.begin = beginTime;
          tone.word = text;
          tone.lang = Lang.Chinese;
          tone.isFullLine = true;
          lines.push(new LyricsLineModel([tone]));
        }
      }
    } catch (error) {
      LogUtils.e(`parseLrcLine error: ${error}`);
    }

    return lines;
  }
}
