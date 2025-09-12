import { LyricType } from '../../constants/LyricType';
import { Utils } from '../../internal/utils/Utils';
import { LyricModel } from '../../model/LyricModel';
import { Lang, LyricsLineModel, Monolog, Tone } from '../../model/LyricsLineModel';
import { PitchData } from '../../model/PitchData';
import { LogUtils } from '../../utils/LogUtils';


/**
 * 歌曲数据结构，包含基本信息和MIDI数据
 */
interface Song {
  general?: SongGeneral;
  midi?: SongMidi;
}

/**
 * 歌曲基本信息
 */
interface SongGeneral {
  name?: string;
  singer?: string;
  type?: number;
  modeType?: string;
}

/**
 * MIDI歌词数据
 */
interface SongMidi {
  paragraphs: Paragraph[];
}

/**
 * 包含多行歌词的段落
 */
interface Paragraph {
  lines: LyricsLineModel[];
}

/**
 * XML音调数据模型
 */
export interface XmlPitchData {
  version: number;
  interval: number;
  reserved: number;
  pitches: number[];
}

/**
 * XML 音调数据 JSON 结构接口
 */
interface XmlPitchDataJson {
  pitchDatas?: string | PitchData[];
}

/**
 * XML格式歌词解析器 - HarmonyOS版本
 * 对应Java项目中的LyricsParserXml
 * 专门处理XML格式歌词解析
 */
export class XmlParser {
  /**
   * 解析XML格式歌词和音调数据（对外接口）
   * @param lyricData XML歌词数据字节数组
   * @param pitchData 音调数据字节数组（可选）
   * @param includeCopyrightSentence 是否包含版权信息
   * @param lyricOffset 歌词时间偏移（毫秒）
   * @returns 解析后的歌词模型
   */
  static parseXmlLyricData(
    lyricData: Uint8Array,
    pitchData?: Uint8Array,
    includeCopyrightSentence: boolean = true,
    lyricOffset: number = 0
  ): LyricModel | null {
    try {
      // 解析音调数据
      let pitchesModel: XmlPitchData | null = null;
      if (pitchData) {
        pitchesModel = XmlParser.parseXmlPitchData(pitchData);
      }

      // 使用专用的XML解析器
      const model = XmlParser.parseXMLFromBytes(lyricData);
      if (!model) {
        LogUtils.e('Failed to parse XML content');
        return null;
      }

      // XML格式通常已经包含音调信息，但如果提供了额外的音调数据，可以进行增强
      if (pitchesModel && pitchesModel.pitches.length > 0) {
        model.hasPitch = true;

        // 为XML歌词添加额外的音调数据处理
        for (let i = 0; i < model.lines.length; i++) {
          const line = model.lines[i];
          if (line.tones && line.tones.length > 0) {
            for (const tone of line.tones) {
              if (tone.pitch === 0) {
                // 如果XML中没有音调信息，从音调数据中获取
                tone.pitch = Math.floor(XmlParser.fetchPitchWithRange(
                  pitchesModel,
                  model.preludeEndPosition,
                  tone.begin,
                  tone.end
                ));
              }
            }
          }
        }
      }

      return model;
    } catch (error) {
      LogUtils.e(`parseXmlLyricData error: ${error}`);
      return null;
    }
  }

