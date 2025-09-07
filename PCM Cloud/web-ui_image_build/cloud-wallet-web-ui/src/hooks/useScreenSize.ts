import { useEffect, useState } from 'react';

export interface ScreenSize {
  width: number;
  height: number;
}

const isWindowDefined = (): boolean => typeof window !== 'undefined';

const getScreenSize = (): ScreenSize => {
  if (!isWindowDefined()) return { width: 0, height: 0 };

  const width = window.innerWidth;
  const height = window.innerHeight;

  return { width, height };
};

const useScreenSize = (): ScreenSize => {
  const [screenSize, setScreenSize] = useState<ScreenSize>(getScreenSize());

  useEffect(() => {
    const handleResize = (): void => {
      setScreenSize(getScreenSize());
    };

    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
    };
  }, []);

  return screenSize;
};

export default useScreenSize;
