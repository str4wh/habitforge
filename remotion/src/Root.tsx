import {Composition} from 'remotion';
import {MotionBackground} from './MotionBackground';

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="PremiumMotionBackground"
      component={MotionBackground}
      durationInFrames={300}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
