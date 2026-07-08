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
const GREEN_DEEP = "#066B33";
const GREEN_BRIGHT = "#22C55E";
const KEY_GREEN = "#00FF00"; // pure chroma green, keyed out in CapCut

const MONTHS = [
  "JAN", "FEB", "MAR",
  "APR", "MAY", "JUN",
  "JUL", "AUG", "SEP",
  "OCT", "NOV", "DEC",
];

// --- Calendar geometry (absolute, so the plane can fly tile-to-tile) ---
const CARD_X = 90;
const CARD_Y = 210;
const CARD_W = 900;
const HEADER_H = 130;
const TILE_W = 270;
const TILE_H = 150;
const GAP = 20;
const GRID_X = CARD_X + (CARD_W - (3 * TILE_W + 2 * GAP)) / 2;
const GRID_Y = CARD_Y + HEADER_H;
const CARD_H = HEADER_H + 4 * TILE_H + 3 * GAP + 35;

const tileX = (i: number) => GRID_X + (i % 3) * (TILE_W + GAP);
const tileY = (i: number) => GRID_Y + Math.floor(i / 3) * (TILE_H + GAP);
const tileCenter = (i: number): [number, number] => [
  tileX(i) + TILE_W / 2,
  tileY(i) + TILE_H / 2,
];

// Month indices
const APR = 3;
const MAY = 4;
const OCT = 9;
const NOV = 10;

// Highlight + flight schedule (30fps, 180 frames)
const LIGHT_TIMES: Record<number, number> = {
  [APR]: 30,
  [MAY]: 58,
  [OCT]: 100,
  [NOV]: 124,
};

type Flight = {
  from: number;
  to: number;
  start: number;
  end: number;
  lift: number; // arc height in px (negative = upward bow)
};

const FLIGHTS: Flight[] = [
  { from: APR, to: MAY, start: 34, end: 58, lift: -130 },
  { from: MAY, to: OCT, start: 66, end: 100, lift: -240 },
  { from: OCT, to: NOV, start: 104, end: 124, lift: -130 },
];

const BANNER_START = 132;
const OUTRO_START = 168;

// Quadratic bezier between tile centers with an upward bow
const flightPos = (fl: Flight, t: number): [number, number] => {
  const [x0, y0] = tileCenter(fl.from);
  const [x1, y1] = tileCenter(fl.to);
  const cx = (x0 + x1) / 2;
  const cy = (y0 + y1) / 2 + fl.lift;
  const u = 1 - t;
  return [
    u * u * x0 + 2 * u * t * cx + t * t * x1,
    u * u * y0 + 2 * u * t * cy + t * t * y1,
  ];
};

// Where is the plane at this frame? Returns [x, y, angleDeg]
const planeState = (frame: number): [number, number, number] => {
  const eased = (fl: Flight) =>
    interpolate(frame, [fl.start, fl.end], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
      easing: Easing.inOut(Easing.ease),
    });

  for (const fl of FLIGHTS) {
    if (frame <= fl.end) {
      if (frame < fl.start) {
        // Parked at the departure tile
        const [x, y] = tileCenter(fl.from);
        return [x, y, 0];
      }
      const t = eased(fl);
      const [x, y] = flightPos(fl, t);
      const [x2, y2] = flightPos(fl, Math.min(1, t + 0.02));
      const angle = (Math.atan2(y2 - y, x2 - x) * 180) / Math.PI;
      return [x, y, angle];
    }
  }
  // After the last flight, glide to NOV's top-right corner so the
  // plane doesn't cover the month label
  const lastEnd = FLIGHTS[FLIGHTS.length - 1].end;
  const settle = interpolate(frame, [lastEnd, lastEnd + 10], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.ease),
  });
  const [x, y] = tileCenter(NOV);
  return [x + settle * TILE_W * 0.34, y - settle * TILE_H * 0.42, 0];
};

const Plane: React.FC<{ x: number; y: number; angle: number; scale: number }> =
  ({ x, y, angle, scale }) => (
    <svg
      width={130}
      height={130}
      viewBox="0 0 24 24"
      style={{
        position: "absolute",
        left: x - 65,
        top: y - 65,
        // The glyph points up, so add 90° to align it with the travel direction
        transform: `rotate(${angle + 90}deg) scale(${scale})`,
        filter: "drop-shadow(0 10px 16px rgba(0,40,15,0.45))",
      }}
    >
      <path
        d="M21.5 15.5v-2l-8-5V3.06c0-.83-.67-1.5-1.5-1.5s-1.5.67-1.5 1.5V8.5l-8 5v2l8-2.5v5.5l-2 1.5V21l3.5-1 3.5 1v-1.5l-2-1.5v-5.5l8 2.5z"
        fill={GREEN_DEEP}
        stroke="#FFFFFF"
        strokeWidth={0.9}
      />
    </svg>
  );