  /**
   * 解析XML格式歌词数据
   * @param xmlContent XML内容字符串
   * @returns 包含解析歌词的LyricModel对象，如果解析失败则返回null
   */
  static parseXML(xmlContent: string): LyricModel | null {
    if (!xmlContent || xmlContent.trim().length === 0) {
      LogUtils.e('XML content is empty');
      return null;
    }

    try {
      // 移除BOM标记
      const cleanContent = Utils.removeStringBom(xmlContent.trim());

      // 使用简单的XML解析（HarmonyOS可能没有完整的XML解析器）
      const song = XmlParser.parseXmlContent(cleanContent);

      if (!song.midi || !song.midi.paragraphs) {
        LogUtils.e('No midi or paragraph found in XML');
        return null;
      }

      const lyrics = new LyricModel(LyricType.XML);
      const lines: LyricsLineModel[] = [];

      for (const paragraph of song.midi.paragraphs) {
        lines.push(...paragraph.lines);
      }

      if (lines.length > 0) {
        lyrics.duration = lines[lines.length - 1].getEndTime();
        // 总是第一行歌词
        lyrics.preludeEndPosition = lines[0].getStartTime();
        lyrics.hasPitch = lines[0].tones.length > 0 && lines[0].tones[0].pitch !== 0;
      }

      lyrics.name = song.general?.name || 'Unknown Title';
      lyrics.singer = song.general?.singer || 'Unknown Singer';
      lyrics.lines = lines;

      if (lyrics.duration <= 0 || lyrics.preludeEndPosition < 0) {
        LogUtils.e(`Invalid XML lyrics: duration=${lyrics.duration}, prelude=${lyrics.preludeEndPosition}`);
        return null;
      }

      return lyrics;
    } catch (error) {
      LogUtils.e(`parseXML error: ${error}`);
    }

    return null;
  }

  /**
   * 从字节数组解析XML格式歌词数据
   * @param xmlFileData 包含XML文件数据的字节数组
   * @returns 包含解析歌词的LyricModel对象，如果解析失败则返回null
   */
  static parseXMLFromBytes(xmlFileData: Uint8Array): LyricModel | null {
    if (!xmlFileData || xmlFileData.length === 0) {
      LogUtils.e('XML file data is empty');
      return null;
    }

    try {
      // 使用 HarmonyOS 兼容的方式将 Uint8Array 转换为字符串
      const xmlContent = Utils.uint8ArrayToString(xmlFileData);
      return XmlParser.parseXML(xmlContent);
    } catch (error) {
      LogUtils.e(`parseXMLFromBytes error: ${error}`);
      return null;
    }
  }

  /**
   * 解析XML内容（简化版本）
   * @param xmlContent XML内容字符串
   * @returns Song对象
   */
  private static parseXmlContent(xmlContent: string): Song {
    const song: Song = {};

    try {
      // 解析general信息
      const generalMatch = xmlContent.match(/<general>([\s\S]*?)<\/general>/);
      if (generalMatch) {
        song.general = XmlParser.parseGeneral(generalMatch[1]);
      }

      // 解析midi_lrc信息
      const midiMatch = xmlContent.match(/<midi_lrc>([\s\S]*?)<\/midi_lrc>/);
      if (midiMatch) {
        song.midi = XmlParser.parseMidiLrc(midiMatch[1]);
      }
    } catch (error) {
      LogUtils.e(`parseXmlContent error: ${error}`);
    }

    return song;
  }

  /**
   * 解析歌曲基本信息
   * @param generalContent general标签内容
   * @returns SongGeneral对象
   */
  private static parseGeneral(generalContent: string): SongGeneral {
    const general: SongGeneral = {};

    try {
      const nameMatch = generalContent.match(/<name>(.*?)<\/name>/);
      if (nameMatch) {
        general.name = nameMatch[1].trim();
      }

      const singerMatch = generalContent.match(/<singer>(.*?)<\/singer>/);
      if (singerMatch) {
        general.singer = singerMatch[1].trim();
      }

      const typeMatch = generalContent.match(/<type>(.*?)<\/type>/);
      if (typeMatch) {
        try {
          general.type = parseInt(typeMatch[1].trim());
        } catch (error) {
          LogUtils.w(`Failed to parse type: ${typeMatch[1]}`);
        }
      }

      const modeTypeMatch = generalContent.match(/<mode_type>(.*?)<\/mode_type>/);
      if (modeTypeMatch) {
        general.modeType = modeTypeMatch[1];
      }
    } catch (error) {
      LogUtils.e(`parseGeneral error: ${error}`);
    }

    return general;
  }

