import ErrorModal from '@/components/error-modal/ErrorModal';
import { useState, createContext, useEffect } from 'react';

interface AppContextProviderProps {
  children: React.ReactNode;
}

export interface IAppContext {
  setError: (error: Error) => void;
}

export const AppContext = createContext<IAppContext>({
  setError: () => {},
});

const AppContextProvider = ({ children }: AppContextProviderProps): JSX.Element => {
  const [error, setError] = useState<Error>();
  const [showError, setShowError] = useState(false);
  const [ctx, setCtx] = useState({
    setError,
  });

  useEffect(() => {
    error && setShowError(true);
  }, [error]);

  const handleHide = (): void => {
    setShowError(false);
  };

  const handleExited = (): void => {
    setError(undefined);
  };

  useEffect(() => {
    setCtx({
      setError,
    });
  }, [setError]);

  return (
    ctx && (
      <AppContext.Provider value={ctx}>
        {children}
        <ErrorModal
          error={error ?? new Error()}
          show={showError}
          handleClose={handleHide}
          handleExited={handleExited}
        />
      </AppContext.Provider>
    )
  );
};

export default AppContextProvider;
