import {AbsoluteFill, Img, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';

// Recreates assets/motion_backgrounds/premium_motion_background_16x9.mp4:
// the 675x1200 reference rotated 90° clockwise onto a 1920x1080 canvas
// (1200x675 * 1.6 covers it exactly), with a seamless-loop zoom drift and
// animated luma-only film grain. Colors of the reference are not altered.

const ZOOM_AMPLITUDE = 0.055;
const DRIFT_PX = 18;
const GRAIN_OPACITY = 0.16;

export const MotionBackground: React.FC = () => {
  const frame = useCurrentFrame();
  const {durationInFrames, width, height} = useVideoConfig();

  // Full sine cycle over the composition: frame 0 and the loop point are
  // identical, so the rendered video loops seamlessly.
  const phase = (2 * Math.PI * frame) / durationInFrames;
  const zoom = 1 + ZOOM_AMPLITUDE * (0.5 - 0.5 * Math.cos(phase));
  const driftX = DRIFT_PX * Math.sin(phase);

  return (
    <AbsoluteFill style={{backgroundColor: '#06121f', overflow: 'hidden'}}>
      <AbsoluteFill style={{transform: `scale(${zoom}) translateX(${driftX}px)`}}>
        <Img
          src={staticFile('reference.jpg')}
          style={{
            position: 'absolute',
            left: '50%',
            top: '50%',
            width: 675,
            height: 1200,
            transform: 'translate(-50%, -50%) rotate(90deg) scale(1.6)',
          }}
        />
      </AbsoluteFill>
      <AbsoluteFill style={{mixBlendMode: 'overlay', opacity: GRAIN_OPACITY}}>
        <svg width={width} height={height}>
          <filter id="grain">
            <feTurbulence
              type="fractalNoise"
              baseFrequency="0.9"
              numOctaves="2"
              seed={frame}
              stitchTiles="stitch"
            />
            <feColorMatrix type="saturate" values="0" />
          </filter>
          <rect width="100%" height="100%" filter="url(#grain)" />
        </svg>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