  /**
   * 解析MIDI歌词数据
   * @param midiContent midi_lrc标签内容
   * @returns SongMidi对象
   */
  private static parseMidiLrc(midiContent: string): SongMidi {
    const midi: SongMidi = { paragraphs: [] };

    try {
      // 匹配所有paragraph标签
      const paragraphMatches = midiContent.matchAll(/<paragraph>([\s\S]*?)<\/paragraph>/g);

      for (const paragraphMatch of paragraphMatches) {
        const paragraph = XmlParser.parseParagraph(paragraphMatch[1]);
        midi.paragraphs.push(paragraph);
      }
    } catch (error) {
      LogUtils.e(`parseMidiLrc error: ${error}`);
    }

    return midi;
  }

  /**
   * 解析段落数据
   * @param paragraphContent paragraph标签内容
   * @returns Paragraph对象
   */
  private static parseParagraph(paragraphContent: string): Paragraph {
    const paragraph: Paragraph = { lines: [] };

    try {
      // 匹配所有sentence标签
      const sentenceMatches = paragraphContent.matchAll(/<sentence[^>]*>([\s\S]*?)<\/sentence>/g);

      for (const sentenceMatch of sentenceMatches) {
        const sentenceTag = sentenceMatch[0];
        const sentenceContent = sentenceMatch[1];

        const lines = XmlParser.parseLines(sentenceTag, sentenceContent);
        for (const line of lines) {
          line.duration = line.getEndTime() - line.getStartTime();
        }
        paragraph.lines.push(...lines);
      }
    } catch (error) {
      LogUtils.e(`parseParagraph error: ${error}`);
    }

    return paragraph;
  }

  /**
   * 解析歌词行数据
   * @param sentenceTag sentence标签（包含属性）
   * @param sentenceContent sentence标签内容
   * @returns LyricsLineModel对象数组
   */
  private static parseLines(sentenceTag: string, sentenceContent: string): LyricsLineModel[] {
    const line = new LyricsLineModel();

    try {
      // 解析sentence的mode属性
      const modeMatch = sentenceTag.match(/mode="([^"]*)"/);
      let isManMode = true;
      if (modeMatch) {
        isManMode = modeMatch[1] === 'man';
      }

      // 匹配所有tone标签
      const toneMatches = sentenceContent.matchAll(/<tone[^>]*>([\s\S]*?)<\/tone>/g);

      for (const toneMatch of toneMatches) {
        const tone = XmlParser.parseTone(toneMatch[0], toneMatch[1]);
        if (tone) {
          line.tones.push(tone);
        }
      }

      // 匹配所有monolog标签
      const monologMatches = sentenceContent.matchAll(/<monolog[^>]*>([\s\S]*?)<\/monolog>/g);

      for (const monologMatch of monologMatches) {
        const monolog = XmlParser.parseMonolog(monologMatch[0], monologMatch[1]);
        if (monolog) {
          line.tones.push(monolog);
        }
      }
    } catch (error) {
      LogUtils.e(`parseLines error: ${error}`);
    }

