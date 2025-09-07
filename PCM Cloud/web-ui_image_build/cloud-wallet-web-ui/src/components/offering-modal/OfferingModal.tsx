'use client';

import { useTranslations } from 'next-intl';
import { type FormEvent, useState } from 'react';
import {
  Button,
  Form,
  FormControl,
  FormGroup,
  FormLabel,
  Modal,
  ModalBody,
  ModalHeader,
  ModalTitle,
} from 'react-bootstrap';
import { toast } from 'react-toastify';

interface OfferingModalProps {
  show: boolean;
  handleClose: () => void;
  onSubmit: (data: OfferingLinkData) => void;
}

export interface OfferingLinkData {
  offeringLink: string;
}

const OfferingModal = ({ show, handleClose, onSubmit }: OfferingModalProps): JSX.Element => {
  const [formData, setFormData] = useState<OfferingLinkData>({
    offeringLink: '',
  });
  const t = useTranslations('Offering');

  const handleSubmit = (event: FormEvent<HTMLFormElement>, formData: OfferingLinkData): void => {
    event.preventDefault();

    if (formData.offeringLink === '') {
      toast.error(t('empty-offering'));
      return;
    }

    onSubmit(formData);
    setFormData({
      offeringLink: '',
    });
    handleClose();
  };

  return (
    <Modal
      show={show}
      onHide={handleClose}
      centered
    >
      <ModalHeader closeButton>
        <ModalTitle>{t('add')}</ModalTitle>
      </ModalHeader>
      <ModalBody>
        <Form
          onSubmit={event => handleSubmit(event, formData)}
          className="d-flex justify-content-between gap-1 align-items-end"
        >
          <FormGroup
            controlId="offeringLink"
            className="flex-grow-1"
          >
            <FormLabel>{t('offering-link')}</FormLabel>
            <FormControl
              type="text"
              placeholder={t('enter-offering')}
              value={formData.offeringLink}
              onChange={e => setFormData({ offeringLink: e.target.value })}
            />
          </FormGroup>
          <Button type="submit">{t('submit')}</Button>
        </Form>
      </ModalBody>
    </Modal>
  );
};

export default OfferingModal;
