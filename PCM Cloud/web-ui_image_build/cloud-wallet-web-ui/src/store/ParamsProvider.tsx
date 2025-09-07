import PermissionRedirectModal from '@/components/permission-redirect-modal/PermissionRedirectModal';
import { type Plugin } from '@/components/side-menu/WalletSideMenu';
import { genericFetch } from '@/service/apiService';
import { type VerifiableCredentials } from '@/service/types';
import { useKeycloak } from '@react-keycloak/web';
import { useQueryClient } from '@tanstack/react-query';
import { useLocale } from 'next-intl';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { toast } from 'react-toastify';
import { useLocalStorage } from 'usehooks-ts';

interface UrlParams {
  presentation: string;
}

interface PluginParams {
  plugin: string;
  type: string;
  userHint: string;
  version: string;
  payload: any;
}

const ParamsProvider = ({ children }: { children: React.ReactNode }): JSX.Element => {
  const locale = useLocale();
  const router = useRouter();
  const { keycloak } = useKeycloak();
  const data = useQueryClient().getQueryData<Plugin[]>(['pluginDiscovery']);
  const [urlParams] = useLocalStorage<UrlParams | null>('urlParams', null);
  const [pluginParams, setPluginParams] = useLocalStorage<PluginParams | null>('pluginParams', null);
  const [showModal, setShowModal] = useState(false);

  useEffect(() => {
    if (urlParams) {
      presentationSelection(urlParams.presentation).catch(() => {
        toast.error('Failed to fetch presentation');
      });

      router.push(`/${locale}/wallet/selection`);
    }

    if (pluginParams) {
      if (!data?.find(plugin => plugin.route === pluginParams.plugin)) {
        toast.error('Plugin not found');
        return;
      }

      if (pluginParams.type.toLowerCase() === 'consent') {
        setShowModal(true);
        return;
      }

      router.push(`/${locale}/wallet/plugins/${pluginParams.plugin}`);
    }
  }, [urlParams, pluginParams]);

  const handleOnSubmit = (confirm: boolean): void => {
    console.log('handleOnSubmit', confirm, pluginParams);
    setShowModal(false);

    if (confirm && pluginParams) {
      genericFetch<any>(
        `${process.env.API_URL}/dynamic/plugins/${pluginParams.plugin}/application/event/accounts.record`,
        {
          headers: {
            Authorization: `Bearer ${keycloak.token}`,
          },
          body: JSON.stringify({
            message: `User redirected to ${locale}/wallet/plugins/${pluginParams.plugin}`,
            type: 'consent',
          }),
          method: 'POST',
        }
      ).catch(() => {
        toast.error('Failed to record event');
      });

      router.push(`/${locale}/wallet/plugins/${pluginParams.plugin}`);
      return;
    }

    setPluginParams(null);
    const url = new URL(window.location.href);
    url.searchParams.delete('params');
    router.push(url.pathname);
  };

  const presentationSelection = async (presentationId: string): Promise<VerifiableCredentials[]> => {
    return await genericFetch(`${process.env.API_URL_ACCOUNT_SERVICE}/presentations/selection/${presentationId}`, {
      headers: {
        Authorization: `Bearer ${keycloak.token}`,
      },
    });
  };

  return (
    <>
      {children}
      {pluginParams && (
        <PermissionRedirectModal
          show={showModal}
          handleClose={() => handleOnSubmit(false)}
          onSubmit={handleOnSubmit}
          redirect={`/${locale}/wallet/plugins/${pluginParams.plugin}`}
        />
      )}
    </>
  );
};

export default ParamsProvider;
