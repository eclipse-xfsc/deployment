'use client';

import type { Description, CredentialData } from '@/service/types';
import { formatDateString } from '@/utils/dateUtils';
import { useTranslations } from 'next-intl';
import { useEffect, useMemo, useState } from 'react';
import { Col, Container, Row } from 'react-bootstrap';
import { useDrag } from 'react-dnd';
import CardModal from '../card-modal/CardModal';
import css from './CardDocument.module.scss';
import { wrapText } from '@/utils/stringUtils';

export interface CardDocumentProps {
  credential: CredentialData;
  description: Description;
  metadata?: any; // define metadata type when available in the API
  movable?: boolean;
  id: string;
}

function getTitle(credential: CredentialData): string {
  if (Array.isArray(credential.type)) {
    return credential.type[1] ?? credential.type[0];
  } else {
    // @ts-expect-error
    return credential.type ?? credential.Type ?? credential.vct;
  }
}

const CardDocument = ({ credential, description, id, movable = false }: CardDocumentProps): JSX.Element => {
  const t = useTranslations('CredentialsOverview');
  const [showModal, setShowModal] = useState(false);
  const [{ isDragging }, drag] = useDrag({
    type: 'credential',
    item: { credential, id, description },
    collect: monitor => ({
      isDragging: monitor.isDragging(),
    }),
  });

  useEffect(() => {
    if (isDragging) {
      setShowModal(false);
    }
  }, [isDragging]);

  const excludedKeys = useMemo(() => new Set(['cnf', 'iat', 'iss', 'pin_otp', 'vct', '_sd_alg']), []);

  const filteredCredentialData = useMemo(
    () =>
      Object.entries(credential.credentialSubject ?? {})
        .filter(([key]) => !excludedKeys.has(key))
        .slice(0, 5),
    [credential, excludedKeys]
  );

  const renderCredential = (): JSX.Element => {
    const { issuanceDate, credentialSubject } = credential;

    return (
      <div
        className={`${css['card-document']} shadow ${movable ? css.movable : ''}`}
        onClick={() => setShowModal(true)}
      >
        <Container className="d-grid gap-3">
          <Row className="p-1 flex-nowrap">
            <Col className="d-flex flex-column justify-content-center align-items-start">
              <h2 className="display-6">{wrapText(getTitle(credential), 20)}</h2>
              <strong>
                {issuanceDate && (
                  <span>
                    {t('issued-at')} {formatDateString(issuanceDate)}
                  </span>
                )}
              </strong>
            </Col>
          </Row>

          <div>
            {credentialSubject &&
              filteredCredentialData.map(([key, value]) => (
                <Row
                  key={key}
                  className="flex-nowrap"
                >
                  <Col>
                    <span data-label={key}>{key}:</span>
                  </Col>
                  <Col>
                    <strong>
                      {typeof value === 'object' && value.name ? (
                        <div dangerouslySetInnerHTML={{ __html: value.name }}></div>
                      ) : (
                        wrapText(value as string, 20)
                      )}
                    </strong>
                  </Col>
                </Row>
              ))}
          </div>
        </Container>
      </div>
    );
  };

  return (
    <>
      {movable ? <div ref={drag}>{renderCredential()}</div> : renderCredential()}

      <CardModal
        show={showModal}
        handleClose={() => setShowModal(false)}
        data={credential}
        description={description}
        title={wrapText(getTitle(credential), 20)}
      />
    </>
  );
};

export default CardDocument;
