'use client';

import { useKeycloak } from '@react-keycloak/web';
import LoadingSpinner from '../loading-spinner/LoadingSpinner';

interface KeycloakLoginInterceptorProps {
  children: React.ReactNode;
}

const KeycloakLoginInterceptor = ({ children }: KeycloakLoginInterceptorProps): JSX.Element => {
  const { initialized, keycloak } = useKeycloak();

  return (
    <>
      {!initialized && <LoadingSpinner />}
      {initialized && keycloak.authenticated && children}
    </>
  );
};

export default KeycloakLoginInterceptor;
