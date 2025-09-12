import { LyricType } from '../../constants/LyricType';
import { Utils } from '../../internal/utils/Utils';
import { LyricModel } from '../../model/LyricModel';
import { Lang, LyricsLineModel, Tone } from '../../model/LyricsLineModel';
import { PitchData } from '../../model/PitchData';
import { LogUtils } from '../../utils/LogUtils';

/**
 * KRC 音调数据 JSON 结构接口
 */
interface KrcPitchDataJson {
  pitchDatas?: string | PitchData[];
}

/**
 * KRC格式歌词解析器 - HarmonyOS版本
 * 对应Java项目中的LyricParser.doParseKrc方法
 * 支持逐字高亮的KRC格式解析
 */
export class KrcParser {
  /**
   * 解析KRC格式歌词和音调数据（对外接口）
   * @param krcData KRC歌词数据字节数组
   * @param pitchData 音调数据字节数组（可选）
   * @param includeCopyrightSentence 是否包含版权信息
   * @param lyricOffset 歌词时间偏移（毫秒）
   * @returns 解析后的歌词模型
   */
  static parseKrcLyricData(
    krcData: Uint8Array,
    pitchData?: Uint8Array,
    includeCopyrightSentence: boolean = true,
    lyricOffset: number = 0
  ): LyricModel | null {
    try {
      // 解析KRC歌词数据
      const lyricsModel = KrcParser.doParseKrc(krcData, lyricOffset);
      if (!lyricsModel) {
        LogUtils.e('Failed to parse KRC data');
        return null;
      }

      // 解析音调数据
      let pitchDataList: PitchData[] | null = null;
      if (pitchData) {
        pitchDataList = KrcParser.doParseKrcPitchData(pitchData);
      }

      // 设置音调相关属性
      lyricsModel.pitchDataList = pitchDataList || [];
      lyricsModel.hasPitch = pitchDataList != null && pitchDataList.length > 0;

      if (lyricsModel.hasPitch && pitchDataList && pitchDataList.length > 0) {
        lyricsModel.preludeEndPosition = pitchDataList[0].startTime;
      }

      // 移除版权信息句子
      if (!includeCopyrightSentence && lyricsModel.lines && lyricsModel.lines.length > 0) {
        let copyrightCount = 0;
        const filteredLines = lyricsModel.lines.filter(line => {
          if (line.getEndTime() < lyricsModel.preludeEndPosition) {
            copyrightCount++;
            return false;
          }
          return true;
        });
        lyricsModel.lines = filteredLines;
        lyricsModel.copyrightSentenceLineCount = copyrightCount;
      }

      return lyricsModel;
    } catch (error) {
      LogUtils.e(`parseKrcLyricData error: ${error}`);
      return null;
    }
  }

  /**
   * 解析KRC格式歌词（对外接口）
   * @param krcContent KRC歌词内容字符串
   * @param lyricOffset 歌词时间偏移（毫秒）
   * @returns 解析后的歌词模型
   */
  static parseKRC(krcContent: string, lyricOffset: number = 0): LyricModel {
    const krcData = Utils.stringToUint8Array(krcContent);
    const result = KrcParser.doParseKrc(krcData, lyricOffset);
    return result || new LyricModel(LyricType.KRC);
  }

