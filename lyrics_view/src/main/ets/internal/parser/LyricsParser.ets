import { Constants } from '../../constants/Constants';
import { LyricType } from '../../constants/LyricType';
import { KrcParser } from '../../internal/parser/KrcParser';
import { LrcParser } from '../../internal/parser/LrcParser';
import { XmlParser } from '../../internal/parser/XmlParser';
import { Utils } from '../../internal/utils/Utils';
import { LyricModel } from '../../model/LyricModel';
import { LogUtils } from '../../utils/LogUtils';

/**
 * 歌词解析器分发器 - HarmonyOS版本
 * 对应Java项目中的LyricPitchParser
 * 负责检测歌词格式并分发给对应的专用解析器
 */
export class LyricsParser {
  /**
   * 正则表达式：匹配LRC格式行
   */
  private static readonly LRC_PATTERN_LINE = /^((\[\d{2}:\d{2}\.\d{2,3}])+)(.+)$/;
  /**
   * 正则表达式：匹配KRC格式行
   */
  private static readonly KRC_PATTERN_LINE = /^\[(\w+):([^\]]*)]$/;

  /**
   * 检测歌词文件类型（基于内容）
   * @param lyricData 歌词数据字节数组
   * @returns 检测到的歌词类型
   */
  private static probeLyricsFileTypeFromBytes(lyricData: Uint8Array): LyricType {
    let type = LyricType.LRC; // 默认类型

    try {
      const fileContent = Utils.uint8ArrayToString(lyricData);
      const lines = fileContent.split(/\n|\r\n/);

      if (lines.length > 0) {
        let firstLine = lines[0].trim();
        if (firstLine) {
          // 移除BOM标记
          firstLine = Utils.removeStringBom(firstLine);

          if (firstLine.includes(`.${Constants.FILE_EXTENSION_XML}`) || firstLine.includes('<song>')) {
            type = LyricType.XML;
          } else if (LyricsParser.LRC_PATTERN_LINE.test(firstLine)) {
            type = LyricType.LRC;
          } else if (LyricsParser.KRC_PATTERN_LINE.test(firstLine)) {
            type = LyricType.KRC;
          } else {
            LogUtils.i('probeLyricsFileType unknown lyric type, defaulting to LRC');
          }
        }
      }
    } catch (error) {
      LogUtils.e(`probeLyricsFileType error: ${error}`);
    }

    return type;
  }

  /**
   * 根据文件扩展名或内容确定歌词文件类型
   *
   * @param lyricPath 要分析的歌词文件路径
   * @return 检测到的歌词类型
   */
  private static probeLyricsFileTypeFromPath(lyricPath: string): LyricType {
    let type = LyricType.LRC;

    if (!lyricPath || lyricPath.trim().length === 0) {
      return type;
    }

    const fileName = lyricPath.substring(lyricPath.lastIndexOf('/') + 1);
    LogUtils.i(`probeLyricsFileType fileName: ${fileName}`);

    if (fileName.endsWith(`.${Constants.FILE_EXTENSION_XML}`)) {
      type = LyricType.XML;
    } else if (fileName.endsWith(`.${Constants.FILE_EXTENSION_LRC}`)) {
      type = LyricType.LRC;
    } else if (fileName.endsWith(`.${Constants.FILE_EXTENSION_KRC}`)) {
      type = LyricType.KRC;
    } else {
      // 如果无法从扩展名判断，尝试读取文件内容进行判断
      try {
        const fileBytes = Utils.getFileBytes(lyricPath);
        if (fileBytes) {
          type = LyricsParser.probeLyricsFileTypeFromBytes(fileBytes);
        }
      } catch (error) {
        LogUtils.e(`Failed to read file for type detection: ${error}`);
      }
    }

    return type;
  }

  /**
   * 解析歌词数据（主入口方法）
   * @param lyricData 歌词数据字节数组
   * @param pitchData 音调数据字节数组（可选）
   * @param includeCopyrightSentence 是否包含版权信息
   * @param lyricOffset 歌词时间偏移（毫秒）
   * @returns 解析后的歌词模型
   */
  static parseLyricData(
    lyricData: Uint8Array,
    pitchData?: Uint8Array,
    includeCopyrightSentence: boolean = true,
    lyricOffset: number = 0
  ): LyricModel | null {
    const type = LyricsParser.probeLyricsFileTypeFromBytes(lyricData);
    LogUtils.d(`Detected lyric type: ${type}`);

    switch (type) {
      case LyricType.KRC:
        return KrcParser.parseKrcLyricData(lyricData, pitchData, includeCopyrightSentence, lyricOffset);
      case LyricType.LRC:
        return LrcParser.parseLrcLyricData(lyricData, pitchData, includeCopyrightSentence, lyricOffset);
      case LyricType.XML:
        return XmlParser.parseXmlLyricData(lyricData, pitchData, includeCopyrightSentence, lyricOffset);
      default:
        LogUtils.e(`Unsupported lyrics file type: ${type}`);
        return null;
    }
  }

  /**
   * 从文件路径解析歌词数据
   * @param lyricFilePath 歌词文件路径
   * @param pitchFilePath 音调文件路径（可选）
   * @param includeCopyrightSentence 是否包含版权信息
   * @param lyricOffset 歌词时间偏移（毫秒）
   * @returns 解析后的歌词模型
   */
  static parseFile(
    lyricFilePath: string,
    pitchFilePath?: string,
    includeCopyrightSentence: boolean = true,
    lyricOffset: number = 0
  ): LyricModel | null {
    try {
      // 根据文件路径检测歌词类型
      const type = LyricsParser.probeLyricsFileTypeFromPath(lyricFilePath);
      LogUtils.d(`Detected lyric type from path: ${type}`);

      // 读取歌词文件数据
      const lyricData = Utils.getFileBytes(lyricFilePath);
      if (!lyricData) {
        LogUtils.e(`Failed to read lyric file: ${lyricFilePath}`);
        return null;
      }

      // 读取音调文件数据（如果提供）
      let pitchData: Uint8Array | undefined = undefined;
      if (pitchFilePath) {
        pitchData = Utils.getFileBytes(pitchFilePath) || undefined;
        if (!pitchData) {
          LogUtils.w(`Failed to read pitch file: ${pitchFilePath}`);
        }
      }

      switch (type) {
        case LyricType.KRC:
          return KrcParser.parseKrcLyricData(lyricData, pitchData, includeCopyrightSentence, lyricOffset);
        case LyricType.LRC:
          return LrcParser.parseLrcLyricData(lyricData, pitchData, includeCopyrightSentence, lyricOffset);
        case LyricType.XML:
          return XmlParser.parseXmlLyricData(lyricData, pitchData, includeCopyrightSentence, lyricOffset);
        default:
          LogUtils.e(`Unsupported lyrics file type: ${type}`);
          return null;
      }
    } catch (error) {
      LogUtils.e(`parseFile error: ${error}`);
      return null;
    }
  }
}
