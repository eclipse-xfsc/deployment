import { Spinner } from 'react-bootstrap';

const loading = (): JSX.Element => {
  return (
    <div className="w-100 h-100 d-flex justify-content-center align-items-center">
      <Spinner
        animation="border"
        variant="primary"
      />
    </div>
  );
};

export default loading;
