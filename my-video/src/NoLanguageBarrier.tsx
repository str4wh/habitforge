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

const GREEN = "#0E9F4F";
const GREEN_DEEP = "#066B33";
const GREEN_BRIGHT = "#22C55E";
// Pure chroma green — keyed out in CapCut; content avoids this hue
const KEY_GREEN = "#00FF00";

const BANNER_START = 88;
const OUTRO_START = 140;

type Bubble = {
  greeting: string;
  language: string;
  side: "left" | "right";
  start: number;
};

const BUBBLES: Bubble[] = [
  { greeting: "Bonzour!", language: "KREOL SESELWA", side: "left", start: 6 },
  { greeting: "Bonjour!", language: "FRANÇAIS", side: "right", start: 24 },
  { greeting: "Hello!", language: "ENGLISH", side: "left", start: 42 },
];

// White sparkles floating up (white survives chroma keying cleanly)
const Sparkles: React.FC = () => {
  const frame = useCurrentFrame();
  const { width, height, durationInFrames } = useVideoConfig();

  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      {Array.from({ length: 20 }).map((_, i) => {
        const seed = i + 1;
        const x = random(`x-${seed}`) * width;
        const startY = height * (0.25 + random(`y-${seed}`) * 0.75);
        const size = 4 + random(`s-${seed}`) * 7;
        const speed = 80 + random(`v-${seed}`) * 160;
        const y = startY - (frame / durationInFrames) * speed;
        const twinkle =
          0.25 + 0.45 * Math.sin(frame / 8 + random(`p-${seed}`) * 10);
        const appear = interpolate(
          frame,
          [BANNER_START + i, BANNER_START + 18 + i],
          [0, 1],
          { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
        );
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
              backgroundColor: "#FFFFFF",
              boxShadow: "0 0 12px rgba(255,255,255,0.9)",
              opacity: Math.max(0, twinkle) * appear,
            }}
          />
        );
      })}
    </AbsoluteFill>
  );
};

const ChatBubble: React.FC<{ bubble: Bubble; outro: number }> = ({
  bubble,
  outro,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const pop = spring({
    frame: frame - bubble.start,
    fps,
    config: { damping: 13, stiffness: 170, mass: 0.7 },
  });
  const check = spring({
    frame: frame - bubble.start - 12,
    fps,
    config: { damping: 12, stiffness: 220, mass: 0.6 },
  });
  // Gentle idle float once landed
  const float = Math.sin(frame / 20 + bubble.start) * 6 * pop;

  const isLeft = bubble.side === "left";

  return (
    <div
      style={{
        display: "flex",
        justifyContent: isLeft ? "flex-start" : "flex-end",
        width: "100%",
        padding: "0 56px",
        transform: `translateY(${float}px) scale(${pop * outro})`,
        opacity: Math.min(1, pop * 2),
      }}
    >
      <div
        style={{
          position: "relative",
          backgroundColor: "#FFFFFF",
          border: `6px solid ${GREEN}`,
          borderRadius: 44,
          [isLeft ? "borderBottomLeftRadius" : "borderBottomRightRadius"]: 8,
          padding: "38px 58px 32px",
          boxShadow: "0 18px 50px rgba(0,40,15,0.35)",
          fontFamily: "'Helvetica Neue', Helvetica, Arial, sans-serif",
        }}
      >
        <div
          style={{
            fontSize: 96,
            fontWeight: 900,
            color: GREEN_DEEP,
            lineHeight: 1,
          }}
        >
          {bubble.greeting}
        </div>
        <div
          style={{
            marginTop: 14,
            fontSize: 34,
            fontWeight: 700,
            letterSpacing: 6,
            color: GREEN,
          }}
        >
          {bubble.language}
        </div>
        {/* Check badge */}
        <div
          style={{
            position: "absolute",
            top: -30,
            [isLeft ? "right" : "left"]: -30,
            width: 86,
            height: 86,
            borderRadius: "50%",
            backgroundColor: GREEN_BRIGHT,
            border: "6px solid #FFFFFF",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            transform: `scale(${check})`,
            boxShadow: "0 8px 24px rgba(0,40,15,0.35)",
            color: "#FFFFFF",
            fontSize: 52,
            fontWeight: 900,
          }}
        >
          ✓
        </div>
      </div>
    </div>
  );
};

export const NoLanguageBarrier: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Everything scales out at the end for a clean overlay exit
  const outro = interpolate(frame, [OUTRO_START, 150], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.in(Easing.cubic),
  });

  // Banner entrance
  const banner = spring({
    frame: frame - BANNER_START,
    fps,
    config: { damping: 12, stiffness: 150, mass: 0.9 },
  });
  const bannerY = interpolate(banner, [0, 1], [420, 0]);
  const underline = spring({
    frame: frame - BANNER_START - 14,
    fps,
    config: { damping: 200, stiffness: 120 },
  });
  // Flash pulse when the banner lands
  const bannerFlash = interpolate(
    frame,
    [BANNER_START + 6, BANNER_START + 10, BANNER_START + 24],
    [0, 0.45, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  return (
    <AbsoluteFill style={{ backgroundColor: KEY_GREEN }}>
      <Sparkles />

      {/* Chat bubbles in the upper half */}
      <AbsoluteFill
        style={{
          justifyContent: "flex-start",
          paddingTop: 230,
          gap: 96,
        }}
      >
        {BUBBLES.map((b) => (
          <ChatBubble key={b.language} bubble={b} outro={outro} />
        ))}
      </AbsoluteFill>

      {/* Banner in the lower third */}
      <AbsoluteFill
        style={{ justifyContent: "flex-end", alignItems: "center" }}
      >
        <div
          style={{
            marginBottom: 320,
            transform: `translateY(${bannerY}px) scale(${outro})`,
            opacity: Math.min(1, banner * 2),
            backgroundColor: "#FFFFFF",
            border: `8px solid ${GREEN}`,
            borderRadius: 48,
            padding: "54px 74px 48px",
            textAlign: "center",
            boxShadow: "0 24px 70px rgba(0,40,15,0.4)",
            fontFamily: "'Helvetica Neue', Helvetica, Arial, sans-serif",
          }}
        >
          <div
            style={{
              fontSize: 108,
              fontWeight: 900,
              lineHeight: 1.08,
              color: GREEN_DEEP,
            }}
          >
            NO LANGUAGE
            <br />
            BARRIER
          </div>
          <div
            style={{
              height: 12,
              width: `${underline * 82}%`,
              margin: "30px auto 0",
              borderRadius: 8,
              background: `linear-gradient(90deg, ${GREEN_BRIGHT}, ${GREEN_DEEP})`,
            }}
          />
        </div>
      </AbsoluteFill>

      {/* Soft white flash when the banner lands */}
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(circle at 50% 62%, rgba(255,255,255,0.9) 0%, rgba(255,255,255,0) 55%)",
          opacity: bannerFlash,
          pointerEvents: "none",
        }}
      />
    </AbsoluteFill>
  );
};
