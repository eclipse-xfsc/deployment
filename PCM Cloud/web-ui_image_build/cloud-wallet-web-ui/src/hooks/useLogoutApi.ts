import type { KeycloakConfig } from '@/service/types';
import { useCallback } from 'react';

// eslint-disable-next-line @typescript-eslint/explicit-function-return-type
const useLogoutApi = (keycloakConfig: KeycloakConfig, token?: string, refreshToken?: string) => {
  const logOut = useCallback(async (onSuccess?: () => void) => {
    try {
      await fetch(`${keycloakConfig.auth}/realms/${keycloakConfig.realm}/protocol/openid-connect/logout`, {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          Authorization: `Bearer ${token}`,
        },
        credentials: 'include',
        method: 'POST',
        body: `client_id=${keycloakConfig.clientId}&refresh_token=${refreshToken}`,
      });

      onSuccess && onSuccess();
    } catch (error) {
      console.log(error);
    }
  }, []);

  return [logOut] as const;
};

export default useLogoutApi;