    return [line];
  }

  /**
   * 解析音调数据
   * @param toneTag 完整的tone标签
   * @param toneContent tone标签内容
   * @returns Tone对象
   */
  private static parseTone(toneTag: string, toneContent: string): Tone | null {
    try {
      const tone = new Tone();

      // 解析属性
      const beginMatch = toneTag.match(/begin="([^"]*)"/);
      if (beginMatch) {
        tone.begin = Math.floor(parseFloat(beginMatch[1]) * 1000);
      }

      const endMatch = toneTag.match(/end="([^"]*)"/);
      if (endMatch) {
        tone.end = Math.floor(parseFloat(endMatch[1]) * 1000);
      }

      const pitchMatch = toneTag.match(/pitch="([^"]*)"/);
      if (pitchMatch) {
        try {
          const pitchValue = parseFloat(pitchMatch[1]);
          tone.pitch = Math.floor(pitchValue);
        } catch (error) {
          LogUtils.w(`Failed to parse pitch: ${pitchMatch[1]}`);
          tone.pitch = 0;
        }
      }

      const langMatch = toneTag.match(/lang="([^"]*)"/);
      if (!langMatch || langMatch[1] === '1') {
        tone.lang = Lang.Chinese;
      } else {
        tone.lang = Lang.English;
      }

      // 解析pronounce属性（发音）
      const pronounceMatch = toneTag.match(/pronounce="([^"]*)"/);
      if (pronounceMatch) {
        // 可以存储发音信息，但当前数据模型中没有对应字段
        LogUtils.d(`Tone pronounce: ${pronounceMatch[1]}`);
      }

      // 解析word内容
      const wordMatch = toneContent.match(/<word>(.*?)<\/word>/);
      if (wordMatch) {
        tone.word = wordMatch[1];

        // 如果lang字段缺失，通过word内容检查语言
        if (!langMatch) {
          const isEnglish = XmlParser.checkLang(tone.word);
          if (isEnglish) {
            tone.lang = Lang.English;
          }
        }
      } else {
        // 如果没有word标签，使用整个内容作为word
        tone.word = toneContent.trim();
      }

      return tone;
    } catch (error) {
      LogUtils.e(`parseTone error: ${error}`);
      return null;
    }
  }

  /**
   * 解析独白数据
   * @param monologTag 完整的monolog标签
   * @param monologContent monolog标签内容
   * @returns Monolog对象
   */
  private static parseMonolog(monologTag: string, monologContent: string): Monolog | null {
    try {
      const monolog = new Monolog();

      // 解析属性
      const beginMatch = monologTag.match(/begin="([^"]*)"/);
      if (beginMatch) {
        monolog.begin = Math.floor(parseFloat(beginMatch[1]) * 1000);
      }

      const endMatch = monologTag.match(/end="([^"]*)"/);
      if (endMatch) {
        monolog.end = Math.floor(parseFloat(endMatch[1]) * 1000);
      }

      const pitchMatch = monologTag.match(/pitch="([^"]*)"/);
      if (pitchMatch) {
        try {
          const pitchValue = parseFloat(pitchMatch[1]);
          monolog.pitch = Math.floor(pitchValue);
        } catch (error) {
          LogUtils.w(`Failed to parse monolog pitch: ${pitchMatch[1]}`);
          monolog.pitch = 0;
        }
      }

      const langMatch = monologTag.match(/lang="([^"]*)"/);
      if (!langMatch || langMatch[1] === '1') {
        monolog.lang = Lang.Chinese;
      } else {
        monolog.lang = Lang.English;
      }

      // monolog的内容直接是文本
      monolog.word = monologContent.trim();

      return monolog;
    } catch (error) {
      LogUtils.e(`parseMonolog error: ${error}`);
      return null;
    }
  }

  /**
   * 检查单词是否为中文
   * @param word 要检查的单词
   * @returns 如果单词不是中文则返回true，否则返回false
   */
  private static checkLang(word: string): boolean {
    for (let i = 0; i < word.length; i++) {
      const charCode = word.charCodeAt(i);
      if (!(19968 <= charCode && charCode < 40869)) {
        return true; // 不是中文字符
      }
    }
    return false; // 全是中文字符
  }

  /**
   * 解析XML格式音调数据
   * @param fileData 包含XML音调数据的字节数组
   * @returns XmlPitchData对象，包含解析后的音调数据
   */
  static parseXmlPitchData(fileData: Uint8Array): XmlPitchData {
    const model: XmlPitchData = {
      version: 0,
      interval: 0,
      reserved: 0,
      pitches: []
    };

    if (!fileData || fileData.length === 0) {
      return model;
    }

    try {
      const buffer = fileData.buffer;
      const dataView = new DataView(buffer);
      let offset = 0;

      // 读取int32值直到文件结束
      model.version = XmlParser.readLittleEndianInt(dataView, offset);
      offset += 4;
      LogUtils.d(`Version for the pitch file: ${model.version}`);

      model.interval = XmlParser.readLittleEndianInt(dataView, offset);
      offset += 4;
      LogUtils.d(`Interval for the pitch file: ${model.interval}`);

      model.reserved = XmlParser.readLittleEndianInt(dataView, offset);
      offset += 4;
      LogUtils.d(`Reserved for the pitch file: ${model.reserved}`);

      while (offset + 8 <= buffer.byteLength) {
        // 每个音调值至少占用8位
        const pitch = XmlParser.readLittleEndianDouble(dataView, offset);
        offset += 8;

        // 格式化到3位小数
        const formattedPitch = Math.round(pitch * 1000) / 1000;
        model.pitches.push(formattedPitch);
      }
    } catch (error) {
      LogUtils.e(`parseXmlPitchData error: ${error}`);
    }

    return model;
  }

  /**
   * 获取指定时间范围内的平均音调值
   * @param data 包含音调值的XmlPitchData
   * @param startOfFirstTone 第一个音调的开始时间（毫秒）
   * @param start 范围开始时间（毫秒）
   * @param end 范围结束时间（毫秒）
   * @returns 范围内的平均音调值，如果没有找到有效音调则返回0
   */
  static fetchPitchWithRange(
    data: XmlPitchData | null,
    startOfFirstTone: number,
    start: number,
    end: number
  ): number {
    if (!data || !data.pitches || data.pitches.length === 0) {
      return 0;
    }

    const fromIdx = Math.floor((start - startOfFirstTone) / data.interval);
    const toIdx = Math.floor((end - startOfFirstTone) / data.interval);

    let total = 0;
    let numberOfValidPitches = 0;

    for (let idx = fromIdx; idx < toIdx && idx < data.pitches.length; idx++) {
      if (idx >= 0) {
        const pitch = data.pitches[idx];
        if (pitch > 0) { // 过滤值 <= 0
          total += pitch;
          numberOfValidPitches++;
        }
      }
    }

    if (numberOfValidPitches > 0) {
      return total / numberOfValidPitches;
    }
    return 0;
  }

  /**
   * 解析KRC格式音调数据
   * @param fileData 包含KRC音调数据的字节数组
   * @returns PitchData对象数组，如果解析失败则返回null
   */
  static parseKrcPitchData(fileData: Uint8Array): PitchData[] | null {
    if (!fileData || fileData.length === 0) {
      return null;
    }

    try {
      let jsonData = Utils.uint8ArrayToString(fileData);

      const jsonObject: XmlPitchDataJson = JSON.parse(jsonData) as XmlPitchDataJson;
      if (jsonObject.pitchDatas) {
        const pitchDatas = jsonObject.pitchDatas;
        if (typeof pitchDatas === 'string') {
          return JSON.parse(pitchDatas) as PitchData[];
        } else if (Array.isArray(pitchDatas)) {
          return pitchDatas as PitchData[];
        }
      }
    } catch (error) {
      LogUtils.e(`parseKrcPitchData error: ${error}`);
    }

    return null;
  }

  /**
   * 从DataView读取小端序32位整数
   * @param dataView DataView对象
   * @param offset 偏移量
   * @returns 读取的整数值
   */
  private static readLittleEndianInt(dataView: DataView, offset: number): number {
    return dataView.getInt32(offset, true); // true表示小端序
  }

  /**
   * 从DataView读取小端序64位双精度浮点数
   * @param dataView DataView对象
   * @param offset 偏移量
   * @returns 读取的双精度浮点数值
   */
  private static readLittleEndianDouble(dataView: DataView, offset: number): number {
    return dataView.getFloat64(offset, true); // true表示小端序
  }

  /**
   * 从DataView读取小端序64位长整数
   * @param dataView DataView对象
   * @param offset 偏移量
   * @returns 读取的长整数值
   */
  private static readLittleEndianLong(dataView: DataView, offset: number): bigint {
    return dataView.getBigInt64(offset, true); // true表示小端序
  }

  /**
   * 获取无符号字节值
   * @param dataView DataView对象
   * @param offset 偏移量
   * @returns 无符号字节值
   */
  private static getUnsignedByte(dataView: DataView, offset: number): number {
    return dataView.getUint8(offset);
  }

  /**
   * 将有符号字节转换为无符号字节值
   * @param b 有符号字节
   * @returns 无符号字节值
   */
  private static asUnsignedByte(b: number): number {
    return b & 0xFF;
  }
}
