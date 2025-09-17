# 绝对定位歌词居中解决方案

## 🎯 **核心思路**

根据您的需求，我们实现了一个基于绝对定位的歌词显示方案，确保当前行始终居中显示。

## 📐 **实现原理**

### 1. 位置计算逻辑

```typescript
@Builder
EnhancedLyricsLineBuilder(line: LyricsLineModel, index: number) {
  // 计算当前行相对于当前播放行的位置偏移
  const offsetFromCurrent = index - this.mIndexOfCurrentLine;
  const lineHeight = this.currentLineTextSize + this.lineSpacing + 20;
  
  // 计算当前行在屏幕中的Y位置
  // 屏幕中心位置 + (偏移行数 × 行高)
  const yPosition = (this.actualViewHeight / 2) + (offsetFromCurrent * lineHeight);
  
  // 只渲染在可视范围内的行
  if (yPosition >= -lineHeight && yPosition <= this.actualViewHeight + lineHeight) {
    // 渲染歌词行...
    .position({ x: 0, y: yPosition }) // 设置绝对位置
  }
}
```

### 2. 布局结构

```typescript
// 使用 Stack 来支持绝对定位
Stack() {
  if (this.mLyricMachine?.getLyricsModel()?.lines) {
    ForEach(this.mLyricMachine?.getLyricsModel()?.lines, (line: LyricsLineModel, index: number) => {
      this.EnhancedLyricsLineBuilder(line, index)
    })
  }
}
.width('100%')
.height('100%')
.alignContent(Alignment.TopStart) // 从顶部开始定位
```

## 🎵 **效果实现**

### 当 `mIndexOfCurrentLine = 0` 时：
- `index = 0`: `offsetFromCurrent = 0`, `yPosition = viewHeight/2` (屏幕中间)
- `index = 1`: `offsetFromCurrent = 1`, `yPosition = viewHeight/2 + lineHeight` (中间下方)
- `index = 2`: `offsetFromCurrent = 2`, `yPosition = viewHeight/2 + 2*lineHeight` (更下方)

### 当 `mIndexOfCurrentLine = 1` 时：
- `index = 0`: `offsetFromCurrent = -1`, `yPosition = viewHeight/2 - lineHeight` (中间上方)
- `index = 1`: `offsetFromCurrent = 0`, `yPosition = viewHeight/2` (屏幕中间)
- `index = 2`: `offsetFromCurrent = 1`, `yPosition = viewHeight/2 + lineHeight` (中间下方)

## ⚡ **性能优化**

### 可视区域裁剪
只渲染在可视范围内的歌词行，避免不必要的渲染：

```typescript
// 只渲染在可视范围内的行
if (yPosition >= -lineHeight && yPosition <= this.actualViewHeight + lineHeight) {
  // 渲染歌词行
}
```

### 平滑动画
使用 800ms 的动画时长，确保行切换时的平滑过渡：

```typescript
.animation({
  duration: 800, // 与滚动动画时长一致
  curve: Curve.EaseInOut,
  iterations: 1,
  playMode: PlayMode.Normal
})
```

## 🔧 **关键改进**

1. **移除滚动依赖**: 不再使用 `Scroll` 组件和 `scroller.scrollTo()`
2. **绝对定位**: 每行使用 `.position({ x: 0, y: yPosition })` 精确定位
3. **动态计算**: 基于 `mIndexOfCurrentLine` 和 `index` 实时计算位置
4. **性能优化**: 只渲染可视区域内的歌词行
5. **平滑动画**: 行切换时自动触发位置动画

## 🎤 **最终效果**

- ✅ 当前行始终在屏幕中心
- ✅ 其他行根据相对位置自动排列
- ✅ 超出可视区域的行不会渲染
- ✅ 行切换时有平滑的动画效果
- ✅ 无需手动滚动，位置自动计算

这个方案完全符合您的需求：**当前行总是屏幕居中效果**！
