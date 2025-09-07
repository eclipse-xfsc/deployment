import { genericFetch } from '@/service/apiService';
import type { BackupUpload } from '@/service/types';
import { AppContext } from '@/store/AppContextProvider';
import { useKeycloak } from '@react-keycloak/web';
import { useTranslations } from 'next-intl';
import { type FormEvent, useState, useContext } from 'react';
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
import QRCode from 'react-qr-code';

interface BackupModalProps {
  show: boolean;
  handleClose: () => void;
}

export interface BackupNameData {
  name: string;
}

const AddBackupModal = ({ show, handleClose }: BackupModalProps): JSX.Element => {
  const { keycloak } = useKeycloak();
  const [formData, setFormData] = useState<BackupNameData>({
    name: '',
  });
  const [showQrCode, setShowQrCode] = useState(false);
  const [qrCode, setQrCode] = useState<string>('');
  const { setError } = useContext(AppContext);
  const t = useTranslations('Backup');

  const handleSubmit = (event: FormEvent<HTMLFormElement>, formData: BackupNameData): void => {
    event.preventDefault();

    const getQrCode = async (): Promise<BackupUpload> => {
      return await genericFetch<BackupUpload>(
        `${process.env.API_URL_ACCOUNT_SERVICE}/credentials/backup/link/upload?name=${formData.name}`,
        {
          headers: {
            Authorization: `Bearer ${keycloak.token}`,
          },
        }
      );
    };

    getQrCode()
      .then(data => {
        setQrCode(data.path);
        setShowQrCode(true);
      })
      .catch(err => setError(err));
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
      <ModalBody className="d-flex flex-column">
        <Form
          onSubmit={event => handleSubmit(event, formData)}
          className="d-flex justify-content-between gap-1 align-items-end"
        >
          <FormGroup
            controlId="backupName"
            className="flex-grow-1"
          >
            <FormLabel>{t('backup-name')}</FormLabel>
            <FormControl
              type="text"
              placeholder={t('backup-name-placeholder')}
              value={formData.name}
              onChange={e => setFormData({ name: e.target.value })}
            />
          </FormGroup>
          <Button type="submit">{t('submit')}</Button>
        </Form>

        {showQrCode && (
          <QRCode
            className="mt-4 align-self-center"
            value={qrCode}
            size={300}
          />
        )}
      </ModalBody>
    </Modal>
  );
};

export default AddBackupModal;
