import React from "react";
import {
  AbsoluteFill,
  Easing,
  interpolate,
  random,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

const GOLD = "#F2C14E";
const GOLD_DEEP = "#C99A2E";

const COUNT_END = 68; // frame where the counter lands on 10

const countValue = (frame: number) =>
  interpolate(frame, [4, COUNT_END], [0, 10], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.poly(4)),
  });

// Slow-drifting gold dust for atmosphere
const GoldDust: React.FC = () => {
  const frame = useCurrentFrame();
  const { width, height, durationInFrames } = useVideoConfig();

  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      {Array.from({ length: 34 }).map((_, i) => {
        const seed = i + 1;
        const x = random(`dx-${seed}`) * width;
        const startY = height * random(`dy-${seed}`);
        const size = 2 + random(`ds-${seed}`) * 5;
        const speed = 40 + random(`dv-${seed}`) * 90;
        const y = startY - (frame / durationInFrames) * speed;
        const twinkle =
          0.1 + 0.3 * Math.sin(frame / 7 + random(`dp-${seed}`) * 10);
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: x,
              top: y,
              width: size,
              height: size,
              borderRadius: "50%",
              backgroundColor: GOLD,
              opacity: Math.max(0, twinkle),
              filter: "blur(1px)",
            }}
          />
        );
      })}
    </AbsoluteFill>
  );
};

export const EuroCounter: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames, width, height } = useVideoConfig();

  const isPortrait = height > width;
  const digitSize = isPortrait ? 330 : 300;

  const value = Math.floor(countValue(frame));
  // Counting speed drives the motion blur — fast at the start, crisp at the end
  const speed = countValue(frame) - countValue(frame - 1);
  const blur = Math.min(14, speed * 26);

  // Small vertical judder while the numbers fly
  const judder =
    speed > 0.05 ? Math.sin(frame * 7.3) * Math.min(10, speed * 22) : 0;

  // Landing punch: scale pop + flash + shockwave ring at COUNT_END
  const punch = spring({
    frame: frame - COUNT_END,
    fps,
    config: { damping: 11, stiffness: 160, mass: 0.8 },
  });
  const punchScale =
    frame < COUNT_END ? 1 : 1 + Math.sin(Math.min(punch, 1) * Math.PI) * 0.16;
  const flash = interpolate(
    frame,
    [COUNT_END, COUNT_END + 3, COUNT_END + 14],
    [0, 0.75, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
  const ring = interpolate(frame, [COUNT_END, COUNT_END + 18], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  // Glow blooms as the value climbs, peaks on landing
  const glow = interpolate(frame, [0, COUNT_END, COUNT_END + 10], [0.25, 0.6, 1], {
    extrapolateRight: "clamp",
  });

  // Gentle cinematic push-in
  const drift = interpolate(frame, [0, durationInFrames], [1.0, 1.09], {
    easing: Easing.inOut(Easing.ease),
  });

  // Quick fade in/out to cut cleanly
  const fade =
    interpolate(frame, [0, 6], [0, 1], {
      extrapolateRight: "clamp",
    }) *
    interpolate(frame, [durationInFrames - 6, durationInFrames], [1, 0], {
      extrapolateLeft: "clamp",
    });

  return (
    <AbsoluteFill style={{ backgroundColor: "#08080B", opacity: fade }}>
      {/* Deep vignette */}
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at 50% 46%, rgba(38,34,22,0.9) 0%, rgba(8,8,11,1) 72%)",
        }}
      />

      <AbsoluteFill style={{ transform: `scale(${drift})` }}>
        <GoldDust />

        {/* Center glow behind the number */}
        <AbsoluteFill
          style={{
            justifyContent: "center",
            alignItems: "center",
          }}
        >
          <div
            style={{
              position: "absolute",
              width: isPortrait ? 950 : 1200,
              height: isPortrait ? 950 : 700,
              borderRadius: "50%",
              background:
                "radial-gradient(circle, rgba(242,193,78,0.28) 0%, rgba(242,193,78,0.08) 42%, rgba(242,193,78,0) 68%)",
              opacity: glow,
              filter: "blur(10px)",
            }}
          />

          {/* Shockwave ring on landing */}
          {frame >= COUNT_END && (
            <div
              style={{
                position: "absolute",
                width: 300 + ring * (isPortrait ? 900 : 1300),
                height: 300 + ring * (isPortrait ? 900 : 1300),
                borderRadius: "50%",
                border: `3px solid rgba(242,193,78,${0.55 * (1 - ring)})`,
                boxShadow: `0 0 60px rgba(242,193,78,${0.35 * (1 - ring)})`,
              }}
            />
          )}

          {/* The counter */}
          <div
            style={{
              display: "flex",
              alignItems: "baseline",
              transform: `translateY(${judder}px) scale(${punchScale})`,
              filter: `blur(${blur}px)`,
              fontFamily: "'Helvetica Neue', Helvetica, Arial, sans-serif",
              fontWeight: 900,
              whiteSpace: "nowrap",
            }}
          >
            <span
              style={{
                fontSize: digitSize * 0.72,
                marginRight: 18,
                background: `linear-gradient(180deg, ${GOLD} 20%, ${GOLD_DEEP} 90%)`,
                WebkitBackgroundClip: "text",
                backgroundClip: "text",
                color: "transparent",
                textShadow: "0 0 70px rgba(242,193,78,0.45)",
              }}
            >
              €
            </span>
            <span
              style={{
                fontSize: digitSize,
                color: "#FFFFFF",
                textShadow: `0 0 40px rgba(255,255,255,0.35), 0 0 120px rgba(242,193,78,${0.35 + 0.35 * glow})`,
                fontVariantNumeric: "tabular-nums",
              }}
            >
              {value}
            </span>
          </div>
        </AbsoluteFill>

        {/* Landing flash */}
        <AbsoluteFill
          style={{
            background:
              "radial-gradient(circle at 50% 50%, rgba(255,244,214,0.95) 0%, rgba(255,244,214,0) 58%)",
            opacity: flash,
            pointerEvents: "none",
          }}
        />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
