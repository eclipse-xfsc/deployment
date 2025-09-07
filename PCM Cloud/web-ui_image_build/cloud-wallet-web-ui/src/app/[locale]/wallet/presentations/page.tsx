'use client';

import { Col, Container, Row } from 'react-bootstrap';
import css from './presentations.module.scss';
import Divider from '@/components/divider/Divider';
import type { VerifiableCredentials, VerifiablePresentation } from '@/service/types';
import { useApiData } from '@/service/apiService';
import { useTranslations } from 'next-intl';
import CredentialColumn from '@/components/credential-column/CredentialColumn';
import LoadingSpinner from '@/components/loading-spinner/LoadingSpinner';
import NoData from '@/components/no-data/NoData';
import { useKeycloak } from '@react-keycloak/web';

function mapCredentialToPresentation(credential: VerifiablePresentation): VerifiableCredentials[] {
  const credentials: VerifiableCredentials[] = [];

  Object.keys(credential.credentials).forEach(key => {
    const presentation = credential.credentials[key];
    const verifiableCredentials = presentation.verifiableCredential;

    if (!verifiableCredentials) return;

    verifiableCredentials.forEach(credential => {
      credentials.push({
        description: {
          id: presentation.id ?? '',
          // @ts-expect-error
          name: presentation.type,
          format: credential.proof?.proofPurpose,
          purpose: credential.proof?.proofPurpose,
        },
        credentials: {
          [key]: credential,
        },
      });
    });
  });

  return credentials;
}

const Presentations = (): JSX.Element => {
  const { keycloak } = useKeycloak();
  const { data, isLoading } = useApiData<VerifiablePresentation[]>(
    'presentationList',
    `${process.env.API_URL_ACCOUNT_SERVICE}/presentations/list`,
    { headers: { Authorization: `Bearer ${keycloak.token}` }, method: 'POST' }
  );
  const t = useTranslations('PresentationsList');

  return (
    <Container
      fluid
      className="overflow-hidden"
    >
      <Row>
        <Col
          md="6"
          sm="12"
          className={`${css['flex-center']} justify-content-between gap-2 mb-2`}
        >
          <h1 className="mb-0">{t('title')}</h1>
        </Col>
      </Row>

      <Divider className="my-2" />

      <div className={css['cards-container']}>
        {data && !isLoading ? (
          data?.map(presentation => {
            const credentials = mapCredentialToPresentation(presentation);
            const presentationDetails = presentation.credentials[Object.keys(presentation.credentials)[0]];

            return credentials.map((credential, index) => (
              <CredentialColumn
                key={index}
                credential={credential}
                presentation={presentationDetails}
              />
            ));
          })
        ) : isLoading ? (
          <div className={`${css['flex-center']}`}>
            <LoadingSpinner />
          </div>
        ) : (
          <div className={`${css['flex-center']} w-100`}>
            <NoData />
          </div>
        )}
      </div>
    </Container>
  );
};

export default Presentations;
