import type { CredentialInPresentation } from '@/service/types';
import { useTranslations } from 'next-intl';
import { useEffect } from 'react';
import { Col, Modal, ModalBody, ModalHeader, ModalTitle, Row } from 'react-bootstrap';
import SyntaxHighlighter from 'react-syntax-highlighter/dist/esm/default-highlight';
import { a11yDark } from 'react-syntax-highlighter/dist/esm/styles/hljs';

interface PresentationModalProps {
  show: boolean;
  handleClose: () => void;
  data: CredentialInPresentation;
  title: string;
}

const PresentationModal = ({ show, handleClose, data, title }: PresentationModalProps): JSX.Element => {
  const t = useTranslations('PresentationsList');

  useEffect(() => {
    if (!data) return;

    // @ts-expect-error
    delete data.verifiableCredential;
  }, [data]);

  return (
    <Modal
      show={show}
      onHide={handleClose}
      centered
    >
      <ModalHeader closeButton>
        <ModalTitle>{title}</ModalTitle>
      </ModalHeader>
      <ModalBody>
        <div>
          <Row>
            <Col>
              <strong>{t('presentation')}</strong>
            </Col>
          </Row>
          <Row>
            <Col>
              <div className="py-1">
                <SyntaxHighlighter
                  language="json"
                  style={a11yDark}
                  customStyle={{ borderRadius: '1rem' }}
                >
                  {JSON.stringify(data, null, 2)}
                </SyntaxHighlighter>
              </div>
            </Col>
          </Row>
        </div>
      </ModalBody>
    </Modal>
  );
};

export default PresentationModal;
