import { AppContext } from '@/store/AppContextProvider';
import { useQuery } from '@tanstack/react-query';
import { useContext, useEffect } from 'react';

interface IApiData<T> {
  data: T | undefined;
  isLoading: boolean;
  error: Error | null;
}

export const genericFetch = async <T>(url: string, config?: RequestInit): Promise<T> => {
  try {
    const response = await fetch(url, config);

    if (!response.ok) {
      throw new Error(`Request failed with status: ${response.status}`);
    }

    const data: T = await response.json();

    return data;
  } catch (error) {
    throw new Error(String(error));
  }
};

export const useApiData = <T>(queryKey: string, url: string, config?: RequestInit): IApiData<T> => {
  const { setError } = useContext(AppContext);

  const useGenericFetch = async (): Promise<T> => {
    return await genericFetch<T>(url, config);
  };

  const { data, isLoading, error } = useQuery({
    queryKey: [queryKey],
    queryFn: useGenericFetch,
  });

  useEffect(() => {
    if (error) {
      setError(error);
    }
  }, [error, setError]);

  return { data, isLoading, error };
};
