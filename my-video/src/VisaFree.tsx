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
const RED = "#DC2626";
const RED_DEEP = "#991B1B";

const FLIP_START = 55;
const FLIP_END = 82;

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

  const translateY = interpolate(progress, [0, 1], [110, 0]);
  const blur = Math.max(
    0,
    interpolate(progress, [0, 1], [16, 0], { extrapolateRight: "clamp" }),
  );
  const opacity = interpolate(progress, [0, 0.5], [0, 1], {
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
}) => (
  <>
    {text.split("").map((char, i) => (
      <Letter key={i} char={char} index={i} startFrame={startFrame} />
    ))}
  </>
);

// Floating green particles for atmosphere
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

// One face of the flipping card
const CardFace: React.FC<{
  wash: string;
  border: string;
  children?: React.ReactNode;
  flipped?: boolean;
}> = ({ wash, border, children, flipped }) => (
  <div
    style={{
      position: "absolute",
      inset: 0,
      borderRadius: 32,
      overflow: "hidden",
      backgroundColor: "#FFFFFF",
      border: `3px solid ${border}`,
      boxShadow: "0 40px 90px rgba(10,40,20,0.28)",
      backfaceVisibility: "hidden",
      transform: flipped ? "rotateY(180deg)" : undefined,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
    }}
  >
    <Img
      src={staticFile("travel.jpg")}
      style={{ width: "86%" }}
    />
    {/* Color wash over the face */}
    <div
      style={{
        position: "absolute",
        inset: 0,
        background: wash,
        mixBlendMode: "multiply",
      }}
    />
    {children}
  </div>
);

