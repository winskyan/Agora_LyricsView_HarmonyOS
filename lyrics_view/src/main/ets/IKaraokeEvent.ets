import { LyricsLineModel } from './model/LyricsLineModel';

/**
 * Karaoke event listener interface
 */
export interface IKaraokeEvent {
  /**
   * Called when all integrated karaoke components are ready
   * <p>
   * This event is fired once when all components (LyricsView and/or ScoringView)
   * that are actually integrated have completed their onAppear lifecycle.
   * Clients don't need to track which components are integrated - this event
   * guarantees that all available components are ready for use.
   * <p>
   * Do not block this callback
   */
  onKaraokeReady(): void;

  /**
   * Called automatically when lyrics is dragged
   * <p>
   * Do not block this callback
   *
   * @param progress progress in milliseconds
   */
  onDragTo(progress: number): void;

  /**
   * Called automatically when the line is finished
   * <p>
   * Do not block this callback
   *
   * @param line            LyricsLineModel
   * @param score           Current line score (0-100)
   * @param cumulativeScore Total cumulative score
   * @param index           Current line index (0-based)
   * @param lineCount       Total number of lines
   */
  onLineFinished(line: LyricsLineModel, score: number,
    cumulativeScore: number, index: number, lineCount: number): void;
}
