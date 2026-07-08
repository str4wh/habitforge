import React from "react";
import {
  AbsoluteFill,
  Easing,
  Img,
  interpolate,
  random,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

const GREEN = "#0E9F4F";
const GREEN_DEEP = "#066B33";
const GREEN_BRIGHT = "#22C55E";

// Staggered letter reveal with blur + rise
const Letter: React.FC<{
  char: string;
  index: number;
  startFrame: number;
}> = ({ char, index, startFrame }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const progress = spring({
    frame: frame - startFrame - index * 2,
    fps,
    config: { damping: 16, stiffness: 130, mass: 0.6 },
  });

  const translateY = interpolate(progress, [0, 1], [120, 0]);
  const blur = interpolate(progress, [0, 1], [16, 0], {
    extrapolateRight: "clamp",
  });
  const opacity = interpolate(progress, [0, 0.5], [0, 1], {
    extrapolateRight: "clamp",
  });

  return (
    <span
      style={{
        display: "inline-block",
        transform: `translateY(${translateY}px)`,
        filter: `blur(${Math.max(0, blur)}px)`,
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
}) => (
  <>
    {text.split("").map((char, i) => (
      <Letter key={i} char={char} index={i} startFrame={startFrame} />
    ))}
  </>
);

// Floating green particles for atmosphere (drawn above everything)
const Particles: React.FC = () => {
  const frame = useCurrentFrame();
  const { width, height, durationInFrames } = useVideoConfig();

  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      {Array.from({ length: 26 }).map((_, i) => {
        const seed = i + 1;
        const x = random(`x-${seed}`) * width;
        const startY = height * (0.3 + random(`y-${seed}`) * 0.8);
        const size = 3 + random(`s-${seed}`) * 6;
        const speed = 60 + random(`v-${seed}`) * 140;
        const y = startY - (frame / durationInFrames) * speed;
        const twinkle =
          0.12 + 0.3 * Math.sin(frame / 9 + random(`p-${seed}`) * 10);
        const appear = interpolate(frame, [10 + i, 35 + i], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        });
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
              backgroundColor: GREEN_BRIGHT,
              opacity: Math.max(0, twinkle) * appear,
              filter: "blur(1px)",
            }}
          />
        );
      })}
    </AbsoluteFill>
  );
};

