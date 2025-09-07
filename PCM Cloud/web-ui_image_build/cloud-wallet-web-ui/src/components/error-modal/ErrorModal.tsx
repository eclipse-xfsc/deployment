import { Modal, ModalBody, ModalHeader, ModalTitle } from 'react-bootstrap';

interface ErrorModalProps {
  show: boolean;
  handleClose: () => void;
  handleExited?: () => void;
  error: Error;
}

const ErrorModal = ({ show, handleClose, handleExited, error }: ErrorModalProps): JSX.Element => {
  return (
    <Modal
      show={show}
      onHide={handleClose}
      onExited={handleExited}
      centered
    >
      <ModalHeader closeButton>
        <ModalTitle>Error</ModalTitle>
      </ModalHeader>
      <ModalBody>
        <p>{error.message}</p>
      </ModalBody>
    </Modal>
  );
};

export default ErrorModal;
