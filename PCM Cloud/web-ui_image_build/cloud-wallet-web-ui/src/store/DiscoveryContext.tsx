import { type Plugin } from '@/components/side-menu/WalletSideMenu';
import { genericFetch } from '@/service/apiService';
import type { DefaultConfig } from '@/service/types';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useContext, useEffect } from 'react';
import { Spinner } from 'react-bootstrap';
import { AppContext } from './AppContextProvider';
import { useLocale } from 'next-intl';
import { usePathname, useRouter } from 'next/navigation';
import { useKeycloak } from '@react-keycloak/web';

interface DiscoveryContextProps {
  children: React.ReactNode;
}

const DiscoveryContext = ({ children }: DiscoveryContextProps): JSX.Element => {
  const { keycloak } = useKeycloak();
  const currentLocale = useLocale();
  const router = useRouter();
  const pathname = usePathname();
  const queryClient = useQueryClient();
  const {
    data: configData,
    isLoading: configIsLoading,
    error: configError,
  } = useQuery({
    queryKey: ['defaultConfig'],
    queryFn: getDefaultSettings,
  });
  const { isLoading: pluginIsLoading } = useQuery({
    queryKey: ['pluginDiscovery'],
    queryFn: getPluginDiscovery,
  });
  const { setError } = useContext(AppContext);

  useEffect(() => {
    if (configError) void setDefaultSettings();
  }, [configError]);

  useEffect(() => {
    if (!configData) return;

    if (configData.language.toLocaleLowerCase() !== currentLocale) {
      const newPathname = pathname.replace(/^\/[^/]+/, `/${configData.language.toLowerCase()}`);
      router.push(newPathname);
    }
  }, [configData]);

  async function getPluginDiscovery(): Promise<Plugin[]> {
    return await genericFetch<Plugin[]>(`${process.env.API_URL_ACCOUNT_SERVICE}/plugin-discovery`, {
      headers: {
        Authorization: `Bearer ${keycloak.token}`,
      },
    });
  }

  async function getDefaultSettings(): Promise<DefaultConfig> {
    return await genericFetch<DefaultConfig>(`${process.env.API_URL_ACCOUNT_SERVICE}/configurations/list`, {
      headers: {
        Authorization: `Bearer ${keycloak.token}`,
      },
    });
  }

  async function setDefaultSettings(): Promise<void> {
    await genericFetch(`${process.env.API_URL_ACCOUNT_SERVICE}/configurations/save`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${keycloak.token}`,
      },
      body: JSON.stringify({
        language: 'en',
        historyLimit: 10,
      }),
    })
      .then(async () => {
        await queryClient.refetchQueries({ queryKey: ['defaultConfig'] });
      })
      .catch(error => {
        setError(error as Error);
      });
  }

  if (pluginIsLoading || configIsLoading) {
    return (
      <div
        className="position-absolute vw-100 vh-100 z-3 d-flex justify-content-center align-items-center"
        style={{ backgroundColor: '#f8f9fc' }}
      >
        <Spinner
          animation="border"
          variant="primary"
        />
      </div>
    );
  }

  return <>{children}</>;
};

export default DiscoveryContext;
