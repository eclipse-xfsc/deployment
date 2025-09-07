import { Modal, ModalBody, ModalHeader, ModalTitle, Spinner } from 'react-bootstrap';
import { genericFetch } from '@/service/apiService';
import { type TableBodyMap } from '../table/Table';
import { AppContext } from '@/store/AppContextProvider';
import { useContext, useEffect, useState } from 'react';
import { useKeycloak } from '@react-keycloak/web';

interface DetailsModalProps {
  show: boolean;
  handleClose: () => void;
  data: string | TableBodyMap;
  title: string;
}

const DetailsModal = ({ show, handleClose, data, title }: DetailsModalProps): JSX.Element => {
  const { keycloak } = useKeycloak();
  const { setError } = useContext(AppContext);
  const [fetchedData, setFetchedData] = useState<TableBodyMap | null>(null);

  useEffect(() => {
    if (!data) return;

    if (typeof data === 'string') {
      void handleGetDetails(data);
    } else if (typeof data === 'object') {
      setFetchedData(data);
    }
  }, [data]);

  const handleGetDetails = async (url: string): Promise<void> => {
    try {
      const response = await genericFetch<any>(url, {
        headers: {
          Authorization: `Bearer ${keycloak.token}`,
        },
      });

      setFetchedData(new Map([['see-details', response]]));
    } catch (error: any) {
      setError(error);
      handleClose();
    }
  };

  const renderValue = (value: any): JSX.Element => {
    if (Array.isArray(value)) {
      return (
        <div style={{ marginLeft: '20px' }}>
          {value.map((item, index) => {
            return <div key={index}>[{renderValue(item)}]</div>;
          })}
        </div>
      );
    } else if (typeof value === 'object' && value !== null) {
      return (
        <div>
          {Object.keys(value).map((key, index) => (
            <div
              key={index}
              style={{ marginLeft: '20px' }}
            >
              <span style={{ fontWeight: 'bold' }}>{key}: </span>
              {renderValue(value[key])}
            </div>
          ))}
        </div>
      );
    } else {
      return <span>{value}</span>;
    }
  };

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
        {fetchedData ? (
          <div>
            {Array.from(fetchedData.values()).map((row, i) => (
              <div key={i}>
                {Object.keys(row).map((key, j) => (
                  <div key={j}>
                    <span style={{ fontWeight: 'bold' }}>{key}: </span>
                    {renderValue(row[key])}
                  </div>
                ))}
              </div>
            ))}
          </div>
        ) : (
          <div className="d-flex justify-content-center">
            <Spinner
              animation="border"
              variant="primary"
            />
          </div>
        )}
      </ModalBody>
    </Modal>
  );
};

export default DetailsModal;
