'use client';

import { ReactKeycloakProvider } from '@react-keycloak/web';
import Keycloak, { type KeycloakError } from 'keycloak-js';
import { useCallback, useContext, useEffect, useState } from 'react';
import { AppContext } from '@/store/AppContextProvider';
import LoadingSpinner from '../loading-spinner/LoadingSpinner';
import type { KeycloakAndMetadata, KeycloakConfig, OidcMetadata } from '@/service/types';
import { useQuery } from '@tanstack/react-query';
import { genericFetch } from '@/service/apiService';

interface RegisterLoginProps {
  children: React.ReactNode;
}

const getKeycloakConfig = async (): Promise<KeycloakAndMetadata> => {
  const keycloakConfig = await genericFetch<KeycloakConfig>(
    process.env.API_URL_CONFIG_SERVICE ?? '/api/keycloak-config'
  );

  const metadata = await genericFetch<OidcMetadata>(
    `${keycloakConfig.auth}/realms/${keycloakConfig.realm}/.well-known/openid-configuration`
  );

  return {
    keycloakConfig,
    metadata,
  };
};

const RegisterLogin = ({ children }: RegisterLoginProps): JSX.Element => {
  const { setError } = useContext(AppContext);
  const [keycloak, setKeycloak] = useState<Keycloak>();
  const { data, isLoading, error } = useQuery({ queryKey: ['keycloakConfigAndMetadata'], queryFn: getKeycloakConfig });

  const handleError = useCallback(
    (error: KeycloakError) => {
      setError(Error(error.error_description));
    },
    [setError]
  );

  useEffect(() => {
    error &&
      process.env.NODE_ENV === 'development' &&
      setError(
        Error(
          `This is a friendly reminder to ensure that Keycloak is running properly and configured correctly for the seamless operation of our application.

            To assist you in this process, we have detailed instructions and helpful information in the repository's README file. Please take a moment to review the README file to ensure that Keycloak is set up according to the specified configuration.
            
            If you encounter any difficulties or have questions during the configuration process, don't hesitate to reach out for assistance.`
        )
      );

    error &&
      process.env.NODE_ENV !== 'development' &&
      setError(
        Error(
          'Sorry, we are unable to process your request at the moment. An unexpected error occurred with our authentication system (Keycloak). Please try again later. If the issue persists, contact our support team for assistance.'
        )
      );
  }, [error]);

  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);

    if (urlParams.has('presentation')) {
      const presentationId = urlParams.get('presentation');
      localStorage.setItem('urlParams', JSON.stringify({ presentation: presentationId }));
    }

    if (urlParams.has('params')) {
      const params = JSON.parse(urlParams.get('params') as string);

      localStorage.setItem('pluginParams', JSON.stringify(params));
    }
  }, []);

  useEffect(() => {
    const fetchKeycloakConfig = async (): Promise<void> => {
      if (!isLoading && data) {
        console.log('data');

        const kc = new Keycloak({
          url: `${data.keycloakConfig.auth}/`,
          realm: data.keycloakConfig.realm,
          clientId: data.keycloakConfig.clientId,
        });

        kc.onAuthError = handleError;
        setKeycloak(kc);
      }
    };

    void fetchKeycloakConfig();
  }, [data, isLoading, handleError]);

  return (
    <>
      {isLoading && <LoadingSpinner />}
      {keycloak && (
        <ReactKeycloakProvider
          onEvent={(event, error) => console.log(event, error)}
          initOptions={{ checkLoginIframe: false, pkceMethod: 'S256' }}
          authClient={keycloak}
          LoadingComponent={<LoadingSpinner />}
        >
          {children}
        </ReactKeycloakProvider>
      )}
    </>
  );
};

export default RegisterLogin;
