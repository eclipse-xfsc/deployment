import type { Description, CredentialData } from '@/service/types';
import { Col, Modal, ModalBody, ModalHeader, ModalTitle, Row } from 'react-bootstrap';
import Divider from '../divider/Divider';
import SyntaxHighlighter from 'react-syntax-highlighter/dist/esm/default-highlight';
import { a11yDark } from 'react-syntax-highlighter/dist/esm/styles/hljs';

interface CardModalProps {
  show: boolean;
  handleClose: () => void;
  data: CredentialData;
  description: Description;
  title: string;
}

const CardModal = ({ show, handleClose, data, description, title }: CardModalProps): JSX.Element => {
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
        <Row>
          <Col>
            <strong>Fields:</strong>
          </Col>
        </Row>
        <div>
          {Object.entries(data.credentialSubject ?? {}).map(([key, value]) => {
            if (typeof value === 'object' && !value?.name) {
              return null;
            }

            let displayValue = value;

            if (typeof value === 'object') {
              // @ts-expect-error
              displayValue = <div dangerouslySetInnerHTML={{ __html: value.name }}></div>;
            } else if (typeof value === 'boolean') {
              // @ts-expect-error
              displayValue = value.toString();
            }

            return (
              <Row
                key={key}
                className="flex-nowrap"
              >
                <Col>
                  <span data-label={key}>{key}:</span>
                </Col>
                <Col
                  style={{
                    overflowWrap: 'anywhere',
                    wordBreak: 'break-all',
                  }}
                >
                  {/* @ts-expect-error */}
                  <strong>{displayValue}</strong>
                </Col>
              </Row>
            );
          })}

          <Divider className="my-3" />

          <Row>
            <Col>
              <strong>Description:</strong>
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
                  {JSON.stringify(description, null, 2)}
                </SyntaxHighlighter>
              </div>
            </Col>
          </Row>

          <Divider className="my-2" />

          <Row>
            <Col>
              <strong>Credential:</strong>
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

export default CardModal;