export const VisaFree: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  // Bold cinematic push-in across the whole clip
  const drift = interpolate(frame, [0, durationInFrames], [1.0, 1.13], {
    easing: Easing.inOut(Easing.ease),
  });

  // --- Card entrance: drops into center with scale + blur ---
  const entry = spring({
    frame,
    fps,
    delay: 2,
    config: { damping: 14, stiffness: 90, mass: 0.9 },
  });
  const cardEntryScale = interpolate(entry, [0, 1], [1.6, 1]);
  const cardEntryY = interpolate(entry, [0, 1], [-420, 0]);
  const entryBlur = Math.max(0, interpolate(entry, [0, 1], [14, 0]));

  // --- "NO VISA" stamp slams on (~frame 18) ---
  const stamp = spring({
    frame: frame - 18,
    fps,
    config: { damping: 13, stiffness: 200, mass: 0.7 },
  });
  const stampScale = interpolate(stamp, [0, 1], [2.6, 1]);
  const stampOpacity = interpolate(stamp, [0, 0.35], [0, 1], {
    extrapolateRight: "clamp",
  });
  // Impact jitter right after the stamp lands
  const jitter =
    frame > 20 && frame < 30
      ? Math.sin(frame * 3.1) * interpolate(frame, [20, 30], [7, 0])
      : 0;

  // --- 3D flip: red face rotates away, green face rotates in ---
  const flip = interpolate(frame, [FLIP_START, FLIP_END], [0, 180], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });
  // Card lifts slightly and re-settles during the flip
  const flipLift = Math.sin((flip / 180) * Math.PI) * -46;

  // Flash right at the midpoint of the flip
  const midFrame = (FLIP_START + FLIP_END) / 2;
  const flash = interpolate(
    frame,
    [midFrame - 4, midFrame, midFrame + 10],
    [0, 0.65, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  // Red ambience during the "no" phase, green after the flip
  const redAmbience = interpolate(
    frame,
    [12, 20, FLIP_START + 8, midFrame],
    [0, 0.5, 0.5, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
  const greenGlow = interpolate(
    frame,
    [midFrame, FLIP_END + 8, 120],
    [0, 0.55, 0.3],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );

  // --- "VISA FREE" title in front of the card after the flip ---
  const titleStart = FLIP_END + 2;
  // Backdrop glow that keeps the title readable over the image
  const titleBackdrop = interpolate(
    frame,
    [titleStart, titleStart + 16],
    [0, 1],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" },
  );
  const underline = spring({
    frame: frame - (titleStart + 26),
    fps,
    config: { damping: 200, stiffness: 110 },
  });

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
        {/* Centered flipping card */}
        <AbsoluteFill
          style={{ justifyContent: "center", alignItems: "center" }}
        >
          <div
            style={{
              width: 600,
              height: 780,
              perspective: 1600,
              transform: `translateY(${cardEntryY + flipLift}px) translateX(${jitter}px) scale(${cardEntryScale})`,
              filter: `blur(${entryBlur}px)`,
            }}
          >
            <div
              style={{
                position: "absolute",
                inset: 0,
                transformStyle: "preserve-3d",
                transform: `rotateY(${flip}deg)`,
              }}
            >
              {/* FRONT: red "no" state */}
              <CardFace
                wash="rgba(220,38,38,0.42)"
                border={RED}
              >
                <div
                  style={{
                    position: "absolute",
                    top: "50%",
                    left: "50%",
                    transform: `translate(-50%, -50%) rotate(-12deg) scale(${stampScale})`,
                    opacity: stampOpacity,
                    color: RED,
                    border: `10px solid ${RED}`,
                    borderRadius: 18,
                    padding: "14px 34px",
                    fontFamily:
                      "'Helvetica Neue', Helvetica, Arial, sans-serif",
                    fontWeight: 900,
                    fontSize: 92,
                    letterSpacing: 10,
                    whiteSpace: "nowrap",
                    backgroundColor: "rgba(255,255,255,0.82)",
                    boxShadow: "0 10px 40px rgba(153,27,27,0.35)",
                  }}
                >
                  NO VISA
                </div>
              </CardFace>

              {/* BACK: green state */}
              <CardFace
                wash="rgba(34,197,94,0.14)"
                border={GREEN}
                flipped
              />
            </div>
          </div>
        </AbsoluteFill>

        {/* "VISA FREE" — centered, in front of the card */}
        <AbsoluteFill
          style={{ justifyContent: "center", alignItems: "center" }}
        >
          {/* Soft white backdrop for readability over the card */}
          <div
            style={{
              position: "absolute",
              width: 1500,
              height: 380,
              background:
                "radial-gradient(ellipse, rgba(255,255,255,0.92) 0%, rgba(255,255,255,0.55) 45%, rgba(255,255,255,0) 72%)",
              opacity: titleBackdrop,
            }}
          />
          <h1
            style={{
              position: "relative",
              fontFamily: "'Helvetica Neue', Helvetica, Arial, sans-serif",
              fontWeight: 900,
              fontSize: 178,
              letterSpacing: 8,
              margin: 0,
              color: GREEN,
              whiteSpace: "nowrap",
              textShadow:
                "0 4px 18px rgba(255,255,255,0.9), 0 8px 60px rgba(14,159,79,0.35)",
            }}
          >
            <Word text="VISA FREE" startFrame={titleStart} />
          </h1>
          {/* Sweeping underline */}
          <div
            style={{
              height: 11,
              width: `${underline * 46}%`,
              marginTop: 30,
              borderRadius: 8,
              background: `linear-gradient(90deg, ${GREEN_BRIGHT}, ${GREEN_DEEP})`,
              boxShadow: "0 6px 30px rgba(14,159,79,0.45)",
            }}
          />
        </AbsoluteFill>

        {/* --- Atmosphere overlays --- */}

        {/* Red ambience while "NO VISA" shows */}
        <AbsoluteFill
          style={{
            background:
              "radial-gradient(ellipse at 50% 50%, rgba(220,38,38,0) 40%, rgba(153,27,27,0.16) 100%)",
            opacity: redAmbience,
            pointerEvents: "none",
          }}
        />

        {/* Green glow ambience after the flip */}
        <AbsoluteFill
          style={{
            background:
              "radial-gradient(ellipse at 50% 50%, rgba(34,197,94,0.16) 0%, rgba(34,197,94,0) 55%), radial-gradient(ellipse at 50% 50%, rgba(255,255,255,0) 55%, rgba(6,107,51,0.12) 100%)",
            opacity: greenGlow,
            pointerEvents: "none",
          }}
        />

        <Particles />

        {/* Flash at the flip midpoint */}
        <AbsoluteFill
          style={{
            background:
              "radial-gradient(ellipse at 50% 50%, rgba(220,255,232,0.95) 0%, rgba(255,255,255,0) 62%)",
            opacity: flash,
            pointerEvents: "none",
          }}
        />

        {/* Cinematic light streaks */}
        <LightStreak start={30} end={58} peak={0.35} width={300} />
        <LightStreak start={FLIP_END + 8} end={142} peak={0.45} width={320} />
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
