import { Spinner } from 'react-bootstrap';

const loading = (): JSX.Element => {
  return (
    <div
      className="w-100 d-flex justify-content-center align-items-center position-relative"
      style={{ height: 'calc(100% - 8rem)' }}
    >
      <Spinner
        animation="border"
        variant="primary"
      />
    </div>
  );
};

export default loading;
