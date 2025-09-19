/**
 * 时间范围对，用于表示调整后的开始和结束时间
 */
interface TimePair {
  first: number;
  second: number;
}

/**
 * 简化的歌词行模型接口
 */
interface SimpleLyricsLine {
  getStartTime(): number;
  getEndTime(): number;
}

/**
 * 简化的歌词模型接口
 */
interface SimpleLyricModel {
  lines: SimpleLyricsLine[] | null;
  preludeEndPosition: number;
  duration: number;
}

/**
 * Utility class for cutting and trimming lyrics based on time ranges.
 * Provides functionality to extract portions of lyrics between specified start and end times.
 */
export class LyricsCutterSimple {

  /**
   * Adjusts the start and end times to match the nearest line boundaries
   *
   * @param startTime The requested start time in milliseconds
   * @param endTime   The requested end time in milliseconds
   * @param lines     List of lyrics lines to process
   * @return A TimePair containing the adjusted start and end times, or null if invalid
   */
  private static handleFixTime(startTime: number, endTime: number, lines: SimpleLyricsLine[]): TimePair | null {
    if (startTime >= endTime || lines.length === 0) {
      return null;
    }

    let start: number = startTime;
    let end: number = endTime;

    const firstLine: SimpleLyricsLine = lines[0];
    const lastLine: SimpleLyricsLine = lines[lines.length - 1];

    if ((start < firstLine.getStartTime() && end < firstLine.getStartTime()) ||
      (start > lastLine.getEndTime() && end > lastLine.getEndTime())) {
      return null;
    }

    // Adjust boundaries if they cross first or last line
    if (start < firstLine.getStartTime()) {
      start = firstLine.getStartTime();
    }
    if (end > lastLine.getEndTime()) {
      end = lastLine.getEndTime();
    }

    let startIndex: number = 0;
    let startGap: number = Number.MAX_VALUE;
    let endIndex: number = 0;
    let endGap: number = Number.MAX_VALUE;

    for (let i = 0; i < lines.length; i++) {
      const line: SimpleLyricsLine = lines[i];
      const currentStartGap: number = Math.abs(line.getStartTime() - start);
      const currentEndGap: number = Math.abs(line.getEndTime() - end);

      if (currentStartGap < startGap) {
        startGap = currentStartGap;
        startIndex = i;
      }
      if (currentEndGap < endGap) {
        endGap = currentEndGap;
        endIndex = i;
      }
    }

    const startLine: SimpleLyricsLine = lines[startIndex];
    const endLine: SimpleLyricsLine = lines[endIndex];
    if (startLine.getStartTime() < endLine.getEndTime()) {
      return {
        first: Math.floor(startLine.getStartTime()),
        second: Math.floor(endLine.getEndTime())
      };
    }
    return null;
  }

  /**
   * Cuts the lyrics model to include only lines within the specified time range
   *
   * @param model     The lyrics model to cut
   * @param startTime The start time in milliseconds
   * @param endTime   The end time in milliseconds
   * @return The modified lyrics model containing only the lines within the specified range,
   * or the original model if cutting is not possible
   */
  static cut(model: SimpleLyricModel | null, startTime: number, endTime: number): SimpleLyricModel | null {
    console.log(`cut LyricModel startTime: ${startTime} endTime: ${endTime} model: ${model}`);

    if (model === null || model.lines === null || model.lines.length === 0) {
      return model;
    }

    const pair: TimePair | null = LyricsCutterSimple.handleFixTime(startTime, endTime, model.lines);
    if (pair === null) {
      return model;
    }

    const highStartTime: number = pair.first;
    const lowEndTime: number = pair.second;
    console.log(`cut LyricModel highStartTime: ${highStartTime} lowEndTime: ${lowEndTime}`);

    const lines: SimpleLyricsLine[] = [];
    let flag: boolean = false;

    for (const line of model.lines) {
      if (line.getStartTime() === highStartTime) {
        flag = true;
      }
      if (line.getEndTime() === lowEndTime) {
        lines.push(line);
        break;
      }
      if (flag) {
        lines.push(line);
      }
    }

    model.lines = lines;
    model.preludeEndPosition = lines.length === 0 ? 0 : lines[0].getStartTime();
    model.duration = lines.length === 0 ? 0 : lines[lines.length - 1].getEndTime() - lines[lines.length - 1].getStartTime();

    return model;
  }
}
