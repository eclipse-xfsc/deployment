import { Button, Modal, ModalBody, ModalHeader, ModalTitle } from 'react-bootstrap';

interface PermissionRedirectModalProps {
  show: boolean;
  handleClose: () => void;
  onSubmit: (allow: boolean) => void;
  redirect: string;
}

const PermissionRedirectModal = ({
  show,
  handleClose,
  onSubmit,
  redirect,
}: PermissionRedirectModalProps): JSX.Element => {
  return (
    <Modal
      show={show}
      onHide={handleClose}
      centered
    >
      <ModalHeader closeButton>
        <ModalTitle>Consent</ModalTitle>
      </ModalHeader>
      <ModalBody className="d-flex flex-column gap-3">
        <p>
          Do you want to allow the redirect to <strong>{redirect}</strong>?
        </p>
        <div className="d-flex justify-content-between gap-1">
          <Button
            className="flex-grow-1"
            onClick={() => onSubmit(true)}
          >
            Allow
          </Button>
          <Button
            className="flex-grow-1"
            onClick={() => onSubmit(false)}
          >
            Deny
          </Button>
        </div>
      </ModalBody>
    </Modal>
  );
};

export default PermissionRedirectModal;
