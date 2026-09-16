// QuestionGraph 世界坐标契约。
//
// canonical layout 以逻辑点表示，CENTER 固定在世界原点。它不随 iPad 的尺寸、
// 方向或本地 camera offset 改变；屏幕转换只发生在 iPad 呈现层。

export const WORLD_LAYOUT_VERSION = 'WORLD_V1';

// v4 及更早版本的 [0, 1] normalized 布局迁移到一张确定性的虚拟画布。
// 两端必须保持这组常量一致，避免离线缓存升级后位置漂移。
export const LEGACY_WORLD_WIDTH = 1000;
export const LEGACY_WORLD_HEIGHT = 700;

// 无限画布不等于接受 NaN/Infinity 或无限大的恶意输入。这个上限远大于正常
// 人工布局范围，同时避免 SQLite/SwiftUI 出现不可渲染的数值。
export const MAX_WORLD_COORDINATE = 1_000_000;
export const WORLD_ORIGIN = Object.freeze({ x: 0, y: 0 });

export function legacyNormalizedToWorld(xNorm, yNorm) {
  return {
    x: (Number(xNorm) - 0.5) * LEGACY_WORLD_WIDTH,
    y: (Number(yNorm) - 0.5) * LEGACY_WORLD_HEIGHT,
  };
}

// 仅用于仍带有 v4 NOT NULL 镜像列的原地升级库。新 canonical 读写永远使用
// x_world/y_world；这里的镜像值不参与同步或渲染。
export function worldToLegacyNormalized(xWorld, yWorld) {
  return {
    x: 0.5 + Number(xWorld) / LEGACY_WORLD_WIDTH,
    y: 0.5 + Number(yWorld) / LEGACY_WORLD_HEIGHT,
  };
}

export function worldPointIsValid(x, y) {
  return Number.isFinite(x) && Number.isFinite(y)
    && Math.abs(x) <= MAX_WORLD_COORDINATE
    && Math.abs(y) <= MAX_WORLD_COORDINATE;
}

/** 确定性向外扩展的黄金角环形初始位置；不再压回旧的 [0,1] 画布。 */
export function worldRadialSlot(index) {
  const goldenAngle = 2.399963229728653;
  const ring = Math.floor(index / 12);
  const radius = 180 + ring * 135;
  const angle = goldenAngle * index;
  return { x: radius * Math.cos(angle), y: radius * Math.sin(angle) };
}
