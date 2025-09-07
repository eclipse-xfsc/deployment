'use client';

import RegisterLogin from '@/components/login/RegisterLogin';
import { DndProvider } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import AppContextProvider from './AppContextProvider';
import DiscoveryContext from './DiscoveryContext';
import TanStackProvider from './TanStackProvider';
import ParamsProvider from './ParamsProvider';
import KeycloakLoginInterceptor from '@/components/login/KeycloakLoginInterceptor';
import { ToastContainer } from 'react-toastify';

export const WalletProvider = ({ children }: { children: React.ReactNode }): JSX.Element => {
  return (
    <AppContextProvider>
      <TanStackProvider>
        <RegisterLogin>
          <KeycloakLoginInterceptor>
            <DndProvider backend={HTML5Backend}>
              <DiscoveryContext>
                <ParamsProvider>
                  <ToastContainer
                    position="top-right"
                    autoClose={5000}
                    hideProgressBar={false}
                    newestOnTop={false}
                    closeOnClick
                    rtl={false}
                    pauseOnFocusLoss
                    draggable
                    pauseOnHover
                  />
                  {children}
                </ParamsProvider>
              </DiscoveryContext>
            </DndProvider>
          </KeycloakLoginInterceptor>
        </RegisterLogin>
      </TanStackProvider>
    </AppContextProvider>
  );
};

export const AppProvider = ({ children }: { children: React.ReactNode }): JSX.Element => {
  return (
    <AppContextProvider>
      <TanStackProvider>
        <RegisterLogin>{children}</RegisterLogin>
      </TanStackProvider>
    </AppContextProvider>
  );
};