const MonthTile: React.FC<{ index: number; outro: number }> = ({
  index,
  outro,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const lightAt = LIGHT_TIMES[index];
  const isBest = lightAt !== undefined;
  const lit = isBest
    ? spring({
        frame: frame - lightAt,
        fps,
        config: { damping: 12, stiffness: 190, mass: 0.7 },
      })
    : 0;
  const pop = 1 + Math.sin(Math.min(lit, 1) * Math.PI) * 0.12;

  return (
    <div
      style={{
        position: "absolute",
        left: tileX(index),
        top: tileY(index),
        width: TILE_W,
        height: TILE_H,
        borderRadius: 22,
        backgroundColor: lit > 0.5 ? GREEN : "#FFFFFF",
        border: `4px solid ${lit > 0.5 ? GREEN_DEEP : "#D8E8DE"}`,
        boxShadow:
          lit > 0.5
            ? "0 12px 36px rgba(14,159,79,0.55)"
            : "0 4px 14px rgba(0,40,15,0.10)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        transform: `scale(${pop * outro})`,
        fontFamily: "'Helvetica Neue', Helvetica, Arial, sans-serif",
        fontWeight: 900,
        fontSize: 56,
        letterSpacing: 4,
        color: lit > 0.5 ? "#FFFFFF" : "#7A9486",
      }}
    >
      {MONTHS[index]}
    </div>
  );
};

export const BestTimeCalendar: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Card entrance + overlay exit
  const entry = spring({
    frame,
    fps,
    config: { damping: 14, stiffness: 120, mass: 0.9 },
  });
  const outro = interpolate(frame, [OUTRO_START, 180], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.in(Easing.cubic),
  });

  // Plane
  const [px, py, angle] = planeState(frame);
  const planeIn = interpolate(frame, [20, 32], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const bob = Math.sin(frame / 9) * 5;

  // Banner
  const banner = spring({
    frame: frame - BANNER_START,
    fps,
    config: { damping: 12, stiffness: 150, mass: 0.9 },
  });
  const bannerY = interpolate(banner, [0, 1], [380, 0]);
  const underline = spring({
    frame: frame - BANNER_START - 12,
    fps,
    config: { damping: 200, stiffness: 120 },
  });

  return (
    <AbsoluteFill style={{ backgroundColor: KEY_GREEN }}>
      {/* Calendar card */}
      <div
        style={{
          position: "absolute",
          left: CARD_X,
          top: CARD_Y,
          width: CARD_W,
          height: CARD_H,
          borderRadius: 46,
          backgroundColor: "#FFFFFF",
          border: `8px solid ${GREEN}`,
          boxShadow: "0 24px 70px rgba(0,40,15,0.4)",
          transform: `scale(${entry * outro})`,
          fontFamily: "'Helvetica Neue', Helvetica, Arial, sans-serif",
        }}
      >
        <div
          style={{
            height: HEADER_H,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontSize: 58,
            fontWeight: 900,
            letterSpacing: 12,
            color: GREEN_DEEP,
            borderBottom: "3px solid #E2EFE7",
          }}
        >
          SEYCHELLES
        </div>
      </div>

      {/* Month tiles (absolute, over the card) */}
      {MONTHS.map((_, i) => (
        <MonthTile key={i} index={i} outro={entry * outro} />
      ))}

      {/* Dotted trail behind the plane */}
      {[6, 12, 18, 24, 30].map((back, i) => {
        const [tx, ty] = planeState(Math.max(0, frame - back));
        const isFlying = FLIGHTS.some(
          (fl) => frame - back >= fl.start && frame - back <= fl.end,
        );
        if (!isFlying) return null;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: tx - 7,
              top: ty - 7,
              width: 14,
              height: 14,
              borderRadius: "50%",
              backgroundColor: "#FFFFFF",
              border: `3px solid ${GREEN}`,
              opacity: (0.55 - i * 0.1) * planeIn * outro,
            }}
          />
        );
      })}

      {/* The plane */}
      <Plane
        x={px}
        y={py + bob}
        angle={angle}
        scale={planeIn * outro}
      />

      {/* Banner */}
      <AbsoluteFill
        style={{ justifyContent: "flex-end", alignItems: "center" }}
      >
        <div
          style={{
            marginBottom: 300,
            transform: `translateY(${bannerY}px) scale(${outro})`,
            opacity: Math.min(1, banner * 2),
            backgroundColor: "#FFFFFF",
            border: `8px solid ${GREEN}`,
            borderRadius: 48,
            padding: "50px 70px 44px",
            textAlign: "center",
            boxShadow: "0 24px 70px rgba(0,40,15,0.4)",
            fontFamily: "'Helvetica Neue', Helvetica, Arial, sans-serif",
          }}
        >
          <div
            style={{
              fontSize: 88,
              fontWeight: 900,
              lineHeight: 1.1,
              color: GREEN_DEEP,
            }}
          >
            BEST TIME
            <br />
            TO VISIT
          </div>
          <div
            style={{
              marginTop: 20,
              fontSize: 60,
              fontWeight: 800,
              letterSpacing: 3,
              color: GREEN,
            }}
          >
            APR–MAY & OCT–NOV
          </div>
          <div
            style={{
              height: 12,
              width: `${underline * 84}%`,
              margin: "26px auto 0",
              borderRadius: 8,
              background: `linear-gradient(90deg, ${GREEN_BRIGHT}, ${GREEN_DEEP})`,
            }}
          />
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