// Diagonal light streak sweeping across the frame
const LightStreak: React.FC<{
  start: number;
  end: number;
  peak: number;
  width: number;
}> = ({ start, end, peak, width: streakWidth }) => {
  const frame = useCurrentFrame();
  const { width } = useVideoConfig();

  const x = interpolate(frame, [start, end], [-width * 0.5, width * 1.2], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.ease),
  });
  const opacity = interpolate(
    frame,
    [start, (start + end) / 2, end],
    [0, peak, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  return (
    <div
      style={{
        position: "absolute",
        top: "-20%",
        bottom: "-20%",
        left: 0,
        width: streakWidth,
        transform: `translateX(${x}px) skewX(-20deg)`,
        background:
          "linear-gradient(90deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.95) 45%, rgba(190,255,215,0.9) 55%, rgba(255,255,255,0) 100%)",
        opacity,
        pointerEvents: "none",
      }}
    />
  );
};

export const VisaFree: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  // Bold cinematic push-in across the whole clip
  const drift = interpolate(frame, [0, durationInFrames], [1.0, 1.16], {
    easing: Easing.inOut(Easing.ease),
  });

  // --- Image entrance: flies in from bottom-right with rotation & motion blur ---
  const flyIn = spring({
    frame,
    fps,
    delay: 2,
    config: { damping: 15, stiffness: 42, mass: 1.1 },
  });
  const imgX = interpolate(flyIn, [0, 1], [900, 0]);
  const imgY = interpolate(flyIn, [0, 1], [520, 0]);
  const imgRotate = interpolate(flyIn, [0, 1], [28, -5]);
  const imgScale = interpolate(flyIn, [0, 1], [1.5, 1]);
  const imgBlur = Math.max(0, interpolate(flyIn, [0, 0.75, 1], [14, 3, 0]));

  // Gentle float once landed
  const floatY = Math.sin(frame / 22) * 8 * flyIn;

  // Impact flash when the image lands (~frame 30)
  const flash = interpolate(frame, [28, 34, 46], [0, 0.5, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Underline sweeps in after the words land
  const underline = spring({
    frame: frame - 88,
    fps,
    config: { damping: 200, stiffness: 90 },
  });

  // Glow pulse behind the title as it lands
  const glow = interpolate(frame, [48, 70, 110], [0, 0.5, 0.22], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Grounding shadow under the image, drawn ON TOP with multiply so it
  // reads through the JPG's white background without revealing its edges
  const shadowOpacity = flyIn * 0.9;

  // Clean fade to end the clip
  const fadeOut = interpolate(
    frame,
    [durationInFrames - 10, durationInFrames],
    [1, 0],
    { extrapolateLeft: "clamp" },
  );

  return (
    <AbsoluteFill style={{ backgroundColor: "#FFFFFF", opacity: fadeOut }}>
      <AbsoluteFill style={{ transform: `scale(${drift})` }}>
        {/* Layout: title left, image right */}
        <AbsoluteFill
          style={{
            flexDirection: "row",
            alignItems: "center",
            padding: "0 120px",
          }}
        >
          {/* Title block */}
          <div style={{ flex: 1.15, position: "relative" }}>
            <h1
              style={{
                position: "relative",
                fontFamily: "'Helvetica Neue', Helvetica, Arial, sans-serif",
                fontWeight: 900,
                fontSize: 230,
                lineHeight: 1.02,
                letterSpacing: 6,
                margin: 0,
                color: GREEN,
                textShadow: "0 6px 60px rgba(14,159,79,0.25)",
              }}
            >
              <div>
                <Word text="VISA" startFrame={42} />
              </div>
              <div style={{ color: GREEN_DEEP }}>
                <Word text="FREE" startFrame={54} />
              </div>
            </h1>

            {/* Sweeping underline */}
            <div
              style={{
                height: 12,
                width: `${underline * 62}%`,
                marginTop: 34,
                borderRadius: 8,
                background: `linear-gradient(90deg, ${GREEN_BRIGHT}, ${GREEN_DEEP})`,
                boxShadow: "0 6px 30px rgba(14,159,79,0.45)",
              }}
            />
          </div>

          {/* Travel image — rendered plain; all atmosphere is layered on top
              so the JPG's white background stays invisible on the white set */}
          <div
            style={{
              flex: 1,
              display: "flex",
              justifyContent: "center",
              position: "relative",
              transform: `translate(${imgX}px, ${imgY + floatY}px) rotate(${imgRotate}deg) scale(${imgScale})`,
              filter: `blur(${imgBlur}px)`,
            }}
          >
            <Img src={staticFile("travel.jpg")} style={{ width: 620 }} />
            {/* Grounding shadow, multiplied over the image bottom */}
            <div
              style={{
                position: "absolute",
                bottom: -20,
                left: "14%",
                right: "14%",
                height: 90,
                borderRadius: "50%",
                background:
                  "radial-gradient(ellipse, rgba(6,50,25,0.20) 0%, rgba(6,50,25,0) 70%)",
                filter: "blur(10px)",
                mixBlendMode: "multiply",
                opacity: shadowOpacity,
              }}
            />
          </div>
        </AbsoluteFill>

        {/* --- Atmosphere overlays (drawn above the image so nothing reveals
             the JPG's rectangular edges) --- */}

        {/* Glow pulse around the title */}
        <AbsoluteFill
          style={{
            background:
              "radial-gradient(ellipse at 24% 50%, rgba(34,197,94,0.30) 0%, rgba(34,197,94,0) 45%)",
            opacity: glow,
            pointerEvents: "none",
          }}
        />

        {/* Soft green vignette / color grade over the whole frame */}
        <AbsoluteFill
          style={{
            background:
              "radial-gradient(ellipse at 45% 45%, rgba(255,255,255,0) 55%, rgba(6,107,51,0.10) 100%)",
            mixBlendMode: "multiply",
            pointerEvents: "none",
          }}
        />

        <Particles />

        {/* Impact flash when the image lands */}
        <AbsoluteFill
          style={{
            background:
              "radial-gradient(ellipse at 68% 50%, rgba(210,255,225,0.9) 0%, rgba(255,255,255,0) 60%)",
            opacity: flash,
            pointerEvents: "none",
          }}
        />

        {/* Cinematic light streaks */}
        <LightStreak start={26} end={62} peak={0.5} width={340} />
        <LightStreak start={95} end={138} peak={0.4} width={260} />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
