'use client';

import CredentialColumn from '@/components/credential-column/CredentialColumn';
import Divider from '@/components/divider/Divider';
import LoadingSpinner from '@/components/loading-spinner/LoadingSpinner';
import NoData from '@/components/no-data/NoData';
import SearchButton from '@/components/search-button/SearchButton';
import { genericFetch, useApiData } from '@/service/apiService';
import type {
  CredentialData,
  CredentialList,
  CodedVerifiableCredentials,
  VerifiableCredentials,
} from '@/service/types';
import { AppContext } from '@/store/AppContextProvider';
import { debounce } from '@/utils/timeUtils';
import { useKeycloak } from '@react-keycloak/web';
import { digest } from '@sd-jwt/crypto-nodejs';
import { decodeSdJwt } from '@sd-jwt/decode';
import { useTranslations } from 'next-intl';
import { useCallback, useContext, useEffect, useState } from 'react';
import { Col, Container, Row } from 'react-bootstrap';
import css from './wallet.module.scss';

const Wallet = (): JSX.Element => {
  const { keycloak } = useKeycloak();
  const { data, isLoading } = useApiData<CodedVerifiableCredentials[]>(
    'credentialList',
    `${process.env.API_URL_ACCOUNT_SERVICE}/credentials/list`,
    {
      headers: { Authorization: `Bearer ${keycloak.token}` },
      body: JSON.stringify({ search: '' }),
      method: 'POST',
    }
  );
  const { setError } = useContext(AppContext);
  const t = useTranslations('CredentialsOverview');
  const [filteredCredentials, setFilteredCredentials] = useState<VerifiableCredentials[]>([]);

  useEffect(() => {
    if (!data) return;

    getDecodedCredentials(data).then(setFilteredCredentials).catch(setError);
  }, [data]);

  const decodeCredential = async (credential: CodedVerifiableCredentials): Promise<VerifiableCredentials> => {
    const { credentials, description } = credential;

    const decodedEntries: CredentialList[] = await Promise.all(
      Object.keys(credentials).map(async key => {
        let decodedCredentials: CredentialData;

        if (credentials[key].type === 'vc+sd-jwt') {
          const decodedCredential = await decodeSdJwt(credentials[key].data, digest);

          decodedCredentials = {
            vct: decodedCredential.jwt.payload.vct as string,
            issuer: decodedCredential.jwt.payload.iss as string,
            issuanceDate: decodedCredential.jwt.payload.iat as string,
            credentialSubject: decodedCredential.jwt.payload as Record<string, string>,
          };
        } else {
          decodedCredentials = JSON.parse(credentials[key].data);
        }

        return {
          [key]: decodedCredentials,
        };
      })
    );

    return {
      description,
      credentials: decodedEntries.reduce((acc, entry) => ({ ...acc, ...entry }), {}),
    };
  };

  const getDecodedCredentials = useCallback(
    async (credentials: CodedVerifiableCredentials[]): Promise<VerifiableCredentials[]> => {
      if (!credentials) return [];
      return await Promise.all(credentials.map(decodeCredential));
    },
    []
  );

  const handleOnSearch = debounce((searchValue: string): void => {
    const getFilteredCredentials = async (): Promise<CodedVerifiableCredentials[]> => {
      return await genericFetch<CodedVerifiableCredentials[]>(
        `${process.env.API_URL_ACCOUNT_SERVICE}/credentials/list`,
        {
          headers: { Authorization: `Bearer ${keycloak.token}` },
          body: JSON.stringify({ search: searchValue }),
          method: 'POST',
        }
      );
    };

    getFilteredCredentials()
      .then(async data => await getDecodedCredentials(data))
      .then(setFilteredCredentials)
      .catch(setError);
  }, 500);

  const renderCredentials = (): JSX.Element | JSX.Element[] | null => {
    if (isLoading) {
      return (
        <div className={`${css['flex-center']}`}>
          <LoadingSpinner />
        </div>
      );
    }

    if (!filteredCredentials.length) {
      return (
        <div className={`${css['flex-center']} w-100`}>
          <NoData />
        </div>
      );
    }

    return filteredCredentials.map((credential, i) => (
      <CredentialColumn
        key={credential?.description?.id ?? i}
        credential={credential}
      />
    ));
  };

  return (
    <Container fluid>
      <Row>
        <Col className={`${css['flex-center']} justify-content-between gap-2 mb-2`}>
          <div className="d-flex gap-2 align-items-center">
            <h1 className="mb-0">{t('title')}</h1>
          </div>
        </Col>
        <Col className={`${css['flex-center']} justify-content-end gap-2`}>
          <SearchButton onSearch={handleOnSearch} />
        </Col>
      </Row>

      <Divider className="my-2" />

      <div className={css['cards-container']}>{renderCredentials()}</div>
    </Container>
  );
};

export default Wallet;
