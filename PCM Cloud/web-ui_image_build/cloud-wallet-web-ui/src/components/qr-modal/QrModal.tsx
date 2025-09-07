'use client';

import { Image, Modal, ModalBody, ModalHeader, ModalTitle } from 'react-bootstrap';
import css from './QrModal.module.scss';
import QRCode from 'react-qr-code';

interface QrModalProps {
  show: boolean;
  handleClose: () => void;
  qrCodeLink: string;
  generate?: boolean;
  title: string;
}

const QrModal = ({ show, handleClose, qrCodeLink, generate, title }: QrModalProps): JSX.Element => {
  return (
    <Modal
      show={show}
      onHide={handleClose}
      centered
    >
      <ModalHeader closeButton>
        <ModalTitle>{title}</ModalTitle>
      </ModalHeader>
      <ModalBody className={`${css['flex-center']} p-5`}>
        <div className={css['qr-code']}>
          {!generate ? (
            <Image
              src={qrCodeLink}
              alt="QR-Code"
              width={300}
            />
          ) : (
            <QRCode
              value={qrCodeLink}
              size={300}
            />
          )}
        </div>
      </ModalBody>
    </Modal>
  );
};

export default QrModal;