  /**
   * 核心KRC解析方法（对应Java的doParseKrc）
   * @param krcFileData KRC文件数据字节数组
   * @param lyricOffset 歌词时间偏移（毫秒）
   * @returns 解析后的歌词模型
   */
  private static doParseKrc(krcFileData: Uint8Array, lyricOffset: number): LyricModel | null {
    try {
      const content = Utils.uint8ArrayToString(krcFileData);

      const lines = content.split(/\n|\r\n/);
      const metadata = new Map<string, string>();
      const lineModels: LyricsLineModel[] = [];

      let isFirstLine = true;
      for (let line of lines) {
        try {
          if (isFirstLine) {
            line = Utils.removeStringBom(line);
            isFirstLine = false;
          }

          if (line.startsWith('[')) {
            if (line.includes('<') && line.includes('>')) {
              // 解析歌词行
              let offsetValue = 0;
              if (metadata.has('offset')) {
                try {
                  offsetValue = parseInt(metadata.get('offset') || '0');
                } catch (error) {
                  LogUtils.e('parse offset error');
                }
              }

              const lineModel = KrcParser.parseKrcLine(line, lyricOffset);
              if (lineModel) {
                lineModels.push(lineModel);
              } else {
                LogUtils.e('parseLine error');
              }
            } else {
              // 处理元数据部分：`[ti:星晴]`
              const index = line.indexOf(':');
              if (index !== -1) {
                // 键值，从第二个字符到":"之前
                const key = line.substring(1, index);
                // 值，从":"之后到"]"之前
                const value = line.substring(index + 1, line.length - 1);
                metadata.set(key, value);
              } else {
                LogUtils.i(`unknown metadata line: ${line}`);
              }
            }
          } else {
            LogUtils.i(`ignore line: ${line}`);
          }
        } catch (error) {
          LogUtils.e(`doParseKrc error: ${error} line: ${line}`);
        }
      }

      const lyrics = new LyricModel(LyricType.KRC);
      lyrics.name = metadata.has('ti') ? metadata.get('ti') || 'unknownTitle' : 'unknownTitle';
      lyrics.singer = metadata.has('ar') ? metadata.get('ar') || 'unknownSinger' : 'unknownSinger';
      lyrics.lines = lineModels;
      lyrics.preludeEndPosition = 0;

      if (lineModels.length === 0) {
        lyrics.duration = 0;
      } else {
        const lastLine = lineModels[lineModels.length - 1];
        lyrics.duration = lastLine.getStartTime() + lastLine.duration;
      }

      return lyrics;
    } catch (error) {
      LogUtils.e(`doParseKrc error: ${error}`);
      return null;
    }
  }

  /**
   * 解析单行KRC格式（对应Java的parseKrcLine）
   * @param line 要解析的行
   * @param offset 时间偏移量（毫秒）
   * @returns 解析后的歌词行模型，解析失败返回null
   */
  private static parseKrcLine(line: string, offset: number): LyricsLineModel | null {
    try {
      const rangeStart = line.indexOf('[');
      const rangeEnd = line.indexOf(']');
      if (rangeStart === -1 || rangeEnd === -1) {
        return null;
      }

      const timeStr = line.substring(rangeStart + 1, rangeEnd);
      const timeComponents = timeStr.split(',');

      // 处理行时间：`0,1600`
      if (timeComponents.length !== 2) {
        return null;
      }

      const startTimeOrigin = parseInt(timeComponents[0].trim());
      const lineStartTime = startTimeOrigin >= offset ? startTimeOrigin - offset : startTimeOrigin;

      const lineDuration = parseInt(timeComponents[1].trim());
      const lineContent = line.substring(rangeEnd + 1).trim();

      // 解析行内容
      const tones: Tone[] = [];
      const toneComponents = lineContent.split('<');

      for (const toneComponent of toneComponents) {
        if (toneComponent.length === 0) {
          continue;
        }

        // 解析单词内容：'0,177,0>星'
        const toneParts = toneComponent.split('>');
        if (toneParts.length === 2) {
          const word = toneParts[1];

          const timeParts = toneParts[0].split(',');
          if (timeParts.length === 3) {
            const startTime = lineStartTime + parseInt(timeParts[0]);
            const duration = parseInt(timeParts[1]);
            const pitch = parseFloat(timeParts[2]);

            const tone = new Tone();
            tone.begin = startTime;
            tone.end = startTime + duration;
            tone.word = word;
            tone.pitch = Math.floor(pitch);
            tone.lang = Lang.Chinese;
            tones.push(tone);
          }
        }
      }

      const lineModel = new LyricsLineModel(tones);
      lineModel.duration = lineDuration;
      return lineModel;
    } catch (error) {
      LogUtils.e(`parseKrcLine error: ${error}`);
    }
    return null;
  }

  /**
   * 解析KRC格式音调数据
   * @param fileData 包含KRC音调数据的字节数组
   * @returns PitchData对象数组，解析失败返回null
   */
  private static doParseKrcPitchData(fileData: Uint8Array): PitchData[] | null {
    if (!fileData || fileData.length === 0) {
      return null;
    }

    try {
      let jsonData = Utils.uint8ArrayToString(fileData);

      const jsonObject: KrcPitchDataJson = JSON.parse(jsonData) as KrcPitchDataJson;
      if (jsonObject.pitchDatas) {
        const pitchDatas = jsonObject.pitchDatas;
        if (typeof pitchDatas === 'string') {
          return JSON.parse(pitchDatas) as PitchData[];
        } else if (Array.isArray(pitchDatas)) {
          return pitchDatas as PitchData[];
        }
      }
    } catch (error) {
      LogUtils.e(`doParseKrcPitchData error: ${error}`);
    }

    return null;
  }
}
