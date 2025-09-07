'use client';

import css from './Header.module.scss';
import SearchUserLoginState from './SearchUserLoginState';
import useLogoutApi from '@/hooks/useLogoutApi';
import { useRouter } from 'next/navigation';
import { useContext } from 'react';
import { AppContext } from '@/store/AppContextProvider';
import { useQueryClient } from '@tanstack/react-query';
import type { KeycloakAndMetadata } from '@/service/types';
import { useLocale, useTranslations } from 'next-intl';
import { useKeycloak } from '@react-keycloak/web';

const AccountButton = (): JSX.Element => {
  const { keycloak } = useKeycloak();
  const data = useQueryClient().getQueryData<KeycloakAndMetadata>(['keycloakConfigAndMetadata']);
  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  const [logOut] = useLogoutApi(data!.keycloakConfig, keycloak.token, keycloak.refreshToken);
  const router = useRouter();
  const locale = useLocale();
  const { setError } = useContext(AppContext);
  const t = useTranslations('Auth');

  const handleSignIn = (): void => {
    keycloak
      .login({
        redirectUri: `${process.env.ENV_URL ?? 'http://localhost:3000'}/${locale}/wallet/credentials`,
      })
      .catch(setError);
  };

  const handleSignOut = (): void => {
    logOut()
      .then(() => {
        router.push(`/${locale}/`);

        window.location.reload();
      })
      .catch(setError);
  };

  return (
    <div className={css['flex-center']}>
      {!keycloak.authenticated && (
        <SearchUserLoginState
          text={t('login')}
          onClick={handleSignIn}
        />
      )}
      {keycloak.authenticated && (
        <SearchUserLoginState
          text={t('logout')}
          onClick={handleSignOut}
        />
      )}
    </div>
  );
};

export default AccountButton;
