import React from "react";
import {
  AbsoluteFill,
  Easing,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

const GREEN = "#0E9F4F";
const GREEN_DARK = "#0B7A3D";

const Letter: React.FC<{
  char: string;
  index: number;
  startFrame: number;
}> = ({ char, index, startFrame }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const progress = spring({
    frame: frame - startFrame - index * 3,
    fps,
    config: { damping: 200, stiffness: 60, mass: 0.9 },
  });

  const translateY = interpolate(progress, [0, 1], [90, 0]);
  const blur = interpolate(progress, [0, 1], [18, 0]);
  const opacity = interpolate(progress, [0, 0.6], [0, 1], {
    extrapolateRight: "clamp",
  });

  return (
    <span
      style={{
        display: "inline-block",
        transform: `translateY(${translateY}px)`,
        filter: `blur(${blur}px)`,
        opacity,
        whiteSpace: "pre",
      }}
    >
      {char}
    </span>
  );
};

const Word: React.FC<{ text: string; startFrame: number }> = ({
  text,
  startFrame,
}) => {
  return (
    <>
      {text.split("").map((char, i) => (
        <Letter key={i} char={char} index={i} startFrame={startFrame} />
      ))}
    </>
  );
};

export const VisaFree: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames, width } = useVideoConfig();

  // Slow cinematic push-in across the whole clip
  const drift = interpolate(frame, [0, durationInFrames], [1.04, 1.12], {
    easing: Easing.inOut(Easing.ease),
  });

  // Underline sweeps in once the letters have landed
  const underline = spring({
    frame: frame - 55,
    fps,
    config: { damping: 200, stiffness: 80 },
  });

  // Letter-spacing relaxes as the title settles
  const tracking = interpolate(frame, [0, 70], [34, 14], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.ease),
  });

  // Soft light shimmer sweeping across the text near the end
  const shimmerX = interpolate(frame, [80, 135], [-width * 0.6, width * 0.6], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.ease),
  });
  const shimmerOpacity = interpolate(
    frame,
    [80, 95, 120, 135],
    [0, 0.35, 0.35, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  // Gentle fade to end the clip cleanly
  const fadeOut = interpolate(
    frame,
    [durationInFrames - 12, durationInFrames],
    [1, 0],
    { extrapolateLeft: "clamp" },
  );

  return (
    <AbsoluteFill style={{ backgroundColor: "#FFFFFF", opacity: fadeOut }}>
      {/* Soft vignette for cinematic depth */}
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at center, rgba(255,255,255,0) 55%, rgba(14,159,79,0.06) 100%)",
        }}
      />
      <AbsoluteFill
        style={{
          justifyContent: "center",
          alignItems: "center",
          transform: `scale(${drift})`,
        }}
      >
        <div style={{ position: "relative", textAlign: "center" }}>
          <h1
            style={{
              fontFamily:
                "'Helvetica Neue', Helvetica, Arial, sans-serif",
              fontWeight: 800,
              fontSize: 190,
              letterSpacing: tracking,
              margin: 0,
              lineHeight: 1.05,
              color: GREEN,
              textShadow: "0 2px 30px rgba(14,159,79,0.18)",
            }}
          >
            <Word text="VISA" startFrame={5} />
            {"  "}
            <Word text="FREE" startFrame={20} />
          </h1>

          {/* Sweeping underline */}
          <div
            style={{
              height: 10,
              width: `${underline * 72}%`,
              margin: "38px auto 0",
              borderRadius: 6,
              background: `linear-gradient(90deg, ${GREEN}, ${GREEN_DARK})`,
              boxShadow: "0 4px 24px rgba(14,159,79,0.35)",
            }}
          />

          {/* Light shimmer sweep */}
          <div
            style={{
              position: "absolute",
              inset: "-40px 0",
              transform: `translateX(${shimmerX}px) skewX(-18deg)`,
              background:
                "linear-gradient(90deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.9) 50%, rgba(255,255,255,0) 100%)",
              width: 220,
              opacity: shimmerOpacity,
              pointerEvents: "none",
            }}
          />
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
