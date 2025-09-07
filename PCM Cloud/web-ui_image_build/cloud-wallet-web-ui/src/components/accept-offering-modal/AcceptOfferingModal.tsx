import { useState, type FormEvent } from 'react';
import { Button, Form, Modal, ModalBody, ModalHeader, ModalTitle } from 'react-bootstrap';
import DidSelection from '../did-selection/DidSelection';
import { useTranslations } from 'next-intl';
import { toast } from 'react-toastify';

interface OfferingModalProps {
  show: boolean;
  handleClose: () => void;
  onSubmit: (did: string) => void;
}

const AcceptDenyOfferingModal = ({ show, handleClose, onSubmit }: OfferingModalProps): JSX.Element => {
  const [selectedDID, setSelectedDID] = useState<string>('');
  const t = useTranslations('Offering');

  const handleAcceptOffering = (event: FormEvent<HTMLFormElement>): void => {
    event.preventDefault();

    if (!selectedDID) {
      toast.error(t('did-empty'));
      return;
    }

    onSubmit(selectedDID);
    setSelectedDID('');
    handleClose();
  };

  return (
    <Modal
      show={show}
      onHide={handleClose}
      centered
    >
      <ModalHeader closeButton>
        <ModalTitle>{t('title')}</ModalTitle>
      </ModalHeader>
      <ModalBody>
        <Form onSubmit={handleAcceptOffering}>
          <DidSelection getSelectedDID={did => setSelectedDID(did)} />
          <Button
            variant="primary"
            type="submit"
            onClick={handleClose}
          >
            {t('accept')}
          </Button>
        </Form>
      </ModalBody>
    </Modal>
  );
};

export default AcceptDenyOfferingModal;
